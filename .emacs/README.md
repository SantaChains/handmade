# 本项目内的 Neomacs 配置（w:\.emacs）

> 一句话：`emcs.bat` 启动 Neomacs（Rust 版 Emacs 31 分支），
> 默认深色主题 `manoj-dark` + 系统字体 **LXGW WenKai Mono（霞鹜文楷等宽）**，
> 不装任何第三方包。evil 与和弦改造**已按实测数据否决**，理由见第 5 节。

---

## 1. 目录结构

| 路径 | 作用 | 加载时机 |
|---|---|---|
| `emcs.bat` | 启动脚本：`runneomacs.exe --init-directory=w:\.emacs` | 你双击/命令行调用时 |
| `.emacs/early-init.el` | GC 阈值、Windows 文件扫描开关、关掉菜单栏/工具栏/滚动条、关 splash | 最早，UI 初始化之前 |
| `.emacs/init.el` | 身份、`custom-file` 重定向、模块加载器 | 第二 |
| `.emacs/lisp/ui.el` | 深色主题 + 字体 | 由 `init.el` `load` |
| `.emacs/tools/parse.el` | 自检工具：逐个文件读语法 / 查括号 / 编译 | 手动跑，不参与启动 |
| `.emacs/custom.el` | Custom 面板写出的变量（首次使用 `M-x customize` 后才生成） | 由 `init.el` `load` |
| `.emacs/README.md` | 本文件：使用说明 + 语法学习路线 | — |

`--init-directory` 是关键：它把 `w:\.emacs` 当成 Emacs 的 `user-emacs-directory`
（等价于平时的 `~/.emacs.d`），于是 `early-init.el` / `init.el` 会被自动加载。
**不要加 `-q`**，加了就跳过 `early-init.el` 和 `site-start`。

依赖：`w:` 是 `D:\LocalSend\Files\pro\handmade` 的 subst（见 `build.bat` 首行注释）。
机器重启后 subst 不持久时，先 `subst w: D:\LocalSend\Files\pro\handmade`，否则 `emcs.bat` 找不到配置。

旧写法 `-q -l w:\.emacs` 是坏的：`.emacs` 是目录，`-l` 要的是文件，会报
`Cannot open load file`。这也是本次改造顺手修掉的一处。

---

## 2. 启动与自检

```bat
:: 正常启动（GUI，无控制台窗口）
w:\emcs.bat
```

```bat
:: 从命令行启动并保留 stdout（排查用；runneomacs.exe 无控制台，看不到输出）
D:\App\NEOEmacs\bin\neomacs.exe --init-directory=w:\.emacs

:: 只跑配置不做界面（验证括号/语法错误，最快的一条）
:: 注意 --batch 隐含 -q（不加载 init.el），所以必须显式 -l
D:\App\NEOEmacs\bin\neomacs.exe --init-directory=w:\.emacs --batch -l w:\.emacs\init.el --eval "(princ custom-enabled-themes)"
:: 期望输出：(manoj-dark)

:: 启动出错时定位行号
D:\App\NEOEmacs\bin\neomacs.exe --init-directory=w:\.emacs --debug-init
```

界面上确认配置生效的两个命令：

| 命令 | 期望输出 |
|---|---|
| `M-x describe-face RET default` | `Family: LXGW WenKai Mono`，`Height: 170` |
| `C-h v custom-enabled-themes RET` | `(manoj-dark)` |

`M-x` = `Alt+x`；`C-h v` = `Ctrl+h` 然后 `v`。

---

## 3. 当前配置做了什么

### 3.1 主题（`lisp/ui.el`）

```elisp
(load-theme 'manoj-dark t)   ; 第二个参数 t = 不询问直接生效
```

内置主题，单文件，**实测 5–131ms**（波动来自虚拟机/GPU 首次初始化，不是主题本身）。
`modus-vivendi` 更好看但本机 Neomacs 上有两个坑，见第 6 节。

### 3.2 字体（`lisp/ui.el`）

三步，顺序不能反：

