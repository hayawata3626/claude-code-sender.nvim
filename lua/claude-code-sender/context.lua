local M = {}

-- Read CLAUDE.md from the project root (walks up from cwd)
---@return string|nil content of CLAUDE.md, or nil if not found
function M.read_claude_md()
  local path = vim.fn.findfile("CLAUDE.md", ".;")
  if path == "" then
    return nil
  end
  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    return nil
  end
  return table.concat(lines, "\n")
end

-- Get LSP diagnostics for a buffer within a line range
---@param bufnr number
---@param start_line number 1-indexed
---@param end_line number 1-indexed
---@return string formatted diagnostics, or empty string if none
function M.get_diagnostics(bufnr, start_line, end_line)
  local diags = vim.diagnostic.get(bufnr)
  if not diags or #diags == 0 then
    return ""
  end

  local relevant = {}
  for _, d in ipairs(diags) do
    -- vim.diagnostic uses 0-indexed lines
    local lnum = d.lnum + 1
    if lnum >= start_line and lnum <= end_line then
      table.insert(relevant, d)
    end
  end

  if #relevant == 0 then
    return ""
  end

  table.sort(relevant, function(a, b)
    return a.lnum < b.lnum
  end)

  local severity_names = { "ERROR", "WARN", "INFO", "HINT" }
  local lines = {}
  for _, d in ipairs(relevant) do
    local sev = severity_names[d.severity] or "INFO"
    local lnum = d.lnum + 1
    table.insert(lines, string.format("%s (%d): %s", sev, lnum, d.message))
  end

  return table.concat(lines, "\n")
end

-- Run git diff and return the output
---@param staged boolean if true, show staged diff (git diff --cached); otherwise unstaged
---@return string|nil diff output, or nil on error
function M.get_git_diff(staged)
  local cmd = staged and "git diff --cached 2>/dev/null" or "git diff HEAD 2>/dev/null"
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 or output == "" then
    return nil
  end
  return output
end

-- Prepend CLAUDE.md content to a prompt if configured
---@param prompt string
---@param opts {inject_claude_md: boolean}
---@return string
function M.with_project_context(prompt, opts)
  if not opts.inject_claude_md then
    return prompt
  end
  local claude_md = M.read_claude_md()
  if not claude_md then
    return prompt
  end
  return "# Project Instructions (CLAUDE.md)\n\n" .. claude_md .. "\n\n---\n\n" .. prompt
end

return M
