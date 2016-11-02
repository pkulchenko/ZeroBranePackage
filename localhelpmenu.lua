local id = ID("localhelpmenu.localhelpmenu")
return {
  name = "Local Lua help",
  description = "Adds local help option to the menu.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = "1.30",

  onRegister = function(self)
    local menu = ide:FindTopMenu("&Help")
    menu:Append(id, "Lua Documentation")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event) wx.wxLaunchDefaultBrowser(self:GetConfig().index, 0) end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Enable(self:GetConfig().index ~= nil) end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
