-- ======================================================================
--  xmake 构建脚本 —— 与 build.bat 等价的另一条构建路径
--
--  工具链 : clang-cl 编译 + lld-link 链接 (同 build.bat)
--  产物   : build\win64-handmade.exe (+ .pdb), 资源拷到 build\data\
--  模式   : xmake 默认 Debug (与 build.bat 默认一致)
--
--  用法:
--    xmake                 Debug 构建  -> build\win64-handmade.exe
--    xmake -r              Release 构建 (优化 + 保留 PDB, 便于 profile)
--    xmake f -m profile    Profile 构建 (/O2 + 完整符号 + 保留帧指针, 给抓帧/热点定位)
--    xmake run             构建并运行 (工作目录 = build\, 与双击 exe 一致)
--    xmake project -k compile_commands --lsp=clangd
--                          生成 compile_commands.json (带 MSVC/WinSDK 头文件路径), 给 CLion / clangd 用
--    xmake f -m debug -c   重新配置为 Debug
--    xmake clean           清理 xmake 产物
-- ======================================================================
set_project("win64-handmade")
set_version("0.1.0")

set_defaultplat("windows")
set_defaultarchs("x64")
set_defaultmode("debug")            -- build.bat 默认也是 Debug

-- 通用语言/编码/警告:/std:c++latest /utf-8 /W4
set_languages("c++latest")
set_encodings("utf-8")
set_warnings("allextra")            -- -W4

add_rules("mode.debug", "mode.release", "mode.profile")

target("win64-handmade")
    set_kind("binary")

    -- clang-cl[llvm] = clang-cl 编译 + LLVM lld-link 链接
    set_toolchains("clang-cl[llvm]")

    add_files("src/*.cpp")
    remove_files("src/.#*.cpp")     -- Emacs 锁文件 (.#name.cpp) 不能参与编译

    add_syslinks("user32", "gdi32")

    -- 游戏工程的默认设置: 关 RTTI, 关 /GS 栈 cookie
    add_cxflags("/GR-", "/GS-", {force = true})

    -- 产物直接落 build\ 根目录, 与 build.bat 保持一致
    set_targetdir("$(builddir)")
    set_rundir("$(builddir)")       -- xmake run 的工作目录 = 部署目录 (exe 同级有 data\)

    if is_mode("debug") then
        -- /Zi /Od /MTd  静态 CRT, 免装 VC 运行时
        set_symbols("debug")
        set_optimize("none")
        set_runtimes("MTd")
        add_defines("DEBUG", "_DEBUG")
    else
        -- release / profile 共用优化档: /Zi /O2 /Oi /fp:fast /MT, 都保留 PDB
        -- (Release 也留 PDB, 崩溃分析 / profile 都用得上, 与 build.bat 一致)
        set_symbols("debug")
        set_optimize("fastest")     -- clang-cl 下 fastest = /O2
        set_runtimes("MT")
        add_cxflags("/Oi", "/fp:fast", {force = true})
        add_ldflags("/DEBUG", {force = true})

        if is_mode("profile") then
            -- /O2 默认省略帧指针 (/Oy), 采样抓栈会断链; profile 档留帧指针,
            -- 换来完整可靠的 callstack, 代价是慢一点点
            add_cxflags("/Oy-", {force = true})
        end
    end

    -- 资源随 exe 一起拷到 build\data\, 保证 build\ 下的 exe 可以直接运行
    after_build(function (target)
        local datadir = path.join(os.projectdir(), "data")
        if os.isdir(datadir) then
            os.cp(datadir, target:targetdir())
        end
    end)
