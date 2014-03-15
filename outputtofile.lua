local filter, fname
local function append(fname, s)
  if not fname then return end
  local f = io.open(fname, "a")
    or error(("Can't open file '%s' for writing"):format(fname))
  f:write(s)
  f:close()
end

return {
  name = "Output to file",
  description = "Redirects debugging output to a file.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local config = ide:GetConfig()
    local output = ide:GetOutput()
    local maxlines = self:GetConfig().maxlines or 100

    filter = config.debugger.outputfilter
    config.debugger.outputfilter = function(s)
      local start  = output:GetLineCount() - maxlines
      if start >= 0 then -- trim the output to the right number of lines
        local readonly = output:GetReadOnly()
        output:SetReadOnly(false)
        output:SetTargetStart(0)
        output:SetTargetEnd(output:PositionFromLine(start+1))
        output:ReplaceTarget("")
        output:SetReadOnly(readonly)
      end
      append(fname, s)
      return s
    end
  end,

  onUnRegister = function(self)
    ide:GetConfig().debugger.outputfilter = filter
  end,
  onProjectLoad = function(self, project)
    fname = MergeFullPath(project, self:GetConfig().fname or "output.log")
  end,
}
