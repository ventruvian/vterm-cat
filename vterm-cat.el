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

;;; Activation Mode

(define-minor-mode vterm-cat-mode
  "Integrate `meow-normal-mode' with vterm buffers."
  :lighter " vcat"
  (progn
    (unless (derived-mode-p 'vterm-mode)
      (user-error "You cannot enable vterm-cat-mode outside of vterm buffers"))
    (if vterm-cat-mode
        (vterm-cat--setup)
      (vterm-cat--teardown))))

;; Copy of meow-insert-exit that drops to VTERM
(defun vterm-cat-insert-exit ()
  "Switch to VTERM state."
  (interactive)
  (cond
   ((meow-keypad-mode-p)
    (meow--exit-keypad-state))
   ((and (meow-insert-mode-p)
         (eq meow--beacon-defining-kbd-macro 'quick))
    (setq meow--beacon-defining-kbd-macro nil)
    (meow-beacon-insert-exit))
   ((meow-insert-mode-p)
    (meow--switch-state 'vterm))))

(defun vterm-cat-meow-insert-exit-a (meow-insert-exit-fn)
  "In `vterm-mode' drop into VTERM state.
Otherwise run MEOW-INSERT-EXIT-FN to drop into NORMAL."
  (if (and (derived-mode-p 'vterm-mode) vterm-cat-mode)
      (vterm-cat-insert-exit)
    (funcall meow-insert-exit-fn)))

(defun vterm-cat--setup ()
  "Setup `vterm-cat-mode'."
  (add-hook 'meow-insert-enter-hook
            #'vterm-cat--sync-point-h
            nil 'local)
  (advice-add 'meow-insert-exit :around
              #'vterm-cat-meow-insert-exit-a)
  ;; Enable expansion hints
  (advice-add 'meow-normal-mode-p :after-until
              #'meow-vterm-mode-p))

(defun vterm-cat--teardown ()
  "Teardown `vterm-cat-mode'."
  (remove-hook 'meow-insert-enter-hook
               #'vterm-cat--sync-point-h
               'local)
  (advice-remove 'meow-insert-exit
                 #'vterm-cat-meow-insert-exit-a)
  (advice-remove 'meow-normal-mode-p
                 #'meow-vterm-mode-p))

(defun vterm-cat--sync-point-h ()
  "Sync point with vterm."
  (when (derived-mode-p 'vterm-mode)
    (vterm-goto-char (point))))

;;; Vterm State

(defvar-keymap meow-vterm-state-keymap
  :doc "Keymap for Meow's Vterm state."
  :parent meow-normal-state-keymap
  "RET" #'vterm-send-return)

(meow-define-state vterm
  "Meow VTERM state minor mode."
  :lighter " [V]"
  :keymap meow-vterm-state-keymap
  :face meow-normal-cursor)

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


(defgroup vterm-cat nil
  "Custom group for vterm-cat."
  :group 'meow)

(defcustom vterm-cat-replace-commands
  '((meow-undo . vterm-undo)
    (meow-kill . vterm-cat-kill-line))
  "Alist mapping commands in NORMAL state to their replacement in VTERM state.
If replacement is nil a command will be generated that syncs point with vterm."
  :type '(alist :key-type symbol
          :value-type (choice symbol (const nil))))

(defun vterm-cat-kill-line ()
  "Kill the line in vterm."
  (interactive)
  (vterm-goto-char (point))
  (vterm-send-key "k" nil nil 'ctrl))

;; Remap commands
(cl-loop for (mcmd . vcmd) in vterm-cat-replace-commands
         do (define-key meow-vterm-state-keymap
                        (vector 'remap mcmd) vcmd))

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
