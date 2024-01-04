-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local id = ID("analyzeall.analyzeall")

local function pathEscape(s)
  return s
    :gsub('([%(%)%.%%%+%-%?%[%^%$%]])','%%%1') -- escape all special symbols
    :gsub("[\\/]","[\\\\/]") -- allow for any path
end

local function path2mask(s)
  return pathEscape(s)
    :gsub("%*", ".*") -- expand asterisk into sequence of any symbols
end

local function analyzeProject(self)
  local frame = ide:GetMainFrame()
  ide:GetOutput():Erase()
  ide:Print("Analyzing the project code.")
  frame:Update()

  local errors, warnings = 0, 0
  local projectPath = ide:GetProject()
  if projectPath then
    local projectMask = pathEscape(projectPath)
    local specs = self:GetConfig().ignore or {}
    local masks = {}
    for i in ipairs(specs) do masks[i] = "^"..path2mask(specs[i]).."$" end
    for _, filePath in ipairs(ide:GetFileList(projectPath, true, "*.lua")) do
      local checkPath = filePath:gsub(projectMask, "")
      local ignore = false
      for _, spec in ipairs(masks) do
        ignore = ignore or checkPath:find(spec)
      end
      if not ignore then
        local warn, err = ide:AnalyzeFile(filePath)
        if err then
          ide:Print(err)
          errors = errors + 1
        elseif #warn > 0 then
          for _, msg in ipairs(warn) do ide:Print(msg) end
          warnings = warnings + #warn
        end
        ide:Yield() -- refresh the output with new results
      end
    end
  end

  ide:Print(("%s error%s and %s warning%s."):format(
    errors > 0 and errors or 'no', errors == 1 and '' or 's',
    warnings > 0 and warnings or 'no', warnings == 1 and '' or 's'
  ))
end

return {
  name = "Analyze all files",
  description = "Analyzes all files in a project.",
  author = "Paul Kulchenko",
  version = 0.44,
  dependencies = "1.7",

  onRegister = function(package)
    local _, menu, analyzepos = ide:FindMenuItem(ID.ANALYZE)
    if menu then
      menu:Insert(analyzepos+1, id, TR("Analyze All")..KSC(id), TR("Analyze the project source code"))
      menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function() return analyzeProject(package) end)
    end
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
