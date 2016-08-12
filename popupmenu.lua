local id = ID("popupmenu.popupshow")
local iditem = ID("popupmenu.popupitem")
return {
  name = "Sample plugin with popup menu",
  description = "Sample plugin showing how to setup and use popup menu.",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.30",

  onRegister = function(self)
    -- add menu item that will activate popup menu
    local menu = ide:FindTopMenu("&Edit")
    menu:Append(id, "Show Popup\tCtrl-Alt-T")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function()
        local editor = ide:GetEditor()
        if editor then editor:AddPendingEvent(wx.wxContextMenuEvent(wx.wxEVT_CONTEXT_MENU)) end
      end)
  end,

  onUnRegister = function(self)
    -- remove added menu item when plugin is unregistered
    ide:RemoveMenuItem(id)
  end,

  onMenuEditor = function(self, menu, editor, event)
    -- add a separator and a sample menu item to the popup menu
    menu:AppendSeparator()
    menu:Append(iditem, "Popup Menu Item &{")

    -- attach a function to the added menu item
    editor:Connect(iditem, wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event) ide:Print("Selected popup item {") end)
  end
}
