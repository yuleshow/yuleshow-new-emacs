;;;; script to add Canji5 phrases.  Run this command:
;;;; emacs --batch -l update.el


;; setup the environment 
(setq load-path
      (append (list "./") load-path))

(require 'canji5)
(register-input-method
 "chinese-canji5" "Chinese-GB" 'quail-use-package
 "canji5" "canji5"
 "canji5")

(set-language-environment "chinese-gb")
(setq default-input-method "chinese-canji5")

;; set the file name of local phrases
(setq canji5-phrases-file "./canji5-phrases.txt")
(setq canji5-phrases-file-el "./canji5-phrases.el")

;; add local phrases
(canji5-load-local-phrases)

(activate-input-method "chinese-canji5")

;; update Canji5_rules.el[c]
(canji5-save-rules-default)

