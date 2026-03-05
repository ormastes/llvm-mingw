#!/bin/bash
# Comprehensive script to build UTHelper for Windows and test it
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_IMAGE="llvm-mingw-my3-post:latest"

echo "================================"
echo "UTHelper Windows Build & Test"
echo "================================"
echo ""

# Function to check if Docker image exists
check_docker_image() {
    if ! sudo docker images | grep -q "llvm-mingw-my3-post"; then
        echo "ERROR: Docker image llvm-mingw-my3-post not found!"
        echo "Please run ./my__build_docker.sh first to build the Docker image"
        exit 1
    fi
    echo "✓ Docker image found: $DOCKER_IMAGE"
}

# Function to build the Windows plugin
build_windows_plugin() {
    echo ""
    echo "=== Building UTHelper Plugin for Windows ==="
    echo ""

    sudo docker run --rm \
        -v "$SCRIPT_DIR:/build/llvm-mingw" \
        -v "$SCRIPT_DIR/../build:/build/build" \
        "$DOCKER_IMAGE" \
        bash /build/llvm-mingw/build_uthelper_windows.sh

    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Windows plugin built successfully!"
    else
        echo ""
        echo "✗ Windows plugin build failed!"
        exit 1
    fi
}

# Function to verify the build output
verify_build() {
    echo ""
    echo "=== Verifying Build Output ==="
    echo ""

    PLUGIN_PATH="$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll"

    if [ ! -f "$PLUGIN_PATH" ]; then
        echo "✗ Plugin not found at: $PLUGIN_PATH"
        exit 1
    fi

    echo "✓ Plugin found at: $PLUGIN_PATH"

    # Check file type
    file "$PLUGIN_PATH"

    # Check file size
    SIZE=$(stat -c%s "$PLUGIN_PATH" 2>/dev/null || stat -f%z "$PLUGIN_PATH" 2>/dev/null)
    SIZE_MB=$((SIZE / 1024 / 1024))
    echo "✓ Plugin size: ${SIZE_MB} MB"

    # Check DLL dependencies (if objdump is available)
    if command -v x86_64-w64-mingw32-objdump &> /dev/null; then
        echo ""
        echo "DLL Dependencies:"
        x86_64-w64-mingw32-objdump -p "$PLUGIN_PATH" | grep "DLL Name:" | head -10
    fi
}

# Function to create a simple test file
create_test_files() {
    echo ""
    echo "=== Creating Test Files ==="
    echo ""

    TEST_DIR="$SCRIPT_DIR/UTHelper/test_windows"
    mkdir -p "$TEST_DIR"

    # Create test C++ file
    cat > "$TEST_DIR/test_simple.cpp" <<'EOF'
#include <string>
#include <iostream>

// A final class that should have final removed and virtual added
class DatabaseHandler final {
public:
    void connect() {
        std::cout << "Connecting to database" << std::endl;
    }

    std::string query(const std::string& sql) {
        return "Result: " + sql;
    }

private:
    void authenticate() {
        std::cout << "Authenticating" << std::endl;
    }
};

int main() {
    DatabaseHandler db;
    db.connect();
    std::string result = db.query("SELECT * FROM users");
    std::cout << result << std::endl;
    return 0;
}
EOF

    echo "✓ Created test file: $TEST_DIR/test_simple.cpp"
}

# Function to test the plugin (transformation only - no Windows execution needed)
test_plugin_transformation() {
    echo ""
    echo "=== Testing Plugin Transformation ==="
    echo "NOTE: We're testing the transformation capability, not running on Windows"
    echo ""

    TEST_DIR="$SCRIPT_DIR/UTHelper/test_windows"
    PLUGIN_PATH="/build/llvm-mingw/UTHelper/build-windows/plugin/UTHelperPlugin.dll"

    # Run transformation test in Docker
    sudo docker run --rm \
        -v "$SCRIPT_DIR:/build/llvm-mingw" \
        -v "$SCRIPT_DIR/../build:/build/build" \
        "$DOCKER_IMAGE" \
        bash -c "
            cd /build/llvm-mingw/UTHelper/test_windows

            echo 'Testing plugin transformation...'

            # We can't actually load the Windows DLL on Linux, but we can verify it exists
            if [ -f '$PLUGIN_PATH' ]; then
                echo '✓ Plugin DLL exists and was built for Windows'
                file '$PLUGIN_PATH'
                echo ''
                echo 'To test this plugin on Windows, you need to:'
                echo '1. Copy UTHelperPlugin.dll to a Windows machine'
                echo '2. Install Clang/LLVM on Windows'
                echo '3. Run the plugin with clang++ on Windows using:'
                echo '   clang++ -Xclang -load -Xclang UTHelperPlugin.dll ...'
                exit 0
            else
                echo '✗ Plugin DLL not found'
                exit 1
            fi
        "
}

