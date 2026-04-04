local M = {}

---@class ClaudeCodeSender.Config
local defaults = {
  -- Terminal multiplexer: "auto" | "cmux" | "tmux"
  -- "auto" detects cmux ($CMUX_WORKSPACE_ID) or tmux ($TMUX)
  multiplexer = "auto",

  cmux = {
    bin = vim.fn.exepath("cmux") ~= "" and vim.fn.exepath("cmux") or "/Applications/cmux.app/Contents/Resources/bin/cmux",
    -- Target surface ID (e.g. "surface:50"). nil = auto-detect.
    surface_id = nil,
  },

  tmux = {
    bin = "tmux",
    -- Target pane ID (e.g. "%3"). nil = auto-detect.
    pane_id = nil,
  },

  -- Project context options
  project_context = {
    -- Automatically prepend CLAUDE.md content to every prompt
    inject_claude_md = true,
  },

  -- Prompt templates shown in send_with_template picker.
  -- These are ADDED to the built-in defaults; set to {} to use defaults only.
  -- Each entry: { label = "...", prompt = "..." }
  templates = {},

  -- Set to false to disable default keymaps
  keymaps = {
    send_selection       = "<leader>ac", -- Visual mode
    send_line            = "<leader>al", -- Normal mode
    send_buffer          = "<leader>ab", -- Normal mode: send whole buffer
    send_diagnostics     = "<leader>ae", -- Normal/Visual: send LSP diagnostics + code
    send_git_diff        = "<leader>ag", -- Normal mode: send git diff
    send_with_template   = "<leader>at", -- Visual mode: pick template then send
  },

  -- Format function for the code block portion of a prompt
  ---@param file string relative file path
  ---@param start_line number
  ---@param end_line number
  ---@param filetype string
  ---@param text string selected text
  ---@return string
  format = function(file, start_line, end_line, filetype, text)
    if start_line == end_line then
      return string.format("%s:%d\n\n```%s\n%s\n```", file, start_line, filetype, text)
    end
    return string.format("%s:%d-%d\n\n```%s\n%s\n```", file, start_line, end_line, filetype, text)
  end,
}

---@type ClaudeCodeSender.Config
M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return M
