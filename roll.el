;;; roll.el --- Rolling window manager -*- lexical-binding: t -*-

;; Author: Szymon Wygnański <sw@7willows.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.3"))
;; Keywords: convenience, windows
;; URL: https://github.com/yourusername/roll.el

;;; Commentary:

;; Roll provides a horizontal scrolling window manager for Emacs that creates
;; a "rolling" view of your buffers, similar to tmux sessions or browser tabs.
;;
;; ## Key Concept
;;
;; Think of Roll as creating a horizontal strip of windows that you can scroll
;; through. Only a limited number of windows (panes) are visible at once, but
;; you can have many more panes that exist "off-screen" to the left and right.
;;
;; ## Features
;;
;; * Horizontal scrolling through multiple buffers
;; * Configurable number of visible windows (default: 3 max)
;; * Smooth navigation with keyboard shortcuts
;; * Move panes left/right to reorganize your workspace
;; * Persistent state - your panes remember their buffer and cursor position
;;
;; ## Quick Start
;;
;; 1. Enable roll-mode: M-x roll-mode
;; 2. Open new panes: M-x roll-open (or C-c C-r o)
;; 3. Navigate: Shift + arrow keys
;; 4. Move panes: Shift + Ctrl + arrow keys
;;
;; ## Default Key Bindings
;;
;; | Key Binding      | Command          | Description                    |
;; |------------------|------------------|--------------------------------|
;; | S-<left>         | roll-go-left     | Move focus to left pane       |
;; | S-<right>        | roll-go-right    | Move focus to right pane      |
;; | S-C-<left>       | roll-move-left   | Move current pane left        |
;; | S-C-<right>      | roll-move-right  | Move current pane right       |
;; | C-c C-r o        | roll-open        | Create new pane               |
;; | C-c C-r r        | roll-reload      | Refresh window layout         |
;;
;; ## Configuration
;;
;; You can customize Roll's behavior with these variables:
;;
;;   (setq roll-max-visible-panes 4)     ; Show up to 4 panes at once
;;   (setq roll-debug-enabled nil)       ; Disable debug messages
;;
;; ## Example Workflow
;;
;; 1. M-x roll-mode                      ; Enable rolling window manager
;; 2. M-x roll-open                      ; Split to create second pane
;; 3. Open a file or switch buffer       ; Work in second pane
;; 4. M-x roll-open                      ; Create third pane
;; 5. S-<left> / S-<right>               ; Navigate between panes
;; 6. S-C-<left>                         ; Move current pane to the left
;;
;; ## Visual Example
;;
;; With roll-max-visible-panes set to 3, you might have:
;;
;; Hidden | Visible Panes        | Hidden
;; -------|---------------------|-------
;; [A][B] | [C] [D*] [E]        | [F][G]
;;             ^^^
;;        Currently focused pane
;;
;; * S-<right> would scroll to show: [D*] [E] [F]
;; * S-<left> would scroll to show: [B] [C] [D*]
;;
;; ## Troubleshooting
;;
;; * If panes seem "stuck", try M-x roll-reload to refresh the layout
;; * Debug messages can be enabled with (setq roll-debug-enabled t)
;; * Roll mode must be enabled before using roll commands
;;
;; ## See Also
;;
;; * `windmove' - Built-in Emacs window navigation
;; * `winner-mode' - Window configuration history
;; * `window-purpose' - Purpose-based window management

;;; Code:

(require 'cl-lib)

(cl-defstruct roll-pane
  "Structure representing a pane in the rolling window manager.
Each pane stores the buffer being displayed and the cursor position."
  buffer   ; The buffer displayed in this pane
  point)   ; The cursor position within the buffer

(defgroup roll nil
  "Rolling window manager settings."
  :group 'convenience
  :prefix "roll-"
  :link '(url-link :tag "Homepage" "https://github.com/yourusername/roll.el"))

(defvar roll-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "S-<left>") 'roll-go-left)
    (define-key map (kbd "S-<right>") 'roll-go-right)
    (define-key map (kbd "S-C-<left>") 'roll-move-left)
    (define-key map (kbd "S-C-<right>") 'roll-move-right)
    (define-key map (kbd "C-c C-r r") 'roll-reload)
    (define-key map (kbd "C-c C-r o") 'roll-open)
    map)
  "Keymap for roll-mode.")

;; Internal state variables
;; These variables maintain the state of the rolling window manager

(defvar roll--windows ()
  "List of actual Emacs windows managed by Roll.
This list contains the visible windows that Roll controls. The length
of this list equals roll--nof-visible-panes.")

(defvar roll--panes ()
  "List of all panes (visible and hidden) managed by Roll.
Each element is a roll-pane struct containing buffer and point information.
This list can be longer than roll--windows, as it includes hidden panes.")

(defvar roll--nof-visible-panes 1
  "Number of currently visible panes.
This starts at 1 and can grow up to roll-max-visible-panes as you
create new panes with roll-open.")

(defvar roll--first-visible-pane 0
  "Index of the leftmost visible pane in roll--panes.
This determines which slice of roll--panes is currently displayed.
As you scroll left/right, this value changes to show different panes.")

;; Customizable options

(defcustom roll-max-visible-panes 3
  "Maximum number of panes visible at once.
When you have more panes than this limit, Roll will hide the excess
panes and allow you to scroll through them."
  :type 'integer
  :group 'roll
  :safe #'integerp)

(defcustom roll-debug-enabled nil
  "Whether to send debug messages to the *Messages* buffer.
Useful for troubleshooting Roll's behavior or understanding
how the internal state changes."
  :type 'boolean
  :group 'roll
  :safe #'booleanp)

;; Utility functions

(defun roll--debug (msg)
  "Display internal state variables with MSG as prefix.
Only outputs if roll-debug-enabled is non-nil."
  (when roll-debug-enabled
    (message "%s: panes=%S visible=%d first=%d windows=%S"
             msg
             (mapcar (lambda (pane)
                       (buffer-name (roll-pane-buffer pane)))
                     roll--panes)
             roll--nof-visible-panes
             roll--first-visible-pane
             (mapcar #'window-buffer roll--windows))))

(defun roll--make-snapshot ()
  "Create a roll-pane struct from the current window state.
Captures the current buffer and cursor position."
  (make-roll-pane :buffer (current-buffer)
                  :point (point)))

;; Mode setup and teardown

(defun roll--enable ()
  "Initialize Roll mode by setting up the initial state.
Removes all other windows and creates the initial pane configuration."
  (delete-other-windows)
  (setq roll--windows (list (selected-window)))
  (setq roll--nof-visible-panes 1)
  (setq roll--first-visible-pane 0)
  (setq roll--panes (list (roll--make-snapshot)))
  (roll--debug "roll-mode enabled"))

(defun roll--disable ()
  "Clean up Roll mode state.
Currently this doesn't restore the previous window configuration."
  (roll--debug "roll-mode disabled"))

;;;###autoload
(define-minor-mode roll-mode
  "Toggle the rolling window manager.

When enabled, Roll mode provides a horizontal scrolling interface
for managing multiple buffers. You can create new panes, scroll
through them, and rearrange them as needed.

Key bindings:
\\{roll-mode-map}

See the commentary section for detailed usage instructions."
  :global t
  :lighter " Roll"
  :keymap roll-mode-map
  (if roll-mode
      (roll--enable)
    (roll--disable)))

;; Core functionality

(defun roll--update-visible-windows ()
  "Recreate visible windows based on current state.
TODO: This function is currently not implemented."
  ;; TODO: Implement this function
  )

(defun roll-next ()
  "Go to the next window.
TODO: This function is currently not implemented."
  (interactive)
  ;; TODO: Implement this function - what should it do differently from roll-go-right?
  )

(defun roll--insert-pane-after-current-position (pane)
  "Insert PANE into roll--panes after the current visible area.
The pane is inserted at the position immediately after the rightmost
visible pane, which allows it to become visible when focus moves right."
  (let* ((insert-position (min (+ roll--first-visible-pane roll--nof-visible-panes)
                               (length roll--panes)))
         (before (cl-subseq roll--panes 0 insert-position))
         (after (cl-subseq roll--panes insert-position)))
    (setq roll--panes (append before (list pane) after))))

(defun roll--move-focus-right ()
  "Move cursor to the window on the right.
Uses \"windmove-right\" for actual window navigation."
  (windmove-right))

(cl-defun roll--pane-to-window (&key pane-index window)
  "Display the pane at PANE-INDEX in the given WINDOW.
Sets both the buffer and cursor position from the pane data."
  (when (< pane-index (length roll--panes))
    (let ((pane (nth pane-index roll--panes)))
      (set-window-buffer window (roll-pane-buffer pane))
      (set-window-point window (roll-pane-point pane)))))

(defun roll--redraw ()
  "Update all visible windows to show the current pane selection.
This is called after any operation that changes which panes should be visible."
  (roll--debug "redrawing")
  (dotimes (window-index roll--nof-visible-panes)
    (let ((pane-index (+ roll--first-visible-pane window-index))
          (window (nth window-index roll--windows)))
      (roll--pane-to-window :pane-index pane-index :window window))))

;; Window and pane state queries

(defun roll--current-window-index ()
  "Return the index of the currently selected window in roll--windows.
Returns nil if the selected window is not managed by Roll."
  (cl-position (selected-window) roll--windows :test 'eq))

(defun roll--is-last-window-selected ()
  "Return t if the currently selected window is the rightmost visible window."
  (= (roll--current-window-index) (1- roll--nof-visible-panes)))

(defun roll--is-max-windows-opened ()
  "Return t if we already have the maximum number of visible windows."
  (>= roll--nof-visible-panes roll-max-visible-panes))

(defun roll--save-visible-buffers ()
  "Update roll--panes with the current state of all visible windows.
This preserves buffer and cursor position information before any operation
that might change which panes are visible."
  (dotimes (window-index roll--nof-visible-panes)
    (let ((window (nth window-index roll--windows))
          (pane-index (+ roll--first-visible-pane window-index)))
      (when (< pane-index (length roll--panes))
        (setf (nth pane-index roll--panes)
              (make-roll-pane
               :buffer (window-buffer window)
               :point (window-point window)))))))

;; Main operations

(defun roll--open ()
  "Internal function to create a new pane.
This handles the complex logic of where to place the new pane
and whether to create a new window or scroll the view."
  (roll--save-visible-buffers)

  (let ((new-pane (roll--make-snapshot)))

    ;; If we're at the rightmost window and already at max windows,
    ;; scroll the view right to make room for the new pane
    (when (and (roll--is-last-window-selected)
               (roll--is-max-windows-opened))
      (setq roll--first-visible-pane (1+ roll--first-visible-pane)))

    ;; If we haven't reached the maximum number of windows,
    ;; create a new physical window
    (unless (roll--is-max-windows-opened)
      (setq roll--nof-visible-panes (1+ roll--nof-visible-panes))
      (let ((win (split-window-right)))
        (nconc roll--windows (list win)))
      (balance-windows))

    ;; Add the new pane to our pane list and update display
    (roll--insert-pane-after-current-position new-pane)
    (roll--redraw)
    (roll--move-focus-right)))

;;;###autoload
(defun roll-open ()
  "Create a new pane to the right of the current position.

If there's room for more visible windows, this creates a new window.
Otherwise, it creates a new pane that will be visible when you scroll right.

The new pane will contain the same buffer as the current pane, but you
can immediately switch to a different buffer or open a file."
  (interactive)
  (if roll-mode
      (roll--open)
    (user-error "Roll mode is not enabled. Use M-x roll-mode first")))

;;;###autoload
(defun roll-go-left ()
  "Move focus to the pane on the left.

If you're already at the leftmost visible pane and there are hidden
panes to the left, this scrolls the view left to show them."
  (interactive)
  (unless roll-mode
    (user-error "Roll mode is not enabled"))

  (roll--save-visible-buffers)
  (if (and (= (roll--current-window-index) 0)
           (> roll--first-visible-pane 0))
      ;; Scroll the view left
      (setq roll--first-visible-pane (1- roll--first-visible-pane))
    ;; Just move focus within visible windows
    (windmove-left))
  (roll--redraw))

;;;###autoload
(defun roll-go-right ()
  "Move focus to the pane on the right.

If you're already at the rightmost visible pane and there are hidden
panes to the right, this scrolls the view right to show them."
  (interactive)
  (unless roll-mode
    (user-error "Roll mode is not enabled"))

  (roll--save-visible-buffers)
  (let* ((current-window-idx (roll--current-window-index))
         (rightmost-window-idx (1- roll--nof-visible-panes))
         (rightmost-pane-idx (+ roll--first-visible-pane rightmost-window-idx))
         (total-panes (length roll--panes)))

    (if (and (= current-window-idx rightmost-window-idx)
             (< rightmost-pane-idx (1- total-panes)))
        ;; Scroll the view right
        (setq roll--first-visible-pane (1+ roll--first-visible-pane))
      ;; Just move focus within visible windows
      (windmove-right)))
  (roll--redraw))

;;;###autoload
(defun roll-reload ()
  "Refresh the window layout.

This closes all windows and recreates them based on the current
pane configuration. Useful if the window layout gets corrupted."
  (interactive)
  (unless roll-mode
    (user-error "Roll mode is not enabled"))

  (delete-other-windows)
  (setq roll--windows (list (selected-window)))

  (let ((curr-win (selected-window)))
    ;; Recreate the proper number of windows
    (dotimes (_ (1- roll--nof-visible-panes))
      (let ((win (split-window-right)))
        (nconc roll--windows (list win))
        (windmove-right)))
    (select-window curr-win))

  (balance-windows)
  (roll--redraw))

;; Pane movement functions

(defun roll--current-pane-index ()
  "Return the index of the current pane in the roll--panes list."
  (+ roll--first-visible-pane (roll--current-window-index)))

(defun roll--swap-panes (index1 index2)
  "Swap the panes at INDEX1 and INDEX2 in the roll--panes list.
Returns t if the swap was successful, nil if the indices were invalid."
  (when (and (>= index1 0) (< index1 (length roll--panes))
             (>= index2 0) (< index2 (length roll--panes))
             (/= index1 index2))
    (let ((temp (nth index1 roll--panes)))
      (setf (nth index1 roll--panes) (nth index2 roll--panes))
      (setf (nth index2 roll--panes) temp)
      t)))

;;;###autoload
(defun roll-move-left ()
  "Move the current pane one position to the left.

This swaps the current pane with the pane to its left and follows
the moved pane by shifting focus left as well."
  (interactive)
  (unless roll-mode
    (user-error "Roll mode is not enabled"))

  (roll--save-visible-buffers)
  (let* ((current-pane-index (roll--current-pane-index))
         (left-pane-index (1- current-pane-index)))
    (if (>= left-pane-index 0)
        (progn
          (roll--swap-panes current-pane-index left-pane-index)
          (roll--redraw)
          (roll-go-left))
      (message "Cannot move pane further left"))))

;;;###autoload
(defun roll-move-right ()
  "Move the current pane one position to the right.

This swaps the current pane with the pane to its right and follows
the moved pane by shifting focus right as well."
  (interactive)
  (unless roll-mode
    (user-error "Roll mode is not enabled"))

  (roll--save-visible-buffers)
  (let* ((current-pane-index (roll--current-pane-index))
         (right-pane-index (1+ current-pane-index)))
    (if (< right-pane-index (length roll--panes))
        (progn
          (roll--swap-panes current-pane-index right-pane-index)
          (roll--redraw)
          (roll-go-right))
      (message "Cannot move pane further right"))))

(provide 'roll)
;;; roll.el ends here
