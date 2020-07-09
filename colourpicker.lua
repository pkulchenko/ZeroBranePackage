local id = ID("colourpicker.insertcolour")
local function insertcolour(event)
  local editor = ide:GetEditor()
  if not editor then return end
  local rgb = editor:GetSelectedText():match("(%d+,%s*%d+,%s*%d+)")
  local colour = wx.wxColour(rgb and "rgb("..rgb..")" or wx.wxBLACK)
  local newcolour = wx.wxGetColourFromUser(ide:GetMainFrame(), colour)
  if newcolour:Ok() then -- user selected some colour
    local newtext
    if editor:GetCharAt(editor:GetCurrentPos()-1) == string.byte('x') then
      editor:DeleteRange(editor:GetCurrentPos()-1, 1)
      newtext = newcolour:GetAsString(wx.wxC2S_HTML_SYNTAX):match("%x+%x+%x+") or ""
      ide:GetEditor():AddText(newtext)
    elseif editor:GetCharAt(editor:GetCurrentPos()-1) == string.byte('f')
        then  -- normalized float format, used by love.graphics from version 11
      editor:DeleteRange(editor:GetCurrentPos()-1, 1)
      local rgb = newcolour:GetRGB()
      local blue = math.floor(rgb / 16^4)
      local green = math.floor(rgb/16^2 - blue*16^2)
      local red = math.floor(rgb - green*16^2 - blue*16^4)
      newtext = string.format("%f, %f, %f", red/255, green/255, blue/255)
      ide:GetEditor():AddText(newtext)
    else
      newtext = newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("%d+,%s*%d+,%s*%d+") or ""
      ide:GetEditor():ReplaceSelection(newtext)
    end
  end
end

return {
  name = "Colour picker",
  description = "Selects color to insert in the document.",
  author = "Paul Kulchenko",
  version = 0.23,
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
