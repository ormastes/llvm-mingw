#!/bin/bash
set -e

echo "=== Building UTHelper Clang Plugin ==="
cd /build/llvm-mingw/UTHelper

# First, build for Linux (native)
echo ""
echo "=== Building Linux Plugin ==="
mkdir -p build-linux
cd build-linux

cmake .. -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=/opt/llvm-mingw/bin/clang++ \
    -DCMAKE_C_COMPILER=/opt/llvm-mingw/bin/clang \
    -DLLVM_DIR=/build/llvm-project/llvm/build/lib/cmake/llvm \
    -DClang_DIR=/build/llvm-project/llvm/build/lib/cmake/clang \
    -DCMAKE_CXX_FLAGS="-I/build/llvm-project/clang/include -I/build/llvm-project/llvm/build/tools/clang/include -I/build/llvm-project/llvm/include -I/build/llvm-project/llvm/build/include" \
    -DCMAKE_EXE_LINKER_FLAGS="-L/build/llvm-project/llvm/build/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/build/llvm-project/llvm/build/lib"

echo "Building plugin..."
make -j$(nproc)

echo ""
echo "=== Linux plugin built successfully ==="
ls -lh plugin/libSaopPlugin.so || ls -lh plugin/*.so

cd /build/llvm-mingw/UTHelper

# Now build for Windows using MinGW cross-compiler
echo ""
echo "=== Building Windows Plugin ==="
mkdir -p build-windows
cd build-windows

# Use the toolchain file for cross-compilation
# Note: For Windows, we'll use the mingw-built LLVM or the same Linux build
cmake .. -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_CXX_COMPILER=/opt/llvm-mingw/bin/x86_64-w64-mingw32-clang++ \
    -DCMAKE_C_COMPILER=/opt/llvm-mingw/bin/x86_64-w64-mingw32-clang \
    -DLLVM_DIR=/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/lib/cmake/llvm \
    -DClang_DIR=/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/lib/cmake/clang \
    -DCMAKE_CXX_FLAGS="-I/build/llvm-project/clang/include -I/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/tools/clang/include -I/build/llvm-project/llvm/include -I/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/include"

echo "Building plugin..."
make -j$(nproc)

echo ""
echo "=== Windows plugin built successfully ==="
ls -lh plugin/libSaopPlugin.dll || ls -lh plugin/*.dll || ls -lh plugin/*.so

echo ""
echo "=== Build Summary ==="
echo "Linux plugin:"
ls -lh /build/llvm-mingw/UTHelper/build-linux/plugin/*.so 2>/dev/null || echo "Not found"
echo ""
echo "Windows plugin:"
ls -lh /build/llvm-mingw/UTHelper/build-windows/plugin/*.dll 2>/dev/null || ls -lh /build/llvm-mingw/UTHelper/build-windows/plugin/*.so 2>/dev/null || echo "Not found"

cd /build/llvm-mingw
