return {
  name = "Clone view",
  description = "Clones the current editor tab.",
  author = "Paul Kulchenko",
  version = 0.11,

  onMenuEditorTab = function(self, menu, notebook, event, index)
    local idvert = ID(self.fname..".clone.vert")
    local idhorz = ID(self.fname..".clone.horz")

    local cloner = function(event)
      local e1 = ide:GetEditor(index)
      local e2 = NewFile("clone: "..ide:GetDocument(e1):GetFileName())
      local docpointer = e1:GetDocPointer()
      e2:SetDocPointer(docpointer)
      ide:GetEditorNotebook():Split(notebook:GetSelection(),
        event:GetId() == idhorz and wx.wxRIGHT or wx.wxBOTTOM)
      notebook:SetSelection(index)
    end

    menu:AppendSeparator()
    menu:Append(idhorz, "Clone Horizontally")
    menu:Append(idvert, "Clone Vertically")
    notebook:Connect(idvert, wx.wxEVT_COMMAND_MENU_SELECTED, cloner)
    notebook:Connect(idhorz, wx.wxEVT_COMMAND_MENU_SELECTED, cloner)
  end,
}
