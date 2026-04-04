local M = {}

---@class ClaudeCodeSender.Template
---@field label string display name shown in picker
---@field prompt string text prepended to the code block

---@type ClaudeCodeSender.Template[]
M.defaults = {
  { label = "Explain this code",      prompt = "Please explain the following code.\n\n" },
  { label = "Fix the bug",            prompt = "Please fix the bug in the following code.\n\n" },
  { label = "Write tests",            prompt = "Please write tests for the following code.\n\n" },
  { label = "Refactor",               prompt = "Please refactor the following code.\n\n" },
  { label = "Add error handling",     prompt = "Please add error handling to the following code.\n\n" },
  { label = "Review for security",    prompt = "Please review the following code for security issues.\n\n" },
  { label = "Add comments/docs",      prompt = "Please add comments and documentation to the following code.\n\n" },
  { label = "Optimize performance",   prompt = "Please optimize the following code for performance.\n\n" },
}

-- Merge user-defined templates with defaults
---@param user_templates ClaudeCodeSender.Template[]|nil
---@return ClaudeCodeSender.Template[]
function M.merge(user_templates)
  if not user_templates or #user_templates == 0 then
    return M.defaults
  end
  local merged = {}
  for _, t in ipairs(M.defaults) do
    table.insert(merged, t)
  end
  for _, t in ipairs(user_templates) do
    table.insert(merged, t)
  end
  return merged
end

-- Show a picker and call callback with the selected template prompt
---@param templates ClaudeCodeSender.Template[]
---@param callback fun(prompt: string)
function M.pick(templates, callback)
  local labels = {}
  for _, t in ipairs(templates) do
    table.insert(labels, t.label)
  end

  vim.ui.select(labels, { prompt = "Send to Claude Code: " }, function(choice)
    if not choice then
      return
    end
    for _, t in ipairs(templates) do
      if t.label == choice then
        callback(t.prompt)
        return
      end
    end
  end)
end

return M
