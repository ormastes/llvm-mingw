#!/bin/bash
set -e

echo "=== Windows UTHelper Plugin Build Fix ==="
echo ""

# Step 1: Update plugin/CMakeLists.txt with proper Windows linking
echo "Step 1: Updating plugin/CMakeLists.txt..."
cat > /build/llvm-mingw/UTHelper/plugin/CMakeLists.txt << 'EOF'
# Add the parser subdirectory
add_subdirectory(parser)

# Determine if we're cross-compiling for Windows
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(IS_WINDOWS TRUE)
    link_directories(/build/llvm-project/llvm/build-x86_64-w64-mingw32-static/lib)
else()
    set(IS_WINDOWS FALSE)
    link_directories(/build/llvm-project/llvm/build/lib)
endif()

# Create the plugin library
if(IS_WINDOWS)
    add_library(UTHelperPlugin SHARED
        UTHelperPlugin.cpp
        AST2Matcher.cpp
        ASTMakeMatcherVisitor.cpp
        WrapFunctionCallback.cpp
        WrapFunctionConsumer.cpp
        UnifiedASTVisitor.cpp
    )
else()
    add_llvm_library(UTHelperPlugin MODULE
        UTHelperPlugin.cpp
        AST2Matcher.cpp
        ASTMakeMatcherVisitor.cpp
        WrapFunctionCallback.cpp
        WrapFunctionConsumer.cpp
        UnifiedASTVisitor.cpp
        PLUGIN_TOOL
        clang
    )
endif()

# Include directories
target_include_directories(UTHelperPlugin PRIVATE
    ${LLVM_INCLUDE_DIRS}
    ${CLANG_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/parser
    ${CMAKE_CURRENT_SOURCE_DIR}/parser/external_inc
)

# Link libraries
if(IS_WINDOWS)
    # For Windows static build, we need all component libraries

    # Map LLVM components to library names
    llvm_map_components_to_libnames(llvm_libs
        support core demangle
        mc mcparser mcdisassembler option
        bitreader bitwriter bitstreamreader
        remarks binaryformat profiledata
        targetparser textapi
        frontendopenmp
    )

    # Clang libraries in dependency order
    set(CLANG_LIBS
        clangBasic
        clangLex
        clangParse
        clangAST
        clangDynamicASTMatchers
        clangASTMatchers
        clangCrossTU
        clangIndex
        clangSema
        clangAnalysis
        clangEdit
        clangRewrite
        clangSerialization
        clangDriver
        clangFrontend
    )

    # Link everything with proper grouping for circular dependencies
    target_link_libraries(UTHelperPlugin PRIVATE
        SaopParser
        -Wl,--start-group
        ${CLANG_LIBS}
        -Wl,--end-group
        ${llvm_libs}
        version
    )

    # Set properties for Windows DLL
    set_target_properties(UTHelperPlugin PROPERTIES
        PREFIX ""
        SUFFIX ".dll"
    )

else()
    # For Linux, use the shared clang-cpp library
    target_link_libraries(UTHelperPlugin PRIVATE
        SaopParser
        /build/llvm-project/llvm/build/lib/libclang-cpp.so
    )
endif()

add_dependencies(UTHelperPlugin SaopParser)
EOF

# Step 2: Create Windows-specific build script
echo "Step 2: Creating Windows build script..."
cat > /build/llvm-mingw/build_uthelper_windows.sh << 'EOFBUILD'
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
EOFBUILD

chmod +x /build/llvm-mingw/build_uthelper_windows.sh

echo ""
echo "=== Files updated successfully ==="
echo "- plugin/CMakeLists.txt: Updated with Windows static linking support"
echo "- build_uthelper_windows.sh: Created Windows-specific build script"
echo ""
echo "Ready to build Windows plugin!"
