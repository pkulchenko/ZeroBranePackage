local G = ...
local id = G.ID("popupmenu.popupshow")
local iditem = G.ID("popupmenu.popupitem")
local menuid
return {
  name = "Sample plugin with popup menu",
  description = "Sample plugin showing how to setup and use popup menu.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    -- add menu item that will activate popup menu
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    menuid = menu:Append(id, "Show Popup\tCtrl-Alt-T")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function()
      GetEditor():AddPendingEvent(wx.wxContextMenuEvent(wx.wxEVT_CONTEXT_MENU))
    end)
  end,

  onUnRegister = function(self)
    -- remove added menu item when plugin is unregistered
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxEVT_COMMAND_MENU_SELECTED)
    if menuid then menu:Destroy(menuid) end
  end,

  onMenuEditor = function(self, menu, editor, event)
    -- add a separator and a sample menu item to the popup menu
    menu:AppendSeparator()
    menu:Append(iditem, "Popup Menu Item &{")

    -- attach a function to the added menu item
    editor:Connect(iditem, wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event) DisplayOutputLn("Selected popup item {") end)
  end
}
