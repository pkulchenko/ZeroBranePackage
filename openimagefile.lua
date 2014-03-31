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

  local width, height = image:GetWidth(), image:GetHeight()
  local screenSizeX, screenSizeY = wx.wxDisplaySize()
  local frame = wx.wxFrame(
    wx.NULL,
    wx.wxID_ANY,
    ('(%d x %d) %s'):format(width, height, name),
    wx.wxDefaultPosition,
    wx.wxSize(width, height),
    wx.wxDEFAULT_FRAME_STYLE + wx.wxSTAY_ON_TOP
    - wx.wxRESIZE_BORDER - wx.wxMAXIMIZE_BOX)
  frame:SetClientSize(width, height)
  frame:Centre()

  local function OnPaint()
    local dc = wx.wxPaintDC(frame)
    dc:DrawBitmap(wx.wxBitmap(image), 0, 0, true)
    dc:delete()
  end

  frame:Connect(wx.wxEVT_PAINT, OnPaint)
  frame:Show(true)

  return false
end

return {
  name = "Open image file",
  description = "Opens image file from the file tree.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = 0.51,

  onFiletreeActivate = function(self, tree, event, item)
    if not item then return end
    return fileShow(tree:GetItemFullName(item))
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
