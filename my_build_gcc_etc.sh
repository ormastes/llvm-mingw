#!/bin/bash
#11.4.0
#13.2.0
GCC_VERSION=11.4.0
PREFIX=/usr/local

wget http://www.zlib.net/zlib-1.3.1.tar.gz
tar -xvzf zlib-1.3.1.tar.gz
cd zlib-1.3.1 && ./configure --prefix=/usr/local/zlib && make && make install && cd ..
# Download and extract GCC source code
wget https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
tar -xzf gcc-$GCC_VERSION.tar.gz
cd gcc-$GCC_VERSION

# Create build directories
mkdir build

# Build and install 64-bit libstdc++ linux
cd build
../configure --enable-languages=c,c++ --enable-multilib
make -j$(nproc) 
sudo make install
cd ..

# Build and install 32-bit libstdc++ linux
mkdir build32
cd build32
../configure --enable-languages=c,c++ --enable-multilib --with-arch=i686
make -j$(nproc)
sudo make install
cd ..


rm -rf gcc-$GCC_VERSION gcc-$GCC_VERSION.tar.gz
rm -rf build
rm -rf build32

