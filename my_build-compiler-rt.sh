#!/bin/sh
#
# Copyright (c) 2018 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

SRC_DIR=../lib/builtins
BUILD_SUFFIX=
BUILD_BUILTINS=TRUE
ENABLE_CFGUARD=1
CFGUARD_CFLAGS="-mguard=cf"

while [ $# -gt 0 ]; do
    case "$1" in
    --build-sanitizers)
        SRC_DIR=..
        BUILD_SUFFIX=-sanitizers
        SANITIZERS=1
        BUILD_BUILTINS=FALSE
        # Override the default cfguard options here; this unfortunately
        # also overrides the user option if --enable-cfguard is passed
        # before --build-sanitizers (although that combination isn't
        # really intended/supported anyway).
        CFGUARD_CFLAGS=
        ENABLE_CFGUARD=
        ;;
    --enable-cfguard)
        CFGUARD_CFLAGS="-mguard=cf"
        ENABLE_CFGUARD=1
        ;;
    --disable-cfguard)
        CFGUARD_CFLAGS=
        ENABLE_CFGUARD=
        ;;
    --use-exsting-compiler)
        USE_EXISTING_COMPILER=1
        ;;
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done

if [ -z "$PREFIX" ]; then
    echo "$0 [--build-sanitizers] [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi
if [ -n "$SANITIZERS" ] && [ -n "$ENABLE_CFGUARD" ]; then
    echo "warning: Sanitizers may not work correctly with Control Flow Guard enabled." 1>&2
fi

if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
        TARGET_WINDOWS=1
        ;;
    *-unknown-elf)
        TARGET_WINDOWS=1
        ;;
    esac
else
    case $(uname) in
    MINGW*)
        TARGET_WINDOWS=1
        ;;
    esac
fi

mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64}}

ANY_ARCH=$(echo $ARCHS | awk '{print $1}')
if [ -n "$USE_EXISTING_COMPILER" ]; then
    NATIVE_PREFIX=/opt/llvm-mingw
else
    NATIVE_PREFIX=$PREFIX
fi
NATIVE_PREFIX="$(cd "$NATIVE_PREFIX" && pwd)"
export PATH="$NATIVE_PREFIX/bin:$PATH"

if [ ! -d llvm-project/compiler-rt ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

if command -v ninja >/dev/null; then
    CMAKE_GENERATOR="Ninja"
else
    : ${CORES:=$(nproc 2>/dev/null)}
    : ${CORES:=$(sysctl -n hw.ncpu 2>/dev/null)}
    : ${CORES:=4}

    case $(uname) in
    MINGW*)
        CMAKE_GENERATOR="MSYS Makefiles"
        ;;
    esac
fi

cd llvm-project/compiler-rt
# Use a staging directory in case parts of the resource dir are immutable
WORKDIR=$(mktemp -d); trap "rm -rf $WORKDIR" 0
echo "WORKDIR=$WORKDIR"
echo "ARCHS=$ARCHS"

