#!/bin/bash
set -e

# Build Docker images up to my2.1-32 stage (excludes PGO builds)

echo "=== Building llvm-mingw base image ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw .

echo "=== Building llvm-mingw-my00 (adding i386 and build tools) ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw-my00 -f Dockerfile.my00 .

echo "=== Building llvm-mingw-my1-linux-env (Linux compiler environment) ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw-my1-linux-env -f Dockerfile.my1-linux-env .

echo "=== Building llvm-mingw-my1.0 (mimalloc library) ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw-my1.0 -f Dockerfile.my1.0 .

echo "=== Building llvm-mingw-my2-base (64-bit toolchains) ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw-my2-base -f Dockerfile.my2-base .

echo "=== Building llvm-mingw-my2.1-32 (32-bit toolchains + packaging) ==="
echo "12ab34" | sudo -S docker build -t llvm-mingw-my2.1-32 -f Dockerfile.my2.1-32 .

echo "=== Cleaning up Docker resources ==="
echo "12ab34" | sudo -S docker builder prune -f
echo "12ab34" | sudo -S docker system prune -f
echo "12ab34" | sudo -S docker container prune -f

echo ""
echo "=== Build complete! ==="
echo "Final image: llvm-mingw-my2.1-32"
echo ""
echo "To run the container:"
echo "  sudo docker container run -v \$(pwd):/build/llvm-mingw -it llvm-mingw-my2.1-32 bash"
echo ""
echo "To list all images:"
echo "  sudo docker images | grep llvm-mingw"
