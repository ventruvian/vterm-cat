;;; vterm-cat.el --- Integrate emacs' meow keybinding system into vterm -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Vince Vice
;;
;; Author: Vince Vice <vincent.troetschel@mailbox.org>
;; Maintainer: Vince Vice <vincent.troetschel@mailbox.org>
;; Created: November 30, 2025
;; Modified: November 30, 2025
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex text tools unix vc wp
;; Homepage: https://github.com/ventriuvian/vterm-cat
;; Package-Requires: ((emacs "29.1"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Integrate emacs' meow keybinding system into vterm.
;;  Ideally meow's commands were generic functions then contextualizing them would be trivial.
;;
;;; Code:
(require 'vterm)
(require 'meow)

(defvar vterm-cat-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "RET" #'vterm-send-return)
    ;; (keymap-set map "<remap> <meow-undo>" #'vterm-undo)
    ;; (keymap-set map "<remap> <meow-kill>" #'vterm-cat-kill-line)
    map)
  "Keymap used to override Meow's normal state in `vterm-mode'.")

(defun vterm-cat--keymap-follow-normal ()
  "Elevate precendence of `vterm-cat-mode-map' in `meow-normal-mode'."
  (if meow-normal-mode
      (vterm-cat--keymap-elevate)
    (vterm-cat--keymap-demote)))

(defun vterm-cat--keymap-elevate ()
  "Elevate precendence of `vterm-cat-mode-map'."
  (cl-callf2 push `(vterm-cat-mode . ,vterm-cat-mode-map)
             emulation-mode-map-alists))

(defun vterm-cat--keymap-demote ()
  "Lessen precedence of `vterm-cat-mode-map'."
  (cl-callf2 assq-delete-all 'vterm-cat-mode emulation-mode-map-alists))

(defun vterm-cat--sync-point-h ()
  "Sync point with vterm."
  (when (derived-mode-p 'vterm-mode)
    (vterm-goto-char (point))))

(defun vterm-cat--setup ()
  "Setup `vterm-cat-mode'."
  ;; Make navigation work
  (add-hook 'meow-insert-enter-hook
            #'vterm-cat--sync-point-h
            nil 'local)
  ;; This will break expansion hints
  ;; (add-hook 'pre-command-hook
  ;;           #'vterm-cat--sync-point-h
  ;;           nil 'local)
  ;; Setup keymap for meow overrides
  (add-hook 'meow-normal-mode-hook
            #'vterm-cat--keymap-follow-normal nil 'local)
  ;; Enable keymap if already in normal state
  (when meow-normal-mode (vterm-cat--keymap-elevate)))

(defun vterm-cat--teardown ()
  "Teardown `vterm-cat-mode'."
  (remove-hook 'meow-insert-enter-hook
               #'vterm-cat--sync-point-h
               'local)
  ;; (remove-hook 'pre-command-hook
  ;;              #'vterm-cat--sync-point-h
  ;;              'local)
  (remove-hook 'meow-normal-mode-hook
               #'vterm-cat--keymap-follow-normal
               'local)
  (vterm-cat--keymap-demote))

(define-minor-mode vterm-cat-mode
  "Integrate `meow-normal-mode' with vterm buffers."
  :keymap vterm-cat-mode-map
  :lighter " vcat"
  (progn
    (unless (derived-mode-p 'vterm-mode)
      (user-error "You cannot enable vterm-cat-mode outside of vterm buffers"))
    (if vterm-cat-mode
        (vterm-cat--setup)
      (vterm-cat--teardown))))

;;; Commands

;; Pass through:
;; Keys not explicitly bound in `vterm-cat-mode-map' would normally be looked up in
;; `vterm-mode-map' already, but point as vterm sees it would not be updated to re-
;; flect any movements done in meow's normal state. Instead of binding functions to
;; all relevant keys we only bind a fallback that syncs the point before passing the
;; key event to the keymaps further down in the keymap stack.
;; (defun vterm-cat-sync-point-cascade-event ()
;;   (interactive)
;;   (vterm-goto-char (point))
;;   (let* (vterm-cat-mode                 ;; bypass emulation map
;;          (cmd (keymap-lookup (current-active-maps)
;;                              (key-description (this-command-keys)))))
;;     (when (commandp cmd) (call-interactively cmd))))

;; (define-key vterm-cat-mode-map
;;             [t] #'vterm-cat-sync-point-cascade-event)

(defun vterm-cat-kill-line ()
  "Kill the line in vterm."
  (interactive)
  (vterm-goto-char (point))
  (vterm-send-key "k" nil nil 'ctrl))

(defvar vterm-cat--commands-alist
  '((meow-undo . vterm-undo)
    (meow-kill . vterm-cat-kill-line))
  "Mapping of meow-commands to their vterm analogue.")

;; remap syntax "<remap> <cmd>" doesn't work for some reason here
(map-keymap
 (lambda (key mcmd)
   (when-let ((vcmd (alist-get mcmd vterm-cat--commands-alist)))
     ;; (message "Set %s[%s] to %s" (single-key-description key) mcmd vcmd)
     (define-key vterm-cat-mode-map (vector key) vcmd)))
 meow-normal-state-keymap)

;;; Cursor

;; (defun vterm-cat--set-cursor-shape (shape)
;;   "Set the vterm cursor shape using escape sequences.
;; SHAPE should be one of: 'block, 'bar, 'underline."
;;   (when (derived-mode-p 'vterm-mode)
;;     (vterm-send-escape)
;;     (vterm-send-string
;;      (pcase shape
;;        ('block "\e[2 q")       ; steady block
;;        ('bar "\e[6 q")         ; steady bar
;;        ('underline "\e[4 q"))))) ; steady underline

;; (defun vterm-cat--update-meow-cursor-h ()
;;   "Update cursor shape in vterm according to meow state."
;;   (when (derived-mode-p 'vterm-mode)
;;     (vterm-cat--set-cursor-shape
;;      (pcase (meow--get-state)
;;        ('insert 'bar)
;;        ('normal 'block)
;;        ('motion 'underline)
;;        (_ 'block)))))

;; (add-hook 'meow-insert-state-entry-hook #'vterm-cat--update-meow-cursor-h)
;; (add-hook 'meow-normal-state-entry-hook #'vterm-cat--update-meow-cursor-h)
;; (add-hook 'meow-motion-state-entry-hook #'vterm-cat--update-meow-cursor-h)

(provide 'vterm-cat)
;;; vterm-cat.el ends here