for arch in $ARCHS; do
    if [ "$arch" = "riscv32" ]; then
        toolchain=$arch-unknown-elf
        CMAKE_SYSTEM_NAME=generic
        OPTIONNAL_FLAGS="-DCOMPILER_RT_BAREMETAL_BUILD=ON -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF"
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_SYSTEM_NAME=Generic -DCMAKE_SYSTEM_PROCESSOR=riscv32 -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/riscv32-unknown-elf -DCMAKE_CXX_COMPILER=riscv32-unknown-elf-clang -DCMAKE_ASM_COMPILER=riscv32-unknown-elf-clang -DCMAKE_C_COMPILER=riscv32-unknown-elf-clang -DCMAKE_C_COMPILER_TARGET=riscv32-unknown-elf -DCMAKE_C_COMPILER=riscv32-unknown-elf-clang -DCMAKE_CXX_COMPILER=riscv32-unknown-elf-clang++ -DCMAKE_C_FLAGS=\"--target=riscv32-unknown-elf\" -DCMAKE_CXX_FLAGS=\"--target=riscv32-unknown-elf\" -DCMAKE_ASM_FLAGS=\"--target=riscv32-unknown-elf\""
    else
        if [ -n "$TARGET_WINDOWS" ]; then
            toolchain=$arch-w64-mingw32
            CMAKE_SYSTEM_NAME=windows
            OPTIONNAL_FLAGS="-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/$arch-w64-mingw32"
        else
            toolchain=$arch-linux-gnu
            CMAKE_SYSTEM_NAME=linux
            # linux shared library must be position independent
            # add libc++ path
            OPTIONNAL_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/$arch-linux-gnu"
        fi
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_C_COMPILER_TARGET=$toolchain"
    fi
    CLANG_RESOURCE_DIR="$("$NATIVE_PREFIX/bin/$toolchain-clang" --print-resource-dir)"
    SUFFIX="${CLANG_RESOURCE_DIR#"$NATIVE_PREFIX"}"
    CLANG_RESOURCE_DIR="$PREFIX$SUFFIX"
    NATIVE_CLANG_RESOURCE_DIR="$NATIVE_PREFIX$SUFFIX"
    INSTALL_PREFIX="$CLANG_RESOURCE_DIR"
    if [ -n "$SANITIZERS" ]; then
        case $arch in
        i686|x86_64)
            # Sanitizers on windows only support x86.
            ;;
        *)
            continue
            ;;
        esac
    fi
    TOOLCHAIN_PATH="$NATIVE_PREFIX/$toolchain"
    echo "TOOLCHAIN_PATH=$TOOLCHAIN_PATH"
    # if TOOLCHAIN_PATH is exist
    if [ -d "$TOOLCHAIN_PATH" ]; then
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_SHARED_LINKER_FLAGS=-L$NATIVE_PREFIX/$toolchain/lib -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/$toolchain -DCMAKE_C_COMPILER=$toolchain-clang -DCMAKE_CXX_COMPILER=$toolchain-clang++"
        LINK_FLAG="-Wl,-L${NATIVE_PREFIX}/${toolchain}/lib,-L${NATIVE_PREFIX}/lib/clang/18/lib/${CMAKE_SYSTEM_NAME}" 
        COMMON_C_FLAG="-fPIC -I${NATIVE_PREFIX}/${toolchain}/include/c++/v1"
        if [ -z "$TARGET_WINDOWS" ]; then
            COMMON_C_FLAG="${COMMON_C_FLAG} -isystem /usr/include"
            COMPILER_RT_BUILD_LIBFUZZER=ON
        else
            COMPILER_RT_BUILD_LIBFUZZER=ON
        fi
    else
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_C_COMPILER=${toolchain}-clang -DCMAKE_CXX_COMPILER=${toolchain}-clang++"
        LINK_FLAG="" 
        COMMON_C_FLAG="-fPIC"   
        if [ -n "$TARGET_WINDOWS" ]; then
            echo "windows withtout toolchain path"
        else
            echo "NOT windows withtout toolchain path"
            LINK_FLAG="${LINK_FLAG} "
            COMMON_C_FLAG="${COMMON_C_FLAG} -I${NATIVE_PREFIX}/${toolchain}/include/c++/v1"
        fi
    fi
    
    [ -z "$CLEAN" ] || rm -rf build-$toolchain$BUILD_SUFFIX
    mkdir -p build-$toolchain$BUILD_SUFFIX
    cd build-$toolchain$BUILD_SUFFIX
    [ -n "$NO_RECONF" ] || rm -rf CMake*
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        ${OPTIONNAL_FLAGS} \
        -DCMAKE_INSTALL_PREFIX="$NATIVE_CLANG_RESOURCE_DIR" \
        -DCMAKE_AR="$NATIVE_PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$NATIVE_PREFIX/bin/llvm-ranlib" \
        -DCMAKE_C_COMPILER_WORKS=1 \
        -DCMAKE_CXX_COMPILER_WORKS=1 \
        -DCMAKE_C_FLAGS="${COMMON_C_FLAG}" -DCMAKE_CXX_FLAGS="${COMMON_C_FLAG}" -DCMAKE_ASM_FLAGS="${COMMON_C_FLAG}" -DCOMPILER_RT_BUILD_LIBFUZZER=$COMPILER_RT_BUILD_LIBFUZZER \
        -DCMAKE_EXE_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_MODULE_LINKER_FLAGS="${LINK_FLAG}" \
        -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
        -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
        -DCOMPILER_RT_BUILD_BUILTINS=$BUILD_BUILTINS \
        -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
        -DLLVM_CONFIG_PATH="" \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DSANITIZER_CXX_ABI=libc++ \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" -DCMAKE_VERBOSE_MAKEFILE=ON  \
        $SRC_DIR

    cmake --build . ${CORES:+-j${CORES}} --verbose
    cmake --install . --prefix "${WORKDIR}/install"
    mkdir -p "$PREFIX/$toolchain/bin"
    if [ -n "$SANITIZERS" ]; then
        if [ -n "$TARGET_WINDOWS" ]; then
            mv "${WORKDIR}/install/lib/$CMAKE_SYSTEM_NAME/"*.dll "$PREFIX/$toolchain/bin"
        else
            mv "${WORKDIR}/install/lib/$CMAKE_SYSTEM_NAME/"*.so "$PREFIX/$toolchain/bin"
        fi
    fi
    cd ..
done

if [ -h "$CLANG_RESOURCE_DIR/include" ]; then
    # symlink to system headers - skip copy
    rm -rf ${WORKDIR}/install/include
fi
mkdir -p $CLANG_RESOURCE_DIR
cp -r ${WORKDIR}/install/. $CLANG_RESOURCE_DIR
