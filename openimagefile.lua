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
    Name("openimagefile"):CaptionVisible(true):Caption(('(%d x %d) %s'):format(width, height, name)):
    Float(true):MinSize(width,height):BestSize(width,height):FloatingSize(width,height):
    PaneBorder(false):CloseButton(true):MaximizeButton(false):PinButton(false))
  mgr:Update()
  return true
end

return {
  name = "Open image file",
  description = "Opens image file from the file tree.",
  author = "Paul Kulchenko",
  version = 0.3,
  dependencies = 1.0,

  onFiletreeActivate = function(self, tree, event, item)
    if not item then return end
    if fileShow(tree:GetItemFullName(item)) then return false end
  end,

  onMenuFiletree = function(self, menu, tree, event)
    local item_id = event:GetItem()
    local name = tree:GetItemFullName(item_id)
    local width, height = fileMeta(name)
    if not width or not height then return end

    local id = ID(self.fname .. ".openimage")
    menu:AppendSeparator()
    menu:Append(id, ("Open Image (%d x %d)"):format(width, height))
    tree:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function() fileShow(name) end)
  end,
}
