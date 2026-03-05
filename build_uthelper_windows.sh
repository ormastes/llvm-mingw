#!/bin/bash
set -e

echo "=== Building UTHelper Plugin for Windows ==="
cd /build/llvm-mingw/UTHelper

# Clean previous build
rm -rf build-windows
mkdir -p build-windows
cd build-windows

echo ""
echo "=== Configuring CMake for Windows ==="
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_CXX_COMPILER=/opt/llvm-mingw/bin/x86_64-w64-mingw32-clang++ \
    -DCMAKE_C_COMPILER=/opt/llvm-mingw/bin/x86_64-w64-mingw32-clang \
    -DLLVM_DIR=/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/lib/cmake/llvm \
    -DClang_DIR=/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/lib/cmake/clang \
    -DCMAKE_CXX_FLAGS="-I/build/llvm-project/clang/include -I/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/tools/clang/include -I/build/llvm-project/llvm/include -I/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/include" \
    -DCMAKE_VERBOSE_MAKEFILE=ON

echo ""
echo "=== Building plugin only (not tests) ==="
# Build only the plugin target to avoid test linking issues
make UTHelperPlugin -j$(nproc) VERBOSE=1 2>&1 | tee build.log

echo ""
if [ -f plugin/UTHelperPlugin.dll ]; then
    echo "=== Windows plugin built successfully ==="
    ls -lh plugin/UTHelperPlugin.dll
    file plugin/UTHelperPlugin.dll
    echo ""
    echo "Checking dependencies:"
    /opt/llvm-mingw/bin/x86_64-w64-mingw32-objdump -p plugin/UTHelperPlugin.dll | grep "DLL Name:" | head -20
else
    echo "=== Build failed - plugin not found ==="
    tail -50 build.log
    exit 1
fi
