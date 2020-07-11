local id = ID("love2dcolourpicker.insertlovecolour")
local function insertcolour(event)
  local editor = ide:GetEditor()
  if not editor then return end
  local rgb = editor:GetSelectedText():match("(%d+,%s*%d+,%s*%d+)")
  local colour = wx.wxColour(rgb and "rgb("..rgb..")" or wx.wxBLACK)
  local newcolour = wx.wxGetColourFromUser(ide:GetMainFrame(), colour)
  if newcolour:Ok() then -- user selected some colour
    local newtext = string.format("{ %d/255, %d/255, %d/255 }", tonumber(newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("(%d+),%s*%d+,%s*%d+")), tonumber(newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("%d+,%s*(%d+),%s*%d+")), tonumber(newcolour:GetAsString(wx.wxC2S_CSS_SYNTAX):match("%d+,%s*%d+,%s*(%d+)")))
    ide:GetEditor():ReplaceSelection(newtext) 
  end
end
return {
  name = "Love2D Colour Picker",
  description = "Fork of Colour Picker plugin by Paul Kulchenko. Changes what gets printed out to match the newer versions of how Love2D reads colors. Includes removing hexadecimal support and RGB conversion to 0-1 instead of 0-255",
  author = "vyraefi",
  version = 0.1,
  dependencies = "1.0",

  onRegister = function()
    local menu = ide:FindTopMenu("&View")
    menu:Append(id, "Love2D Colour Picker Window"..KSC(id))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, insertcolour)
  end,
  onUnRegister = function()
    ide:RemoveMenuItem(id)
  end,

  onMenuEditor = function(self, menu, editor, event)
    menu:AppendSeparator()
    menu:Append(id, "Insert Love2D Colour"..KSC(id))
  end
}
