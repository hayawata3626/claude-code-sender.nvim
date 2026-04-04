# claude-code-sender.nvim

Send selected code from Neovim to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with rich context — file path, line numbers, LSP diagnostics, git diff, and project instructions.

Works with [cmux](https://cmux.com/) and [tmux](https://github.com/tmux/tmux).

## Features

- **Send selection / current line / entire buffer** to Claude Code
- **Prompt templates** — pick "Fix the bug", "Write tests", etc. from a menu
- **LSP diagnostics** — send error messages alongside the relevant code
- **Git diff** — send current unstaged changes to Claude Code
- **CLAUDE.md auto-injection** — project instructions are automatically prepended to every prompt
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
    { "<leader>ab", desc = "Send buffer to Claude Code" },
    { "<leader>ae", mode = { "n", "v" }, desc = "Send diagnostics to Claude Code" },
    { "<leader>ag", desc = "Send git diff to Claude Code" },
    { "<leader>at", mode = "v", desc = "Send with template to Claude Code" },
  },
}
```

## Usage

### Basic

1. Open Neovim and Claude Code in separate panes (same cmux workspace or tmux session)
2. Select code in Visual mode and press `<leader>ac` to send with file context

The text is sent in this format:

```
src/app/page.tsx:10-25

```tsx
// selected code here
```
```

### Prompt templates (`<leader>at`)

Select code in Visual mode and press `<leader>at`. A picker appears:

```
Send to Claude Code:
  > Explain this code
    Fix the bug
    Write tests
    Refactor
    Add error handling
    Review for security
    Add comments/docs
    Optimize performance
```

The chosen instruction is prepended to your code block before sending.

### LSP diagnostics (`<leader>ae`)

Press `<leader>ae` on a line (or select a range) to send the diagnostic errors together with the code:

```
# LSP Diagnostics (src/app/page.tsx:10)

ERROR (10): Property 'foo' does not exist on type 'Bar'

src/app/page.tsx:10

```tsx
const x = bar.foo
```
```

### Git diff (`<leader>ag`)

Press `<leader>ag` to send the current unstaged changes:

```
# Git Diff (unstaged changes)

```diff
diff --git a/src/app/page.tsx b/src/app/page.tsx
...
```
```

### CLAUDE.md auto-injection

If a `CLAUDE.md` file exists anywhere up the directory tree from your current working directory, its contents are automatically prepended to every prompt:

```
# Project Instructions (CLAUDE.md)

<contents of CLAUDE.md>

---

src/app/page.tsx:10-25

```tsx
// your code
```
```

Disable this with `project_context = { inject_claude_md = false }`.

## Configuration

```lua
require("claude-code-sender").setup({
  -- Terminal multiplexer: "auto" | "cmux" | "tmux"
  multiplexer = "auto",

  cmux = {
    bin = "cmux", -- auto-detected from PATH, or set full path
    surface_id = nil, -- auto-detect, or set e.g. "surface:50"
  },

  tmux = {
    bin = "tmux",
    pane_id = nil, -- auto-detect, or set e.g. "%3"
  },

  -- Project context
  project_context = {
    inject_claude_md = true, -- prepend CLAUDE.md to every prompt
  },

  -- Add custom templates (appended after built-in ones)
  templates = {
    { label = "Add JSDoc comments", prompt = "Please add JSDoc comments to the following code.\n\n" },
  },

  -- Keymaps (set any to false to disable)
  keymaps = {
    send_selection     = "<leader>ac", -- Visual mode
    send_line          = "<leader>al", -- Normal mode
    send_buffer        = "<leader>ab", -- Normal mode
    send_diagnostics   = "<leader>ae", -- Normal + Visual mode
    send_git_diff      = "<leader>ag", -- Normal mode
    send_with_template = "<leader>at", -- Visual mode
  },

  -- Custom format function for the code block
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
| `<leader>ab` | Normal | Send entire buffer to Claude Code |
| `<leader>ae` | Normal / Visual | Send LSP diagnostics + code to Claude Code |
| `<leader>ag` | Normal | Send git diff (unstaged) to Claude Code |
| `<leader>at` | Visual | Pick a prompt template, then send selection |

## Troubleshooting

### "Could not find Claude Code surface/pane"

Make sure Claude Code is fully started (showing the `>` prompt) in a pane within the same cmux workspace or tmux session.

### cmux binary not found

If `cmux` is not in your PATH, set the full path:

```lua
opts = {
  cmux = {
    bin = "/Applications/cmux.app/Contents/Resources/bin/cmux",
  },
}
```

## License

MIT
