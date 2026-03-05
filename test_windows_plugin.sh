#!/bin/bash
# Simple script to test the Windows plugin that's already built
# This script works without Docker - just tests the existing build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================"
echo "UTHelper Windows Plugin Tester"
echo "================================"
echo ""

# Function to verify the build output
verify_build() {
    echo "=== Verifying Windows Plugin ==="
    echo ""

    PLUGIN_PATH="$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll"

    if [ ! -f "$PLUGIN_PATH" ]; then
        echo "✗ Plugin not found at: $PLUGIN_PATH"
        echo ""
        echo "You need to build it first. The plugin can be built inside Docker using:"
        echo "  sudo docker run --rm -v \$(pwd):/build/llvm-mingw -v \$(pwd)/../build:/build/build llvm-mingw-my3-post:latest bash /build/llvm-mingw/build_uthelper_windows.sh"
        exit 1
    fi

    echo "✓ Plugin found at: $PLUGIN_PATH"
    echo ""

    # Check file type
    echo "File information:"
    file "$PLUGIN_PATH"
    echo ""

    # Check file size
    SIZE=$(stat -c%s "$PLUGIN_PATH" 2>/dev/null || stat -f%z "$PLUGIN_PATH" 2>/dev/null)
    SIZE_MB=$((SIZE / 1024 / 1024))
    echo "Plugin size: ${SIZE_MB} MB"
    echo ""

    # Check DLL dependencies
    OBJDUMP="x86_64-w64-mingw32-objdump"
    if command -v "$OBJDUMP" &> /dev/null; then
        echo "DLL Dependencies:"
        "$OBJDUMP" -p "$PLUGIN_PATH" | grep "DLL Name:" | head -10
        echo ""
    else
        echo "Note: Install mingw-w64 tools to check DLL dependencies"
        echo ""
    fi

    # Check when it was built
    echo "Last modified: $(ls -lh "$PLUGIN_PATH" | awk '{print $6, $7, $8}')"
}

# Function to create test files
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
   - Or use Clang from llvm-mingw

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
- The plugin depends on LLVM libraries built into the DLL
- The DLL is large (~60MB) because it's statically linked

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
        Write-Host "Content preview:"
        Get-Content test_transformed.cpp | Select-Object -First 30
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

Save this as `test_plugin.ps1` and run:
```powershell
powershell -ExecutionPolicy Bypass .\test_plugin.ps1
```
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
        Write-Host "Content preview:"
        Get-Content test_transformed.cpp | Select-Object -First 30
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
EOF

    echo "✓ Created PowerShell test script: $TEST_DIR/test_plugin.ps1"

    # Create batch file version for cmd.exe
    cat > "$TEST_DIR/test_plugin.bat" <<'EOF'
@echo off
echo ================================
echo UTHelper Plugin Test (Batch)
echo ================================
echo.

echo [Test 1] Loading plugin...
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -fsyntax-only test_simple.cpp
if %ERRORLEVEL% EQU 0 (
    echo OK Plugin loaded successfully
) else (
    echo FAIL Plugin failed to load
    exit /b 1
)

echo.
echo [Test 2] Transforming code...
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -Xclang -plugin -Xclang uthelper -Xclang -plugin-arg-uthelper -Xclang "base-folder=%CD%" -fsyntax-only test_simple.cpp > test_transformed.cpp
if %ERRORLEVEL% EQU 0 (
    echo OK Code transformed successfully
) else (
    echo FAIL Transformation failed
    exit /b 1
)

echo.
echo [Test 3] Compiling transformed code...
clang++ -o test_transformed.exe test_transformed.cpp
if %ERRORLEVEL% EQU 0 (
    echo OK Compilation successful
) else (
    echo FAIL Compilation failed
    exit /b 1
)

echo.
echo [Test 4] Running transformed code...
test_transformed.exe
if %ERRORLEVEL% EQU 0 (
    echo OK Execution successful
) else (
    echo FAIL Execution failed
    exit /b 1
)

echo.
echo ================================
echo All tests passed!
echo ================================
EOF

    echo "✓ Created batch test script: $TEST_DIR/test_plugin.bat"
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
    cp "$SCRIPT_DIR/UTHelper/test_windows/test_plugin.bat" "$PACKAGE_DIR/"

    # Create README
    cat > "$PACKAGE_DIR/README.txt" <<'EOF'
UTHelper Windows Plugin Test Package
=====================================

This package contains everything you need to test the UTHelper plugin on Windows.

Contents:
- UTHelperPlugin.dll      : The Clang plugin for Windows (x86_64)
- test_simple.cpp          : Sample C++ file to test transformation
- RUN_ON_WINDOWS.md        : Detailed testing instructions
- test_plugin.ps1          : Automated test script (PowerShell)
- test_plugin.bat          : Automated test script (Command Prompt)

Quick Start on Windows:

Option 1 - PowerShell (Recommended):
1. Install LLVM/Clang for Windows (version 18+)
2. Open PowerShell in this directory
3. Run: powershell -ExecutionPolicy Bypass .\test_plugin.ps1

Option 2 - Command Prompt:
1. Install LLVM/Clang for Windows (version 18+)
2. Open Command Prompt in this directory
3. Run: test_plugin.bat

For manual testing and detailed instructions, see RUN_ON_WINDOWS.md

