;;; yuleshow-nov.el --- EPUB reading & vertical CJK display -*- lexical-binding: t; -*-

;; This package provides two main features:
;;   1. EPUB reading via nov.el with CJK-friendly settings
;;   2. A custom vertical CJK reader that displays text top-to-bottom,
;;      right-to-left—mimicking traditional Chinese/Japanese book layout
;;
;; Usage:
;;   - Open any .epub file to enter nov-mode (auto-launches vertical reader)
;;   - Or call M-x vertical-read in any text buffer
;;   - M-x vertical-read-traditional to convert Simplified → Traditional first

;; ============================================================
;; §1  Package Installation & EPUB Mode Setup
;;     Install nov.el if missing, register .epub files, and
;;     configure CJK-friendly display settings.
;; ============================================================
(unless (package-installed-p 'nov)
  (package-install 'nov))
;; Automatically open .epub files with nov-mode
(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

;; Setting nov-text-width to t disables fixed-width filling,
;; which otherwise breaks CJK character wrapping at wrong positions.
(setq nov-text-width t)
;; Use visual-line-mode for soft wrapping instead of hard line breaks
(add-hook 'nov-mode-hook #'visual-line-mode)

;; Force UTF-8 coding so CJK characters are decoded correctly
(add-hook 'nov-mode-hook
          (lambda ()
            (set-buffer-file-coding-system 'utf-8)))

;; ============================================================
;; §2  Vertical Reading Bookmarks
;;     Persist the reader's current page per-file so that
;;     re-opening a book resumes from where you left off.
;;     Bookmarks are stored as an alist in a plain-text file.
;; ============================================================
(defvar yuleshow-vt-places-file
  (expand-file-name "~/yuleshow-emacs-backup/vt-places")
  "File to store vertical reading positions.")

(defvar yuleshow-vt-places nil
  "Alist of (source-buffer-name . page) for vertical reading.")

(defun yuleshow-vt-places-load ()
  "Load vertical reading places from file."
  (when (file-exists-p yuleshow-vt-places-file)
    (with-temp-buffer
      (insert-file-contents yuleshow-vt-places-file)
      (setq yuleshow-vt-places (read (current-buffer))))))

(defun yuleshow-vt-places-save ()
  "Save vertical reading places to file."
  (let ((dir (file-name-directory yuleshow-vt-places-file)))
    (unless (file-directory-p dir)
      (make-directory dir t)))
  (with-temp-file yuleshow-vt-places-file
    (prin1 yuleshow-vt-places (current-buffer))))

(defun yuleshow-vt-bookmark-save ()
  "Save current page for the source file."
  (when yuleshow-vt-source-file
    (setf (alist-get yuleshow-vt-source-file yuleshow-vt-places nil nil #'equal)
          yuleshow-vt-page)
    (yuleshow-vt-places-save)))

(defun yuleshow-vt-bookmark-restore (src-file)
  "Return saved page number for SRC-FILE, or 0.
Tries full path first, then falls back to bare filename."
  (yuleshow-vt-places-load)
  (let ((page (or (alist-get src-file yuleshow-vt-places nil nil #'equal)
                  (alist-get (file-name-nondirectory src-file)
                             yuleshow-vt-places nil nil #'equal)
                  0)))
    (when (> page 0)
      (message "Restored bookmark: page %d" (1+ page)))
    page))

;; Load saved bookmarks at init time so they are available immediately
(yuleshow-vt-places-load)

;; ============================================================
;; §3  Buffer-Local State Variables & Keymap
;;     These variables hold per-buffer state for the vertical
;;     reader: the character array, pagination info, chapter
;;     index, and display parameters.
;; ============================================================
(defvar-local yuleshow-vt-chars nil "Character vector for vertical display.")
(defvar-local yuleshow-vt-page 0 "Current page index (0-based).")
(defvar-local yuleshow-vt-col-height 0 "Number of characters per column (rows).")
(defvar-local yuleshow-vt-num-cols 0 "Number of columns per page.")
(defvar-local yuleshow-vt-chapters nil "List of (title . char-index) for chapter navigation.")
(defvar-local yuleshow-vt-source-buf nil "Name of the source buffer we are reading from.")
(defvar-local yuleshow-vt-source-file nil "Source file path, used as bookmark key.")
(defvar-local yuleshow-vt-font-height 380 "Font height (in 1/10 pt) for vertical mode face.")

;; Keymap for vertical reading mode:
;;   n / SPC      — next page
;;   p / DEL      — previous page
;;   ] / [        — next / previous chapter
;;   t            — table of contents (jump to chapter)
;;   g            — go to page by number
;;   = / -        — increase / decrease column height (rows)
;;   C-= / C--    — increase / decrease number of columns
;;   h            — set exact number of columns
;;   o            — switch back to horizontal (nov-mode) view
;;   q            — save bookmark and quit
(defvar yuleshow-vertical-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "n")   #'yuleshow-vt-next-page)
    (define-key map (kbd "SPC") #'yuleshow-vt-next-page)
    (define-key map (kbd "p")   #'yuleshow-vt-prev-page)
    (define-key map (kbd "DEL") #'yuleshow-vt-prev-page)
    (define-key map (kbd "q")   #'yuleshow-vt-quit)
    (define-key map (kbd "=")   #'yuleshow-vt-increase-height)
    (define-key map (kbd "-")   #'yuleshow-vt-decrease-height)
    (define-key map (kbd "C-=") #'yuleshow-vt-increase-cols)
    (define-key map (kbd "C--") #'yuleshow-vt-decrease-cols)
    (define-key map (kbd "]")   #'yuleshow-vt-next-chapter)
    (define-key map (kbd "[")   #'yuleshow-vt-prev-chapter)
    (define-key map (kbd "t")   #'yuleshow-vt-toc)
    (define-key map (kbd "g")   #'yuleshow-vt-goto-page)
    (define-key map (kbd "h")   #'yuleshow-vt-set-columns)
    (define-key map (kbd "o")   #'yuleshow-vt-horizontal)
    map))

;; ============================================================
;; §4  Vertical Mode Definition (Major Mode)
;;     Derives from special-mode (read-only).  Sets up a dark
;;     background with the TW-Kai font for an authentic
;;     traditional Chinese reading experience.
;; ============================================================
(define-derived-mode yuleshow-vertical-mode special-mode "Vertical"
  "Mode for reading CJK text in vertical columns (right-to-left)."
  ;; Prevent Emacs from wrapping long lines—each row is one screen line
  (setq truncate-lines t)
  (setq-local word-wrap nil)
  (visual-line-mode -1)
  (display-line-numbers-mode -1)
  (setq-local cursor-type nil)
  ;; Vertical reading appearance: dark grey bg, light grey fg, TW-Kai
  (face-remap-add-relative 'default
    :family "TW-Kai" :height 380
    :background "#333333" :foreground "#cccccc")
  (setq-local yuleshow-vt-font-height 380)
  (set-face-background 'fringe "#333333" (selected-frame))
  ;; Disable whitespace/trailing-space highlighting
  (setq-local show-trailing-whitespace nil)
  (setq-local nobreak-char-display nil)
  (when (bound-and-true-p whitespace-mode) (whitespace-mode -1))
  ;; Override global-visual-line-mode after it re-enables
  (add-hook 'after-change-major-mode-hook
            (lambda () (when (eq major-mode 'yuleshow-vertical-mode)
                         (setq truncate-lines t)
                         (visual-line-mode -1)))
            nil t))

;; ============================================================
;; §5  Pagination & Chapter Helpers
;;     Compute page counts, map character indices to pages,
;;     and determine the current chapter title.
;; ============================================================
(defun yuleshow-vt--total-pages ()
  "Return total number of pages based on chars-per-page."
  (let ((chars-per-page (* yuleshow-vt-col-height yuleshow-vt-num-cols)))
    (max 1 (ceiling (/ (float (length yuleshow-vt-chars)) chars-per-page)))))

(defun yuleshow-vt--page-for-char (char-idx)
  "Return the page number containing CHAR-IDX."
  (let ((chars-per-page (* yuleshow-vt-col-height yuleshow-vt-num-cols)))
    (/ char-idx chars-per-page)))

(defun yuleshow-vt--current-chapter ()
  "Return the title of current chapter based on page position."
  (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols)))
        (result ""))
    (dolist (ch yuleshow-vt-chapters)
      (when (<= (cdr ch) char-pos)
        (setq result (car ch))))
    result))

;; ============================================================
;; §6  Page Rendering
;;     Draws one page of vertical text into the *vertical-read*
;;     buffer.  Each CJK character occupies a 2-wide cell.
;;     Horizontal punctuation is mapped to vertical forms
;;     (e.g. 「→﹁) and ASCII is converted to fullwidth.
;;     Columns are drawn right-to-left; rows top-to-bottom.
;; ============================================================
(defun yuleshow-vt-render ()
  "Render the current page of vertical text."
  (let* ((inhibit-read-only t)
         (cell-width 2)
         (col-spacing 1)
         (total (length yuleshow-vt-chars))
         (chars-per-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))
         (start (* yuleshow-vt-page chars-per-page))
         (total-pages (yuleshow-vt--total-pages))
         (ch-title (yuleshow-vt--current-chapter)))
    (erase-buffer)
    (dotimes (row yuleshow-vt-col-height)
      (dotimes (c yuleshow-vt-num-cols)
        (let* ((col (- yuleshow-vt-num-cols 1 c))
               (idx (+ start (* col yuleshow-vt-col-height) row))
               (ch (if (< idx total) (aref yuleshow-vt-chars idx) ?\s))
               ;; Horizontal → vertical punctuation
               (ch (pcase ch
                     (?「 ?﹁) (?」 ?﹂)
                     (?『 ?﹃) (?』 ?﹄)
                     (?\u201C ?﹁) (?\u201D ?﹂)  ; " "
                     (?\u2018 ?﹃) (?\u2019 ?﹄)  ; ' '
                     (?（ ?︵) (?） ?︶)
                     (?【 ?︻) (?】 ?︼)
                     (?《 ?︽) (?》 ?︾)
                     (?〈 ?︿) (?〉 ?﹀)
                     (?〔 ?︹) (?〕 ?︺)
                     (?｛ ?︷) (?｝ ?︸)
                     (?— ?︱) (?─ ?︱)
                     (?… ?⋮)
                     (_ ch)))
               ;; Convert halfwidth ASCII (! to ~) to fullwidth equivalents
               (ch (if (and (>= ch ?!) (<= ch ?~))
                       (+ ch (- ?！ ?!))
                     ch))
               (s (if (= ch ?\s) "  " (char-to-string ch)))
               (w (string-width s))
               (pad (if (= ch ?⋮) 0 (max 0 (- cell-width w)))))
          (insert s)
          (when (> pad 0)
            (insert (make-string pad ?\s)))
          (unless (= c (1- yuleshow-vt-num-cols))
            (insert (make-string col-spacing ?\s)))))
      (insert "\n"))
    (insert (format "\n— %s — 第 %d/%d 頁 —"
                    (if (string-empty-p ch-title) ""
                      (truncate-string-to-width ch-title 40 nil nil "…"))
                    (1+ yuleshow-vt-page) total-pages))
    (goto-char (point-min))
    (setq truncate-lines t)
    (setq word-wrap nil)
    (when (bound-and-true-p visual-line-mode) (visual-line-mode -1))))

;; ============================================================
;; §7  Navigation Commands
;;     Page forward/backward, chapter forward/backward,
;;     table-of-contents jump, and go-to-page-number.
;; ============================================================
(defun yuleshow-vt-quit ()
  "Save reading position and quit."
  (interactive)
  (yuleshow-vt-bookmark-save)
  (quit-window))

(defun yuleshow-vt-next-page ()
  "Go to next page."
  (interactive)
  (when (< yuleshow-vt-page (1- (yuleshow-vt--total-pages)))
    (cl-incf yuleshow-vt-page)
    (yuleshow-vt-bookmark-save)
    (yuleshow-vt-render)))

(defun yuleshow-vt-prev-page ()
  "Go to previous page."
  (interactive)
  (when (> yuleshow-vt-page 0)
    (cl-decf yuleshow-vt-page)
    (yuleshow-vt-bookmark-save)
    (yuleshow-vt-render)))

(defun yuleshow-vt-next-chapter ()
  "Jump to the next chapter."
  (interactive)
  (let* ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols)))
         (next (cl-find-if (lambda (ch) (> (cdr ch) char-pos)) yuleshow-vt-chapters)))
    (if next
        (progn
          (setq yuleshow-vt-page (yuleshow-vt--page-for-char (cdr next)))
          (yuleshow-vt-render))
      (message "No next chapter"))))

(defun yuleshow-vt-prev-chapter ()
  "Jump to the previous chapter."
  (interactive)
  (let* ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols)))
         (prev nil))
    (dolist (ch yuleshow-vt-chapters)
      (when (< (cdr ch) char-pos)
        (setq prev ch)))
    (if prev
        (progn
          (setq yuleshow-vt-page (yuleshow-vt--page-for-char (cdr prev)))
          (yuleshow-vt-render))
      (message "No previous chapter"))))

(defun yuleshow-vt-toc ()
  "Show table of contents and jump to selected chapter."
  (interactive)
  (if (null yuleshow-vt-chapters)
      (message "No chapters detected")
    (let* ((choices (mapcar #'car yuleshow-vt-chapters))
           (sel (completing-read "Jump to chapter: " choices nil t))
           (entry (assoc sel yuleshow-vt-chapters)))
      (when entry
        (setq yuleshow-vt-page (yuleshow-vt--page-for-char (cdr entry)))
        (yuleshow-vt-render)))))

(defun yuleshow-vt-goto-page ()
  "Jump to a specific page number."
  (interactive)
  (let* ((total (yuleshow-vt--total-pages))
         (pg (read-number (format "Go to page (1-%d): " total) (1+ yuleshow-vt-page))))
    (setq yuleshow-vt-page (max 0 (min (1- total) (1- pg))))
    (yuleshow-vt-render)))

;; ============================================================
;; §8  Layout Adjustment Commands
;;     Resize the grid on-the-fly.  Column height controls
;;     how many characters each vertical column holds;
;;     num-cols controls how many columns fit on one page.
;;     All adjustments preserve the current reading position
;;     by recalculating the page from the character offset.
;; ============================================================
(defun yuleshow-vt-increase-height ()
  "Increase column height by 1."
  (interactive)
  (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))))
    (cl-incf yuleshow-vt-col-height)
    (setq yuleshow-vt-page (yuleshow-vt--page-for-char char-pos))
    (yuleshow-vt-render)))

(defun yuleshow-vt-decrease-height ()
  "Decrease column height by 1 (minimum 5)."
  (interactive)
  (when (> yuleshow-vt-col-height 5)
    (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))))
      (cl-decf yuleshow-vt-col-height)
      (setq yuleshow-vt-page (yuleshow-vt--page-for-char char-pos))
      (yuleshow-vt-render))))

(defun yuleshow-vt-set-columns (cols)
  "Set number of vertical columns to COLS."
  (interactive "nNumber of columns: ")
  (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))))
    (setq yuleshow-vt-num-cols (max 1 cols))
    (setq yuleshow-vt-page (yuleshow-vt--page-for-char char-pos))
    (yuleshow-vt-render)))

(defun yuleshow-vt-increase-cols ()
  "Increase number of columns by 1."
  (interactive)
  (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))))
    (cl-incf yuleshow-vt-num-cols)
    (setq yuleshow-vt-page (yuleshow-vt--page-for-char char-pos))
    (yuleshow-vt-render)))

