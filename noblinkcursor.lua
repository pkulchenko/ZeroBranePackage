return {
  name = "No-blink cursor",
  description = "Disables cursor blinking.",
  author = "Paul Kulchenko",
  version = 0.2,

  onEditorLoad = function(self, editor) editor:SetCaretPeriod(0) end,
  onEditorNew = function(self, editor) editor:SetCaretPeriod(0) end,
}
