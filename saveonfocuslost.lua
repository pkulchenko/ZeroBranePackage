return {
  name = "Save a file on editor losing focus",
  description = "A plugin to save a file when editor focus is lost.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorFocusLost = function(plugin, editor)
    local fpath = ide:GetDocument(editor):GetFilePath()
    -- don't save those files that don't have a file name yet
    if fpath then SaveFile(editor, fpath) end
  end
}
