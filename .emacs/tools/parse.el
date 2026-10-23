;;; parse.el --- 配置自检：读语法 + 查括号 + 编译 -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; 用法（项目根目录或任意位置）：
;;   D:\App\NEOEmacs\bin\neomacs.exe -Q --batch -l w:\.emacs\tools\parse.el
;;
;; 每个文件输出一行：forms=N read=OK parens=OK bc=t
;;   forms  —— 能读出的顶层表达式个数（少一个说明有表达式被注释掉了）
;;   read   —— read 是否读完不报错（真正的括号/引号错误会在这里 FAIL）
;;   parens —— check-parens 结果
;;   bc     —— byte-compile-file 是否成功（能抓未绑定变量、未定义函数）
;;
;; 两个必须知道的坑：
;;   1. 必须先 `emacs-lisp-mode`。在 fundamental-mode 下 check-parens 会误报
;;      "Unmatched bracket or quote"（GNU Emacs 32 同样行为，不是本配置的问题）。
;;   2. byte-compile-file 会在源码旁生成 .elc，这里编译完立刻删掉，避免产物入库。
;;
;;; Code:

(defconst my/checked-files
  '("w:/.emacs/early-init.el" "w:/.emacs/init.el" "w:/.emacs/lisp/ui.el")
  "要自检的配置文件。新增模块记得加进来。")

(dolist (f my/checked-files)
  (let (n rd cp bc)
    (with-temp-buffer
      (insert-file-contents f)
      (delay-mode-hooks (emacs-lisp-mode))      ; 坑 1：不能省
      (goto-char (point-min))
      (setq n 0)
      (condition-case e
          (while t (read (current-buffer)) (setq n (1+ n)))
        (end-of-file nil)
        (error (setq rd e)))
      (setq cp (condition-case e (progn (check-parens) "OK")
                 (error (format "FAIL(pos=%d line=%d %S)" (point) (line-number-at-pos) e)))))
    (setq bc (condition-case e
                 (prog1 (byte-compile-file f)
                   (let ((elc (byte-compile-dest-file f)))
                     (when (file-exists-p elc) (delete-file elc))))
               (error (format "FAIL(%s)" e))))
    (princ (format "%-28s forms=%-3d read=%-4s parens=%-4s bc=%s\n"
                   f n (if rd "FAIL" "OK") cp bc))))

(provide 'parse)
;;; parse.el ends here
