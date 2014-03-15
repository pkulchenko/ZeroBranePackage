local tool
return {
  name = "Livecoding toolbar button",
  description = "Adds livecoding toolbar button.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local tb = ide:GetToolBar()
    local pos = tb:GetToolPos(ID_STARTDEBUG)
    tool = tb:InsertTool(pos+1, ID_RUNNOW, "Run as Scratchpad", wx.wxBitmap({
      "16 16 4 1",
      "       c None",
      ".      c black",
      "X      c #808080",
      "o      c white",
      "                ",
      "  ..            ",
      " .Xo.    ...    ",
      " .Xoo. ..oo.    ",
      " .Xooo.Xooo...  ",
      " .Xooo.oooo.X.  ",
      " .Xooo.Xooo.X.  ",
      " .Xooo.oooo.X.  ",
      " .Xooo.Xooo.X.  ",
      " .Xooo.oooo.X.  ",
      "  .Xoo.Xoo..X.  ",
      "   .Xo.o..ooX.  ",
      "    .X..XXXXX.  ",
      "    ..X.......  ",
      "     ..         ",
      "                "}), wx.wxBitmap(), wx.wxITEM_CHECK)
    tb:Realize()
  end,

  onUnRegister = function(self)
    local tb = ide:GetToolBar()
    tb:DeleteTool(tool)
    tb:Realize()
  end,
}
