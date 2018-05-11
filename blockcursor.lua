local function setCaretStyle(self, editor) editor:SetCaretStyle(wxstc.wxSTC_CARETSTYLE_BLOCK) end

return {
  name = "Block cursor",
  description = "Switches cursor to a block cursor.",
  author = "Paul Kulchenko",
  version = 0.21,

  onEditorLoad = setCaretStyle,
  onEditorNew = setCaretStyle,
}
