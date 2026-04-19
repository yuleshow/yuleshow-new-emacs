;;; init.el --- Yuleshow's Emacs Configuration -*- lexical-binding: t; -*-
;;
;; Setup:
;;   ~/.emacs.d -> symlink to this folder (yuleshow-new-emacs/)
;;   ~/.emacs.d/init.el is loaded automatically by Emacs.
;;   Run setup.sh to create symlinks automatically.

;; ============================================================
;; 1. Package Sources
;; ============================================================
(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

;; ============================================================
;; 2. Backup / Autosave / History -> ~/yuleshow-emacs-backup
;; ============================================================
(defvar yuleshow-backup-dir (expand-file-name "~/yuleshow-emacs-backup"))
(unless (file-directory-p yuleshow-backup-dir)
  (make-directory yuleshow-backup-dir t))

(let ((auto-save-dir (concat yuleshow-backup-dir "/auto-save/")))
  (unless (file-directory-p auto-save-dir)
    (make-directory auto-save-dir t))
  (setq auto-save-file-name-transforms `((".*" ,auto-save-dir t))))

(setq backup-directory-alist         `(("." . ,(concat yuleshow-backup-dir "/backups/")))
      backup-by-copying               t
      delete-old-versions             t
      kept-new-versions               6
      kept-old-versions               2
      version-control                 t)

(setq create-lockfiles nil)

(setq auto-save-list-file-prefix     (concat yuleshow-backup-dir "/auto-save-list/.saves-"))
(setq savehist-file                  (concat yuleshow-backup-dir "/history"))
(setq recentf-save-file              (concat yuleshow-backup-dir "/recentf"))
(setq ido-save-directory-list-file   (concat yuleshow-backup-dir "/ido.last"))

(savehist-mode 1)
(recentf-mode 1)

;; ============================================================
;; 3. OS Detection & Platform-Specific Settings
;; ============================================================
(defvar yuleshow-os
  (cond
   ((eq system-type 'darwin)                          'macos)
   ((eq system-type 'gnu/linux)                       'linux)
   ((memq system-type '(windows-nt cygwin ms-dos))   'windows)
   (t                                                 'unknown))
  "Current operating system: macos, linux, windows, or unknown.")

(pcase yuleshow-os
  ('macos
   (setq mac-command-modifier 'meta
         mac-option-modifier  'super)
   (when (display-graphic-p)
     (add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))))

  ('linux
   (setq x-alt-keysym  'meta
         x-super-keysym 'super))

  ('windows
   (setq w32-get-true-file-attributes nil
         w32-pipe-read-delay          0)))

;; ============================================================
;; 4. UI Layout: no icons, no menu, black bg, green fg, box cursor
;; ============================================================
(when (fboundp 'tool-bar-mode)   (tool-bar-mode   -1))
(when (fboundp 'menu-bar-mode)   (menu-bar-mode   -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(when (fboundp 'tooltip-mode)    (tooltip-mode    -1))
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(add-to-list 'default-frame-alist '(background-color . "black"))
(add-to-list 'default-frame-alist '(foreground-color . "#00ff00"))
(add-to-list 'default-frame-alist '(cursor-color     . "#00ff00"))

(setq-default cursor-type 'box)
(blink-cursor-mode 1)

;; ============================================================
;; 5. Window Splitting
;;    C-x h  -> split side by side   (vertical divider)
;;    C-x v  -> split top and bottom (horizontal divider)
;; ============================================================
(global-set-key (kbd "C-x h") #'split-window-right)
(global-set-key (kbd "C-x v") #'split-window-below)

;; ============================================================
;; 6. Window Navigation: S-M-<arrow> jump between windows
;;    (On macOS: Shift+Cmd+Arrow since mac-command-modifier = meta)
;;    M-<left>/M-<right> left free for org-mode (promote/demote).
;; ============================================================
(require 'windmove)
(windmove-default-keybindings '(shift meta))
(global-set-key (kbd "S-M-<left>")    #'windmove-left)
(global-set-key (kbd "S-M-<right>")   #'windmove-right)
(global-set-key (kbd "S-M-<up>")      #'windmove-up)
(global-set-key (kbd "S-M-<down>")    #'windmove-down)
(global-set-key (kbd "ESC S-<left>")  #'windmove-left)
(global-set-key (kbd "ESC S-<right>") #'windmove-right)
(global-set-key (kbd "ESC S-<up>")    #'windmove-up)
(global-set-key (kbd "ESC S-<down>")  #'windmove-down)

;; ============================================================
;; 7. Buffer Rotation: C-<left> / C-<right> in current window
;;    NOTE (macOS): Disable Mission Control arrow shortcuts first.
;; ============================================================
(defvar yuleshow-buffer-nav-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [C-left]  #'previous-buffer)
    (define-key map [C-right] #'next-buffer)
    map))

(define-minor-mode yuleshow-buffer-nav-mode
  "Minor mode for C-<left>/C-<right> buffer rotation."
  :global t :lighter "")
(yuleshow-buffer-nav-mode 1)

;; ============================================================
;; 8. Shift-Wheel: enlarge / reduce font (per-buffer text-scale)
;; ============================================================
(global-set-key [S-wheel-right]  #'text-scale-decrease)
(global-set-key [S-wheel-left]   #'text-scale-increase)
(global-set-key [S-double-right] #'text-scale-decrease)
(global-set-key [S-double-left]  #'text-scale-increase)
(global-set-key [S-triple-right] #'text-scale-decrease)
(global-set-key [S-triple-left]  #'text-scale-increase)
(global-set-key (kbd "M-]")      #'text-scale-increase)
(global-set-key (kbd "M-[")      #'text-scale-decrease)

;; ============================================================
;; 9. Font Lists (Chinese & English)
;; ============================================================
(defvar yuleshow-chinese-font-list
  '((1 . "MingLiU")
    (2 . "Noto Serif TC")
    (3 . "Noto Sans TC")
    (4 . "TW-Sung")
    (5 . "TW-Kai")
    (6 . "Huiwen-mincho")
    (7 . "SentyWen"))
  "Chinese fonts mapped to keys 1-7.")

(defvar yuleshow-english-font-list
  '((1 . "EB Garamond")
    (2 . "Source Code Pro")
    (3 . "Times New Roman")
    (4 . "Georgia")
    (5 . "Fira Code")
    (6 . "Courier New")
    (0 . "Menlo")
    (9 . "Monaco"))
  "English fonts mapped to keys 0-6.")

;; Per-buffer tracking
(defvar-local yuleshow-current-chinese-font "MingLiU")
(defvar-local yuleshow-current-english-font "EB Garamond")
(defvar yuleshow-current-theme-name "Default")
(defvar-local yuleshow--cn-cookie nil)
(defvar-local yuleshow--en-cookie nil)

;; ---- English Font (per-buffer) ----
(defun yuleshow-set-english-font (font-name)
  "Set the English font for this buffer."
  (interactive
   (list (completing-read "English font: "
                          (mapcar #'cdr yuleshow-english-font-list))))
  (when yuleshow--en-cookie
    (face-remap-remove-relative yuleshow--en-cookie)
    (setq yuleshow--en-cookie nil))
  (setq yuleshow-current-english-font font-name)
  (setq yuleshow--en-cookie
        (face-remap-add-relative 'default :family font-name))
  (message "English font → %s" font-name)
  (force-mode-line-update t))

;; ---- Chinese Font (per-buffer) ----
(defun yuleshow-set-chinese-font (font-name)
  "Set the Chinese font for this buffer."
  (interactive
   (list (completing-read "Chinese font: "
                          (mapcar #'cdr yuleshow-chinese-font-list))))
  (when yuleshow--cn-cookie
    (face-remap-remove-relative yuleshow--cn-cookie)
    (setq yuleshow--cn-cookie nil))
  (setq yuleshow-current-chinese-font font-name)
  ;; Update CJK fontset so Chinese characters use this font
  (dolist (charset '(han cjk-misc bopomofo kana))
    (set-fontset-font t charset (font-spec :family font-name) nil 'prepend))
  (setq yuleshow--cn-cookie
        (face-remap-add-relative 'default :family font-name))
  (message "Chinese font → %s" font-name)
  (force-mode-line-update t))

;; ---- Keybindings for fonts ----
;; Use named commands for proper closure under lexical-binding.
;; C-1 … C-0 for Chinese fonts (Ctrl+digit)
(defun yuleshow--make-cn-cmd (font-name)
  "Return a command that sets Chinese font to FONT-NAME."
  (let ((f font-name))
    (lambda () (interactive) (yuleshow-set-chinese-font f))))

(defun yuleshow--make-en-cmd (font-name)
  "Return a command that sets English font to FONT-NAME."
  (let ((f font-name))
    (lambda () (interactive) (yuleshow-set-english-font f))))

(dolist (entry yuleshow-chinese-font-list)
  (let ((key  (car entry))
        (font (cdr entry)))
    (global-set-key (kbd (format "C-%d" key))
                    (yuleshow--make-cn-cmd font))))

(dolist (entry yuleshow-english-font-list)
  (let ((key  (car entry))
        (font (cdr entry)))
    (global-set-key (kbd (format "M-%d" key))
                    (yuleshow--make-en-cmd font))))

;; ============================================================
;; 10. Theme Configuration: C-t prefix (per-buffer via face-remap)
;; ============================================================
(defvar yuleshow-theme-list
  '((1 . ("tango-dark"    "#2e3436" "#eeeeec"))
    (2 . ("deeper-blue"   "#181a26" "#c8c8c8"))
    (3 . ("misterioso"    "#2d3743" "#e1e1e0"))
    (4 . ("manoj-dark"    "#000000" "#fffff0"))
    (5 . ("tsdh-dark"     "#000000" "#c0c0c0"))
    (6 . ("wheatgrass"    "#000000" "#f5deb3"))
    (7 . ("wombat"        "#242424" "#f6f3e8"))
    (8 . ("dichromacy"    "#ffffff" "#000000"))
    (9 . ("modus-vivendi" "#000000" "#ffffff")))
  "Themes: (key . (name bg fg)).")

(defvar-local yuleshow--theme-cookies nil)

(defun yuleshow--remove-theme-cookies ()
  "Remove per-buffer theme cookies."
  (dolist (c yuleshow--theme-cookies)
    (face-remap-remove-relative c))
  (setq yuleshow--theme-cookies nil))

(defun yuleshow-apply-default-theme ()
  "Restore per-buffer default: black bg, green fg."
  (interactive)
  (yuleshow--remove-theme-cookies)
  (push (face-remap-add-relative 'default
          :background "black" :foreground "#00ff00")
        yuleshow--theme-cookies)
  (setq yuleshow-current-theme-name "Default")
  (message "Theme → Default")
  (force-mode-line-update t))

(defun yuleshow-load-theme (name bg fg)
  "Apply theme colors NAME with BG/FG to this buffer only."
  (yuleshow--remove-theme-cookies)
  (push (face-remap-add-relative 'default :background bg :foreground fg)
        yuleshow--theme-cookies)
  (setq yuleshow-current-theme-name name)
  (message "Theme → %s" name)
  (force-mode-line-update t))

;; C-t prefix keymap
(define-prefix-command 'yuleshow-theme-map)
(global-set-key (kbd "C-t") 'yuleshow-theme-map)
(define-key yuleshow-theme-map (kbd "0") #'yuleshow-apply-default-theme)

(dolist (entry yuleshow-theme-list)
  (let* ((key  (car entry))
         (spec (cdr entry))
         (name (nth 0 spec))
         (bg   (nth 1 spec))
         (fg   (nth 2 spec)))
    (define-key yuleshow-theme-map (kbd (format "%d" key))
      (let ((n name) (b bg) (f fg))
        (lambda () (interactive) (yuleshow-load-theme n b f))))))

;; Auto-apply theme 9 (modus-vivendi) for programming files (.el, .py, etc.)
(defun yuleshow-prog-theme ()
  "Apply theme 9 (modus-vivendi) and Source Code Pro for programming buffers."
  (yuleshow-load-theme "modus-vivendi" "#000000" "#ffffff")
  (face-remap-add-relative 'default :family "Hank Nerd Font Mono"))

(add-hook 'prog-mode-hook #'yuleshow-prog-theme)

;; ============================================================
;; 11. Mode Line: date/time + Chinese font + English font + theme
;; ============================================================
(setq display-time-default-load-average nil)
(setq-default mode-line-format
              '("%e"
                mode-line-front-space
                mode-line-mule-info
                mode-line-client
                mode-line-modified
                mode-line-remote
                " "
                mode-line-buffer-identification
                " "
                mode-line-position
                " "
                mode-line-modes
                " "
                (:eval (format-time-string "%Y-%m-%d %H:%M "))
                (:eval (format "[CN:%s EN:%s T:%s]"
                               yuleshow-current-chinese-font
                               yuleshow-current-english-font
                               yuleshow-current-theme-name))
                (:eval (when (eq major-mode 'yuleshow-vertical-mode)
                         (let ((scaled (round (* (or yuleshow-vt-font-height 160)
                                                (expt text-scale-mode-step
                                                      (or text-scale-mode-amount 0))))))
                           (format " [S:%d C:%d H:%d]"
                                   (/ scaled 10)
                                   yuleshow-vt-num-cols
                                   yuleshow-vt-col-height))))
                mode-line-end-spaces))

;; ============================================================
;; 12. Apply defaults on startup (GUI only)
;; ============================================================
(defun yuleshow-initial-setup (&optional _frame)
  "Apply default fonts and theme for the initial GUI frame."
  (when (display-graphic-p)
    (set-face-attribute 'default nil :family "EB Garamond" :height 180
                        :background "black" :foreground "#00ff00")
    (set-face-attribute 'cursor nil :background "#00ff00")
    ;; Frame-level CJK fallback
    (dolist (charset '(han cjk-misc bopomofo kana))
      (set-fontset-font t charset (font-spec :family "MingLiU") nil 'prepend))
    (yuleshow-apply-default-theme)
    ;; Larger font for minibuffer and *Messages*
    (run-with-idle-timer 1 nil
      (lambda ()
        (dolist (buf (list " *Minibuf-0*" " *Minibuf-1*" "*Messages*"))
          (when (get-buffer buf)
            (with-current-buffer buf
              (text-scale-set 3))))))
    (message "Yuleshow loaded. C-1..7=CN font, M-1..6=EN font, C-t 1..9=theme")
    (find-file "~/yuleshow@gmail.com/Org Notes/yuleshow.org")
    ;; Apply OrgTheme to the startup org buffer
    (yuleshow-org-theme)))

(if (daemonp)
    (add-hook 'after-make-frame-functions #'yuleshow-initial-setup)
  (add-hook 'after-init-hook #'yuleshow-initial-setup))

;; ============================================================
;; 13. Misc quality-of-life
;; ============================================================
(setq inhibit-startup-screen t)
(setq ring-bell-function 'ignore)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(delete-selection-mode 1)
(ido-mode 1)
(ido-everywhere 1)
(setq ido-enable-flex-matching t)
(setq ido-auto-merge-work-directories-length 0)
(setq ido-use-filename-at-point 'guess)
(global-visual-line-mode 1)
;; Keep word-wrap display but use real-line C-a/C-e/C-k
(define-key visual-line-mode-map [remap kill-line]              nil)
(define-key visual-line-mode-map [remap move-beginning-of-line] nil)
(define-key visual-line-mode-map [remap move-end-of-line]       nil)
(define-key visual-line-mode-map [remap beginning-of-line]      nil)
(define-key visual-line-mode-map [remap end-of-line]            nil)

;; ============================================================
;; 14. bing-dict: M-/ to translate word at point
;; ============================================================
(defun yuleshow-bing-dict-at-point ()
  "Translate word at point or region with bing-dict, no prompt."
  (interactive)
  (let ((word (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (thing-at-point 'word t))))
    (if word
        (bing-dict-brief word)
      (call-interactively #'bing-dict-brief))))

(global-set-key (kbd "M-/") #'yuleshow-bing-dict-at-point)
(global-set-key (kbd "M-a") #'mark-whole-buffer)
(global-set-key (kbd "M-c") #'clipboard-kill-ring-save)
(global-set-key (kbd "M-s") #'save-buffer)
(global-set-key (kbd "<f3>") #'shell)
(global-set-key (kbd "<f4>") (lambda () (interactive) (load-file user-init-file) (message "Reloaded %s" user-init-file)))
(global-set-key (kbd "<f8>") #'menu-bar-mode)

;; Insert current filename at point (M-n); with prefix arg, full path
(defun insert-current-file-name-at-point (&optional full-path)
  "Insert the current filename at point.
With prefix argument, use full path."
  (interactive "P")
  (let* ((buffer (if (minibufferp)
                     (window-buffer (minibuffer-selected-window))
                   (current-buffer)))
         (filename (buffer-file-name buffer)))
    (if filename
        (insert (if full-path filename (file-name-nondirectory filename)))
      (error "Buffer %s is not visiting a file" (buffer-name buffer)))))
(global-set-key (kbd "M-n") #'insert-current-file-name-at-point)

;; ============================================================
;; 15. Cangjie 5 Input Method: C-\ to toggle
;; ============================================================
(add-to-list 'load-path (expand-file-name "canji5" user-emacs-directory))
(require 'canji5)
(canji5-load-local-phrases)
(register-input-method
 "chinese-canji5" "Chinese-UTF8" 'quail-use-package
 "Canji5" "Canji5"
 "canji5")
(setq default-input-method "chinese-canji5")
(global-set-key (kbd "C-\\") #'toggle-input-method)

;; ============================================================
;; 16. Simplified ↔ Traditional Chinese Conversion (opencc)
;; ============================================================
(defvar yuleshow-opencc-program (executable-find "opencc")
  "Path to the opencc binary.")

(defun yuleshow--opencc-convert (text config)
  "Convert TEXT using opencc with CONFIG (e.g. \"s2t\" or \"t2s\")."
  (unless yuleshow-opencc-program
    (error "opencc not found; install with: brew install opencc"))
  (with-temp-buffer
    (insert text)
    (let ((exit-code
           (call-process-region (point-min) (point-max)
                                yuleshow-opencc-program
                                t t nil
                                "-c" (concat config ".json"))))
      (unless (zerop exit-code)
        (error "opencc failed (exit %d)" exit-code))
      (buffer-string))))

(defun convert-to-traditional (beg end)
  "Convert region from Simplified Chinese to Traditional Chinese."
  (interactive "r")
  (let ((result (yuleshow--opencc-convert (buffer-substring beg end) "s2t")))
    (delete-region beg end)
    (insert result)
    (message "Simplified → Traditional")))

(defun convert-to-simplified (beg end)
  "Convert region from Traditional Chinese to Simplified Chinese."
  (interactive "r")
  (let ((result (yuleshow--opencc-convert (buffer-substring beg end) "t2s")))
    (delete-region beg end)
    (insert result)
    (message "Traditional → Simplified")))

(defun convert-to-traditional-buffer ()
  "Convert entire buffer from Simplified Chinese to Traditional Chinese."
  (interactive)
  (convert-to-traditional (point-min) (point-max)))

(defun convert-to-simplified-buffer ()
  "Convert entire buffer from Traditional Chinese to Simplified Chinese."
  (interactive)
  (convert-to-simplified (point-min) (point-max)))

;; C-c s -> Traditional to Simplified (region)
;; C-c t -> Simplified to Traditional (region)
(global-set-key (kbd "C-c s") #'convert-to-simplified)
(global-set-key (kbd "C-c t") #'convert-to-traditional)

;; ============================================================
;; 17. Insert Date / Time
;; ============================================================
(defun my-insert-date ()
  "Insert current date as <MM/DD/YY>."
  (interactive)
  (insert (format-time-string "<%m/%d/%y>" (current-time))))

(defun my-insert-time ()
  "Insert current time as [HHMM]."
  (interactive)
  (insert (format-time-string "[%H%M]" (current-time))))

(global-set-key (kbd "C-x d") #'my-insert-date)
(global-set-key (kbd "C-x t") #'my-insert-time)

;; ============================================================
;; 18. EPUB reading & Vertical CJK Reader  (yuleshow-nov.el)
;; ============================================================
(load (concat user-emacs-directory "yuleshow-nov"))

;; ============================================================
;; 19. Org-mode customisation (yuleshow-org.el)
;; ============================================================
(load (concat user-emacs-directory "yuleshow-org"))

;;; dot.emacs ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
