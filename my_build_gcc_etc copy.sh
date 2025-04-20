#!/bin/bash
#11.4.0
#13.2.0
GCC_VERSION=11.4.0
PREFIX=/usr/local
THREADS=$(nproc)

cd gcc-$GCC_VERSION
# Build and install 32-bit libstdc++ (Dynamic and Static)
cd build32
# backup CC and CXX
export CC_OLD=$CC
export CXX_OLD=$CXX
export CFLAGS_OLD=$CFLAGS
export LDFLAGS_OLD=$LDFLAGS
export CC="gcc -m32"
export CXX="g++ -m32"
export CFLAGS="-m32 -I/usr/include/i386-linux-gnu"
export LDFLAGS="-m32 -L/usr/lib32 -L/usr/lib/i386-linux-gnu"
../configure --enable-languages=c,c++ --disable-multilib --enable-static --enable-shared --host=x86_64-linux-gnu --build=x86_64-linux-gnu --target=i686-pc-linux-gnu 
make -j$THREADS
make install
# restore CC and CXX
export CC=$CC_OLD
export CXX=$CXX_OLD
export CFLAGS=$CFLAGS_OLD
export LDFLAGS=$LDFLAGS_OLD
cd ..
cd ..