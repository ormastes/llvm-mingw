#!/bin/sh
#
# Copyright (c) 2020 Martin Storsjo
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

: ${LLDB_MI_VERSION:=a6c8c66d70b13209f3dabba5b6aefb2c58c3976c}
BUILDDIR=build
unset HOST

while [ $# -gt 0 ]; do
    case "$1" in
    --host=*)
        HOST="${1#*=}"
        ;;
    --use-exsting-compiler)
        USE_EXISTING_COMPILER=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done
if [ -z "$PREFIX" ]; then
    echo $0 [--host=<triple>] dest
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
echo "PATH=$PATH"
echo "HOST=$HOST"

if [ ! -d lldb-mi ]; then
    git clone https://github.com/lldb-tools/lldb-mi.git
    CHECKOUT=1
fi

if [ -n "$SYNC" ] || [ -n "$CHECKOUT" ]; then
    cd lldb-mi
    [ -z "$SYNC" ] || git fetch
    git checkout $LLDB_MI_VERSION
    cd ..
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

if [ -n "$TOOLCHAIN_PREFIX" ]; then
    export LLVM_DIR="$TOOLCHAIN_PREFIX/$HOST"
else
    export LLVM_DIR="$PREFIX/$HOST"
fi


# Try to find/guess the builddir under the llvm buildtree next by.
# If LLVM was built without LLVM_INSTALL_TOOLCHAIN_ONLY, and the LLVM
# installation directory hasn't been stripped, we should point the build there.
# But as this isn't necessarily the case, point to the LLVM build directory
# instead (which hopefully hasn't been removed yet).
LLVM_SRC="$(pwd)/llvm-project/llvm"
if [ -d "$LLVM_SRC" ]; then
    SUFFIX=${HOST+-}$HOST
    for base in build build-asserts; do
        if [ -d "$LLVM_SRC/$base$SUFFIX" ]; then
            export LLVM_DIR="$LLVM_SRC/$base$SUFFIX"
            break
        fi
    done
fi
# Specify the path to the LLVM installation prefix
echo "LLVM_DIR=$LLVM_DIR"
if [ -n "$HOST" ]; then
    BUILDDIR=$BUILDDIR-$HOST

    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
    case $HOST in
    *-mingw32)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
        toolchain=x86_64-w64-mingw32
        ;;
    *-linux*)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
        toolchain=x86_64-linux-gnu
        ;;
    *)
        echo "Unrecognized host $HOST"
        exit 1
        ;;
    esac
fi
CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$LLVM_DIR"
CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"

if [ -n "$MACOS_REDIST" ]; then
    : ${MACOS_REDIST_ARCHS:=arm64 x86_64}
    : ${MACOS_REDIST_VERSION:=10.9}
    ARCH_LIST=""
    NATIVE=
    for arch in $MACOS_REDIST_ARCHS; do
        if [ -n "$ARCH_LIST" ]; then
            ARCH_LIST="$ARCH_LIST;"
        fi
        ARCH_LIST="$ARCH_LIST$arch"
        if [ "$(uname -m)" = "$arch" ]; then
            NATIVE=1
        fi
    done
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_ARCHITECTURES=$ARCH_LIST"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOS_REDIST_VERSION"
    if [ -z "$NATIVE" ]; then
        # If we're not building for the native arch, flag to CMake that we're
        # cross compiling.
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Darwin"
    fi
fi

cd lldb-mi

[ -z "$CLEAN" ] || rm -rf $BUILDDIR
mkdir -p $BUILDDIR
cd $BUILDDIR
[ -n "$NO_RECONF" ] || rm -rf CMake*
echo "current directory: $(pwd)"
    TOOLCHAIN_PATH="$NATIVE_PREFIX/$toolchain"
    echo "TOOLCHAIN_PATH=$TOOLCHAIN_PATH"
    # if TOOLCHAIN_PATH is exist
    if [ -d "$TOOLCHAIN_PATH" ]; then
        LINK_FLAG="-Wl,-L${TOOLCHAIN_PATH}/lib" 
        COMMON_C_FLAG="-stdlib=libc++ -isystem ${TOOLCHAIN_PATH}/include/c++/v1"
    else
        LINK_FLAG="" 
        COMMON_C_FLAG=""   
    fi
cmake \
    ${CMAKE_GENERATOR+-G} "$CMAKE_GENERATOR" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
                -DCMAKE_C_FLAGS="${COMMON_C_FLAG}" -DCMAKE_CXX_FLAGS="${COMMON_C_FLAG}" -DCMAKE_ASM_FLAGS="${COMMON_C_FLAG}" \
        -DCMAKE_EXE_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_MODULE_LINKER_FLAGS="${LINK_FLAG}" \
        -DCMAKE_C_COMPILER_WORKS=TRUE -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_BUILD_TYPE=Release \
    $CMAKEFLAGS \
    ..

cmake --build . ${CORES:+-j${CORES}}
cmake --install . --strip