1. `set-face-attribute 'default` —— 拉丁字母/数字走这里；
2. `set-fontset-font t 'han` —— 中日韩字符显式绑同一字体，中英混排不跳字宽；
3. `initial-frame-alist` / `default-frame-alist` —— 第一帧就用它，避免先闪一下默认字体。

字体族名必须是**英文注册名** `LXGW WenKai Mono`（写中文「霞鹜文楷等宽」找不到）。
本机文件：`%LOCALAPPDATA%\Microsoft\Windows\Fonts\LXGWWenKaiMono-Regular.ttf`。

`my/font-available-p` 用 `font-family-list` 做一次存在性检查。这一步**首次调用约 147ms**
（第一次枚举 656 个字体族，之后只要 1.6ms），是整套配置里最贵的一项，属字体子系统初始化，
省不掉；反过来，`set-face-attribute` 指向一个**不存在**的字族会花 230ms
（`ui.el` 里的检查正是为了避免走这条路）。

---

## 4. 实测启动数据（2026-10-22，本机，同一台机器同一时段）

| 场景 | 启动耗时 | 采信方式 |
|---|---|---|
| `neomacs.exe -Q --batch`（无界面） | **188 / 198 / 187ms** | 进程墙钟，3 次 |
| GUI，只有 `early-init.el`（不设主题/字体） | **2138 / 2167 / 2258ms** | 进程内 `before-init-time` → `window-setup-hook`，3 次取最小 |
| GUI，本配置（主题 + 字体） | **1901 / 1942 / 2000ms** | 同上 |
| 逐项：`load-theme` | 5–131ms | 进程内计时 |
| 逐项：首次 `font-family-list` | 147ms | 进程内计时 |
| 逐项：`set-face-attribute` + `set-fontset-font` | 8.5ms + 2ms | 进程内计时 |
| **evil `require`** | **864ms**（batch 下 946–1002ms） | 进程内计时，3 次 |
| **evil `evil-mode 1`** | **19ms** | 进程内计时 |
| **evil-collection `require` + `init`** | **723ms** | 进程内计时 |
| 参照：内置 `org` `require` | 443ms | 说明解释器整体偏慢 |

**结论一：GUI 的 2 秒开销不在配置里。** 不设主题、不设字体、只留 `early-init.el`
也是 2.1s；本配置 1.9s（差异在噪声 ±150ms 之内）。瓶颈是 Neomacs GUI 自身的
窗口/GPU 初始化，`-Q` 也一样，改配置动不了它。

**结论二：evil 不是「轻量」的。** evil + evil-collection 合计 **+1.6s**，
相当于在 2.0s 上再翻 80%。

---

## 5. 为什么最终**没有**做 evil 和「和弦简化」

你给的门槛是「几百毫秒内启动才做」。按第 4 节数据，连 `-Q` 的 GUI 都要 2.1s，
evil 再 +1.6s —— 门槛没有达成，所以这两项**不做**，只保留主题 + 字体。

这不是「没想到」，而是先把账算清楚：

| 方案 | 代价 | 结论 |
|---|---|---|
| evil + evil-collection | +1.6s | 否决（超门槛 8 倍以上） |
| 和弦清野（unbind 68 个 `M-*`/`C-M-*`） | 纯减法，~0ms | 也不做：没有 evil 的 operator/motion 兜底，删了就没等价键；等 evil 真启用时再做 |
| leader 层（`SPC`） | general 需 ~150ms 级 + 依赖 evil | 同上，跟 evil 同生共死 |
| `key-chord`（同击双键） | 需延迟判定，快打会 lag | 不采纳（`~/.emacs.d/KEYS-ERGONOMICS.md` §7 已有论证） |

完整的和弦改造设计与数据（177 → 109 → 73 的三阶段目标）已经写在
`C:\Users\JliuPureey\.emacs.d\KEYS-ERGONOMICS.md`，那是**系统级配置**的账本；
本项目日后若要上 evil，直接对照那份文档的 P0-a/P0-b 执行即可。

---

## 6. 本机 Neomacs 的两个坑（都实测过）

