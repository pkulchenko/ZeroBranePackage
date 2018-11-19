local oldmenu
local nobar = wx.wxMenuBar(0)

local function hideMenu()
  oldmenu = oldmenu or ide:GetMenuBar()
  ide:GetMainFrame():SetMenuBar(nobar)
end

local function showMenu()
  ide:GetMainFrame():SetMenuBar(oldmenu)
end

return {
  name = "Hide menu",
  description = "Hides the menubar.",
  author = "David Krawiec",
  version = 0.2,
  dependencies = "1.60",

  onAppLoad = function(package)
    hideMenu()
  end,
  
  onEditorKeyDown = function(self, editor, event)
    local key = event:GetKeyCode()
    if (key == wx.WXK_ALT and ide:GetMainFrame():GetMenuBar() == nobar) then
        showMenu()
    elseif (key == wx.WXK_ALT and ide:GetMainFrame():GetMenuBar() ~= nobar) then
        hideMenu()
    end
  end,
}
