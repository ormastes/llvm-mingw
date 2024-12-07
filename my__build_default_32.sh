mkdir ../build
sudo docker container run  -v $(pwd):/build -v $(pwd)/../build:/build/build -it llvm-mingw bash
./build-all.sh build/WindowsDynlib --host=x86_64-w64-mingw32 --lto
./build-all.sh build/LinuxDynlib --lto

./build-all.sh build/Windows --host=x86_64-w64-mingw32 --disable-dylib --lto
./build-all.sh build/Linux --disable-dylib --lto

./my_build-all.sh build/Windows32 --host=x86_64-w64-mingw32 --lto
./my_build-all.sh build/Linux32 --lto

./my_build-all.sh build/Windows32 --host=x86_64-w64-mingw32 --lto
./my_build-all.sh build/Linux32 --lto

./my_build-llvm_pgo_pre.sh build_win_pgo_pre32 --host=x86_64-w64-mingw32 --lto

# ./my_build-llvm_pgo_post.sh build_win32 --host=x86_64-w64-mingw32 --lto
# ./my_build-llvm_pgo_post.sh build_linux32 --lto