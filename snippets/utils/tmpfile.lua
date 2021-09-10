local tmpfile_methods = {__index = {
  write = function(self, data)
    self.file:Write(data)
    self.file:Flush()
  end,
  close = function(self)
    if self.file then
      self.file:Close()
      self.file = nil
    end
  end,
  remove = function(self)
    self:close()
    if self.path then
      wx.wxRemoveFile(self.path)
      self.path = nil
    end
  end,
}}

local function tmpfile(prefix)
  local file = wx.wxFile()
  local path = wx.wxFileName.CreateTempFileName(prefix, file)
  if not path then
    file:Close()
    return nil
  end
  return setmetatable({path = path, file = file}, tmpfile_methods)
end

return tmpfile