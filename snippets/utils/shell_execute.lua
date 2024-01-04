local wx = wx

---
-- execute shell command and stdout return
local shell_execute_flags = wx.wxEXEC_SYNC + (wx.wxEXEC_NOEVENTS or 0) + (wx.wxEXEC_HIDE_CONSOLE or 0)

local function shell_execute(code)
  local ret, stdout, stderr = wx.wxExecuteStdoutStderr(code, shell_execute_flags)

  if stdout then
    stdout = table.concat(stdout, '\n')
  end

  if stderr then
    stderr = table.concat(stderr, '\n')
  end

  return ret, stdout, stderr
end

return shell_execute