@echo off
rem ======================================================================
rem  win64-handmade build script (clang-cl + lld-link)
rem
rem  默认 = Debug 构建: 带完整调试信息(PDB)、不优化, 所有产物落在 build\
rem  面向游戏工程的默认设置:
rem    /GR-   关闭 RTTI (游戏不用 dynamic_cast / typeid)
rem    /GS-   关闭 /GS 栈检查 cookie (省函数序言/尾声开销)
rem    /MTd   静态 CRT, build 目录下的 exe 免装 VC 运行时即可直接跑
rem    /DEBUG 生成 PDB, 断点/单步/事后 dump 分析都可用
rem
rem  用法:
rem    build.bat                Debug 构建   -> build\win64-handmade.exe + .pdb
rem    build.bat -release       Release 构建 (优化 + 保留调试信息, 便于 profile)
rem    build.bat -profile       Profile 构建 (/O2 + /Oy- 保留帧指针 + 完整 PDB, 采样抓栈用)
rem    build.bat -c             只编译不链接 -> build\win64-handmade.obj
rem    build.bat -o name.exe    自定义输出文件名 (输出仍在 build\)
rem    build.bat -std=c++20     指定 C++ 标准 (默认 /std:c++latest)
rem    build.bat -clean         清空 build\ 后退出
rem ======================================================================
setlocal

set "ROOT=%~dp0"
set "BUILD_DIR=%ROOT%build"
set "SRC=%ROOT%src\win64-handmade.cpp"
set "DATA_DIR=%ROOT%data"
set "OBJ_NAME=win64-handmade.obj"
set "OUT_NAME=win64-handmade.exe"
set "MODE=debug"
set "COMPILE_ONLY=0"
set "STD_FLAG=/std:c++latest"

:parse_args
if "%~1"=="" goto prepare
if /I "%~1"=="-h"             goto usage
if /I "%~1"=="--help"         goto usage
if /I "%~1"=="-c"             goto arg_compile_only
if /I "%~1"=="-release"       goto arg_release
if /I "%~1"=="-profile"       goto arg_profile
if /I "%~1"=="-clean"         goto arg_clean
if /I "%~1"=="-o"             goto arg_output
if /I "%~1"=="-std=c++20"     goto arg_std20
if /I "%~1"=="-std=c++latest" goto arg_stdlatest
echo [Build] error: unknown argument "%~1"
goto usage

:arg_compile_only
set "COMPILE_ONLY=1"
shift
goto parse_args

:arg_release
set "MODE=release"
shift
goto parse_args

:arg_profile
set "MODE=profile"
shift
goto parse_args

:arg_std20
set "STD_FLAG=/std:c++20"
shift
goto parse_args

:arg_stdlatest
set "STD_FLAG=/std:c++latest"
shift
goto parse_args

:arg_output
if "%~2"=="" (
    echo [Build] error: -o needs a file name
    exit /b 2
)
set "OUT_NAME=%~2"
shift
shift
goto parse_args

:arg_clean
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
echo [Build] cleaned "%BUILD_DIR%"
exit /b 0

:usage
echo.
echo   build.bat [-release^|-profile] [-c] [-o name.exe] [-std=c++20^|-std=c++latest] [-clean]
echo.
echo   default : Debug build with PDB into build\
echo   -release: optimized build, keeps debug info
echo   -profile: optimized + frame pointers (/Oy-) + full PDB, for capture/profiling
echo   -c      : compile only (build\win64-handmade.obj)
echo   -o NAME : custom output executable name
echo   -clean  : remove build\ and exit
echo.
exit /b 2

:prepare
rem 源码必须存在, 否则后面的 clang-cl 只会给出难懂的报错
if not exist "%SRC%" (
    echo [Build] error: source not found: "%SRC%"
    exit /b 1
)

rem 注意: 必须用 "build" 或 ".\build", 写成 "./build" 会被 cmd 当成开关, 报
rem "The syntax of the command is incorrect." 并且不会创建目录 (历史 bug)
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if errorlevel 1 (
    echo [Build] error: cannot create "%BUILD_DIR%"
    exit /b 1
)
pushd "%BUILD_DIR%"
if errorlevel 1 (
    echo [Build] error: cannot enter "%BUILD_DIR%"
    exit /b 1
)

rem ---- 通用参数 ----
rem /nologo 不打印 banner; /W4 四级警告; /utf-8 源码与执行字符集都按 UTF-8
rem /EHsc   标准 C++ 异常语义 (STL 依赖, 不建议关)
set "CL_COMMON=/nologo /W4 /utf-8 /GR- /GS- /EHsc %STD_FLAG%"

if /I "%MODE%"=="profile" goto flags_profile
if /I "%MODE%"=="release" goto flags_release

rem ---- Debug (默认): 完整调试信息, 不优化 ----
set "CL_MODE=/Zi /Od /DDEBUG=1 /D_DEBUG /MTd"
set "LINK_DEBUG=/DEBUG:FULL"
echo [Build] mode   : Debug  (/Zi /Od /MTd + full PDB)
goto compile

:flags_profile
rem ---- Profile: 与 Release 同优化, 但 /Oy- 保留帧指针, 采样抓栈不断链 ----
set "CL_MODE=/Zi /O2 /Oi /fp:fast /Oy- /DNDEBUG /MT"
set "LINK_DEBUG=/DEBUG:FULL"
echo [Build] mode   : Profile  (/O2 /Oi /fp:fast /Oy- /MT + full PDB)
goto compile

:flags_release
rem ---- Release: 优化开启, 但仍保留符号表方便 profile / 崩溃分析 ----
set "CL_MODE=/Zi /O2 /Oi /fp:fast /DNDEBUG /MT"
set "LINK_DEBUG=/DEBUG"
echo [Build] mode   : Release  (/O2 /Oi /fp:fast /MT + PDB)

:compile
set "OUT_LABEL=%OUT_NAME%"
if "%COMPILE_ONLY%"=="1" set "OUT_LABEL=%OBJ_NAME%"
echo [Build] source : "%SRC%"
echo [Build] output : "%BUILD_DIR%\%OUT_LABEL%"

rem 两步构建: 先出 obj 再链接。原因: clang-cl 在"源码 + .lib 同处一条命令行"
rem 时会拒绝 /Fo (报 "cannot specify '/Fo...' when compiling multiple source files"),
rem 拆开两步就能把 obj 稳定留在 build\ 里
clang-cl %CL_COMMON% %CL_MODE% /c "%SRC%" /Fo:"%OBJ_NAME%"
if errorlevel 1 goto fail

if "%COMPILE_ONLY%"=="1" goto done_ok

clang-cl /nologo "%OBJ_NAME%" /Fe:"%OUT_NAME%" /link %LINK_DEBUG% user32.lib gdi32.lib
if errorlevel 1 goto fail

rem 资源同 exe 一起拷到 build\, 保证 build\ 下的 exe 可以直接运行
if exist "%DATA_DIR%" xcopy "%DATA_DIR%\*" "%BUILD_DIR%\data\" /E /I /Y /Q >nul 2>nul

:done_ok
popd
echo [Build] ok
exit /b 0

:fail
popd
echo [Build] FAILED
exit /b 1
