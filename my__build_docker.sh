sudo docker build -t llvm-mingw .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw bash
sudo docker build -t llvm-mingw-my1-linux-env -f Dockerfile.my1-linux-env . 
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my1-linux-env bash
sudo docker build -t llvm-mingw-my1-linux-envt -f Dockerfile.my1-linux-envt .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my1-linux-envt bash
sudo docker build -t llvm-mingw-my2-base -f Dockerfile.my2-base .
sudo docker build -t llvm-mingw-my3 -f Dockerfile.my3 .
