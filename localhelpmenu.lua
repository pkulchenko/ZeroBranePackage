local G = ...
local id = G.ID("localhelpmenu.localhelpmenu")
local menuid
return {
  name = "Local Lua help",
  description = "Adds local help option to the menu.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Help")))
    menuid = menu:Append(id, "Lua Documentation")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event) wx.wxLaunchDefaultBrowser(self:GetConfig().index, 0) end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Enable(self:GetConfig().index ~= nil) end)
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Help")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxID_ANY)
    if menuid then menu:Destroy(menuid) end
  end,
}
