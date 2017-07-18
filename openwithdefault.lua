return {
  name = "Open With Default",
  description = "Opens file with Default Program when activated.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = 1.0,

  onFiletreeActivate = function(self, tree, event, item_id)
    local fname = tree:GetItemText(item_id)
    local ext = wx.wxFileName(fname):GetExt()
    -- don't activate for known extensions
    if #(ide:GetKnownExtensions(ext)) == 1 then return end
    local ft = wx.wxTheMimeTypesManager:GetFileTypeFromExtension('.'..ext)
    if ft then
      tree:SelectItem(item_id)
      tree:AddPendingEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, ID_OPENEXTENSION))
      return false
    end
  end,
}
