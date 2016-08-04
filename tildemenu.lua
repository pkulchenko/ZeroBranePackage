local id = ID("tildemenu.tildemenu")
return {
  name = "Tilde",
  description = "Allows to enter tilde (~) on keyboards that may not have it.",
  author = "Paul Kulchenko",
  version = 0.2,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    menu:Append(id, "Tilde\tAlt-'")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function()
        local ed = ide:GetEditor()
        if ed then ed:AddText("~") end
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function(event)
        event:Enable(ide:GetEditor() ~= nil)
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
