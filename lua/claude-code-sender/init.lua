local M = {}
local Config = require("claude-code-sender.config")

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

  vim.fn.system(string.format("%s send --surface %s %s", bin, target, vim.fn.shellescape(text)))
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
  M.send(prompt)
end

-- Send current line with file context
function M.send_line()
  local line_nr = vim.fn.line(".")
  local line = vim.fn.getline(line_nr)
  local file = vim.fn.expand("%:.")
  local ft = vim.bo.filetype

  local prompt = Config.options.format(file, line_nr, line_nr, ft, line)
  M.send(prompt)
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
end

function M.setup(opts)
  Config.setup(opts)
  setup_keymaps()
end

return M
