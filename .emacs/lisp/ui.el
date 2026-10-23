;;; ui.el --- 深色主题 + 霞鹜文楷等宽字体 -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; 两个开关式配置：主题一行、字体一段。都不依赖网络和第三方包。
;; 主题选 manoj-dark 的理由是可测的：内置单文件，8ms 加载完（modus-vivendi 要 238ms，
;; 且在本机 neomacs 上还得先手动补 load-path 才能 require，见 README 的对照表）。
;;
;;; Code:

;;;; 主题（深色）
;; `load-theme' 第二个参数 t = 不询问、直接生效（配置文件里必须这么写，
;; 否则启动时会卡在 "Load theme? (y or n)"）。
(load-theme 'manoj-dark t)

;;;; 字体
(defconst my/font-family "LXGW WenKai Mono"
  "首选等宽字体（霞鹜文楷等宽）。
本机文件：%LOCALAPPDATA%\\Microsoft\\Windows\\Fonts\\LXGWWenKaiMono-Regular.ttf
字体族名来自系统注册表，必须是英文名，不能写中文名。")

(defconst my/font-height 170
  "默认字号，单位是 0.1pt：170 = 17pt。")

(defun my/font-available-p (family)
  "FAMILY 是否在当前图形终端可用。"
  (and (display-graphic-p) (member family (font-family-list))))

(when (my/font-available-p my/font-family)
  ;; 1) 默认 face：拉丁字母、数字、符号走这里
  (set-face-attribute 'default nil :family my/font-family :height my/font-height)

  ;; 2) 中日韩字符：显式绑到同一字体，中英混排时字宽/基线一致，不跳动
  (dolist (script '(han cjk-misc bopomofo kana))
    (set-fontset-font t script (font-spec :family my/font-family)))

  ;; 3) 首帧就用这个字体，避免窗口先闪一下默认字体再变
  (let ((spec (font-spec :family my/font-family :size (/ my/font-height 10))))
    (setq initial-frame-alist (cons (cons 'font spec) initial-frame-alist)
          default-frame-alist (cons (cons 'font spec) default-frame-alist))))

(provide 'ui)
;;; ui.el ends here
