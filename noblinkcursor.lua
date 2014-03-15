return {
  name = "No-blink cursor",
  description = "Disables cursor blinking.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = function(self, editor)
    editor:SetCaretPeriod(0)
  end,
}