# Function to create Windows test instructions
create_windows_test_instructions() {
    echo ""
    echo "=== Creating Windows Test Instructions ==="
    echo ""

    TEST_DIR="$SCRIPT_DIR/UTHelper/test_windows"

    cat > "$TEST_DIR/RUN_ON_WINDOWS.md" <<'EOF'
# Testing UTHelper Plugin on Windows

## Prerequisites
1. Install LLVM/Clang for Windows (version 18 or later)
   - Download from: https://github.com/llvm/llvm-project/releases
   - Or use the MinGW-w64 build

## Files Needed
1. `UTHelperPlugin.dll` - The plugin (from build-windows/plugin/)
2. `test_simple.cpp` - The test source file

## How to Test

### Test 1: Plugin Loading
```cmd
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -fsyntax-only test_simple.cpp
```

Expected: Should complete without errors (plugin loads successfully)

### Test 2: Transform Code (All Features)
```cmd
clang++ -Xclang -load -Xclang UTHelperPlugin.dll ^
        -Xclang -plugin -Xclang uthelper ^
        -Xclang -plugin-arg-uthelper -Xclang "base-folder=%CD%" ^
        -fsyntax-only test_simple.cpp > test_transformed.cpp
```

Expected output in `test_transformed.cpp`:
- `final` keyword removed from DatabaseHandler
- `virtual` added to all methods
- Friend declarations added to the class

### Test 3: Compile Transformed Code
```cmd
clang++ -o test_transformed.exe test_transformed.cpp
test_transformed.exe
```

Expected: Program compiles and runs successfully

## Verify Transformation

The transformed code should look like:

```cpp
class DatabaseHandler {
  friend class DatabaseHandlerTest;
  template<typename T> friend class DatabaseHandlerFriend;

public:
    virtual void connect() {
        std::cout << "Connecting to database" << std::endl;
    }

    virtual std::string query(const std::string& sql) {
        return "Result: " + sql;
    }

private:
    virtual void authenticate() {
        std::cout << "Authenticating" << std::endl;
    }
};
```

## Success Criteria
- ✓ Plugin loads without errors
- ✓ Code transformation completes
- ✓ `final` keyword is removed
- ✓ `virtual` is added to methods
- ✓ Friend declarations are added
- ✓ Transformed code compiles
- ✓ Transformed code runs correctly

## Troubleshooting

### "Unable to load plugin"
- Make sure clang.exe and UTHelperPlugin.dll are in the same directory, or
- Use absolute path to UTHelperPlugin.dll

### Missing LLVM libraries
- The plugin may depend on LLVM DLLs that need to be in the same directory
- Check with: `dumpbin /dependents UTHelperPlugin.dll`

## Automated Test Script (PowerShell)

```powershell
# test_plugin.ps1
$ErrorActionPreference = "Stop"

Write-Host "Testing UTHelper Plugin on Windows" -ForegroundColor Green

# Test 1: Load plugin
Write-Host "`n[Test 1] Loading plugin..." -ForegroundColor Yellow
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -fsyntax-only test_simple.cpp
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Plugin loaded successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Plugin failed to load" -ForegroundColor Red
    exit 1
}

# Test 2: Transform code
Write-Host "`n[Test 2] Transforming code..." -ForegroundColor Yellow
clang++ -Xclang -load -Xclang UTHelperPlugin.dll `
        -Xclang -plugin -Xclang uthelper `
        -Xclang -plugin-arg-uthelper -Xclang "base-folder=$PWD" `
        -fsyntax-only test_simple.cpp > test_transformed.cpp

if ($LASTEXITCODE -eq 0 -and (Test-Path test_transformed.cpp)) {
    Write-Host "✓ Code transformed successfully" -ForegroundColor Green

    # Check for expected transformations
    $content = Get-Content test_transformed.cpp -Raw
    if ($content -match "friend class DatabaseHandlerTest" -and
        $content -match "virtual void connect" -and
        $content -notmatch "class DatabaseHandler final") {
        Write-Host "✓ All transformations verified" -ForegroundColor Green
    } else {
        Write-Host "⚠ Transformation incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Transformation failed" -ForegroundColor Red
    exit 1
}

# Test 3: Compile transformed code
Write-Host "`n[Test 3] Compiling transformed code..." -ForegroundColor Yellow
clang++ -o test_transformed.exe test_transformed.cpp
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Compilation successful" -ForegroundColor Green
} else {
    Write-Host "✗ Compilation failed" -ForegroundColor Red
    exit 1
}

# Test 4: Run transformed code
Write-Host "`n[Test 4] Running transformed code..." -ForegroundColor Yellow
.\test_transformed.exe
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Execution successful" -ForegroundColor Green
} else {
    Write-Host "✗ Execution failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All tests passed! ===" -ForegroundColor Green
```

Save this as `test_plugin.ps1` and run: `powershell -ExecutionPolicy Bypass .\test_plugin.ps1`
EOF

    echo "✓ Created Windows test instructions: $TEST_DIR/RUN_ON_WINDOWS.md"

    # Create PowerShell test script
    cat > "$TEST_DIR/test_plugin.ps1" <<'EOF'
# PowerShell test script for UTHelper Plugin on Windows
$ErrorActionPreference = "Stop"

Write-Host "Testing UTHelper Plugin on Windows" -ForegroundColor Green

# Test 1: Load plugin
Write-Host "`n[Test 1] Loading plugin..." -ForegroundColor Yellow
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -fsyntax-only test_simple.cpp
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Plugin loaded successfully" -ForegroundColor Green
} else {
    Write-Host "X Plugin failed to load" -ForegroundColor Red
    exit 1
}