(defun yuleshow-vt-decrease-cols ()
  "Decrease number of columns by 1 (minimum 1)."
  (interactive)
  (when (> yuleshow-vt-num-cols 1)
    (let ((char-pos (* yuleshow-vt-page (* yuleshow-vt-col-height yuleshow-vt-num-cols))))
      (cl-decf yuleshow-vt-num-cols)
      (setq yuleshow-vt-page (yuleshow-vt--page-for-char char-pos))
      (yuleshow-vt-render))))

;; ============================================================
;; §9  Chapter Detection
;;     Scan text for common CJK chapter headings such as
;;     第一回, 第二章, 第三節, etc.  Returns an alist of
;;     (title . char-position) used for chapter navigation.
;; ============================================================
(defun yuleshow-vt--detect-chapters (text)
  "Detect chapter positions in TEXT. Return list of (title . char-position)."
  (let ((chapters nil)
        (pos 0))
    ;; Common CJK chapter patterns
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (while (re-search-forward
              "\\(第[一二三四五六七八九十百零○０-９0-9]+[回章節卷集篇]\\)[　 ]*\\([^。！？\n]*\\)"
              nil t)
        (let* ((marker (match-string 1))
               (rest (string-trim (match-string 2)))
               (title (string-trim (concat marker " " rest)))
               ;; Count chars from start to this match
               (mpos (- (match-beginning 0) 1)))
          (push (cons title mpos) chapters))))
    (nreverse chapters)))

