return {
  name = "Quit on Escape",
  description = "Exits application on Escape.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorKeyDown = function(self, editor, event)
    if (event:GetKeyCode() == wx.WXK_ESCAPE
    and event:GetModifiers() == wx.wxMOD_NONE) then
      ide:GetMainFrame():AddPendingEvent(wx.wxCommandEvent(
        wx.wxEVT_COMMAND_MENU_SELECTED, ID_EXIT))
    end
  end,
}
