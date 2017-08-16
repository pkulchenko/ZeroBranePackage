local lasterr
local markername, marker
local function clean(editor)
  ide:GetStatusBar():SetStatusText("")
  if marker then editor:MarkerDeleteAll(marker) end -- remove markers
end
local function setmarker(editor, cfgmark)
  marker = ide:AddMarker(markername,
    cfgmark.ch or wxstc.wxSTC_MARK_CHARACTER+(' '):byte(),
    cfgmark.fg or {0, 0, 0},
    cfgmark.bg or {255, 192, 192})
  if marker then editor:MarkerDefine(ide:GetMarker(markername)) end
end
return {
  name = "Syntax check while typing",
  description = "Reports syntax errors while typing (on Enter)",
  author = "Paul Kulchenko",
  version = 0.4,
  dependencies = 1.11,

  -- use the file name as the marker name to avoid conflicts
  onRegister = function(self) markername = self:GetFileName() end,
  onUnRegister = function(self) ide:RemoveMarker(markername) end,

  onEditorNew = function(self, editor) setmarker(editor, self:GetConfig().marker or {}) end,
  onEditorLoad = function(self, editor) setmarker(editor, self:GetConfig().marker or {}) end,

  onEditorCharAdded = function(self, editor, event)
    if lasterr then clean(editor); lasterr = nil end
    local keycode = event:GetKey()
    if keycode > 255 or string.char(keycode) ~= "\n" then return end

    local text = editor:GetText():gsub("^#!.-\n", "\n")
    local _, err = loadstring(text, ide:GetDocument(editor):GetFileName())

    if err then
      local line1, err = err:match(":(%d+)%s*:(.+)")
      local line2 = err and err:match("line (%d+)")

      if line1 and marker then editor:MarkerAdd(line1-1, marker) end
      if line2 and marker then editor:MarkerAdd(line2-1, marker) end
      ide:SetStatus(err and "Syntax error: "..err or "")

      lasterr = err
    end
  end,
}

--[[ configuration example:
syntaxcheckontype = {marker =
  {ch = wxstc.wxSTC_MARK_CHARACTER+('>'):byte(),
   fg = {0, 0, 0}, bg = {192, 192, 255}}
}
--]]
