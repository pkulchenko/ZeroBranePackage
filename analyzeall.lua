-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local G = ...
local id = G.ID("analyzeall.analyzeall")

local function path2mask(s)
  return s
    :gsub('([%(%)%.%%%+%-%?%[%^%$%]])','%%%1') -- escape all special symbols
    :gsub("%*", ".*") -- but expand asterisk into sequence of any symbols
    :gsub("[\\/]","[\\\\/]") -- allow for any path
end

local function analyzeProject(self)
  local frame = ide:GetMainFrame()
  local menubar = ide:GetMenuBar()
  if menubar:IsChecked(ID_CLEAROUTPUT) then ClearOutput() end
  DisplayOutputLn("Analyzing the project code.")
  frame:Update()

  local errors, warnings = 0, 0
  local projectPath = ide:GetProject()
  if projectPath then
    local specs = self:GetConfig().ignore or {}
    local masks = {}
    for i in ipairs(specs) do masks[i] = "^"..path2mask(specs[i]).."$" end
    for _, filePath in ipairs(FileSysGetRecursive(projectPath, true, "*.lua")) do
      local checkPath = filePath:gsub(projectPath, "")
      local ignore = false
      for _, spec in ipairs(masks) do
        ignore = ignore or checkPath:find(spec)
      end
      if not ignore then
        local warn, err, line = AnalyzeFile(filePath)
        if err then
          DisplayOutputNoMarker(err .. "\n")
          errors = errors + 1
        elseif #warn > 0 then
          DisplayOutputNoMarker(table.concat(warn, "\n") .. "\n")
          warnings = warnings + #warn
        end
        ide:Yield() -- refresh the output with new results
      end
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
  version = 0.4,
  dependencies = 0.71,

  onRegister = function(package)
    local _, menu, analyzepos = ide:FindMenuItem(ID_ANALYZE)
    if menu then
      menu:Insert(analyzepos+1, id, TR("Analyze All")..KSC(id), TR("Analyze the project source code"))
      menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function() return analyzeProject(package) end)
    end
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
