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

BUILD_STATIC=ON
BUILD_SHARED=ON
CFGUARD_CFLAGS="-mguard=cf"

while [ $# -gt 0 ]; do
    case "$1" in
    --disable-shared)
        BUILD_SHARED=OFF
        ;;
    --enable-shared)
        BUILD_SHARED=ON
        ;;
    --disable-static)
        BUILD_STATIC=OFF
        ;;
    --enable-static)
        BUILD_STATIC=ON
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
    echo "$0 [--disable-shared] [--disable-static] [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi
if [ -n "$HOST" ]; then
    case $HOST in
    *-mingw32)
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
if [ -n "$USE_EXISTING_COMPILER" ]; then
    NATIVE_PREFIX=/opt/llvm-mingw
else
    NATIVE_PREFIX=$PREFIX
fi
NATIVE_PREFIX="$(cd "$NATIVE_PREFIX" && pwd)"
export PATH="$NATIVE_PREFIX/bin:$PATH"

: ${ARCHS:=${TOOLCHAIN_ARCHS-x86_64 i686}}

if [ ! -d llvm-project/libunwind ] || [ -n "$SYNC" ]; then
    CHECKOUT_ONLY=1 ./build-llvm.sh
fi

cd llvm-project

LLVM_PATH="$(pwd)/llvm"

cd runtimes

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

for arch in $ARCHS; do
    if [ "$arch" = "riscv32" ]; then
        toolchain=$arch-unknown-elf
        CMAKE_SYSTEM_NAME=generic
        OPTIONNAL_FLAGS="-DCOMPILER_RT_BAREMETAL_BUILD=ON -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_LIBFUZZER=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_PROFILE=OFF -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF"
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_SYSTEM_NAME=Generic -DCMAKE_SYSTEM_PROCESSOR=riscv32 -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/riscv32-unknown-elf -DCMAKE_CXX_COMPILER=riscv32-unknown-elf-clang -DCMAKE_ASM_COMPILER=riscv32-unknown-elf-clang -DCMAKE_C_COMPILER=riscv32-unknown-elf-clang -DCMAKE_C_COMPILER_TARGET=riscv32-unknown-elf -DCMAKE_C_COMPILER=riscv32-unknown-elf-clang -DCMAKE_CXX_COMPILER=riscv32-unknown-elf-clang++ -DCMAKE_C_FLAGS=\"--target=riscv32-unknown-elf\" -DCMAKE_CXX_FLAGS=\"--target=riscv32-unknown-elf\" -DCMAKE_ASM_FLAGS=\"--target=riscv32-unknown-elf\""
        COMPILER_TARGET="$arch-unknown-elf"
    else
        if [ -n "$TARGET_WINDOWS" ]; then
            toolchain=$arch-w64-mingw32
            CMAKE_SYSTEM_NAME=windows
            OPTIONNAL_FLAGS="-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_FIND_ROOT_PATH=$NATIVE_PREFIX/$arch-w64-mingw32"
            COMPILER_TARGET="$arch-w64-windows-gnu"
        else
            toolchain=$arch-linux-gnu
            CMAKE_SYSTEM_NAME=linux
            # linux shared library must be position independent
            # add libc++ path
            OPTIONNAL_FLAGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_FIND_ROOT_PATH=$PREFIX/$arch-linux-gnu"
            COMPILER_TARGET="$arch-linux-gnu"

        fi
        OPTIONNAL_FLAGS="$OPTIONNAL_FLAGS -DCMAKE_C_COMPILER_TARGET=$toolchain"
    fi

    [ -z "$CLEAN" ] || rm -rf $CMAKE_SYSTEM_NAME
    mkdir -p $CMAKE_SYSTEM_NAME
    cd $CMAKE_SYSTEM_NAME
    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    [ -n "$NO_RECONF" ] || rm -rf CMake*
    COMMON_C_FLAG="-fPIC"   
    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX/$toolchain" \
        -DCMAKE_C_COMPILER=$toolchain-clang \
        -DCMAKE_CXX_COMPILER=$toolchain-clang++ \
        -DCMAKE_CXX_COMPILER_TARGET=$COMPILER_TARGET\
        ${OPTIONNAL_FLAGS} \
        -DCMAKE_C_FLAGS="${COMMON_C_FLAG}" -DCMAKE_CXX_FLAGS="${COMMON_C_FLAG}" -DCMAKE_ASM_FLAGS="${COMMON_C_FLAG}" \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DLLVM_PATH="$LLVM_PATH" \
        -DCMAKE_AR="$NATIVE_PREFIX/bin/llvm-ar" \
        -DCMAKE_RANLIB="$NATIVE_PREFIX/bin/llvm-ranlib" \
        -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
        -DLIBUNWIND_USE_COMPILER_RT=TRUE \
        -DLIBUNWIND_ENABLE_SHARED=$BUILD_SHARED \
        -DLIBUNWIND_ENABLE_STATIC=$BUILD_STATIC \
        -DLIBCXX_USE_COMPILER_RT=ON \
        -DLIBCXX_ENABLE_SHARED=$BUILD_SHARED \
        -DLIBCXX_ENABLE_STATIC=$BUILD_STATIC \
        -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
        -DLIBCXX_CXX_ABI=libcxxabi \
        -DLIBCXX_LIBDIR_SUFFIX="" \
        -DLIBCXX_INCLUDE_TESTS=FALSE \
        -DLIBCXX_INSTALL_MODULES=ON \
        -DLIBCXX_INSTALL_MODULES_DIR="$PREFIX/share/libc++/v1" \
        -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
        -DLIBCXXABI_USE_COMPILER_RT=ON \
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_LIBDIR_SUFFIX="" \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" \
        ../..

    cmake --build . ${CORES:+-j${CORES}}
    cmake --install .
    cd ../..
done
