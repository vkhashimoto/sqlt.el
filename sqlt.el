;;; sqlt.el --- Transient interface for SQL column insertion -*- lexical-binding: t -*-

;; Package-Requires: ((emacs "28.1") (transient "0.4.0"))
;; Keywords: sql, tools, convenience
;; URL: https://github.com/vkhashimoto/sqlt.el

;;; Commentary:
;;
;; A magit-style transient menu for selecting SQL table columns and inserting
;; them at point.  Select a table, toggle columns, optionally set a table
;; alias, then press ! to insert the result into the current buffer.
;;
;; Before using, define `sqlt--tables' as an alist of table-name to column
;; list pairs:
;;
;;   (setq sqlt--tables
;;         \\='((\"users\"  . (\"id\" \"email\" \"name\" \"status\"))
;;           (\"orders\" . (\"id\" \"user_id\" \"total\" \"created_at\"))))
;;
;; Then call \\[sqlt-insert-columns] with point at the desired insertion site.

;;; Code:

(require 'transient)

(defvar sqlt--active-table nil
  "The currently selected table name (string).")

(defvar sqlt--selected-columns nil
  "List of selected column names for the active table.")

(defvar sqlt--alias nil
  "Optional alias string for the active table.")

(defvar sqlt--insert-buffer nil
  "Buffer where columns should be inserted.")

(defvar sqlt--insert-point nil
  "Position in `sqlt--insert-buffer' where columns should be inserted.")

;;; Helpers

(defun sqlt--reset-state ()
  "Clear per-session transient state."
  (setq sqlt--active-table nil
        sqlt--selected-columns nil
        sqlt--alias nil))

(defun sqlt--columns-for (table)
  "Return the list of column names for TABLE."
  (cdr (assoc table sqlt--tables)))

(defun sqlt--toggle-column (col)
  "Toggle COL in `sqlt--selected-columns'."
  (if (member col sqlt--selected-columns)
      (setq sqlt--selected-columns (delete col sqlt--selected-columns))
    (push col sqlt--selected-columns)))

(defun sqlt--column-indicator (col)
  "Return a marker string indicating whether COL is selected."
  (if (member col sqlt--selected-columns) "[x]" "[ ]"))

(defun sqlt--build-column-string ()
  "Build the final comma-separated column string, respecting alias and selection order."
  (let* ((ordered (seq-filter (lambda (col) (member col sqlt--selected-columns))
                              (sqlt--columns-for sqlt--active-table))))
    (if sqlt--alias
        (mapconcat (lambda (c) (format "%s.%s" sqlt--alias c)) ordered ", ")
      (mapconcat #'identity ordered ", "))))

;;; Actions

(defun sqlt--select-table (table)
  "Switch the active TABLE and reset column selection."
  (setq sqlt--active-table table
        sqlt--selected-columns nil
        sqlt--alias nil)
  (sqlt--rebuild-columns-menu)
  (transient-setup 'sqlt-columns-menu))

(defun sqlt--do-set-alias ()
  "Prompt for a table alias and store it."
  (interactive)
  (setq sqlt--alias
        (read-string (format "Alias for %s (empty to clear): " sqlt--active-table)))
  (when (string-empty-p sqlt--alias)
    (setq sqlt--alias nil))
  (when sqlt--active-table (sqlt--rebuild-columns-menu))
  (transient-setup (if sqlt--active-table 'sqlt-columns-menu 'sqlt-main)))

(defun sqlt--do-generate-columns ()
  "Insert the selected columns at the saved point, then close the transient."
  (interactive)
  (if (null sqlt--selected-columns)
      (message "No columns selected.")
    (let ((text (sqlt--build-column-string)))
      (when (and sqlt--insert-buffer (buffer-live-p sqlt--insert-buffer))
        (with-current-buffer sqlt--insert-buffer
          (goto-char sqlt--insert-point)
          (insert (format "%s " text))))
      (message "Inserted: %s" text))))

;;; Transient Menus

(defconst sqlt--alphabet
  (mapcar #'char-to-string (string-to-list "abcdefghijklmnopqrstuvwxyz"))
  "Single-character keys assigned in declaration order.")

(defun sqlt--assign-keys (names)
  "Assign keys to NAMES in declaration order using `sqlt--alphabet'."
  (cl-mapcar #'cons names sqlt--alphabet))

(defun sqlt--rebuild-main ()
  "Redefine `sqlt-main' dynamically from `sqlt--tables'."
  (let* ((names (mapcar #'car sqlt--tables))
         (key-alist (sqlt--assign-keys names))
         (suffixes (mapcar (lambda (pair)
                             (let ((name (car pair))
                                   (key  (cdr pair)))
                               `(,key
                                 ,(lambda ()
                                    (interactive)
                                    (sqlt--select-table name))
                                 :description ,name)))
                           key-alist)))
    (eval
     `(transient-define-prefix sqlt-main ()
        "SQL Column Picker — select a table."
        :transient-suffix  #'transient--do-stay
        :transient-non-suffix #'transient--do-warn
        ["Tables" ,@suffixes])
     t)))

(defun sqlt--rebuild-columns-menu ()
  "Redefine `sqlt-columns-menu' dynamically for the active table."
  (let* ((cols (sqlt--columns-for sqlt--active-table))
         (key-alist (sqlt--assign-keys cols))
         (col-suffixes
          (mapcar (lambda (pair)
                    (let ((col (car pair))
                          (key (cdr pair)))
                      `(,key
                        ,(lambda ()
                           (interactive)
                           (sqlt--toggle-column col)
                           (sqlt--rebuild-columns-menu)
                           (transient-setup 'sqlt-columns-menu))
                        :description
                        ,(lambda ()
                           (format "%s %s" (sqlt--column-indicator col) col)))))
                  key-alist)))
    (eval
     `(transient-define-prefix sqlt-columns-menu ()
        "SQL Column Picker — pick columns, set alias, insert."
        :transient-suffix #'transient--do-stay
        :transient-non-suffix #'transient--do-warn
        [:description
         (lambda ()
           (format "Table: %s%s"
                   (propertize (or sqlt--active-table "none") 'face 'transient-value)
                   (if sqlt--alias
                       (format "  alias: %s"
                               (propertize sqlt--alias 'face 'transient-argument))
                     "")))
         :class transient-column]
        [,(format "%s Columns" (capitalize (or sqlt--active-table "")))
         ,@col-suffixes]
        [""
         ("@" sqlt--do-set-alias
          :description
          (lambda ()
            (if sqlt--alias
                (format "alias  [%s]" sqlt--alias)
              "alias  [none]")))
         ("!" sqlt--do-generate-columns
          :description "generate columns"
          :transient nil)]
        ["Navigation"
         ("q" "back to tables" (lambda ()
                                  (interactive)
                                  (sqlt--rebuild-main)
                                  (transient-setup 'sqlt-main))
          :transient nil)])
     t)))

;;; Entry Point

;;;###autoload
(defun sqlt-insert-columns ()
  "Open the SQL column picker transient at point."
  (interactive)
  (sqlt--reset-state)
  (setq sqlt--insert-buffer (current-buffer)
        sqlt--insert-point  (point))
  (sqlt--rebuild-main)
  (sqlt-main))

(provide 'sqlt)
;;; sqlt.el ends here
