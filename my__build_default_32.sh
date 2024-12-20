mkdir ../build
cd llvm-mingw
sudo docker container run  -v $(pwd):/build/llvm-mingw  -v $(pwd)/../build:/build/build -it llvm-mingw bash
./my_build-all.sh build/Windows --host=x86_64-w64-mingw32
./my_build-all.sh build/Linux 

./my_build-all.sh build/WindowsStatic --host=x86_64-w64-mingw32 --disable-dylib 
./my_build-all.sh build/LinuxStatic --disable-dylib 

./my_build-all.sh build/Windows32 --host=x86_64-w64-mingw32 
./my_build-all.sh build/Linux32 

./my_build-llvm_pgo_pre.sh build/win_pgo_pre32 --host=x86_64-w64-mingw32 --lto

# ./my_build-llvm_pgo_post.sh build/Windows32 --host=x86_64-w64-mingw32 --lto
# ./my_build-llvm_pgo_post.sh build/Linux32  --lto