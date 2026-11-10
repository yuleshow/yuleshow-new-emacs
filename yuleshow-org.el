;;; yuleshow-org.el --- Org-mode customisation -*- lexical-binding: t; -*-

;; ============================================================
;; §1  OrgTheme: Custom Appearance for Org Buffers
;;     C-t 9  applies the theme manually.
;;     Auto-applied via org-mode-hook.
;;       Chinese text -> MingLiU (via yuleshow-set-chinese-font)
;;       Tables       -> Menlo (monospace, for alignment)
;; ============================================================
(defun yuleshow-org-theme ()
  "Apply OrgTheme: MingLiU + Menlo tables."
  (interactive)
  ;; Chinese font (same mechanism as C-1)
  (yuleshow-set-chinese-font "MingLiU")
  ;; Monospace font for org tables
  (face-remap-add-relative 'org-table :family "Menlo")
  (setq yuleshow-current-theme-name "OrgTheme")
  (force-mode-line-update t)
  (message "OrgTheme → CN:MingLiU  Table:Menlo"))

(define-key yuleshow-theme-map (kbd "9") #'yuleshow-org-theme)

;; Auto-apply OrgTheme when entering any org-mode buffer
(add-hook 'org-mode-hook #'yuleshow-org-theme)

;; Align tags 120 columns from the right margin
(setq org-tags-column -120)

;; Ensure tags align automatically when you change a headline
(setq org-auto-align-tags t)

;; Keep list text unindented and highlight numbered-list item lines.
(setq org-list-indent-offset 0
      org-adapt-indentation nil
      org-startup-indented nil)

(defun yuleshow-org--update-wrap-prefixes (beg end &optional _old-length)
  "Indent soft-wrapped continuations like their physical Org lines."
  (save-excursion
    (let ((start (progn (goto-char beg) (line-beginning-position)))
          (finish (progn (goto-char end) (line-beginning-position 2))))
      (with-silent-modifications
        (remove-text-properties start finish '(wrap-prefix nil))
        (goto-char start)
          (while (re-search-forward "^\\([ \t]+\\)\\S-" finish t)
          (put-text-property
           (line-beginning-position) (line-end-position)
            'wrap-prefix (match-string-no-properties 1)))))))

(defun yuleshow-org-indent-wrapped-lines ()
  "Preserve leading whitespace on visually wrapped Org lines."
  (yuleshow-org--update-wrap-prefixes (point-min) (point-max))
  (add-hook 'after-change-functions
            #'yuleshow-org--update-wrap-prefixes nil t))

(add-hook 'org-mode-hook #'yuleshow-org-indent-wrapped-lines)

(defun yuleshow-org--pad-numbered-list-markers (original-function struct prevs)
  "Run ORIGINAL-FUNCTION while preserving each list's marker width."
  (let ((widths (make-hash-table :test #'eql)))
    (dolist (entry struct)
      (let* ((item (car entry))
             (bullet (org-list-get-bullet item struct))
             (width (and (string-match "\\`\\([0-9]+\\)[.)][ \t]*\\'" bullet)
                         (length (match-string 1 bullet)))))
        (when width
          (let ((list-begin (org-list-get-list-begin item struct prevs)))
            (puthash list-begin (max width (gethash list-begin widths 0))
                     widths)))))
    (funcall original-function struct prevs)
    (dolist (entry struct)
      (let* ((item (car entry))
             (bullet (org-list-get-bullet item struct))
             (width (gethash (org-list-get-list-begin item struct prevs)
                             widths)))
        (when (and width
                   (string-match "\\`\\([0-9]+\\)\\([.)]\\)[ \t]*\\'" bullet))
          (let ((number (string-to-number (match-string 1 bullet)))
                (delimiter (match-string 2 bullet)))
            (org-list-set-bullet
             item struct
             (org-list-bullet-string
              (format (format "%%0%dd%%s" width) number delimiter)))))))
    struct))

(with-eval-after-load 'org-list
  (unless (advice-member-p #'yuleshow-org--pad-numbered-list-markers
                           'org-list-struct-fix-bul)
    (advice-add 'org-list-struct-fix-bul :around
                #'yuleshow-org--pad-numbered-list-markers)))

(defface yuleshow-org-numbered-list-marker
  '((t (:foreground "#ffff00" :weight bold)))
  "Face for numbered Org list markers such as `1.'."
  :group 'org-faces)

(defun yuleshow-org-fontify-numbered-list-markers ()
  "Highlight complete numbered list item lines."
  (font-lock-add-keywords
   nil
   '(("^[ \t]*[0-9]+\\.\\(?:[ \t]+.*\\)?$"
      0 'yuleshow-org-numbered-list-marker prepend))))

(add-hook 'org-mode-hook #'yuleshow-org-fontify-numbered-list-markers)

(defun yuleshow-org-return ()
  "Expand a three-digit dated list item, or run the usual Org Return command."
  (interactive)
  (let ((date-entry
         (and (eolp)
              (save-excursion
                (beginning-of-line)
                (when (looking-at
                       "^[ \t]*[0-9]\\{3\\}\\.[ \t]+\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)[ \t]*$")
                  (list (current-indentation)
                        (match-string 1)
                        (match-string 2)
                        (match-string 3)))))))
    (if (null date-entry)
        (call-interactively #'org-return)
      (let ((field-indent (make-string (+ (nth 0 date-entry) 5) ?\s)))
        (insert "\n\n" field-indent
                "時間：" (nth 1 date-entry) "年"
                (number-to-string (string-to-number (nth 2 date-entry))) "月"
                (number-to-string (string-to-number (nth 3 date-entry))) "日\n"
                field-indent "地點：\n")
        (forward-line -2)
        (end-of-line)))))

(defvar-local yuleshow-org--heading-list-cycle-states nil
  "Cycle direction for Org headings whose sections contain plain lists.")

(defun yuleshow-org--heading-list-state-entry (heading)
  "Return the cycle-state entry for HEADING, creating it when needed."
  (let (entry live-entries)
    (dolist (candidate yuleshow-org--heading-list-cycle-states)
      (when (marker-buffer (car candidate))
        (push candidate live-entries)
        (when (= heading (marker-position (car candidate)))
          (setq entry candidate))))
    (setq yuleshow-org--heading-list-cycle-states (nreverse live-entries))
    (or entry
        (let ((new-entry (cons (copy-marker heading) nil)))
          (push new-entry yuleshow-org--heading-list-cycle-states)
          new-entry))))

(defun yuleshow-org--first-list-item-in-section ()
  "Return the first plain-list item in the current heading's section."
  (save-excursion
    (org-back-to-heading t)
    (forward-line 1)
    (let ((section-end
           (save-excursion
             (if (re-search-forward org-heading-regexp nil t)
                 (line-beginning-position)
               (point-max)))))
      (catch 'item
        (while (< (point) section-end)
          (let ((item (org-in-item-p)))
            (when (and item (= item (line-beginning-position)))
              (throw 'item item)))
          (forward-line 1))))))

(defun yuleshow-org--fold-list-level (item)
  "Show ITEM's list but fold wording below every item at its level."
  (let* ((struct (save-excursion
                   (goto-char item)
                   (org-list-struct)))
         (indent (org-list-get-ind item struct)))
    (dolist (entry struct)
      (let ((other-item (car entry)))
        (when (= indent (org-list-get-ind other-item struct))
          (org-list-set-item-visibility other-item struct 'folded))))))

(defun yuleshow-org-cycle (&optional arg)
  "Cycle list headings from full to list-only, closed, list-only, and full."
  (interactive "P")
  (let ((item (and (null arg)
                   (org-at-heading-p)
                   (yuleshow-org--first-list-item-in-section))))
    (if (not item)
        (org-cycle arg)
      (let* ((heading (line-beginning-position))
             (state-entry (yuleshow-org--heading-list-state-entry heading))
             (stored-state (cdr state-entry))
             (visible-state
              (cond
               ((org-fold-folded-p (line-end-position)) 'closed)
               ((save-excursion
                  (goto-char item)
                  (org-fold-folded-p (line-end-position)))
                (if (eq stored-state 'list-expanding)
                    'list-expanding
                  'list-closing))
               (t 'full))))
        (pcase visible-state
          ('full
           (org-fold-show-subtree)
           (yuleshow-org--fold-list-level item)
           (setcdr state-entry 'list-closing))
          ('list-closing
           (org-fold-hide-subtree)
           (setcdr state-entry 'closed))
          ('closed
           (org-fold-show-subtree)
           (yuleshow-org--fold-list-level item)
           (setcdr state-entry 'list-expanding))
          ('list-expanding
           (org-fold-show-subtree)
           (setcdr state-entry 'full)))))))

;; ============================================================
;; §2  Food List & Dietary Capture
;;     Read food options from EatingDiary folder.
;;     org-capture template "f" for dietary logging.
;;     C-c i inserts a food item from the list.
;; ============================================================
(defun yuleshow-read-food-list ()
  "Read the general food list from list-foods.txt."
  (let ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-foods.txt"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (split-string (buffer-string) "\n" t))
      (list "Error: list-foods.txt not found"))))

(setq org-capture-templates
      '(("f" "飲食日誌" entry (file+headline "~/yuleshow@gmail.com/Writing/EatingDiary/yuleshow.org" "Dietary Log")
         "* %t %^{餐點|早飯|中飯|夜飯}\n  - [ ] %^{食物名稱|%(yuleshow-read-food-list)} %?")))

(defun yuleshow-insert-food-item ()
  "Select food from the list and insert at point. Adds a bullet if line is empty."
  (interactive)
  (let* ((completing-read-function #'completing-read-default)
         (food (completing-read "Select Food: " (yuleshow-read-food-list))))
    (when (and food (not (string-empty-p food)))
      (save-excursion
        (beginning-of-line)
        (when (looking-at-p "^[ \t]*$")
          (insert "- ")))
      (insert food))))

(global-set-key (kbd "C-c i") 'yuleshow-insert-food-item)

;; ============================================================
;; §3  Orderless Completion
;;     Fuzzy/multi-word matching for completing-read.
;;     Brackets in patterns are matched literally.
;; ============================================================
(unless (package-installed-p 'orderless)
  (package-install 'orderless))
(setq completion-styles '(orderless basic)
      completion-category-defaults nil
      completion-category-overrides '((file (styles . (partial-completion)))))

;; Enable Vertico for vertical completion UI (works with orderless)
(unless (package-installed-p 'vertico)
  (package-install 'vertico))
(vertico-mode 1)

(defun yuleshow-orderless-literal-dispatcher (pattern _index _total)
  "Force literal matching when pattern contains brackets or special symbols."
  (when (string-match-p "[()[]]" pattern)
    `(orderless-literal . ,pattern)))

(setq orderless-matching-styles '(orderless-regexp orderless-literal orderless-initialism)
      orderless-style-dispatchers '(yuleshow-orderless-literal-dispatcher))

;; ============================================================
;; §4  Food Tag Insertion
;;     C-c f i  inserts the full heritage path.
;;     C-c i    inserts only the dish name (leaf node).
;; ============================================================
(defun my/insert-food-tag-full ()
  "Search and insert the FULL heritage path."
  (interactive)
  (let* ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-foods.txt")
         (options (with-temp-buffer
                    (insert-file-contents file-path)
                    (split-string (buffer-string) "\n" t)))
         (completing-read-function #'completing-read-default)
         (selection (completing-read "Full Heritage Search: " options)))
    (insert selection)))

(defun my/insert-food-tag-only ()
  "Search the full heritage, but insert ONLY the dish name."
  (interactive)
  (let* ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-foods.txt")
         (options (with-temp-buffer
                    (insert-file-contents file-path)
                    (split-string (buffer-string) "\n" t)))
         (completing-read-function #'completing-read-default)
         (selection (completing-read "Dish Only Search: " options))
         (components (split-string selection " > "))
         (leaf-node (car (last components))))
    (insert leaf-node)))

(global-set-key (kbd "C-c f i") 'my/insert-food-tag-full)
(global-set-key (kbd "C-c i")   'my/insert-food-tag-only)

;; ============================================================
;; §5  Restaurant List
;;     Read restaurant directory from EatingDiary folder.
;; ============================================================
(defun yuleshow-read-restaurant-list ()
  "Read the restaurant directory from the Google Drive path."
  (let ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-restaurants.txt"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          ;; Split the file content into a list of strings by line
          (split-string (buffer-string) "\n" t))
      (list "Error: restaurant_list.txt not found"))))

(defun yuleshow-insert-restaurant ()
  "Select a restaurant and insert it as an Org headline with Cuisine and City tags.
Expected format: Name|Address|City|State|ChineseName|Cuisine"
  (interactive)
  (let* ((completing-read-function #'completing-read-default)
         (raw-entry (completing-read "Select Restaurant: " (yuleshow-read-restaurant-list)))
         (parts (split-string raw-entry "|"))
         ;; Clean Name (remove )
         (name (string-trim (replace-regexp-in-string "\\+\\] " "" (or (nth 0 parts) ""))))
         (address (string-trim (or (nth 1 parts) "")))
         (city (string-trim (or (nth 2 parts) "")))
         (state (string-trim (or (nth 3 parts) "")))
         (chinese-name (string-trim (or (nth 4 parts) "")))
         (cuisine (string-trim (or (nth 5 parts) "")))
         ;; Create a safe tag for cities with spaces (e.g., San_Diego)
         (city-tag (replace-regexp-in-string " " "_" city)))
    (when (not (string-empty-p name))
      ;; 1. Insert Level 3 Headline: :RESTAURANT:Cuisine:City:
      (insert (format "*** [Restaurant] *%s*%s :RESTAURANT:%s:%s:\n" 
                      name 
                      (if (string-empty-p chinese-name) "" (format " (%s)" chinese-name))
                      (if (string-empty-p cuisine) "" cuisine)
                      (if (string-empty-p city-tag) "" city-tag)))
      ;; 2. Insert Properties Drawer
      (insert ":PROPERTIES:\n")
      (insert (format ":地址:  %s, %s, %s\n" address city state))
      (insert ":人物:      \n")
      (insert ":菜品:\n")
      (insert "  - \n")
      (insert ":Price:  $\n")
      (insert ":END:\n")
      ;; 3. Position cursor under :菜品:
      (forward-line -3)
      (end-of-line))))

;; Bind the command to C-c r (r for restaurant)
(global-set-key (kbd "C-c r") 'yuleshow-insert-restaurant)

;; ============================================================
;; §5b Shopping List
;;     Read shopping directory from EatingDiary folder.
;;     C-c s inserts a shopping entry with tags.
;; ============================================================
(defun yuleshow-read-shopping-list ()
  "Read the shopping directory from the Google Drive path."
  (let ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-shopping.txt"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (split-string (buffer-string) "\n" t))
      (list "Error: list-shopping.txt not found"))))

(defun yuleshow-insert-shopping ()
  "Select a shop and insert it as an Org headline with City tag.
Expected format: Name|Address|City|State|ChineseName"
  (interactive)
  (let* ((completing-read-function #'completing-read-default)
         (raw-entry (completing-read "Select Shop: " (yuleshow-read-shopping-list)))
         (parts (split-string raw-entry "|"))
         (name (string-trim (or (nth 0 parts) "")))
         (address (string-trim (or (nth 1 parts) "")))
         (city (string-trim (or (nth 2 parts) "")))
         (state (string-trim (or (nth 3 parts) "")))
         (chinese-name (string-trim (or (nth 4 parts) "")))
         (city-tag (replace-regexp-in-string " " "_" city)))
    (when (not (string-empty-p name))
      ;; 1. Insert Level 3 Headline: :SHOPPING:City:
      (insert (format "*** [Shopping] *%s*%s :SHOPPING:%s:\n"
                      name
                      (if (string-empty-p chinese-name) "" (format " (%s)" chinese-name))
                      (if (string-empty-p city-tag) "" city-tag)))
      ;; 2. Insert Properties Drawer
      (insert ":PROPERTIES:\n")
      (insert (format ":地址:  %s, %s, %s\n" address city state))
      (insert ":購物:\n")
      (insert "  - \n")
      (insert ":Price:  $\n")
      (insert ":END:\n")
      ;; 3. Position cursor under :購物:
      (forward-line -3)
      (end-of-line))))

;; Bind the command to C-c s (s for shopping)
(global-set-key (kbd "C-c s") 'yuleshow-insert-shopping)

;; Rebind org-set-property to C-c p and keep standard C-k behavior.
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c p") #'org-set-property)
  (define-key org-mode-map (kbd "TAB") #'yuleshow-org-cycle)
  (define-key org-mode-map (kbd "<tab>") #'yuleshow-org-cycle)
  (define-key org-mode-map (kbd "RET") #'yuleshow-org-return)
  (define-key org-mode-map (kbd "<return>") #'yuleshow-org-return)
  (define-key org-mode-map [remap kill-line] nil))

;; ============================================================
;; §5c Medical List
;;     Read medical facility directory from EatingDiary folder.
;;     C-c m inserts a medical entry with tags.
;; ============================================================
(defun yuleshow-read-medical-list ()
  "Read the medical facility directory from the Google Drive path."
  (let ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-medical.txt"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (split-string (buffer-string) "\n" t))
      (list "Error: list-medical.txt not found"))))

(defun yuleshow-insert-medical ()
  "Select a medical facility and insert it as an Org headline with City tag.
Expected format: Name|Address|City|State|ChineseName"
  (interactive)
  (let* ((completing-read-function #'completing-read-default)
         (raw-entry (completing-read "Select Medical: " (yuleshow-read-medical-list)))
         (parts (split-string raw-entry "|"))
         (name (string-trim (or (nth 0 parts) "")))
         (address (string-trim (or (nth 1 parts) "")))
         (city (string-trim (or (nth 2 parts) "")))
         (state (string-trim (or (nth 3 parts) "")))
         (chinese-name (string-trim (or (nth 4 parts) "")))
         (city-tag (replace-regexp-in-string " " "_" city)))
    (when (not (string-empty-p name))
      ;; 1. Insert Level 3 Headline: :MEDICAL:City:
      (insert (format "*** [Medical] *%s*%s :MEDICAL:%s:\n"
                      name
                      (if (string-empty-p chinese-name) "" (format " (%s)" chinese-name))
                      (if (string-empty-p city-tag) "" city-tag)))
      ;; 2. Insert Properties Drawer
      (insert ":PROPERTIES:\n")
      (insert (format ":地址:  %s, %s, %s\n" address city state))
      (insert ":備註:\n")
      (insert ":END:\n")
      ;; 3. Position cursor at :備註:
      (forward-line -2)
      (end-of-line))))

;; Bind the command to C-c m (m for medical)
(global-set-key (kbd "C-c m") 'yuleshow-insert-medical)

;; ============================================================
;; §5d Library List
;;     Read library directory from EatingDiary folder.
;;     C-c l inserts a library entry with tags.
;; ============================================================
(defun yuleshow-read-library-list ()
  "Read the library directory from the Google Drive path."
  (let ((file-path "~/yuleshow@gmail.com/Writing/EatingDiary/list-library.txt"))
    (if (file-exists-p file-path)
        (with-temp-buffer
          (insert-file-contents file-path)
          (split-string (buffer-string) "\n" t))
      (list "Error: list-library.txt not found"))))

(defun yuleshow-insert-library ()
  "Select a library and insert it as an Org headline with City tag.
Expected format: Name|Address|City|State"
  (interactive)
  (let* ((completing-read-function #'completing-read-default)
         (raw-entry (completing-read "Select Library: " (yuleshow-read-library-list)))
         (parts (split-string raw-entry "|"))
         (name (string-trim (or (nth 0 parts) "")))
         (address (string-trim (or (nth 1 parts) "")))
         (city (string-trim (or (nth 2 parts) "")))
         (state (string-trim (or (nth 3 parts) "")))
         (city-tag (replace-regexp-in-string " " "_" city)))
    (when (not (string-empty-p name))
      ;; 1. Insert Level 3 Headline: :LIBRARY:City:
      (insert (format "*** [Library] *%s* :LIBRARY:%s:\n"
                      name
                      (if (string-empty-p city-tag) "" city-tag)))
      ;; 2. Insert Properties Drawer
      (insert ":PROPERTIES:\n")
      (insert (format ":地址:  %s, %s, %s\n" address city state))
      (insert ":備註:\n")
      (insert ":END:\n")
      ;; 3. Position cursor at :備註:
      (forward-line -2)
      (end-of-line))))

;; Bind the command to C-c l (l for library)
(global-set-key (kbd "C-c l") 'yuleshow-insert-library)

;; ============================================================
;; §6  Save History
;;     Persist minibuffer history across sessions.
;; ============================================================
(savehist-mode 1)

(provide 'yuleshow-org)
;;; yuleshow-org.el ends here
