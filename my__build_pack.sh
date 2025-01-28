
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my2.1-32 bash

cd WinMG32 && zip -r ../WinMG32.zip . && cd ..
cd WinMG64 && zip -r ../WinMG64.zip . && cd ..
cd Lin32 && zip -r ../Lin32.zip . && cd ..
cd Lin64 && zip -r ../Lin64.zip . && cd ..
cp *.zip llvm-mingw/
