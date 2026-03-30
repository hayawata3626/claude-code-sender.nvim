# claude-code-sender.nvim

Send selected code from Neovim to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with file context (`file:line-line` format).

Works with [cmux](https://cmux.com/) and [tmux](https://github.com/tmux/tmux).

## Features

- Send visual selection or current line to Claude Code
- Automatically includes file path, line numbers, and filetype as context
- Auto-detects Claude Code pane/surface
- Supports both cmux and tmux

## Requirements

- Neovim >= 0.9.0
- [cmux](https://cmux.com/) or [tmux](https://github.com/tmux/tmux)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) running in a separate pane

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hayawata3626/claude-code-sender.nvim",
  opts = {},
  keys = {
    { "<leader>ac", mode = "v", desc = "Send selection to Claude Code" },
    { "<leader>al", desc = "Send current line to Claude Code" },
  },
}
```

## Usage

1. Open Neovim and Claude Code in separate panes (same cmux workspace or tmux session)
2. Select code in Visual mode (`V` for line select)
3. Press `<leader>ac` to send the selection to Claude Code

The text is sent in this format:

```
src/app/page.tsx:10-25

```tsx
// selected code here
```
```

## Configuration

```lua
require("claude-code-sender").setup({
  -- Terminal multiplexer: "auto" | "cmux" | "tmux"
  multiplexer = "auto",

  cmux = {
    bin = "/Applications/cmux.app/Contents/Resources/bin/cmux",
    surface_id = nil, -- auto-detect, or set e.g. "surface:50"
  },

  tmux = {
    bin = "tmux",
    pane_id = nil, -- auto-detect, or set e.g. "%3"
  },

  -- Keymaps (set to false to disable all)
  keymaps = {
    send_selection = "<leader>ac", -- Visual mode
    send_line = "<leader>al",     -- Normal mode
  },

  -- Custom format function
  format = function(file, start_line, end_line, filetype, text)
    return string.format("%s:%d-%d\n\n```%s\n%s\n```", file, start_line, end_line, filetype, text)
  end,
})
```

## Keymaps

| Key | Mode | Description |
| --- | --- | --- |
| `<leader>ac` | Visual | Send selection to Claude Code |
| `<leader>al` | Normal | Send current line to Claude Code |

## License

MIT
