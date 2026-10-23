;;; init.el --- w:\.emacs 项目内 Neomacs 配置入口 -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; 启动链：emcs.bat -> runneomacs.exe --init-directory=w:\.emacs
;;         -> early-init.el -> init.el（本文件） -> lisp/ui.el
;;
;; 设计约束：不装任何第三方包（evil/主题/补全一律没有），
;; 因此启动开销只有「主题 + 字体」两项，实测见 README.md 的计时表。
;; 每个模块都独立可回退：注释掉下面一行，就退回到上一个状态。
;;
;;; Code:

;;;; 身份（影响文件头、邮件、org 导出）
(setq user-full-name "pureey"
      user-mail-address "148528901+SantaChains@users.noreply.github.com")

;;;; Custom 面板写出的变量另存，避免污染本文件（`C-h v' 里看到的值来自这里）
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)

;;;; 模块加载器
;; 用本文件自身路径定位 lisp/：--init-directory 与 -l 两种启动方式都能找到。
(defconst my/lisp-dir
  (expand-file-name "lisp/" (file-name-directory (or load-file-name buffer-file-name)))
  "配置模块目录。")

(load (expand-file-name "ui" my/lisp-dir) nil 'nomessage)

(provide 'init)
;;; init.el ends here
