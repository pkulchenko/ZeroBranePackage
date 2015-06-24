-- Copyright 2015 Paul Kulchenko, ZeroBrane LLC; All rights reserved

return {
  name = "File type based on Shebang",
  description = "Sets file type based on executable in shebang.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = 1.0,

  onEditorLoad = function(self, editor)
    local src = editor:GetLine(0)
    if editor:GetLexer() == wxstc.wxSTC_LEX_NULL and src:find('^#!') then
      local ext = src:match("%W(%w+)%s*$")
      if ext then editor:SetupKeywords(ext) end
    end
  end,
}
