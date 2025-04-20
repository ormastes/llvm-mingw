
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my2.1-32 bash

cd WinMG32 && zip -q -r ../WinMG32.zip . && cd ..
cd WinMG64 && zip -q -r ../WinMG64.zip . && cd ..
cd Lin32 && zip -q -r ../Lin32.zip . && cd ..
cd Lin64 && zip -q -r ../Lin64.zip . && cd ..
#mv *.zip llvm-mingw/
