echo on

mkdir stage0
cd stage0

REM Stage0 binaries directory; used in stage1.
set "stage0_bin_dir=%cd%\bin"
set stage0_cmake_flags=^
  -DCMAKE_BUILD_TYPE=Release ^
  -DLLVM_ENABLE_ASSERTIONS=OFF ^
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON ^
  -DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" ^
  -DLLVM_BUILD_LLVM_C_DYLIB=ON ^
  -DCMAKE_INSTALL_UCRT_LIBRARIES=ON ^
  -DPython3_FIND_REGISTRY=NEVER ^
  -DLLDB_RELOCATABLE_PYTHON=1 ^
  -DLLDB_EMBED_PYTHON_HOME=OFF ^
  -DCMAKE_CL_SHOWINCLUDES_PREFIX="Note: including file: " ^
  -DLLVM_ENABLE_LIBXML2=FORCE_ON ^
  -DLLDB_ENABLE_LIBXML2=OFF ^
  -DCLANG_ENABLE_LIBXML2=OFF ^
  -DCMAKE_C_FLAGS="-DLIBXML_STATIC" ^
  -DCMAKE_CXX_FLAGS="-DLIBXML_STATIC" ^
  -DLLVM_ENABLE_RPMALLOC=ON ^
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;compiler-rt;lldb;openmp" ^
  -DCLANG_DEFAULT_LINKER=lld ^
  -DLIBXML2_INCLUDE_DIR=%libxmldir%/include/libxml2 ^
  -DLIBXML2_LIBRARIES=%libxmldir%/lib/libxml2s.lib ^
  -DPython3_ROOT_DIR=%PYTHONHOME% ^
  -DCOMPILER_RT_BUILD_PROFILE=OFF ^
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF

REM We need to build stage0 compiler-rt with clang-cl (msvc lacks some builtins).
cmake -GNinja %stage0_cmake_flags% ^
  -DCMAKE_C_COMPILER=clang-cl.exe ^
  -DCMAKE_CXX_COMPILER=clang-cl.exe ^
  %SRC_DIR%/llvm
cd..

mkdir build
cd build

REM remove GL flag for now
set "CXXFLAGS=-MD"
set "CC=%stage0_bin_dir%/clang-cl.exe"
set "CXX=%stage0_bin_dir%/clang-cl.exe"

cmake -G "Ninja" ^
    -DCMAKE_BUILD_TYPE="Release" ^
    -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
    -DCMAKE_INSTALL_PREFIX:PATH=%LIBRARY_PREFIX% ^
    -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL ^
    -DLLVM_USE_INTEL_JITEVENTS=ON ^
    -DLLVM_ENABLE_DUMP=ON ^
    -DLLVM_ENABLE_LIBXML2=FORCE_ON ^
    -DLLVM_ENABLE_RTTI=ON ^
    -DLLVM_ENABLE_ZLIB=FORCE_ON ^
    -DLLVM_ENABLE_ZSTD=FORCE_ON ^
    -DLLVM_INCLUDE_BENCHMARKS=OFF ^
    -DLLVM_INCLUDE_DOCS=OFF ^
    -DLLVM_INCLUDE_EXAMPLES=OFF ^
    -DLLVM_INCLUDE_TESTS=ON ^
    -DLLVM_INCLUDE_UTILS=ON ^
    -DLLVM_INSTALL_UTILS=ON ^
    -DLLVM_USE_SYMLINKS=OFF ^
    -DLLVM_UTILS_INSTALL_DIR=libexec\llvm ^
    -DLLVM_BUILD_LLVM_C_DYLIB=ON ^
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly ^
    -DCMAKE_POLICY_DEFAULT_CMP0111=NEW ^
    %SRC_DIR%/llvm
if %ERRORLEVEL% neq 0 exit 1

cmake --build .
if %ERRORLEVEL% neq 0 exit 1

REM bin\opt -S -vector-library=SVML -mcpu=haswell -O3 %RECIPE_DIR%\numba-3016.ll | bin\FileCheck %RECIPE_DIR%\numba-3016.ll
REM if %ERRORLEVEL% neq 0 exit 1

cd ..\llvm\test
python ..\..\build\bin\llvm-lit.py -vv Transforms ExecutionEngine Analysis CodeGen/X86
