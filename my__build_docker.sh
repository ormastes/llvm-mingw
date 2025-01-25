#sudo docker build -t llvm-mingw .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw bash
#sudo docker build -t llvm-mingw-my0 -f Dockerfile.my0 . 
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my0 bash
#sudo docker build -t llvm-mingw-my1-linux-env -f Dockerfile.my1-linux-env . 
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my1-linux-env bash
# sudo docker build -t llvm-mingw-my1-linux-envt -f Dockerfile.my1-linux-envt .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my1-linux-envt bash
sudo docker builder prune -f
sudo docker build -t llvm-mingw-my2-base -f Dockerfile.my2-base .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my2-base bash

sudo docker build -t llvm-mingw-my2.1-32 -f Dockerfile.my2.1-32 .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my2.1-32 bash

sudo docker build -t llvm-mingw-my3 -f Dockerfile.my3 .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my3 bash

sudo docker build -t llvm-mingw-my3-post -f Dockerfile.my3-post .
# sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw-my3-post bash
sudo docker builder prune -f
sudo docker system prune -f
sudo docker container prune -f
#sudo docker image save  llvm-mingw-my3-post | tqdm --bytes --total $(sudo docker image inspect llvm-mingw-my3-post --format='{{.Size}}') > llvm.tar