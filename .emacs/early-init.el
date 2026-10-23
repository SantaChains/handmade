;;; early-init.el --- 先于 init.el 和 UI 初始化执行 -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Emacs 27+ 的加载顺序：early-init.el -> 包/UI 初始化 -> init.el。
;; 这里只放三类「必须早」的东西：GC 阈值、Windows 文件系统开关、GUI 零件。
;; 每一项都是纯 setq / 一次 mode 调用，加载耗时可以忽略（实测 <1ms）。

;;; Code:

;;;; 1. 启动期放大 GC 阈值，after-init 后回落到 8MB
;; 启动过程中若触发 GC，会把刚分配的对象白扫一遍。启动完成后没有大量分配，
;; 阈值降回来，避免日常编辑时一次扫 128MB。
(setq gc-cons-threshold (* 128 1024 1024))
(add-hook 'after-init-hook (lambda () (setq gc-cons-threshold (* 8 1024 1024))) 90)

;;;; 2. Windows：不逐文件查安全描述符（访问大目录/项目树时明显）
(when (eq system-type 'windows-nt)
  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil))
  (when (boundp 'w32-pipe-read-delay)
    (setq w32-pipe-read-delay 0)))

;;;; 3. GUI 零件：在这里关掉，第一帧就不会画出来（比 init.el 里关更省）
(when (fboundp 'menu-bar-mode)   (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-screen t      ; 不显示 splash
      initial-scratch-message nil   ; *scratch* 留空
      ring-bell-function 'ignore    ; 不响铃、不闪屏
      use-dialog-box nil)           ; 弹窗走 minibuffer

(provide 'early-init)
;;; early-init.el ends here