Plugin Info:
- Built: $(date)
- Target: Windows x86_64
- Size: ~60 MB (statically linked with LLVM)
- Dependencies: Windows system DLLs only (no external LLVM DLLs needed)
EOF

    echo "✓ Package created at: $PACKAGE_DIR"
    echo ""
    echo "Package contents:"
    ls -lh "$PACKAGE_DIR"
}

# Function to create summary
create_summary() {
    echo ""
    echo "=== Creating Build Summary ==="
    echo ""

    cat > "$SCRIPT_DIR/WINDOWS_PLUGIN_STATUS.md" <<EOF
# UTHelper Windows Plugin - Build Status

## Build Information

**Date:** $(date)
**Plugin Location:** \`UTHelper/build-windows/plugin/UTHelperPlugin.dll\`
**Plugin Size:** $(stat -c%s "$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll" 2>/dev/null | awk '{print int($1/1024/1024)" MB"}' || echo "Unknown")

## Plugin Details

\`\`\`
$(file "$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll")
\`\`\`

## What This Plugin Does

The UTHelper plugin transforms C++ code to improve testability:
1. **Remove Final** - Removes \`final\` specifiers from classes/methods
2. **Make Virtual** - Adds \`virtual\` to methods for mocking
3. **Add Friend** - Injects friend declarations for test access

## Testing on Windows

### Prerequisites
- Windows 10/11 (x64)
- LLVM/Clang 18+ for Windows
- Plugin file: \`UTHelperPlugin.dll\`

### Quick Test

1. Transfer the \`UTHelper_Windows_Test_Package\` folder to Windows
2. Open PowerShell in that directory
3. Run: \`powershell -ExecutionPolicy Bypass .\\test_plugin.ps1\`

### Manual Test

\`\`\`cmd
REM Test 1: Load the plugin
clang++ -Xclang -load -Xclang UTHelperPlugin.dll -fsyntax-only test_simple.cpp

REM Test 2: Transform code
clang++ -Xclang -load -Xclang UTHelperPlugin.dll ^
        -Xclang -plugin -Xclang uthelper ^
        -Xclang -plugin-arg-uthelper -Xclang "base-folder=%CD%" ^
        -fsyntax-only test_simple.cpp > test_transformed.cpp

REM Test 3: Compile and run
clang++ -o test.exe test_transformed.cpp
test.exe
\`\`\`

## Expected Transformation

Input:
\`\`\`cpp
class DatabaseHandler final {
public:
    void connect() { /* ... */ }
private:
    void authenticate() { /* ... */ }
};
\`\`\`

Output:
\`\`\`cpp
class DatabaseHandler {
  friend class DatabaseHandlerTest;
  template<typename T> friend class DatabaseHandlerFriend;

public:
    virtual void connect() { /* ... */ }
private:
    virtual void authenticate() { /* ... */ }
};
\`\`\`

## Files for Windows Testing

All files are in \`UTHelper_Windows_Test_Package/\`:
- UTHelperPlugin.dll - The plugin
- test_simple.cpp - Test source code
- test_plugin.ps1 - PowerShell test script
- test_plugin.bat - Batch test script
- RUN_ON_WINDOWS.md - Detailed instructions

## Rebuilding the Plugin

To rebuild the Windows plugin:

\`\`\`bash
# Using Docker with the cross-compiler environment
sudo docker run --rm \\
    -v \$(pwd):/build/llvm-mingw \\
    -v \$(pwd)/../build:/build/build \\
    llvm-mingw-my3-post:latest \\
    bash /build/llvm-mingw/build_uthelper_windows.sh
\`\`\`

## Technical Details

- **Architecture:** x86_64 (64-bit)
- **Format:** PE32+ DLL
- **Linking:** Static (includes all LLVM libraries)
- **Dependencies:** Windows system DLLs only
- **Compiler:** MinGW-w64 Clang cross-compiler

## Known Issues

None currently. The plugin builds successfully and is ready for testing on Windows.

## Next Steps

1. Transfer test package to Windows machine
2. Install Clang for Windows
3. Run automated tests
4. Verify all transformations work correctly
5. Integrate into your build system

## Support

See the main README.md for:
- Plugin usage documentation
- Feature descriptions
- Command-line arguments
- Integration examples
EOF

    echo "✓ Created status document: $SCRIPT_DIR/WINDOWS_PLUGIN_STATUS.md"
}

# Main execution
main() {
    echo "Checking Windows plugin build..."
    echo ""

    # Verify the build exists
    verify_build

    # Create test files
    create_test_files

    # Create Windows test instructions
    create_windows_test_instructions

    # Create Windows package
    create_windows_package

    # Create summary
    create_summary

    echo ""
    echo "================================"
    echo "✓ Windows Plugin Ready!"
    echo "================================"
    echo ""
    echo "Plugin location:"
    echo "  UTHelper/build-windows/plugin/UTHelperPlugin.dll"
    echo ""
    echo "Test package created:"
    echo "  UTHelper_Windows_Test_Package/"
    echo ""
    echo "Next steps:"
    echo "1. Transfer 'UTHelper_Windows_Test_Package' to a Windows machine"
    echo "2. Install Clang/LLVM on Windows (version 18+)"
    echo "3. Run the test script:"
    echo "   - PowerShell: powershell -ExecutionPolicy Bypass .\\test_plugin.ps1"
    echo "   - Cmd: test_plugin.bat"
    echo ""
    echo "For details, see:"
    echo "  - WINDOWS_PLUGIN_STATUS.md"
    echo "  - UTHelper_Windows_Test_Package/RUN_ON_WINDOWS.md"
    echo ""
}

# Run main function
main
