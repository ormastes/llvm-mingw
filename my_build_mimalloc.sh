#!/bin/bash
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

# if mimalloc dir is not present, clone it
if [ ! -d mimalloc ]; then
    git clone https://github.com/ormastes/mimalloc.git
    cd mimalloc
    git checkout private/current
    cd ..
fi

set -e

BUILD_STATIC=ON
BUILD_SHARED=ON
CFGUARD_CFLAGS="-mguard=cf"
TOOL_CHAIN_DIR=/opt/llvm-mingw
HOST_ARGS=""

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
        ;;
    --disable-cfguard)
        CFGUARD_ARGS=
        ;;
    --use-exsting-compiler)
        USE_EXISTING_COMPILER=1
        ;;
    --host=*)
        HOST_ARGS="$HOST_ARGS $1"
        # taks char after '='
        HOST_ARGS="${1#*=}"
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            echo Unrecognized parameter $1
            exit 1
        fi
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo "$0 [--disable-shared] [--disable-static] [--enable-cfguard|--disable-cfguard] dest"
    exit 1
fi

if [ -n "$HOST_ARGS" ]; then
    case $HOST_ARGS in
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
PREFIX="$(cd "$PREFIX" && pwd)"

if [ -n "$USE_EXISTING_COMPILER" ]; then
    if [ -n "$TARGET_WINDOWS" ]; then
        NATIVE_PREFIX=/opt/llvm-mingw
    else
        NATIVE_PREFIX=/opt/llvm-linux
    fi
else
    NATIVE_PREFIX=$PREFIX
fi
NATIVE_PREFIX="$(cd "$NATIVE_PREFIX" && pwd)"
export PATH="$NATIVE_PREFIX/bin:$PATH"


#: ${ARCHS:=${TOOLCHAIN_ARCHS-i686 x86_64 armv7 aarch64}}
#: ${TARGET:=${TOOL_CHAIN_TARGET--w64-mingw32 -linux-gnu}}
toolchain=$HOST_ARGS

LLVM_PATH="llvm-project/llvm"


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

CMAKEFLAGS=


cd mimalloc
if [[ $HOST_ARGS == i686* ]]; then
    LINK_FLAG="$LINK_FLAG -m32 "
    COMMON_C_FLAG="$COMMON_C_FLAG -m32 "
    arch="i686"
else
    LINK_FLAG="$LINK_FLAG "
    COMMON_C_FLAG="$COMMON_C_FLAG  "
    arch="x86_64"
fi


TOOLCHAIN_PATH="$NATIVE_PREFIX/$toolchain"

LINK_FLAG="${LINK_FLAG} -Wl,-L${TOOLCHAIN_PATH}/lib" 
        COMMON_C_FLAG="${COMMON_C_FLAG} -I${TOOLCHAIN_PATH}/include/c++/v1"

    case $HOST_ARGS in
        *-mingw32)
            CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
            CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST_ARGS-windres"
            TOOLCHAIN_DIR="/$arch-w64-mingw32"
            TOOLCHAIN_PREFIX="$arch-w64-mingw32-"
            TOOLCHAIN_TARGET="$arch-w64-windows-gnu"
            ;;
        *)
            CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
            TOOLCHAIN_DIR=""
            TOOLCHAIN_PREFIX=""
            TOOLCHAIN_TARGET="$arch-linux-gnu"
            CFGUARD_CFLAGS=""
            ;;
    esac
    CFLAGS="$CFGUARD_CFLAGS"
    [ -z "$CLEAN" ] || rm -rf build-$arch
    mkdir -p build-$arch
    cd build-$arch
    [ -n "$NO_RECONF" ] || rm -rf CMake*

    cmake \
        ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX/$HOST_ARGS" \
        -DCMAKE_C_COMPILER=${TOOLCHAIN_PREFIX}clang \
        -DCMAKE_CXX_COMPILER=${TOOLCHAIN_PREFIX}clang++ \
        -DCMAKE_CXX_COMPILER_TARGET=$TOOLCHAIN_TARGET \
        ${CMAKEFLAGS} \
        -DCMAKE_C_FLAGS="${COMMON_C_FLAG}" -DCMAKE_CXX_FLAGS="${COMMON_C_FLAG}" -DCMAKE_ASM_FLAGS="${COMMON_C_FLAG}" \
        -DCMAKE_EXE_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_MODULE_LINKER_FLAGS="${LINK_FLAG}" \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_STATIC_LIBS=ON \
        -DCMAKE_C_COMPILER_WORKS=TRUE \
        -DCMAKE_CXX_COMPILER_WORKS=TRUE \
        -DLLVM_PATH="$LLVM_PATH" \
        -DCMAKE_C_FLAGS_INIT="$CFGUARD_CFLAGS" \
        -DCMAKE_CXX_FLAGS_INIT="$CFGUARD_CFLAGS" \
        ..

    cmake --build . ${CORES:+-j${CORES}}
    cmake --install .
    cd ..

cd ..