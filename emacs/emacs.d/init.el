;; -*- lexical-binding: t; -*-

;;; ---------------------------------------------------------------------------
;;; Package system
;;; ---------------------------------------------------------------------------

(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(defvar mm/package-contents-refreshed nil)

(defun mm/require (&rest packages)
  "Install each of PACKAGES that is not installed yet."
  (dolist (package packages)
    (unless (package-installed-p package)
      (unless mm/package-contents-refreshed
        (setq mm/package-contents-refreshed t)
        (package-refresh-contents))
      (package-install package))))

;; Keep Custom's auto-generated settings in their own file so package
;; installs don't rewrite this one.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;;; ---------------------------------------------------------------------------
;;; Appearance
;;; ---------------------------------------------------------------------------

(mm/require 'gruber-darker-theme)
(load-theme 'gruber-darker t)

(tool-bar-mode 0)
(menu-bar-mode 0)
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode 0))
(column-number-mode 1)
(show-paren-mode 1)

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;;; ---------------------------------------------------------------------------
;;; Sane defaults
;;; ---------------------------------------------------------------------------

(setq-default inhibit-splash-screen t
              make-backup-files nil
              tab-width 4
              indent-tabs-mode nil)

(setq confirm-kill-emacs 'y-or-n-p)
(setq warning-suppress-log-types '((files missing-lexbind-cookie)))

;;; ---------------------------------------------------------------------------
;;; Minibuffer completion
;;; ---------------------------------------------------------------------------

(fido-vertical-mode 1)

;;; ---------------------------------------------------------------------------
;;; Shell environment
;;;
;;; A GUI Emacs on macOS is launched by the window server, not by your shell,
;;; so it never sees the PATH from .zshrc. Without this, Emacs cannot find
;;; clangd.
;;; ---------------------------------------------------------------------------

(mm/require 'exec-path-from-shell)

(when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize))

;;; ---------------------------------------------------------------------------
;;; Completion popup
;;; ---------------------------------------------------------------------------

(mm/require 'company)

(setq company-idle-delay 0.2
      company-minimum-prefix-length 1)

;;; ---------------------------------------------------------------------------
;;; C / C++
;;;
;;; eglot is built in and already knows to launch clangd for these modes.
;;; It needs a compile_commands.json at the project root to resolve includes.
;;; ---------------------------------------------------------------------------

(dolist (hook '(c-mode-hook c++-mode-hook c-ts-mode-hook c++-ts-mode-hook))
  (add-hook hook #'eglot-ensure)
  (add-hook hook #'company-mode))

;;; ---------------------------------------------------------------------------
;;; CMake builds
;;;
;;; Both helpers resolve the project from the nearest CMakeLists.txt and drive
;;; the out-of-source build/ directory, configuring it first when the cache is
;;; absent so a fresh clone needs no manual cmake run.
;;; ---------------------------------------------------------------------------

(defvar mm/cmake-history nil)

(defun mm/cmake-root ()
  "Directory of the nearest CMakeLists.txt at or above `default-directory'."
  (or (locate-dominating-file default-directory "CMakeLists.txt")
      (user-error "No CMakeLists.txt above %s" default-directory)))

(defun mm/cmake-configure-prefix ()
  (unless (file-exists-p "build/CMakeCache.txt")
    "cmake -S . -B build && "))

(defun mm/cmake (target)
  "Build TARGET of the enclosing CMake project."
  (interactive
   (list (read-string "cmake target: " nil 'mm/cmake-history "all")))
  (let ((default-directory (mm/cmake-root)))
    (compile (concat (mm/cmake-configure-prefix)
                     (format "cmake --build build -j%d --target %s"
                             (num-processors) target)))))

(defun mm/ctest ()
  "Build the enclosing CMake project and run its test suite."
  (interactive)
  (let ((default-directory (mm/cmake-root)))
    (compile (concat (mm/cmake-configure-prefix)
                     (format "cmake --build build -j%d && " (num-processors))
                     "ctest --test-dir build --output-on-failure"))))

(defun mm/cmake-set-compile-command ()
  "Point plain \\[compile] at the project build instead of the `make -k' default."
  (setq-local compile-command
              (format "cmake --build build -j%d" (num-processors))))

(dolist (hook '(c-mode-hook c++-mode-hook c-ts-mode-hook c++-ts-mode-hook))
  (add-hook hook #'mm/cmake-set-compile-command))

(global-set-key (kbd "C-c c") 'mm/cmake)
(global-set-key (kbd "C-c t") 'mm/ctest)
(global-set-key (kbd "C-c n") 'next-error)
(global-set-key (kbd "C-c p") 'previous-error)

;;; ---------------------------------------------------------------------------
;;; Tree-sitter grammars
;;;
;;; Emacs ships the major modes but not the grammars themselves.
;;; M-x mm/treesit-install-missing compiles the ones listed here.
;;; ---------------------------------------------------------------------------

(require 'treesit)

(dolist (source '((java "https://github.com/tree-sitter/tree-sitter-java")
                  (kotlin "https://github.com/fwcd/tree-sitter-kotlin")
                  (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
                  (typescript "https://github.com/tree-sitter/tree-sitter-typescript" nil "typescript/src")
                  (tsx "https://github.com/tree-sitter/tree-sitter-typescript" nil "tsx/src")
                  (json "https://github.com/tree-sitter/tree-sitter-json")
                  ;; js-ts-mode and friends highlight doc comments with this one.
                  (jsdoc "https://github.com/tree-sitter/tree-sitter-jsdoc")))
  (add-to-list 'treesit-language-source-alist source))

(defun mm/treesit-install-missing ()
  "Compile every grammar in `treesit-language-source-alist' that is missing."
  (interactive)
  (dolist (lang (mapcar #'car treesit-language-source-alist))
    (unless (treesit-language-available-p lang)
      (treesit-install-language-grammar lang))))

;;; ---------------------------------------------------------------------------
;;; Java / Kotlin
;;;
;;; Both servers need a recent JDK to run on -- jdtls refuses to start on
;;; anything below 21 -- while the projects themselves still target Java 11.
;;; So the servers get their own JDK, and jdtls is handed the whole list of
;;; installed ones so it can compile each module against its real target.
;;; ---------------------------------------------------------------------------

(mm/require 'kotlin-ts-mode 'groovy-mode)

(defvar mm/sdkman-java-dir (expand-file-name "~/.sdkman/candidates/java"))

(defun mm/jdk-path (major)
  "Newest sdkman JDK whose major version is MAJOR, or nil if none."
  (car (sort (directory-files mm/sdkman-java-dir t (format "\\`%d\\." major))
             #'string>)))

(defun mm/jdtls-runtimes ()
  "Installed JDKs, in the shape jdtls expects for `java.configuration.runtimes'."
  (vconcat
   (delq nil
         (mapcar (lambda (major)
                   (when-let* ((path (mm/jdk-path major)))
                     (list :name (format "JavaSE-%d" major) :path path)))
                 '(11 17 21 25)))))

(defvar mm/lsp-jdk (or (mm/jdk-path 25) (mm/jdk-path 21))
  "JDK the language servers run on, regardless of what a project builds with.")

(add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode))
(add-to-list 'auto-mode-alist '("\\.kts?\\'" . kotlin-ts-mode))

(with-eval-after-load 'eglot
  ;; Both entries shadow eglot's defaults, which point at executables that
  ;; are not installed here.
  (add-to-list 'eglot-server-programs
               `((java-mode java-ts-mode)
                 . (,(expand-file-name "~/.local/share/jdtls/bin/jdtls")
                    ,(format "--java-executable=%s/bin/java" mm/lsp-jdk))))

  (add-to-list 'eglot-server-programs
               `((kotlin-mode kotlin-ts-mode)
                 . (,(expand-file-name "~/.local/share/kotlin-lsp/bin/intellij-server")
                    "--stdio"
                    ;; Without this the IntelliJ indexes land in a temp dir and
                    ;; are rebuilt from scratch on every restart.
                    ,(format "--system-path=%s" (expand-file-name "~/.cache/kotlin-lsp")))))

  (setq-default eglot-workspace-configuration
                `(:java (:configuration (:runtimes ,(mm/jdtls-runtimes))))))

(dolist (hook '(java-ts-mode-hook kotlin-ts-mode-hook))
  (add-hook hook #'eglot-ensure)
  (add-hook hook #'company-mode))

;;; ---------------------------------------------------------------------------
;;; Gradle
;;;
;;; Gradle 7.x does not run on JDK 21+, so the wrapper is invoked with the
;;; JDK the project actually targets rather than whatever sdkman points at.
;;; ---------------------------------------------------------------------------

(defvar mm/gradle-jdk (or (mm/jdk-path 11) (mm/jdk-path 17))
  "JDK used to run the gradle wrapper.")

(defvar mm/gradlew-history nil)

(defun mm/gradlew (task)
  "Run TASK with the gradle wrapper of the enclosing project."
  (interactive (list (read-string "gradlew: " nil 'mm/gradlew-history "build")))
  (let* ((root (or (locate-dominating-file default-directory "gradlew")
                   (user-error "No gradlew above %s" default-directory)))
         (default-directory root)
         (process-environment (cons (format "JAVA_HOME=%s" mm/gradle-jdk)
                                    process-environment)))
    (compile (concat "./gradlew " task))))

(setq compilation-scroll-output t)

(global-set-key (kbd "C-c g") 'mm/gradlew)

;;; ---------------------------------------------------------------------------
;;; JavaScript / TypeScript
;;;
;;; TypeScript 7 dropped tsserver.js and speaks LSP from the tsc binary
;;; itself, so the right server depends on the version a project pins: its
;;; own tsc when that is v7 or newer, the adapter in ~/.local otherwise.
;;; ---------------------------------------------------------------------------

(dolist (entry '(("\\.[cm]js\\'" . js-ts-mode)
                 ("\\.jsx\\'" . js-ts-mode)))
  (add-to-list 'auto-mode-alist entry))

(dolist (remap '((javascript-mode . js-ts-mode)
                 (js-json-mode . json-ts-mode)))
  (add-to-list 'major-mode-remap-alist remap))

(defun mm/node-bin (name)
  "Path to NAME in the nearest node_modules/.bin above `default-directory'."
  (let ((bin (concat "node_modules/.bin/" name)))
    (when-let* ((dir (locate-dominating-file
                      default-directory
                      (lambda (dir) (file-executable-p (expand-file-name bin dir))))))
      (expand-file-name bin dir))))

(defun mm/tsc-major-version (tsc)
  "Major version of the TypeScript installed at TSC, or nil."
  (with-temp-buffer
    (when (eq 0 (call-process tsc nil t nil "--version"))
      (goto-char (point-min))
      (when (re-search-forward "\\([0-9]+\\)\\." nil t)
        (string-to-number (match-string 1))))))

(defun mm/typescript-server (&rest _)
  "Command for the server matching the TypeScript this project pins."
  (let* ((tsc (mm/node-bin "tsc"))
         (major (and tsc (mm/tsc-major-version tsc))))
    (if (and major (>= major 7))
        (list tsc "--lsp" "--stdio")
      (list (expand-file-name "~/.local/bin/typescript-language-server") "--stdio"))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((js-mode js-ts-mode typescript-ts-mode tsx-ts-mode)
                 . mm/typescript-server)))

(dolist (hook '(js-ts-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook))
  (add-hook hook #'eglot-ensure)
  (add-hook hook #'company-mode))

;;; ---------------------------------------------------------------------------
;;; Git
;;; ---------------------------------------------------------------------------

(mm/require 'magit)

(global-set-key (kbd "C-c m s") 'magit-status)
(global-set-key (kbd "C-c m l") 'magit-log)

(load custom-file t)

