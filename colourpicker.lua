local id = ID("colourpicker.insertcolour")
return {
  name = "Colour picker",
  description = "Select color to insert in the document",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = 1.0,

  onRegister = function()
    -- SetAccelerator is only available in 1.31+, so check for it
    if ide.SetAccelerator and KSC(id) > "" then ide:SetAccelerator(id, KSC(id)) end
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        local editor = ide:GetEditor()
        if not editor then return end
        local rgb = editor:GetSelectedText():match("(%d+,%s*%d+,%s*%d+)")
        local colour = wx.wxColour(rgb and "rgb("..rgb..")" or wx.wxBLACK)
        local newcolour = wx.wxGetColourFromUser(ide:GetMainFrame(), colour)
        if newcolour:Ok() then -- user selected some colour
          local newtext = newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("%d+,%s*%d+,%s*%d+") or ""
          ide:GetEditor():ReplaceSelection(newtext)
        end
      end)
  end,
  onUnRegister = function()
    if ide.SetAccelerator then ide:SetAccelerator(id, nil) end
    ide:GetMainFrame():Disconnect(id, wx.wxEVT_COMMAND_MENU_SELECTED)
  end,

  onMenuEditor = function(self, menu, editor, event)
    menu:AppendSeparator()
    menu:Append(id, "Select colour to insert"..KSC(id))
  end
}
