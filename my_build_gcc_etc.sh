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
./contrib/download_prerequisites

cd libstdc++-v3
../configure --prefix=/opt/llvm-linux/i686-linux-gnu \
    --disable-shared --enable-static \
    --disable-multilib \
    CXXFLAGS="-m32 -static-libgcc" LDFLAGS="-m32"
cd ..
# Build and install 64-bit gcc and libatomic
#mkdir -p build
#cd build
#../configure --enable-languages=c,c++ --enable-multilib --disable-bootstrap --enable-shared --enable-static
#make -j$(nproc)
#make install
#cd ..

cd ..
# Clean up
rm -rf gcc-$GCC_VERSION 
rm -f gcc-$GCC_VERSION.tar.gz
rm -rf zlib-1.3.1
rm -f zlib-1.3.1 zlib-1.3.1.tar.gz
