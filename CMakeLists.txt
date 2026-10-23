cmake_minimum_required(VERSION 4.3)

# ---------------------------------------------------------------------------
#  工具链/开关与 build.bat、xmake.lua 保持一致: clang-cl + lld-link (MSVC ABI)
#  生成器用 Ninja: 单配置、靠 mtime 依赖图判定, 源码没改动时输出
#  "ninja: no work to do" 直接返回 => 增量/全量的判定不需要自己写
#  配置入口见 CMakePresets.json (debug / release / profile)
# ---------------------------------------------------------------------------
project(handmade LANGUAGES CXX)

# 本工程的开关全是 MSVC 语法 (/std: /GS- /Zi /MTd), 被 g++ 收下只会变成
# "cannot specify '-o' with '-c' with multiple files" 这类难读的报错,
# 所以在配置阶段就把错工具链挡住 (CLion/IDE 默认的 MinGW 工具链会走到这里)
if(NOT (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC"))
    message(FATAL_ERROR
        "本工程只支持 clang-cl (MSVC 前端 + lld-link)。当前编译器: ${CMAKE_CXX_COMPILER}\n"
        "  ID=${CMAKE_CXX_COMPILER_ID}  frontend=${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}\n"
        "命令行用预设: cmake --preset debug|release|profile\n"
        "CLion: Settings > Build, Execution, Deployment > CMake 里启用 CMakePresets 配置\n"
        "       (debug / release / profile), 不要用默认的 Debug + MinGW 工具链")
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)            # 给 clangd / cpptools / CLion
# /MTd (Debug) 与 /MT (其余): 静态 CRT, build 目录下的 exe 免装 VC 运行时
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Emacs 锁文件 (src/.#name.cpp) 也会匹配 *.cpp, 必须排除
file(GLOB HANDMADE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")
list(FILTER HANDMADE_SOURCES EXCLUDE REGEX "/\\.#")

# WIN32: 入口是 WinMain, 不写会被链成 console 子系统并报 "undefined symbol: main"
add_executable(handmade WIN32 ${HANDMADE_SOURCES})

target_compile_options(handmade PRIVATE
    /std:c++latest /utf-8 /W4
    /GR-                # 游戏: 关 RTTI (不用 dynamic_cast / typeid)
    /GS-                # 游戏: 关 /GS 栈 cookie, 省函数序言/尾声
    /Zi                 # PDB 调试信息, CodeLLDB / 崩溃转储都要它
    # 与 build.bat 的三个档位逐项对齐 (Debug 的 /Od /Ob0 由 CMake 默认给出)
    $<$<CONFIG:Debug>:/DDEBUG=1>
    $<$<CONFIG:Release>:/Oi /fp:fast /DNDEBUG>
    $<$<CONFIG:Profile>:/O2 /Oi /fp:fast /DNDEBUG /Oy->  # /Oy-: 保帧指针, 采样抓栈不断链
)

target_link_options(handmade PRIVATE /DEBUG:FULL)

# 资源随 exe 一起拷到产物目录, 保证构建出来的 exe 可以直接运行
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data")
    add_custom_command(TARGET handmade POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_SOURCE_DIR}/data" "$<TARGET_FILE_DIR:handmade>/data"
        COMMENT "copy data/ -> $<TARGET_FILE_DIR:handmade>/data")
endif()
