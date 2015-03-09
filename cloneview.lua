local clones = {}
return {
  name = "Clone view",
  description = "Clones the current editor tab.",
  author = "Paul Kulchenko",
  version = 0.13,
  dependencies = 0.96,

  -- don't offer to save cloned tabs
  onEditorPreSave = function(self, editor, filepath)
    if clones[editor] then
      -- save the original document
      ide:GetDocument(clones[editor].editor):Save()
      return false -- don't save the clone
    end
  end,

  -- release document pointer for closed tabs
  onEditorClose = function(self, editor)
    if clones[editor] then
      clones[editor].editor:ReleaseDocument(clones[editor].pointer)
      clones[editor] = nil
    end
  end,

  onMenuEditorTab = function(self, menu, notebook, event, index)
    local idvert = ID(self.fname..".clone.vert")
    local idhorz = ID(self.fname..".clone.horz")

    local cloner = function(event)
      local e1 = ide:GetEditor(index)
      local e2 = NewFile("clone: "..ide:GetDocument(e1):GetTabText())
      local docpointer = e1:GetDocPointer()
      e1:AddRefDocument(docpointer)
      clones[e2] = {editor = e1, pointer = docpointer}
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
