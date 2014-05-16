local function focusOnEnterWindow(editor)
  editor:Connect(wx.wxEVT_ENTER_WINDOW, function() editor:SetFocus() end)
end
return {
  name = "Editor auto-focus by mouse",
  description = "Moves focus to an editor tab the mouse is over.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = function(self, editor) focusOnEnterWindow(editor) end,
  onEditorNew = function(self, editor) focusOnEnterWindow(editor) end,
}
