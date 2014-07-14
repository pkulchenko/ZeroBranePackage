return {
  name = "Open With Default",
  description = "Opens file with Default Program when activated.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = 0.51,

  onFiletreeActivate = function(self, tree, event, item_id)
    local fname = tree:GetItemText(item_id)
    local ext = '.'..wx.wxFileName(fname):GetExt()
    local ft = wx.wxTheMimeTypesManager:GetFileTypeFromExtension(ext)
    if ft then
      tree:SelectItem(item_id)
      tree:AddPendingEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, ID_OPENEXTENSION))
      return false
    end
  end,
}
