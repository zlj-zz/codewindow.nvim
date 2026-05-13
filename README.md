# Codewindow.nvim

Codewindow.nvim is a minimap plugin for neovim, that is closely integrated with treesitter and the builtin LSP to display more information to the user.

![Codewindow in action](https://i.imgur.com/MokAFG0.png)

## Requirements

- **Neovim >= 0.8**
- Treesitter parsers installed for filetypes you want highlighted (e.g. via [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter))

> **Note:** This plugin uses Neovim's built-in `vim.treesitter` API. It does not depend on the `nvim-treesitter` plugin itself, but you will need the appropriate parsers installed for syntax highlighting to work.
>
> **Checking parser installation:** Run `:checkhealth nvim-treesitter` to verify parsers are installed. If a language shows as missing, install it with `:TSInstall <language>` (e.g. `:TSInstall python`). You can also run `:TSInstallInfo` to see all available parsers and their installation status.

## How it works

Opening the minimap creates a floating window that will follow the active window around, always staying on the right, filling the entire height of said window.

In this floating window you can see the text rendered out using braille characters. Unless disabled, it will also try to get the treesitter highlights from the active buffer and apply them to the minimap[^1]. If the builtin LSP reports an error
or a warning, it will also appear as a small red or yellow dot next to the line the issue is in. The current viewport is shown as 2 white lines around the block of code being observed.

The minimap updates every time you leave insert mode, change the text in normal mode or the builtin LSP reports new diagnostics. `TextChanged` events are debounced (80ms) to avoid lag during fast typing.

You can also focus the minimap, this lets you quickly move through the code to get to a specific point. When focused, the cursor is hidden globally for a cleaner navigation experience.

[^1]: Because one character in the minimap represents several in the actual buffer, it will show the highlights that occured the most in that region.

## Installation

Packer:
```lua
use {
  'gorbit99/codewindow.nvim',
  config = function()
    local codewindow = require('codewindow')
    codewindow.setup()
    codewindow.apply_default_keybinds()
  end,
}
```

## Configuration

The setup method accepts an optional table as an argument with the following options (with the defaults):
```lua
{
  active_in_terminals = false, -- Should the minimap activate for terminal buffers
  auto_close = true, -- Automatically close the minimap when quitting Neovim if it's the only remaining window
  auto_enable = false, -- Automatically open the minimap when entering a (non-excluded) buffer (accepts a boolean or a table of filetypes)
  exclude_filetypes = { 'help' }, -- Choose certain filetypes to not show minimap on
  max_minimap_height = nil, -- The maximum height the minimap can take (including borders)
  max_lines = nil, -- Don't render the minimap for buffers with more than this many lines (keeps editing large files responsive)
  minimap_width = 20, -- The width of the text part of the minimap
  use_lsp = true, -- Use the builtin LSP to show errors and warnings
  use_treesitter = true, -- Use built-in treesitter to highlight the code
  use_git = true, -- Show small dots to indicate git additions and deletions
  width_multiplier = 4, -- How many characters one dot represents
  z_index = 1, -- The z-index the floating window will be on
  show_cursor = true, -- Show the cursor position in the minimap
  screen_bounds = 'lines', -- How the visible area is displayed, "lines": lines above and below, "background": background color
  window_border = 'single', -- The border style of the floating window (accepts all usual options)
  relative = 'win', -- What will the minimap be placed relative to, "win": the current window, "editor": the entire editor
  events = { 'TextChanged', 'InsertLeave', 'DiagnosticChanged', 'FileWritePost' } -- Events that update the code window
}
```
config changes get merged in with defaults, so defining every config option is unnecessary (and probably error prone).

The default keybindings are as follows:
```
<leader>mf - focus/unfocus the minimap
<leader>mm - toggle the minimap
```

`open_minimap` and `close_minimap` are no longer bound by default. If you want them, set them up manually:

```lua
vim.keymap.set('n', '<leader>mo', codewindow.open_minimap, { desc = 'Open minimap' })
vim.keymap.set('n', '<leader>mc', codewindow.close_minimap, { desc = 'Close minimap' })
```

All available functions:
```lua
codewindow.open_minimap()
codewindow.close_minimap()
codewindow.toggle_minimap()
codewindow.toggle_focus()
```

To change how the minimap looks, you can define the following highlight groups 
somewhere in your config:
```lua
CodewindowBorder -- the border highlight
CodewindowBackground -- the background highlight
CodewindowWarn -- the color of the warning dots
CodewindowError -- the color of the error dots
CodewindowAddition -- the color of the addition git sign
CodewindowDeletion -- the color of the deletion git sign
CodewindowUnderline -- the color of the underlines on the minimap
CodewindowBoundsBackground -- the color of the background on the minimap

-- Example
vim.api.nvim_set_hl(0, 'CodewindowBorder', {fg = '#ffff00'})
```

## Working alongside other plugins

I'll try to make sure, that most plugins can be made to work without any issues alongside codewindow. If you find a usecase that should be supported, but can't be, then open an issue detailing the plugin used and the issue at hand.

For the most part most plugins can simply be made to work by making them ignore the Codewindow filetype.

## Performance

The minimap is optimized to stay responsive even in large files:

- **changedtick caching**: Scrolling and cursor movement skip Braille re-compression and treesitter highlighting if the buffer hasn't changed.
- **Debounced `TextChanged`**: Fast typing triggers an 80ms debounce instead of re-rendering on every keystroke.
- **`max_lines` guard**: Buffers above the threshold render an empty minimap, keeping Neovim responsive in generated bundles or log files.

On a ~180 line file, a full render (cold cache) takes ~7ms. Cached renders (scroll, cursor move) are effectively free.

## Related projects

- [https://github.com/wfxr/minimap.vim](https://github.com/wfxr/minimap.vim) - A very fast minimap plugin for neovim, though it relies on a separate program
- [https://github.com/echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim) - Funnily enough, this came out only a couple of days after I started working on codewindow

## TODO

- Help pages for the functions
- Incremental line-range updates - only re-compress Braille rows that overlap edited lines
- More display options - like floating to the left, not full height, etc. etc.
