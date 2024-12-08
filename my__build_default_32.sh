#mkdir ../build
#sudo docker container run  -v $(pwd):/build -v $(pwd)/../build:/build/build -it llvm-mingw bash
./build-all.sh build/WindowsDynlib --host=x86_64-w64-mingw32
./build-all.sh build/LinuxDynlib 

./build-all.sh build/Windows --host=x86_64-w64-mingw32 --disable-dylib 
./build-all.sh build/Linux --disable-dylib 

./my_build-all.sh build/Windows32 --host=x86_64-w64-mingw32 
./my_build-all.sh build/Linux32 

./my_build-llvm_pgo_pre.sh build/win_pgo_pre32 --host=x86_64-w64-mingw32 --lto

# ./my_build-llvm_pgo_post.sh build/Windows32 --host=x86_64-w64-mingw32 --lto
# ./my_build-llvm_pgo_post.sh build/Linux32  --lto