local function setCaretPeriod(self, editor) editor:SetCaretPeriod(0) end

return {
  name = "No-blink cursor",
  description = "Disables cursor blinking.",
  author = "Paul Kulchenko",
  version = 0.21,

  onEditorLoad = setCaretPeriod,
  onEditorNew = setCaretPeriod,
}
