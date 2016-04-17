local clones = {}
return {
  name = "Clone view",
  description = "Clones the current editor tab.",
  author = "Paul Kulchenko",
  version = 0.14,
  dependencies = 0.96,

  -- release document pointer for closed tabs
  -- remove from the list of clones (in either direction) this closed editor
  onEditorClose = function(self, editor)
    if not clones[editor] then return end

    if clones[editor].pointer then
      clones[editor].editor:ReleaseDocument(clones[editor].pointer)
    end
    -- remove the editor this one clones from the list of clones
    clones[clones[editor].editor] = nil
    -- now remove this editor from the list of clones
    clones[editor] = nil
  end,

  -- mark the other document as not modified when the clone is saved (either one)
  onEditorSave = function(self, editor)
    if not clones[editor] then return end

    local doc1, doc2 = ide:GetDocument(editor), ide:GetDocument(clones[editor].editor)
    doc2:SetModified(false)
    doc2.modTime = doc1:GetModTime() -- TODO: replace with SetModTime when 1.40 is released
  end,

  onMenuEditorTab = function(self, menu, notebook, event, index)
    local idvert = ID(self.fname..".clone.vert")
    local idhorz = ID(self.fname..".clone.horz")

    local cloner = function(event)
      local e1 = ide:GetEditor(index)
      local e2 = NewFile(ide:GetDocument(e1):GetTabText())
      local docpointer = e1:GetDocPointer()
      e1:AddRefDocument(docpointer)
      clones[e2] = {editor = e1, pointer = docpointer}
      clones[e1] = {editor = e2}
      e2:SetDocPointer(docpointer)
      ide:GetEditorNotebook():Split(notebook:GetSelection(),
        event:GetId() == idhorz and wx.wxRIGHT or wx.wxBOTTOM)
      notebook:SetSelection(index)
      local doc1, doc2 = ide:GetDocument(e1), ide:GetDocument(e2)
      doc2:SetModified(doc1:IsModified())
      doc2.filePath = doc1:GetFilePath() -- TODO: replace with GetFilePath when 1.40 is released
    end

    local cloned = clones[ide:GetEditor(index)]
    menu:AppendSeparator()
    menu:Append(idhorz, "Clone Horizontally")
    menu:Append(idvert, "Clone Vertically")
    -- disable if this editor already has a clone
    menu:Enable(idhorz, not cloned)
    menu:Enable(idvert, not cloned)
    notebook:Connect(idvert, wx.wxEVT_COMMAND_MENU_SELECTED, cloner)
    notebook:Connect(idhorz, wx.wxEVT_COMMAND_MENU_SELECTED, cloner)
  end,
}
