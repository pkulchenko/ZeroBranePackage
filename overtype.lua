local G = ...
local id = G.ID("overtype.overtype")
local menuid
return {
  name = "Overtype on/off",
  description = "Allows to switch overtyping on/off on systems that don't provide shortcut for that.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = 0.50,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    local pos = self:GetConfig().insertat and
      self:GetConfig().insertat-1 or menu:GetMenuItemCount()
    menuid = menu:InsertCheckItem(pos, id, "Overtype"..KSC(id, "Alt-Shift-I"))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event) GetEditor():SetOvertype(event:IsChecked()) end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Check(GetEditor():GetOvertype()) end)
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxID_ANY)
    if menuid then menu:Destroy(menuid) end
  end,
}
