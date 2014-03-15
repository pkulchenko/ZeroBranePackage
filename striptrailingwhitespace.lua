return {
  name = "Strip trailing whitespaces on save",
  description = "Strips trailing whitespaces before saving a file.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorPreSave = function(self, editor)
    for line = editor:GetLineCount()-1, 0, -1 do
      local spos, _, spaces = editor:GetLine(line):find("([ \t]+)([\r\n]*)$")
      if spos then
        editor:DeleteRange(editor:PositionFromLine(line)+spos-1, #spaces)
      end
    end
  end,
}
