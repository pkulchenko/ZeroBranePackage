local function configureEditor(self, editor)
  editor:Connect(wx.wxEVT_MOTION, function(event)
      if not event:Dragging() then
        editor:SetSTCCursor(0)
        editor:SetSTCCursor(-1)
      end
      event:Skip()
    end)
  editor:Connect(wx.wxEVT_KEY_DOWN,
    function (event)
      local mod = event:GetModifiers()
      if not mod or mod ~= wx.wxMOD_SHIFT then editor:SetCursor(wx.wxCursor(wx.wxCURSOR_BLANK)) end
      event:Skip()
    end)
end

return {
  name = "Hide mouse cursor when typing",
  description = "Hides mouse cursor when typing.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = configureEditor,
  onEditorNew = configureEditor,
}
