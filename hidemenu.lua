local oldmenu
local menuIsShown = false

local function hideMenu()
  menuIsShown = false
  oldmenu = ide.frame.menuBar
  ide.frame:SetMenuBar(wx.wxMenuBar(0))
end

local function showMenu()
  menuIsShown = true
  ide.frame:SetMenuBar(oldmenu)
end

return {
  name = "Hide menu",
  description = "Hides the menubar.",
  author = "David Krawiec",
  version = 0.1,

  onAppLoad = function(package)
    hideMenu()
  end,
  
  onEditorKeyDown = function(self, editor, event)
    local key = event:GetKeyCode()
    local mod = event:GetModifiers()
    if (key == wx.WXK_ALT and menuIsShown == false) then
        showMenu()
    elseif (key == wx.WXK_ALT and menuIsShown == true) then
        hideMenu()
    end
  end,
}
