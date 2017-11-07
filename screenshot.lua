local id = ID("screenshot.takeit")

local function fileLoad(file)
  local f = FileRead(file)
  if not f then return end
  local fstream = wx.wxMemoryInputStream.new(f, #f)
  local log = wx.wxLogNull()
  local image = wx.wxImage()
  local loaded = image:LoadFile(fstream)
  return loaded and image or nil
end

local function fileMeta(name)
  local image = fileLoad(name)
  if not image then return end

  return image:GetWidth(), image:GetHeight()
end

local function fileShow(name)
  local image = fileLoad(name)
  if not image then return end

  local panel = wx.wxPanel(ide:GetMainFrame(), wx.wxID_ANY,
    wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxFULL_REPAINT_ON_RESIZE)
  panel:Connect(wx.wxEVT_PAINT, function()
      local dc = wx.wxPaintDC(panel)
      dc:DrawBitmap(wx.wxBitmap(image), 0, 0, true)
      dc:delete()
    end)

  local width, height = image:GetWidth(), image:GetHeight()
  local mgr = ide:GetUIManager()
  mgr:AddPane(panel, wxaui.wxAuiPaneInfo():
    Name("screenshot"):CaptionVisible(true):Caption(('(%d x %d) %s'):format(width, height, name)):
    Float(true):MinSize(width,height):BestSize(width,height):FloatingSize(width,height):
    PaneBorder(false):CloseButton(true):MaximizeButton(false):PinButton(false))
  mgr:Update()
  return true
end

local function takeScreenshot(file)
  file = file or ("screenshot-%s.png"):format(os.date():gsub(" ","T"):gsub("[/:]",""))
  local win = ide:GetMainFrame()
  local topleft = win:GetPosition()
  local winDC = wx.wxWindowDC(win)
  local width, height = winDC:GetSize()
  local bitmap = wx.wxBitmap(width, height, -1)
  local scrDC = wx.wxScreenDC()
  local memDC = wx.wxMemoryDC()
  memDC:SelectObject(bitmap)
  memDC:Blit(0, 0, width, height, scrDC, topleft:GetX(), topleft:GetY())
  memDC:SelectObject(wx.wxNullBitmap)

  local path = ide:MergePath(wx.wxStandardPaths.Get():GetUserDir(wx.wxStandardPaths.Dir_Pictures), file)
  bitmap:SaveFile(path, wx.wxBITMAP_TYPE_PNG)
  return path
end

local timer
local delay

local function takeDelayedScreenshot()
  if not delay then delay = 5 end
  if timer then
    if delay > 0 then
      ide:SetStatus(delay.."...")
      delay = delay - 1
      timer:Start(1000, wx.wxTIMER_ONE_SHOT)
      return
    else
      delay = nil
      ide:SetStatus("")
    end
  end
  fileShow(takeScreenshot())
end

return {
  name = "Screenshot",
  description = "Takes a delayed screenshot of the application window and saves it into a file.",
  author = "Paul Kulchenko",
  version = 0.11,
  dependencies = "1.61",

  onRegister = function()
    local menu = ide:FindTopMenu("&View")
    menu:Append(id, "Take Screenshot"..KSC(id))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, takeDelayedScreenshot)
    timer = ide:AddTimer(ide:GetMainFrame(), takeDelayedScreenshot)
  end,
  onUnRegister = function()
    ide:RemoveMenuItem(id)
  end,
}
