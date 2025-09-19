# roll.el

A horizontal scrolling window manager for Emacs that creates a "rolling" view of your buffers, similar to tmux sessions or browser tabs.

## Overview

Roll provides a unique approach to window management in Emacs. Instead of managing windows in a 2D grid, Roll creates a horizontal strip of windows (called "panes") that you can scroll through. Only a limited number of panes are visible at once, but you can have many more that exist "off-screen" to the left and right.

Think of it as having an infinite horizontal workspace where you can quickly navigate between different contexts while maintaining a clean, organized view.

## Features

- 🔄 **Horizontal scrolling** through multiple buffers
- 🪟 **Configurable visibility** - control how many panes are visible at once
- ⌨️ **Smooth navigation** with intuitive keyboard shortcuts
- 🔀 **Pane reordering** - move panes left/right to organize your workspace
- 💾 **Persistent state** - panes remember their buffer and cursor position
- 🎯 **Focus follows navigation** - cursor automatically moves to the right window
- ⚙️ **Customizable** - adjust behavior to fit your workflow

## Installation

### Manual Installation

1. Download `roll.el` and place it in your Emacs load path
2. Add to your init file:

```elisp
(require 'roll)
```

### Using package managers

*Coming soon: MELPA package submission*

## Quick Start

1. **Enable roll-mode**: `M-x roll-mode`
2. **Create new panes**: `M-x roll-open` (or `C-c C-r o`)
3. **Navigate**: `Shift + arrow keys`
4. **Reorganize**: `Shift + Ctrl + arrow keys` to move panes

## Key Bindings

| Key Binding | Command | Description |
|-------------|---------|-------------|
| `S-<left>` | `roll-go-left` | Move focus to left pane or scroll left |
| `S-<right>` | `roll-go-right` | Move focus to right pane or scroll right |
| `S-C-<left>` | `roll-move-left` | Move current pane to the left |
| `S-C-<right>` | `roll-move-right` | Move current pane to the right |
| `C-c C-r o` | `roll-open` | Create new pane |
| `C-c C-r r` | `roll-reload` | Refresh window layout |
| `C-c C-r c` | `roll-reload` | Close current pane |

## Configuration

Customize Roll's behavior with these variables:

```elisp
;; Maximum number of visible panes (default: 3)
(setq roll-max-visible-panes 4)

;; Disable debug messages (default: t)
(setq roll-debug-enabled nil)
```

### Custom Key Bindings

You can override the default key bindings:

```elisp
(define-key roll-mode-map (kbd "C-<left>") 'roll-go-left)
(define-key roll-mode-map (kbd "C-<right>") 'roll-go-right)
(define-key roll-mode-map (kbd "M-<left>") 'roll-move-left)
(define-key roll-mode-map (kbd "M-<right>") 'roll-move-right)
```

## How It Works

### Visual Example

With `roll-max-visible-panes` set to 3, your workspace might look like this:

```
Hidden Panes | Visible Panes        | Hidden Panes
-------------|---------------------|-------------
[A] [B]      | [C] [D*] [E]        | [F] [G]
                  ^^^
             Currently focused pane
```

- **`S-<right>`** would scroll to show: `[D*] [E] [F]`
- **`S-<left>`** would scroll to show: `[B] [C] [D*]`
- **`S-C-<left>`** would move pane D left: `[B] [D*] [C] [E]`

### Navigation Logic

1. **Within visible panes**: Arrow keys move focus between visible windows
2. **At boundaries**: When you're at the leftmost/rightmost visible pane and try to go further, Roll scrolls the view to reveal hidden panes
3. **Pane creation**: New panes are created to the right of your current position
4. **State persistence**: Each pane remembers its buffer and cursor position

## Example Workflow

Here's a typical workflow using Roll:

```elisp
;; 1. Enable roll mode
M-x roll-mode

;; 2. Open your main file
C-x C-f main.py

;; 3. Create a new pane for documentation
M-x roll-open  ; or C-c C-r o
C-x C-f README.md

;; 4. Create another pane for tests
M-x roll-open
C-x C-f test_main.py

;; 5. Navigate between contexts
S-<left>       ; Back to README.md
S-<left>       ; Back to main.py
S-<right>      ; Forward to README.md

;; 6. Reorganize panes (move tests to the left)
S-<right>      ; Go to test_main.py
S-C-<left>     ; Move it left (now: main.py, test_main.py, README.md)
S-C-<left>     ; Move it left again (now: test_main.py, main.py, README.md)
```

## Use Cases

Roll is particularly useful for:

- **Code review**: Keep original, modified, and reference files side by side
- **Documentation writing**: Main content, references, and examples in separate panes
- **Development workflows**: Code, tests, documentation, and REPL sessions
- **Research**: Multiple papers, notes, and writing buffers
- **Configuration editing**: Multiple config files that need coordination

## Comparison with Other Tools

| Feature | Roll | `windmove` | `winner-mode` | tmux panes |
|---------|------|------------|---------------|------------|
| Horizontal scrolling | ✅ | ❌ | ❌ | ❌ |
| Unlimited panes | ✅ | ❌ | ❌ | ✅ |
| Pane reordering | ✅ | ❌ | ❌ | ❌ |
| State persistence | ✅ | ❌ | ✅ | ✅ |
| Built into Emacs | ✅ | ✅ | ✅ | ❌ |

## Troubleshooting

### Common Issues

**Q: Panes seem "stuck" or not responding**
A: Try `M-x roll-reload` to refresh the window layout.

**Q: Key bindings don't work**
A: Make sure `roll-mode` is enabled. Check with `M-x describe-mode`.

**Q: Lost track of which pane is which**
A: Enable debug mode with `(setq roll-debug-enabled t)` to see pane information in the `*Messages*` buffer.

**Q: Want to see what's happening internally**
A: Enable debug mode and watch the `*Messages*` buffer as you navigate.

### Debug Mode

Enable verbose logging to understand Roll's behavior:

```elisp
(setq roll-debug-enabled t)
```

This will log internal state changes to the `*Messages*` buffer, showing:
- Current pane list (by buffer name)
- Number of visible panes
- Index of first visible pane
- List of managed windows

## Contributing

Contributions are welcome! Here are some areas where help would be appreciated:

- [ ] MELPA package submission
- [ ] Integration with `project.el`
- [ ] Storing panes per frame
- [ ] Pane persistence across Emacs sessions
- [ ] Visual indicators for hidden panes
- [ ] Mouse support for pane navigation
- [ ] Zooming with `roll-zoom-in` and `roll-zoom-out` to single out a window and then go back

### Development

To contribute:

1. Fork the repository
2. Create a feature branch
3. Add tests if applicable
4. Update documentation
5. Submit a pull request

## License

This project is licensed under the ISC License - see the LICENSE file for details.

## Acknowledgments

- Inspired by tmux's window management
- Built on Emacs' excellent windmove functionality
- Thanks to the Emacs community for feedback and suggestions

## Changelog

### Version 0.1.0
- Initial release
- Basic horizontal scrolling functionality
- Pane creation and navigation
- Pane reordering support
- Configurable number of visible panes
