# sqlt.el

Emacs transient interface for selecting and inserting SQL columns at point.

## Overview

`sqlt.el` provides a magit-style menu for building SQL column lists interactively. Invoke it with point where you want the output, pick a table, toggle columns on or off, optionally set a table alias, and press `!` to insert `col1, col2` (or `alias.col1, alias.col2`) directly into your buffer.

## Requirements

- Emacs 28+
- [`transient`](https://github.com/magit/transient)

## Installation

**Manual:**
```elisp
(load-file "/path/to/sqlt.el/sqlt.el")
```

**straight.el:**
```elisp
(straight-use-package
 '(sqlt :type git :host github :repo "vkhashimoto/sqlt.el"))
```

## Configuration

You must define `sqlt--tables` before invoking the menu. It is an alist mapping table names to their column lists:

```elisp
(setq sqlt--tables
      '(("users"  . ("id" "email" "name" "status"))
        ("orders" . ("id" "user_id" "total" "created_at"))))
```

Up to 26 tables are supported (one key per letter of the alphabet).

## Usage

Place point where you want the columns inserted, then call:

```
M-x sqlt-insert-columns
```

Or bind it to a key:

```elisp
(global-set-key (kbd "C-c s") #'sqlt-insert-columns)
```

### Key bindings

| Key   | Action                                  |
|-------|-----------------------------------------|
| `a`–`z` | Select a table (main menu)            |
| `a`–`z` | Toggle a column on/off (column menu)  |
| `@`   | Set (or clear) a table alias            |
| `!`   | Insert selected columns and close       |
| `q`   | Go back to the table list               |

Column order in the output follows the declaration order in `sqlt--tables`, not the order in which you toggled them.

**Without alias:** `id, email, name`

**With alias `u`:** `u.id, u.email, u.name`

## Running Tests

```
emacs -batch -l ert -l sqlt-test.el -f ert-run-tests-batch-and-exit
```
