local G = ...
local id = G.ID("wordwrapmenu.wordwrapmenu")
local menuid
return {
  name = "Wordwrap menu",
  description = "Adds word wrap option to the menu.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    local pos = self:GetConfig().insertat and
      self:GetConfig().insertat-1 or menu:GetMenuItemCount()
    menuid = menu:InsertCheckItem(pos, id, "WordWrap\tAlt-W")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event)
        local wrap = event:IsChecked() and wxstc.wxSTC_WRAP_WORD or wxstc.wxSTC_WRAP_NONE
        GetEditor():SetWrapMode(wrap) end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event)
        event:Check(GetEditor():GetWrapMode() ~= wxstc.wxSTC_WRAP_NONE) end)
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxID_ANY)
    if menuid then menu:Destroy(menuid) end
  end,
}
