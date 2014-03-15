return {
  name = "Block cursor",
  description = "Switches cursor to a block cursor.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = function(self, editor)
    editor:SetCaretStyle(wxstc.wxSTC_CARETSTYLE_BLOCK)
  end,
}