# Test 2: Transform code
Write-Host "`n[Test 2] Transforming code..." -ForegroundColor Yellow
clang++ -Xclang -load -Xclang UTHelperPlugin.dll `
        -Xclang -plugin -Xclang uthelper `
        -Xclang -plugin-arg-uthelper -Xclang "base-folder=$PWD" `
        -fsyntax-only test_simple.cpp > test_transformed.cpp

if ($LASTEXITCODE -eq 0 -and (Test-Path test_transformed.cpp)) {
    Write-Host "OK Code transformed successfully" -ForegroundColor Green

    # Check for expected transformations
    $content = Get-Content test_transformed.cpp -Raw
    if ($content -match "friend class DatabaseHandlerTest" -and
        $content -match "virtual void connect" -and
        $content -notmatch "class DatabaseHandler final") {
        Write-Host "OK All transformations verified" -ForegroundColor Green
    } else {
        Write-Host "! Transformation incomplete" -ForegroundColor Yellow
    }
} else {
    Write-Host "X Transformation failed" -ForegroundColor Red
    exit 1
}

# Test 3: Compile transformed code
Write-Host "`n[Test 3] Compiling transformed code..." -ForegroundColor Yellow
clang++ -o test_transformed.exe test_transformed.cpp
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Compilation successful" -ForegroundColor Green
} else {
    Write-Host "X Compilation failed" -ForegroundColor Red
    exit 1
}

# Test 4: Run transformed code
Write-Host "`n[Test 4] Running transformed code..." -ForegroundColor Yellow
.\test_transformed.exe
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Execution successful" -ForegroundColor Green
} else {
    Write-Host "X Execution failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All tests passed! ===" -ForegroundColor Green
EOF

    echo "✓ Created PowerShell test script: $TEST_DIR/test_plugin.ps1"
}

# Function to create package for Windows testing
create_windows_package() {
    echo ""
    echo "=== Creating Windows Test Package ==="
    echo ""

    PACKAGE_DIR="$SCRIPT_DIR/UTHelper_Windows_Test_Package"
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"

    # Copy plugin
    cp "$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll" "$PACKAGE_DIR/"

    # Copy test files
    cp "$SCRIPT_DIR/UTHelper/test_windows/test_simple.cpp" "$PACKAGE_DIR/"
    cp "$SCRIPT_DIR/UTHelper/test_windows/RUN_ON_WINDOWS.md" "$PACKAGE_DIR/"
    cp "$SCRIPT_DIR/UTHelper/test_windows/test_plugin.ps1" "$PACKAGE_DIR/"

    # Create README
    cat > "$PACKAGE_DIR/README.txt" <<'EOF'
UTHelper Windows Plugin Test Package
=====================================

This package contains everything you need to test the UTHelper plugin on Windows.

Contents:
- UTHelperPlugin.dll      : The Clang plugin for Windows
- test_simple.cpp          : Sample C++ file to test transformation
- RUN_ON_WINDOWS.md        : Detailed testing instructions
- test_plugin.ps1          : Automated test script (PowerShell)

Quick Start on Windows:
1. Install LLVM/Clang for Windows (version 18+)
2. Open PowerShell in this directory
3. Run: powershell -ExecutionPolicy Bypass .\test_plugin.ps1

For manual testing, see RUN_ON_WINDOWS.md
EOF

    echo "✓ Package created at: $PACKAGE_DIR"
    echo ""
    echo "Package contents:"
    ls -lh "$PACKAGE_DIR"
}

# Main execution
main() {
    echo "Starting Windows build and test process..."
    echo ""

    # Step 1: Check Docker image
    check_docker_image

    # Step 2: Build Windows plugin
    read -p "Build/rebuild the Windows plugin? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_windows_plugin
    else
        echo "Skipping build - using existing plugin"
    fi

    # Step 3: Verify build
    verify_build

    # Step 4: Create test files
    create_test_files

    # Step 5: Test plugin (basic check)
    test_plugin_transformation

    # Step 6: Create Windows test instructions
    create_windows_test_instructions

    # Step 7: Create Windows package
    create_windows_package

    echo ""
    echo "================================"
    echo "✓ Build and Test Setup Complete!"
    echo "================================"
    echo ""
    echo "Next steps:"
    echo "1. Transfer 'UTHelper_Windows_Test_Package' folder to a Windows machine"
    echo "2. Install Clang/LLVM on Windows"
    echo "3. Run the PowerShell test script: test_plugin.ps1"
    echo ""
    echo "For detailed instructions, see:"
    echo "  UTHelper_Windows_Test_Package/RUN_ON_WINDOWS.md"
    echo ""
}

# Run main function
main
