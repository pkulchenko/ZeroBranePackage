local id = ID("colourpicker.insertcolour")
local function insertcolour(event)
  local editor = ide:GetEditor()
  if not editor then return end
  local rgb = editor:GetSelectedText():match("(%d+,%s*%d+,%s*%d+)")
  local colour = wx.wxColour(rgb and "rgb("..rgb..")" or wx.wxBLACK)
  local newcolour = wx.wxGetColourFromUser(ide:GetMainFrame(), colour)
  if newcolour:Ok() then -- user selected some colour
    if editor:GetCharAt(editor:GetCurrentPos()-1) == 120 then
      editor:DeleteRange(editor:GetCurrentPos()-1, 1)
      local newtext2 = newcolour:GetAsString(wx.wxC2S_HTML_SYNTAX):match("%x+%x+%x+") or ""
      ide:GetEditor():AddText(newtext2)
    else
      local newtext = newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("%d+,%s*%d+,%s*%d+") or ""
      ide:GetEditor():ReplaceSelection(newtext)
    end
  end
end

return {
  name = "Colour picker",
  description = "Select color to insert in the document",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.0",

  onRegister = function()
    local menu = ide:FindTopMenu("&View")
    menu:Append(id, "Colour Picker Window"..KSC(id))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, insertcolour)
  end,
  onUnRegister = function()
    ide:RemoveMenuItem(id)
  end,

  onMenuEditor = function(self, menu, editor, event)
    menu:AppendSeparator()
    menu:Append(id, "Insert Colour"..KSC(id))
  end
}
