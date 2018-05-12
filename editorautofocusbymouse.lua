local function focusOnEnterWindow(self, editor)
  editor:Connect(wx.wxEVT_ENTER_WINDOW, function() editor:SetFocus() end)
end

return {
  name = "Editor auto-focus by mouse",
  description = "Moves focus to an editor tab the mouse is over.",
  author = "Paul Kulchenko",
  version = 0.11,

  onEditorLoad = focusOnEnterWindow,
  onEditorNew = focusOnEnterWindow,
}
