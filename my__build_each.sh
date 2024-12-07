sudo docker container run  -v $(pwd):/build -v $(pwd)/../build:/build/build -it llvm-mingw bash
# ./build-all.sh build_win --host=x86_64-w64-mingw32 --lto
# ./build-all.sh build_linux --lto

# ./my_build-all.sh build_win32 --host=x86_64-w64-mingw32 --lto
# ./my_build-all.sh build_linux32 --lto
# ./my_build-llvm.sh build_win32 --host=x86_64-w64-mingw32 --lto
# ./my_build-llvm.sh build_linux32 --lto
# ./my_build-llvm_pgo_pre.sh build_win_pgo_pre32 --host=x86_64-w64-mingw32 --lto

# ./my_build-llvm_pgo_post.sh build_win32 --host=x86_64-w64-mingw32 --lto
# ./my_build-llvm_pgo_post.sh build_linux32 --lto

# build lib
## ./build-compiler-rt.sh build_win --enable-cfguard
## ./build-compiler-rt.sh build_win --build-sanitizers --host=x86_64-w64-mingw32 
# ./my_build-compiler-rt.sh build_win32 --enable-cfguard --host=x86_64-w64-mingw32
# ./my_build-compiler-rt.sh build_linux32 --enable-cfguard
# ./build-compiler-rt.sh build_win32 --build-sanitizers --host=x86_64-w64-mingw32 
# ./build-compiler-rt.sh build_linux32 --build-sanitizers 

# ./build-all.sh build --host=x86_64-w64-mingw32
# cp -r /opt/llvm-mingw /linked_dir