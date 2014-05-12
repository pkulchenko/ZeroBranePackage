return {
  name = "Block cursor",
  description = "Switches cursor to a block cursor.",
  author = "Paul Kulchenko",
  version = 0.2,

  onEditorLoad = function(self, editor) editor:SetCaretStyle(wxstc.wxSTC_CARETSTYLE_BLOCK) end,
  onEditorNew = function(self, editor) editor:SetCaretStyle(wxstc.wxSTC_CARETSTYLE_BLOCK) end,
}
