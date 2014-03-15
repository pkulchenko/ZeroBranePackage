local G = ...
local id = G.ID("zoommenu.zoommenu")
local menuid
return {
  name = "Zoom editor view",
  description = "Adds zoom submenu to the View menu to control Zoom in the current editor.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local zoomMenu = wx.wxMenu{
      {ID "zoomreset", "Zoom to 100%\tCtrl-0"},
      {ID "zoomin", "Zoom In\tCtrl-+"},
      {ID "zoomout", "Zoom Out\tCtrl--"},
    }
    local frame = ide:GetMainFrame()
    local menubar = ide:GetMenuBar()
    local menu = menubar:GetMenu(menubar:FindMenu(TR("&View")))
    menuid = menu:Append(ID "zoom", "Zoom", zoomMenu)

    frame:Connect(ID "zoomreset", wx.wxEVT_COMMAND_MENU_SELECTED,
      function () GetEditor():SetZoom(0) end)
    frame:Connect(ID "zoomin", wx.wxEVT_COMMAND_MENU_SELECTED,
      function () GetEditor():SetZoom(GetEditor():GetZoom()+1) end)
    frame:Connect(ID "zoomout", wx.wxEVT_COMMAND_MENU_SELECTED,
      function () GetEditor():SetZoom(GetEditor():GetZoom()-1) end)

    -- only enable if there is an editor
    for _, m in G.ipairs({"zoomreset", "zoomin", "zoomout"}) do
      frame:Connect(ID(m), wx.wxEVT_UPDATE_UI,
        function (event) event:Enable(GetEditor() ~= nil) end)
    end
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    if menuid then menu:Destroy(menuid) end
  end,
}
