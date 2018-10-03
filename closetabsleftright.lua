return {
  name = "Close tabs left and right",
  description = "Closes editor tabs to the left and to the right of the current one.",
  author = "Paul Kulchenko",
  version = 0.12,
  dependencies = "1.60",

  onMenuEditorTab = function(self, menu, notebook, event, index)
    local idleft = ID(self.fname..".left")
    local idright = ID(self.fname..".right")

    menu:AppendSeparator()
    menu:Append(idleft, "Close All on Left")
    menu:Append(idright, "Close All on Right")
    menu:Enable(idleft, index > 0)
    menu:Enable(idright, index < notebook:GetPageCount()-1)
    notebook:Connect(idleft, wx.wxEVT_COMMAND_MENU_SELECTED, function()
        for _ = 0, index-1 do
          if not ide:GetDocument(notebook:GetPage(0)):Close() then break end
        end
      end)
    notebook:Connect(idright, wx.wxEVT_COMMAND_MENU_SELECTED, function()
        for _ = index+1, notebook:GetPageCount()-1 do
          if not ide:GetDocument(notebook:GetPage(index+1)):Close() then break end
        end
      end)
  end,
}
