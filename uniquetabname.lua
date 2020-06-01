local sep = GetPathSeparator()
local function makeUnique(exeditor)
  local docs = {}
  for id, doc in pairs(ide:GetDocuments()) do
    if doc:GetEditor() ~= exeditor and doc:GetFileName() and doc:GetFilePath() then
      local fn = doc:GetFileName()
      local fpath = doc:GetFilePath()
      local uniquepath = true
      if docs[fn] then
        for _, tab in pairs(docs[fn]) do
          if tab.path == fpath then uniquepath = false end
        end
      end
      -- only count duplicates if they are for different paths
      -- this excludes clones and other situations when the paths match
      if uniquepath then
        docs[fn] = docs[fn] or {}
        table.insert(docs[fn], {doc = doc, path = fpath, parts = wx.wxFileName(doc:GetFilePath()):GetDirs()})
      end
    end
  end

  while true do
    local updated = false
    local newdocs = {}
    for fn, tabs in pairs(docs) do
      if #tabs > 1 then -- conflicting name
        updated = true
        newdocs[fn] = nil
        for _, tab in ipairs(tabs) do
          local fn = (table.remove(tab.parts) or '?') .. sep .. fn
          if not docs[fn] then
            newdocs[fn] = newdocs[fn] or {}
            table.insert(newdocs[fn], tab)
          end
        end
      end
    end
    if not updated then break end
    docs = newdocs
  end

  -- update all labels as some might have lost their conflicts
  for fn, tabs in pairs(docs) do
    for _, tab in ipairs(tabs) do tab.doc:SetTabText(fn) end end
end

return {
  name = "Unique tabname",
  description = "Updates editor tab names to always stay unique.",
  author = "Paul Kulchenko",
  version = 0.2,

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
