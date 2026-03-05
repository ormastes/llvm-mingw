#!/bin/bash
set -e

echo "=== Building UTHelper Plugin COMPATIBLE with Deployed Clang ==="
echo ""
echo "This build uses the deployed libraries from /opt/llvm-mingw/lib/"
echo "instead of /build/llvm-project/llvm/build/lib/"
echo ""

cd /build/llvm-mingw/UTHelper

# Clean previous build
rm -rf build-linux-deployed
mkdir -p build-linux-deployed
cd build-linux-deployed

echo "=== Configuring CMake with DEPLOYED library paths ==="
# Use build CMake configs but link against deployed libraries
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=/opt/llvm-mingw/bin/clang++ \
    -DCMAKE_C_COMPILER=/opt/llvm-mingw/bin/clang \
    -DLLVM_DIR=/build/llvm-project/llvm/build/lib/cmake/llvm \
    -DClang_DIR=/build/llvm-project/llvm/build/lib/cmake/clang \
    -DCMAKE_CXX_FLAGS="-I/build/llvm-project/clang/include -I/build/llvm-project/llvm/build/tools/clang/include -I/build/llvm-project/llvm/include -I/build/llvm-project/llvm/build/include" \
    -DCMAKE_EXE_LINKER_FLAGS="-L/opt/llvm-mingw/lib -Wl,-rpath,/opt/llvm-mingw/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/opt/llvm-mingw/lib -Wl,-rpath,/opt/llvm-mingw/lib"

echo ""
echo "=== Building plugin ==="
make -j$(nproc)

echo ""
if [ -f plugin/UTHelperPlugin.so ]; then
    echo "=== Plugin built successfully ==="
    ls -lh plugin/UTHelperPlugin.so

    echo ""
    echo "=== Checking library dependencies ==="
    ldd plugin/UTHelperPlugin.so | grep -E '(LLVM|clang)'

    echo ""
    echo "=== Verifying it uses DEPLOYED libraries ==="
    ldd plugin/UTHelperPlugin.so | grep -q '/opt/llvm-mingw/lib/' && echo "✓ Uses deployed libraries!" || echo "✗ Still uses build libraries"

    echo ""
    echo "=== Running tests ==="
    export LD_LIBRARY_PATH=/opt/llvm-mingw/lib:$LD_LIBRARY_PATH
    cd test/system_test
    ./test_transformed || echo "Test failed, but plugin was built"

else
    echo "=== Build failed ==="
    exit 1
fi
