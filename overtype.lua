local id = ID("overtype.overtype")
return {
  name = "Overtype on/off",
  description = "Allows to switch overtyping on/off on systems that don't provide shortcut for that.",
  author = "Paul Kulchenko",
  version = 0.3,
  dependencies = 0.50,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    local pos = self:GetConfig().insertat and
      self:GetConfig().insertat-1 or menu:GetMenuItemCount()
    menu:InsertCheckItem(pos, id, "Overtype"..KSC(id, "Alt-Shift-I"))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        local ed = ide:GetEditor()
        if ed then ed:SetOvertype(event:IsChecked()) end
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function(event)
        local ed = ide:GetEditor()
        event:Check(ed and ed:GetOvertype())
        event:Enable(ed ~= nil)
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