;; ============================================================
;; §10 Text Extraction from nov-mode
;;     Iterate over every document in the EPUB (skipping images),
;;     render each via shr, and concatenate the plain text.
;;     Restores the original document index after extraction.
;; ============================================================
(defun yuleshow-vt--nov-all-text ()
  "Extract rendered text from ALL documents in the current nov-mode buffer."
  (let ((doc-count (length nov-documents))
        (saved-index nov-documents-index)
        (parts nil))
    (dotimes (i doc-count)
      (let ((path (cdr (aref nov-documents i))))
        ;; Skip image documents
        (unless (seq-find (lambda (item) (string-match-p (car item) path))
                          image-type-file-name-regexps)
          (let ((default-directory (file-name-directory path))
                (html (if (and (version< nov-epub-version "3.0")
                               (eq (car (aref nov-documents i)) nov-toc-id))
                          (nov-ncx-to-html path)
                        (nov-slurp path))))
            (with-temp-buffer
              (insert html)
              (let ((shr-use-fonts nil)
                    (shr-width nil))
                (cl-letf (((symbol-function 'shr-fill-line) #'ignore))
                  (shr-render-region (point-min) (point-max))))
              (push (buffer-substring-no-properties (point-min) (point-max))
                    parts))))))
    ;; Restore original document
    (setq nov-documents-index saved-index)
    (nov-render-document)
    (mapconcat #'identity (nreverse parts) "\n\n")))

;; ============================================================
;; §11 Entry Points
;;     Interactive commands to launch the vertical reader.
;;     `vertical-read'             — read buffer as-is
;;     `vertical-read-traditional' — convert Simplified → Traditional first
;;     `vertical-read--internal'   — shared core that builds the char
;;       array, detects chapters, and opens the display buffer.
;; ============================================================
(defun vertical-read-traditional ()
  "Like `vertical-read' but convert Simplified Chinese to Traditional first."
  (interactive)
  (let* ((src-buf (buffer-name))
         (src-file (yuleshow-vt--source-file))
         (text (if (derived-mode-p 'nov-mode)
                   (yuleshow-vt--nov-all-text)
                 (buffer-substring-no-properties (point-min) (point-max))))
         (text (yuleshow--opencc-convert text "s2t")))
    (vertical-read--internal src-buf src-file text)))

(defun yuleshow-vt--source-file ()
  "Return a stable file path for bookmarking the current buffer."
  (cond ((and (derived-mode-p 'nov-mode) (boundp 'nov-file-name) nov-file-name)
         nov-file-name)
        ((buffer-file-name))
        (t (buffer-name))))

(defun vertical-read ()
  "Read current buffer text in vertical CJK layout.
Text flows top-to-bottom, columns go right-to-left.
Detects chapters (第X回/章/節) for navigation with bracket and t keys.
In nov-mode, extracts text from ALL documents (not just current one)."
  (interactive)
  (let* ((src-buf (buffer-name))
         (src-file (yuleshow-vt--source-file))
         (text (if (derived-mode-p 'nov-mode)
                   (yuleshow-vt--nov-all-text)
                 (buffer-substring-no-properties (point-min) (point-max)))))
    (vertical-read--internal src-buf src-file text)))

(defun vertical-read--internal (src-buf src-file text)
  "Render TEXT from SRC-BUF (file SRC-FILE) in vertical CJK layout."
  (let* ((clean (string-trim text))
         (clean (replace-regexp-in-string "\r" "" clean))
         ;; Detect chapters (use clean text that still has newlines)
         (raw-chapters (yuleshow-vt--detect-chapters clean))
         ;; Split into paragraphs on any newline(s)
         (paragraphs (split-string clean "\n+" t "[ \t]*"))
         (col-height 25)
         ;; Build char list: pad each paragraph to fill its last column
         (chars (let (result (pos 0))
                  (dolist (para paragraphs)
                    (let ((p (string-trim para)))
                      (dotimes (i (length p))
                        (push (aref p i) result)
                        (cl-incf pos))
                      ;; Pad remaining slots in current column with blanks
                      (let ((remainder (mod pos col-height)))
                        (when (> remainder 0)
                          (let ((pad (- col-height remainder)))
                            (dotimes (_ pad)
                              (push ?\s result)
                              (cl-incf pos)))))))
                  (vconcat (nreverse result))))
         ;; Remap chapter positions to padded char array positions
         (chapters (let (mapped (para-offset 0) (padded-offset 0)
                         (flat-pos 0))
                     ;; Simple approach: search for chapter titles in the char array
                     (dolist (ch raw-chapters)
                       (let* ((title (car ch))
                              (first-chars (substring title 0 (min 4 (length title))))
                              (found nil))
                         (dotimes (i (- (length chars) 4))
                           (unless found
                             (when (and (= (aref chars i) (aref first-chars 0))
                                        (= (aref chars (+ i 1)) (aref first-chars 1))
                                        (= (aref chars (+ i 2)) (aref first-chars 2)))
                               (setq found i)
                               (push (cons title i) mapped))))))
                     (nreverse mapped)))
         (num-cols 17)
         (buf (get-buffer-create "*vertical-read*")))
    (switch-to-buffer buf)
    (yuleshow-vertical-mode)
    (setq yuleshow-vt-chars chars
          yuleshow-vt-page (yuleshow-vt-bookmark-restore src-file)
          yuleshow-vt-col-height col-height
          yuleshow-vt-num-cols num-cols
          yuleshow-vt-chapters chapters
          yuleshow-vt-source-buf src-buf
          yuleshow-vt-source-file src-file)
    (when chapters
      (message "Detected %d chapters. Use ] [ to navigate, t for TOC" (length chapters)))
    (yuleshow-vt-render)))

;; ============================================================
;; §12 Auto-open & Horizontal Switch
;;     Automatically launch vertical-read when an EPUB is opened
;;     in nov-mode (after a short idle delay to let nov finish
;;     rendering).  `yuleshow-vt-horizontal' switches back to
;;     the original horizontal nov-mode buffer.
;; ============================================================

;; Auto-open vertical mode for EPUB files after nov-mode finishes loading
(add-hook 'nov-mode-hook
          (lambda ()
            (let ((buf (current-buffer)))
              (run-with-idle-timer
               0.5 nil
               (lambda ()
                 (when (buffer-live-p buf)
                   (with-current-buffer buf
                     (vertical-read))))))))

;; Switch back to horizontal (nov-mode) reading
(defun yuleshow-vt-horizontal ()
  "Quit vertical reading and switch back to horizontal nov-mode buffer."
  (interactive)
  (yuleshow-vt-bookmark-save)
  (let ((src yuleshow-vt-source-buf))
    (quit-window)
    (when (get-buffer src)
      (switch-to-buffer src))))

(provide 'yuleshow-nov)
;;; yuleshow-nov.el ends here