1. **`fontset-font` 说谎。** `(fontset-font t ?中)` 返回 `("mutt-clearlyu" . "iso10646-1")`，
   但 `(font-get (font-at 0 nil "中") :family)` 返回 `"LXGW WenKai Mono"`。
   后者才是真实渲染用的字体（前者只是 fontset 里的模式串）。**判断字体用 `font-at`**。
2. **`load-theme 'modus-vivendi` 会失败。** 报 `Cannot open load file: modus-themes`，
   因为 `custom-theme-load-path` 里有 `data-directory/themes`，但 theme 文件里的
   `(require 'modus-themes)` 找不到同目录的 `modus-themes.el`。绕法一行：

   ```elisp
   (add-to-list 'load-path (expand-file-name "themes" data-directory))
   (load-theme 'modus-vivendi t)   ; 实测 238ms，是 manoj-dark 的 20~40 倍
   ```

3. **`--batch` 隐含 `-q`。** 帮助文本里写着「implies -q」，所以 `--init-directory=... --batch`
   **不会**加载 `init.el`，`features` 里连 `init` 都没有（本轮就踩过）。要批量验证配置，
   必须显式 `-l w:\.emacs\init.el`。

另外 `runneomacs.exe` 无控制台，`princ`/`message` 输出看不到；要输出就用 `neomacs.exe`
或写文件。

---

## 7. 学 Emacs Lisp：本配置足够练的最小闭环

### 7.1 四个必会按键

| 键 | 命令 | 用途 |
|---|---|---|
| `C-x C-e` | `eval-last-sexp` | 求值光标前那个括号表达式，结果在 echo area |
| `C-M-x` | `eval-defun` | 求值整个 `defun`（改完函数按它，不用重启） |
| `C-h v` / `C-h f` | `describe-variable` / `describe-function` | 变量/函数文档，含源码链接 |
| `C-h k` | `describe-key` | 按一个键，看它到底绑定到谁 |

交互实验场：`M-x ielm`（REPL）。改配置时**永远先 `C-x C-e` 单行验证再落盘**。

### 7.2 本配置用到的语法，按难度递增

```elisp
;; 1. setq：改变量。一次设多个，成对出现
(setq inhibit-startup-screen t
      ring-bell-function 'ignore)

;; 2. 引号 ' ：不要求值，把符号本身当数据
(load-theme 'manoj-dark t)          ; 'manoj-dark 就是符号 manoj-dark

;; 3. defconst / defvar：定义自己的变量；defconst 表示「别改我」
(defconst my/font-family "LXGW WenKai Mono")

;; 4. defun + lambda：定义函数
(defun my/font-available-p (family)
  "FAMILY 是否可用。"                 ; 文档字符串，C-h f 能看到
  (and (display-graphic-p) (member family (font-family-list))))
(add-hook 'after-init-hook (lambda () (setq gc-cons-threshold (* 8 1024 1024))) 90)

;; 5. let：局部绑定（类似块级作用域）
(let ((spec (font-spec :family my/font-family :size 17)))
  (push (cons 'font spec) initial-frame-alist))

;; 6. dolist / when / unless：遍历与条件
(dolist (script '(han cjk-misc bopomofo kana))
  (set-fontset-font t script (font-spec :family my/font-family)))
(when (fboundp 'menu-bar-mode) (menu-bar-mode -1))

;; 7. 属性列表（plist）：:key value 成对，set-face-attribute 的参数就是它
(set-face-attribute 'default nil :family "LXGW WenKai Mono" :height 170)

;; 8. 加载协议：provide / require / load
(provide 'ui)                       ; lisp/ui.el 结尾声明「我提供 ui 这个 feature」
(load (expand-file-name "ui" my/lisp-dir) nil 'nomessage)  ; 按路径加载，不建 feature 依赖

;; 9. 定位自身路径（本配置的加载器就靠它，两种启动方式都能用）
(file-name-directory (or load-file-name buffer-file-name))
```

### 7.3 调试三件套

