local M = {}
local Config = require("claude-code-sender.config")
local Context = require("claude-code-sender.context")
local Templates = require("claude-code-sender.templates")

-- Detect which multiplexer is available
---@return "cmux" | "tmux" | nil
local function detect_multiplexer()
  if vim.env.CMUX_WORKSPACE_ID then
    return "cmux"
  elseif vim.env.TMUX then
    return "tmux"
  end
  return nil
end

-- Find Claude Code surface in cmux by searching the workspace tree
---@return string|nil surface ref (e.g. "surface:50")
local function find_cmux_surface()
  local bin = Config.options.cmux.bin
  local output = vim.fn.system(bin .. " tree 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  for line in output:gmatch("[^\n]+") do
    -- Skip the current surface
    if not line:find("◀ here") then
      -- Match Claude Code indicators in surface titles
      if line:match("surface") and (line:match("✳") or line:match("⠐") or line:match("⠂") or line:match("Claude Code")) then
        local surface = line:match("(surface:%d+)")
        if surface then
          return surface
        end
      end
    end
  end
  return nil
end

-- Find Claude Code pane in tmux
---@return string|nil pane id (e.g. "%3")
local function find_tmux_pane()
  local bin = Config.options.tmux.bin
  local output = vim.fn.system(bin .. " list-panes -F '#{pane_id} #{pane_current_command}' 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  for line in output:gmatch("[^\n]+") do
    if line:match("claude") then
      local pane_id = line:match("(%%%d+)")
      if pane_id then
        return pane_id
      end
    end
  end
  return nil
end

-- Send text via cmux
---@param text string
---@return boolean success
local function send_cmux(text)
  local bin = Config.options.cmux.bin
  local target = Config.options.cmux.surface_id or find_cmux_surface()
  if not target then
    vim.notify("claude-code-sender: Could not find Claude Code surface", vim.log.levels.ERROR)
    return false
  end

  -- Use set-buffer + paste-buffer to handle large text safely
  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("claude-code-sender: Failed to create temp file", vim.log.levels.ERROR)
    return false
  end
  f:write(text)
  f:close()

  vim.fn.system(string.format('%s set-buffer "$(cat %s)"', bin, vim.fn.shellescape(tmpfile)))
  vim.fn.delete(tmpfile)
  if vim.v.shell_error ~= 0 then
    return false
  end

  vim.fn.system(string.format("%s paste-buffer --surface %s", bin, target))
  if vim.v.shell_error ~= 0 then
    return false
  end

  vim.fn.system(string.format("%s send-key --surface %s Enter", bin, target))
  return vim.v.shell_error == 0
end

-- Send text via tmux
---@param text string
---@return boolean success
local function send_tmux(text)
  local bin = Config.options.tmux.bin
  local target = Config.options.tmux.pane_id or find_tmux_pane()
  if not target then
    vim.notify("claude-code-sender: Could not find Claude Code pane", vim.log.levels.ERROR)
    return false
  end

  -- Write to temp file and use load-buffer for safe text transfer
  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if not f then
    vim.notify("claude-code-sender: Failed to create temp file", vim.log.levels.ERROR)
    return false
  end
  f:write(text)
  f:close()

  vim.fn.system(string.format("%s load-buffer %s", bin, vim.fn.shellescape(tmpfile)))
  vim.fn.delete(tmpfile)
  if vim.v.shell_error ~= 0 then
    return false
  end

  vim.fn.system(string.format("%s paste-buffer -t %s", bin, target))
  if vim.v.shell_error ~= 0 then
    return false
  end

  vim.fn.system(string.format("%s send-keys -t %s Enter", bin, target))
  return vim.v.shell_error == 0
end

-- Send raw text to Claude Code
---@param text string
function M.send(text)
  local mux = Config.options.multiplexer
  if mux == "auto" then
    mux = detect_multiplexer()
    if not mux then
      vim.notify("claude-code-sender: No supported multiplexer detected (cmux or tmux)", vim.log.levels.ERROR)
      return
    end
  end

  local ok = false
  if mux == "cmux" then
    ok = send_cmux(text)
  elseif mux == "tmux" then
    ok = send_tmux(text)
  else
    vim.notify("claude-code-sender: Unknown multiplexer: " .. mux, vim.log.levels.ERROR)
    return
  end

  if ok then
    vim.notify("Sent to Claude Code", vim.log.levels.INFO)
  else
    vim.notify("claude-code-sender: Failed to send", vim.log.levels.ERROR)
  end
end

-- Apply project context (CLAUDE.md injection) to a prompt
---@param prompt string
---@return string
local function with_context(prompt)
  return Context.with_project_context(prompt, Config.options.project_context)
end

-- Send visual selection with file context
function M.send_selection()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local lines = vim.fn.getline(start_line, end_line)
  if type(lines) == "string" then
    lines = { lines }
  end
  local text = table.concat(lines, "\n")
  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype

  local prompt = Config.options.format(file, start_line, end_line, ft, text)
  M.send(with_context(prompt))
end

-- Send current line with file context
function M.send_line()
  local line_nr = vim.fn.line(".")
  local line = vim.fn.getline(line_nr)
  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype

  local prompt = Config.options.format(file, line_nr, line_nr, ft, line)
  M.send(with_context(prompt))
end

-- Send entire buffer with file context
function M.send_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype
  local line_count = #lines

  local prompt = Config.options.format(file, 1, line_count, ft, text)
  M.send(with_context(prompt))
end

-- Send LSP diagnostics for a line range (or current line in normal mode)
---@param start_line number|nil 1-indexed; defaults to current line
---@param end_line number|nil 1-indexed; defaults to start_line
function M.send_diagnostics(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  start_line = start_line or vim.fn.line(".")
  end_line = end_line or start_line

  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype

  -- Get the code for context
  local code_lines = vim.fn.getline(start_line, end_line)
  if type(code_lines) == "string" then
    code_lines = { code_lines }
  end
  local code_text = table.concat(code_lines, "\n")

  local diag_text = Context.get_diagnostics(bufnr, start_line, end_line)

  local location = start_line == end_line
    and string.format("%s:%d", file, start_line)
    or string.format("%s:%d-%d", file, start_line, end_line)

  local parts = {}
  if diag_text ~= "" then
    table.insert(parts, string.format("# LSP Diagnostics (%s)\n\n%s", location, diag_text))
  else
    table.insert(parts, string.format("# No LSP Diagnostics (%s)", location))
  end
  table.insert(parts, Config.options.format(file, start_line, end_line, ft, code_text))

  local prompt = table.concat(parts, "\n\n")
  M.send(with_context(prompt))
end

-- Send visual-selection diagnostics (called from visual mode)
function M.send_diagnostics_selection()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  M.send_diagnostics(start_line, end_line)
end

-- Send git diff (unstaged by default)
---@param staged boolean|nil if true, send staged diff
function M.send_git_diff(staged)
  local diff = Context.get_git_diff(staged)
  if not diff then
    vim.notify("claude-code-sender: No git diff found (or not a git repo)", vim.log.levels.WARN)
    return
  end

  local title = staged and "# Git Diff (staged changes)" or "# Git Diff (unstaged changes)"
  local prompt = string.format("%s\n\n```diff\n%s\n```", title, diff)
  M.send(with_context(prompt))
end

-- Show template picker then send visual selection with the chosen prompt prefix
function M.send_with_template()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local lines = vim.fn.getline(start_line, end_line)
  if type(lines) == "string" then
    lines = { lines }
  end
  local text = table.concat(lines, "\n")
  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype

  local templates = Templates.merge(Config.options.templates)
  Templates.pick(templates, function(template_prompt)
    local code_block = Config.options.format(file, start_line, end_line, ft, text)
    local prompt = template_prompt .. code_block
    M.send(with_context(prompt))
  end)
end

-- Setup keymaps
local function setup_keymaps()
  local keymaps = Config.options.keymaps
  if not keymaps then
    return
  end

  if keymaps.send_selection then
    vim.keymap.set("v", keymaps.send_selection, function()
      M.send_selection()
    end, { desc = "Send selection to Claude Code", silent = true })
  end

  if keymaps.send_line then
    vim.keymap.set("n", keymaps.send_line, function()
      M.send_line()
    end, { desc = "Send current line to Claude Code", silent = true })
  end

  if keymaps.send_buffer then
    vim.keymap.set("n", keymaps.send_buffer, function()
      M.send_buffer()
    end, { desc = "Send buffer to Claude Code", silent = true })
  end

  if keymaps.send_diagnostics then
    vim.keymap.set("n", keymaps.send_diagnostics, function()
      M.send_diagnostics()
    end, { desc = "Send diagnostics + current line to Claude Code", silent = true })
    vim.keymap.set("v", keymaps.send_diagnostics, function()
      M.send_diagnostics_selection()
    end, { desc = "Send diagnostics + selection to Claude Code", silent = true })
  end

  if keymaps.send_git_diff then
    vim.keymap.set("n", keymaps.send_git_diff, function()
      M.send_git_diff()
    end, { desc = "Send git diff to Claude Code", silent = true })
  end

  if keymaps.send_with_template then
    vim.keymap.set("v", keymaps.send_with_template, function()
      M.send_with_template()
    end, { desc = "Send selection to Claude Code with template", silent = true })
  end
end

function M.setup(opts)
  Config.setup(opts)
  setup_keymaps()
end

return M
