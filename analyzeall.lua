local G = ...
local id = G.ID("analyzeall.analyzeall")
local menuid

local function analyzeProject()
  local frame = ide:GetMainFrame()
  local menubar = ide:GetMenuBar()
  if menubar:IsChecked(ID_CLEAROUTPUT) then ClearOutput() end
  DisplayOutputLn("Analyzing the project code.")
  frame:Update()

  local errors, warnings = 0, 0
  local projectPath = ide:GetProject()
  if projectPath then
    for _, filePath in ipairs(FileSysGetRecursive(projectPath, true, "*.lua")) do
      local warn, err, line = AnalyzeFile(filePath)
      if err then
        DisplayOutputNoMarker(filePath..'('..line..'): '..err.."\n")
        errors = errors + 1
      elseif #warn > 0 then
        DisplayOutputNoMarker(table.concat(warn, "\n") .. "\n")
        warnings = warnings + #warn
      end
      frame:Update() -- refresh the output with new results
    end
  end

  DisplayOutputLn(("%s error%s and %s warning%s."):format(
    errors > 0 and errors or 'no', errors == 1 and '' or 's',
    warnings > 0 and warnings or 'no', warnings == 1 and '' or 's'
  ))
end

return {
  name = "Analyze all files",
  description = "Analyzes all files in a project.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Project")))
    local _, analyzepos = ide:FindMenuItem(menu, ID_ANALYZE)
    if analyzepos then
      menu:Insert(analyzepos+1, id, TR("Analyze All")..KSC(id), TR("Analyze the project source code"))
    end
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, analyzeProject)
  end,

  onUnRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Project")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxEVT_COMMAND_MENU_SELECTED)
    if menuid then menu:Destroy(menuid) end
  end,
}
