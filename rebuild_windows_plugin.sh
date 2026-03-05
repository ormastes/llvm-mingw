#!/bin/bash
# Script to rebuild the Windows plugin using Docker
# Run with: sudo ./rebuild_windows_plugin.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Rebuilding UTHelper Windows Plugin"
echo "========================================"
echo ""
echo "Using Docker to rebuild with latest code updates..."
echo ""

# Check which Docker image is available
echo "Checking for Docker images..."
if docker images | grep -q "llvm-mingw-my3-post"; then
    DOCKER_IMAGE="llvm-mingw-my3-post:latest"
    echo "✓ Found: llvm-mingw-my3-post"
elif docker images | grep -q "llvm-mingw-my3"; then
    DOCKER_IMAGE="llvm-mingw-my3:latest"
    echo "✓ Found: llvm-mingw-my3"
elif docker images | grep -q "llvm-mingw-my2.1-32"; then
    DOCKER_IMAGE="llvm-mingw-my2.1-32:latest"
    echo "✓ Found: llvm-mingw-my2.1-32"
else
    echo "✗ No suitable Docker image found!"
    echo ""
    echo "Available images:"
    docker images | grep llvm-mingw || echo "  No llvm-mingw images"
    echo ""
    echo "Please build the Docker image first using:"
    echo "  sudo ./my__build_docker.sh"
    exit 1
fi

echo "Using Docker image: $DOCKER_IMAGE"
echo ""

# Show what changes were pulled
echo "Recent updates from git:"
cd "$SCRIPT_DIR/UTHelper"
git log --oneline -3
echo ""

# Backup old plugin if it exists
OLD_PLUGIN="$SCRIPT_DIR/UTHelper/build-windows/plugin/UTHelperPlugin.dll"
if [ -f "$OLD_PLUGIN" ]; then
    BACKUP_NAME="UTHelperPlugin.dll.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up old plugin to: $BACKUP_NAME"
    cp "$OLD_PLUGIN" "$SCRIPT_DIR/UTHelper/build-windows/plugin/$BACKUP_NAME"
    echo ""
fi

# Run the build in Docker
echo "Starting Docker build..."
echo "This may take several minutes..."
echo ""

docker run --rm \
    -v "$SCRIPT_DIR:/build/llvm-mingw" \
    -v "$SCRIPT_DIR/../build:/build/build" \
    "$DOCKER_IMAGE" \
    bash /build/llvm-mingw/build_uthelper_windows.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================"
    echo "✓ Build Successful!"
    echo "========================================"
    echo ""

    # Show plugin info
    if [ -f "$OLD_PLUGIN" ]; then
        echo "Plugin location: $OLD_PLUGIN"
        file "$OLD_PLUGIN"
        SIZE=$(stat -c%s "$OLD_PLUGIN" 2>/dev/null || stat -f%z "$OLD_PLUGIN" 2>/dev/null)
        SIZE_MB=$((SIZE / 1024 / 1024))
        echo "Size: ${SIZE_MB} MB"
        echo ""
        echo "Last modified: $(ls -lh "$OLD_PLUGIN" | awk '{print $6, $7, $8}')"
    fi
else
    echo ""
    echo "========================================"
    echo "✗ Build Failed!"
    echo "========================================"
    echo ""
    echo "Check the error messages above."
    echo "The old plugin backup is still available if it existed."
    exit 1
fi
