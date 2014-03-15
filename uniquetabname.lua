local sep = GetPathSeparator()
local function makeUnique(exeditor)
  local docs = {}
  for id, doc in pairs(ide:GetDocuments()) do
    if doc:GetEditor() ~= exeditor and doc:GetFileName() and doc:GetFilePath() then
      local fn = doc:GetFileName()
      docs[fn] = docs[fn] or {}
      table.insert(docs[fn], {doc = doc, parts = wx.wxFileName(doc:GetFilePath()):GetDirs()})
    end
  end

  while true do
    local updated = false
    for fn, tabs in pairs(docs) do
      if #tabs > 1 then -- conflicting name
        updated = true
        docs[fn] = nil
        for _, tab in ipairs(tabs) do
          local fn = (table.remove(tab.parts) or '?').. sep .. fn
          docs[fn] = docs[fn] or {}
          table.insert(docs[fn], tab)
        end
      end
    end
    if not updated then break end
  end

  -- update all labels as some might have lost their conflicts
  for fn, tabs in pairs(docs) do
    for _, tab in ipairs(tabs) do tab.doc:SetTabText(fn) end end
end

return {
  name = "Unique tabname",
  description = "Updates editor tab names to always stay unique.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = function(self) makeUnique() end,
  onEditorSave = function(self) makeUnique() end,
  onEditorClose = function(self, editor) makeUnique(editor) end,
  onAppClose = function(self, app)
    -- restore "original" names back before saving configuration
    for _, doc in pairs(ide:GetDocuments()) do
      if doc:GetFileName() then doc:SetTabText(doc:GetFileName()) end
    end
  end
}
