@echo off
@REM 启动本项目自带的 Neomacs 配置（w:\.emacs\early-init.el + init.el + lisp\*.el）
@REM --init-directory 让 Emacs 把 w:\.emacs 当成 user-emacs-directory，等价于 ~/.emacs.d
@REM 不加 -q，否则 early-init.el 与 site-start 都不会加载。
"D:\App\NEOEmacs\bin\runneomacs.exe" --init-directory=w:\.emacs