| 症状 | 命令 |
|---|---|
| 启动就报错、看不出哪一行 | `neomacs.exe --init-directory=w:\.emacs --debug-init` |
| 交互操作报错想进 debugger | `M-x toggle-debug-on-error` |
| 看启动各阶段耗时 | `M-x emacs-init-time`，或 `C-h v before-init-time` |

**规则**：改一行 → `C-x C-e` 看 echo area → 有错改 → 再落盘。不要改三处再启动。

### 7.4 常见改法（复制即用）

```elisp
;; 换主题（内置，均为深色）：deeper-blue / tsdh-dark / wombat / tango-dark / manoj-dark
(load-theme 'tsdh-dark t)                      ; 同一时间只留一个，换前先 disable-theme

;; 换字号（170 = 17pt；中文字形大，17~20 之间试）
(set-face-attribute 'default nil :height 190)

;; 打开行号 + 列号（默认没开，因为本次需求没要求）
(global-display-line-numbers-mode 1)
(column-number-mode 1)

;; 关掉 Ctrl+Z 挂起（Windows 上没意义）
(when (fboundp 'global-unset-key) (global-unset-key (kbd "C-z")))

;; 让 lisp/ui.el 里新加的 defun 能被 C-h f 找到：加一行 (provide 'ui) 前先 C-M-x 求值
```

---

## 8. 回退

| 想退到 | 做法 |
|---|---|
| 退回 Neomacs 原始默认（白底、默认字体） | `emcs.bat` 里改成 `runneomacs.exe -Q` |
| 只退主题 | 注释 `lisp/ui.el` 第一段 `(load-theme ...)` |
| 只退字体 | 注释 `lisp/ui.el` 的 `(when (my/font-available-p ...) ...)` 整块 |
| 退掉 early-init 优化 | 注释 `.emacs/early-init.el` 第 1、2 段；GUI 零件开关留着无害 |
| 退掉整个项目配置 | `runneomacs.exe --init-directory=%USERPROFILE%\.emacs.d`（用系统配置） |

改完任何一处，用第 2 节的 `--batch ... -l init.el` 自检命令确认没有括号错误
（Lisp 唯一的高频事故就是少一个右括号），再启动 GUI 确认观感。

---

## 9. 验证清单（改完就按顺序跑，全部有可读输出）

| # | 检查什么 | 命令 | 期望 |
|---|---|---|---|
| 1 | 语法 / 括号 / 编译期未定义（三合一） | `neomacs.exe -Q --batch -l w:\.emacs\tools\parse.el` | 3 行全为 `read=OK parens=OK bc=t` |
| 2 | 配置能否无错加载 | 第 2 节的自检命令 | 输出 `(manoj-dark)` |
| 3 | 主题/字体是否真生效 | GUI 里 `M-x describe-face RET default` | `Family: LXGW WenKai Mono`，`Height: 170` |
| 4 | 启动脚本能否到位 | 启动后 `Get-CimInstance Win32_Process -Filter "Name='neomacs.exe'"` 看 `CommandLine` | 含 `--init-directory=w:\.emacs` |

检查 1 的实测输出（`tools/parse.el` 已包含这三个断言）：

```
w:/.emacs/early-init.el      forms=8   read=OK   parens=OK   bc=t
w:/.emacs/init.el            forms=6   read=OK   parens=OK   bc=t
w:/.emacs/lisp/ui.el         forms=6   read=OK   parens=OK   bc=t
```

`bc=` 是 `byte-compile-file` 的结果（编译完自动删 .elc），能抓到运行时不报的
未绑定变量 / 未定义函数。两个必须知道的坑已经写进 `tools/parse.el` 的注释：
**必须先 `emacs-lisp-mode`**（在 `fundamental-mode` 下 `check-parens` 会误报
`Unmatched bracket or quote`，GNU Emacs 32 相同，已用 oracle 排除）。

第 3 步也可以不看 face 名、直接问「这一个字实际用哪个字体渲染」（比 `fontset-font` 可靠，
见第 6 节坑 1）：

```elisp
(font-get (font-at 0 nil "中") :family)   ; => "LXGW WenKai Mono"
```
