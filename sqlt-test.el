;;; sqlt-test.el --- ERT tests for sqlt -*- lexical-binding: t -*-

(require 'ert)

(load-file (expand-file-name "sqlt.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

;;; sqlt--assign-keys

(ert-deftest sqlt-assign-keys/basic ()
  "Tables get keys a, b, c… in declaration order."
  (should (equal (sqlt--assign-keys '("users" "links" "orders"))
                 '(("users" . "a") ("links" . "b") ("orders" . "c")))))

(ert-deftest sqlt-assign-keys/single ()
  "A single name gets key a."
  (should (equal (sqlt--assign-keys '("users"))
                 '(("users" . "a")))))

(ert-deftest sqlt-assign-keys/same-initial-letter ()
  "Tables starting with the same letter still get distinct sequential keys."
  (should (equal (sqlt--assign-keys '("users" "uploads" "urls"))
                 '(("users" . "a") ("uploads" . "b") ("urls" . "c")))))

(ert-deftest sqlt-assign-keys/26-tables ()
  "26 tables exhaust the alphabet without error."
  (let* ((names (mapcar (lambda (i) (format "table_%d" i)) (number-sequence 1 26)))
         (result (sqlt--assign-keys names)))
    (should (= (length result) 26))
    (should (equal (cdr (nth 25 result)) "z"))))

;;; sqlt--column-indicator

(ert-deftest sqlt-column-indicator/unselected ()
  "Columns not in the selection show [ ]."
  (let ((sqlt--selected-columns '("email")))
    (should (equal (sqlt--column-indicator "id") "[ ]"))))

(ert-deftest sqlt-column-indicator/selected ()
  "Columns in the selection show [x]."
  (let ((sqlt--selected-columns '("id" "email")))
    (should (equal (sqlt--column-indicator "id") "[x]"))))

;;; sqlt--toggle-column

(ert-deftest sqlt-toggle-column/adds ()
  "Toggling an absent column adds it."
  (let ((sqlt--selected-columns '()))
    (sqlt--toggle-column "id")
    (should (member "id" sqlt--selected-columns))))

(ert-deftest sqlt-toggle-column/removes ()
  "Toggling a present column removes it."
  (let ((sqlt--selected-columns '("id" "email")))
    (sqlt--toggle-column "id")
    (should-not (member "id" sqlt--selected-columns))
    (should (member "email" sqlt--selected-columns))))

;;; sqlt--build-column-string

(ert-deftest sqlt-build-column-string/no-alias ()
  "Selected columns are joined without alias."
  (let ((sqlt--tables '(("users" . ("id" "email" "name"))))
        (sqlt--active-table "users")
        (sqlt--selected-columns '("id" "name"))
        (sqlt--alias nil))
    (should (equal (sqlt--build-column-string) "id, name"))))

(ert-deftest sqlt-build-column-string/with-alias ()
  "Selected columns are prefixed with the alias."
  (let ((sqlt--tables '(("users" . ("id" "email" "name"))))
        (sqlt--active-table "users")
        (sqlt--selected-columns '("id" "name"))
        (sqlt--alias "u"))
    (should (equal (sqlt--build-column-string) "u.id, u.name"))))

(ert-deftest sqlt-build-column-string/preserves-declaration-order ()
  "Output follows declaration order, not selection order."
  (let ((sqlt--tables '(("users" . ("id" "email" "name" "status"))))
        (sqlt--active-table "users")
        ;; Selected in reverse order
        (sqlt--selected-columns '("status" "email" "id"))
        (sqlt--alias nil))
    (should (equal (sqlt--build-column-string) "id, email, status"))))

(ert-deftest sqlt-build-column-string/all-columns ()
  "All columns selected produces the full list."
  (let ((sqlt--tables '(("users" . ("id" "email" "name" "status"))))
        (sqlt--active-table "users")
        (sqlt--selected-columns '("id" "email" "name" "status"))
        (sqlt--alias nil))
    (should (equal (sqlt--build-column-string) "id, email, name, status"))))

(ert-deftest sqlt-build-column-string/empty-selection ()
  "No columns selected produces an empty string."
  (let ((sqlt--tables '(("users" . ("id" "email"))))
        (sqlt--active-table "users")
        (sqlt--selected-columns '())
        (sqlt--alias nil))
    (should (equal (sqlt--build-column-string) ""))))

;;; sqlt--columns-for

(ert-deftest sqlt-columns-for/known-table ()
  "Returns the column list for a known table."
  (let ((sqlt--tables '(("users" . ("id" "email"))
                        ("links" . ("id" "url")))))
    (should (equal (sqlt--columns-for "users") '("id" "email")))))

(ert-deftest sqlt-columns-for/unknown-table ()
  "Returns nil for an unknown table."
  (let ((sqlt--tables '(("users" . ("id" "email")))))
    (should (null (sqlt--columns-for "missing")))))

(provide 'sqlt-test)
;;; sqlt-test.el ends here
