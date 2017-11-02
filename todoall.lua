-- Copyright 2017 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- Contributed by Chronos Phaenon Eosphoros (@cpeosphoros)
--
-- Some code taken from those plugins:
-- todo.lua:
-- 	Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- 	Contributed by Mark Fainstein
-- analyzeall.lua:
-- 	Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved
--
--
-- In your system or user config/preferences file, you can set the tokens
-- used by this package...
--
-- Example: 
--
-- todoall = { 
--   patterns = { { name = "TODO",  pattern = "%-%-TODO[%s:;>]"  },
--                { name = "FIXME", pattern = "%-%-FIXME[%s:;>]" },
--                { name = "WTF",   pattern = "%-%-WTF[%s:;>]"   }
--              }
-- } 
--

local id = ID("TODOAllpanel.referenceview")
local TODOpanel = "TODOAllpanel"
local refeditor
local spec = {iscomment = {}}

local function path2mask(s)
  return s
  :gsub('([%(%)%.%%%+%-%?%[%^%$%]])','%%%1') -- escape all special symbols
  :gsub("%*", ".*") -- but expand asterisk into sequence of any symbols
  :gsub("[\\/]","[\\\\/]") -- allow for any path
end

local fileTasks
local patterns = {}

local function mapTODOS(fileName, text)
  local tasks = {}
  for _, pattern in ipairs(patterns) do
    local first = false
    local i = 0
    while true do
      --find next todo index
      i = string.find(text, pattern.pattern, i+1)
      if i == nil then
        break
      end
      local j = string.find(text, "\n",i+1)
      local taskStr
      taskStr = string.sub(text, i+3+#pattern.name, j)
      if first == false then
        first = true
        tasks[#tasks+1] = {pos = -1, str = pattern.name .. "s\n"}
        tasks[#tasks+1] = {pos = i,  str = taskStr}
      else
        tasks[#tasks+1] = {pos = i,  str = taskStr}
      end
    end
  end
  fileTasks[fileName] = tasks
end

local function readfile(filePath)
  local input = io.open(filePath)
  local data = input:read("*a")
  input:close()
  return data
end

local function sortedKeys(tbl)
  local sorted = {}
  for k, _ in pairs (tbl) do
    table.insert(sorted, k)
  end
  table.sort(sorted)
  return sorted
end

local projectPath

local function fileNameFromPath(filePath)
  return filePath:gsub(projectPath, "")
end

-- main function, called on project load and on new char in editor
local function mapProject(self, editor)
  local specs = self:GetConfig().ignore or {}
  if editor then
    mapTODOS(fileNameFromPath(ide:GetDocument(editor):GetFilePath()), editor:GetText())
  else
    local masks = {}
    for i in ipairs(specs) do masks[i] = "^"..path2mask(specs[i]).."$" end
    for _, filePath in ipairs(FileSysGetRecursive(projectPath, true, "*.lua")) do
      local fileName = fileNameFromPath(filePath)
      local ignore = false or editor
      for _, spec in ipairs(masks) do
        ignore = ignore or fileName:find(spec)
      end
      -- TODO: testing here
      if not ignore then
        mapTODOS(fileName, readfile(filePath))
      end
    end
  end
  
  local files = sortedKeys(fileTasks)
  local tasksListStr = "Project Tasks: \n\n"
  local lineCounter = 2
  local positions = {}
  
  local function insertLine(line, pos, file)
    tasksListStr = tasksListStr .. line
    lineCounter = lineCounter + 1
    if pos then
      positions[lineCounter] = {pos = pos, file = file}
    end
  end
  
  local fileDispText = ""
  local displayLengthLimit = 30 -- truncate file name to this length
  for _, file in ipairs(files) do
    local tasks = fileTasks[file]
    if tasks and #tasks ~= 0 then
      if #file >= displayLengthLimit then
        fileDispText = "~" .. file:sub(-displayLengthLimit)
      else
        fileDispText = file
      end
      insertLine(fileDispText .. ":\n", 1, file)
      local counter = 1
      for _, taskStr in ipairs(tasks) do
        if taskStr.pos ~= -1 then
          insertLine(counter.."." ..taskStr.str, taskStr.pos, file)
          counter = counter + 1
        else
          insertLine(taskStr.str)
          counter = 1
        end
      end
      insertLine("\n")
    end
  end
  
  refeditor:SetReadOnly(false)
  refeditor:SetText(tasksListStr)
  refeditor:SetReadOnly(true)

  --On click of a task, go to relevant position in the text
  refeditor:Connect(wxstc.wxEVT_STC_DOUBLECLICK, function()
      local line = refeditor:GetCurrentLine()+1
      local position = positions[line]
      if not position then return end
      local filePath = projectPath .. position.file
      local docs = ide:GetDocuments()

      local editor
      for _, doc in ipairs(docs) do
        if doc:GetFilePath() == filePath then
          editor = doc:GetEditor()
          break
        end
      end
      if not editor then
        editor = ide:LoadFile(filePath)
        if not editor then error("Couldn't load " .. filePath) end
      end
      editor:GotoPosEnforcePolicy(position.pos - 1)
      if not ide:GetEditorWithFocus(editor) then ide:GetDocument(editor):SetActive() end
    end)
end

return {
  name = "Show project-wise TODO panel",
  description = "Adds a project-wise panel for showing a tasks list.",
  author = "Chronos Phaenon Eosphoros",
  version = 0.2,
  dependencies = 1.60,

  onRegister = function(self)
    patterns = self:GetConfig().patterns 
    if not patterns or not next(patterns) then
       patterns = { { name = "TODO",  pattern = "%-%-TODO[%s:;>]" },
                    { name = "FIXME", pattern = "%-%-FIXME[%s:;>]" }
                  }
    end

    local e = ide:CreateBareEditor()
    refeditor = e

    local w, h = 250, 250
    local conf = function(pane)
      pane:Dock():MinSize(w,-1):BestSize(w,-1):FloatingSize(w,h)
    end
    local layout = ide:GetSetting("/view", "uimgrlayout")

    --if ide:IsPanelDocked(TODOpanel) then
    if not layout or not layout:find(TODOpanel) then
      ide:AddPanelDocked(ide.frame.projnotebook, e, TODOpanel, TR("PTasks"), conf)
    else
      ide:AddPanel(e, TODOpanel, TR("Tasks"), conf)
    end

    do -- markup handling in the reference panel
      -- copy some settings from the lua spec
      for _, s in ipairs({'lexer', 'lexerstyleconvert'}) do
        spec[s] = ide.specs.lua[s]
      end
      -- this allows the markup to be recognized in all token types
      for i = 0, 16 do spec.iscomment[i] = true end
      e:Connect(wxstc.wxEVT_STC_UPDATEUI, function() MarkupStyle(e,0,e:GetLineCount()) end)
    end

    e:SetReadOnly(true)
    e:SetWrapMode(wxstc.wxSTC_WRAP_WORD)
    e:SetupKeywords("lua",spec,ide:GetConfig().styles,ide:GetOutput():GetFont())

    -- remove all margins
    for m = 0, 4 do e:SetMarginWidth(m, 0) end

    -- disable dragging to the panel
    e:Connect(wxstc.wxEVT_STC_DO_DROP, function(event) event:SetDragResult(wx.wxDragNone) end)

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Project")))

    menu:InsertCheckItem(4, id, TR("Tasks List")..KSC(id))

    menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function ()
        local uimgr = ide:GetUIManager()
        uimgr:GetPane(TODOpanel):Show(not uimgr:GetPane(TODOpanel):IsShown())
        uimgr:Update()
      end)

    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function (event)
        local pane = ide:GetUIManager():GetPane(TODOpanel)
        menu:Enable(event:GetId(), pane:IsOk()) -- disable if doesn't exist
        menu:Check(event:GetId(), pane:IsOk() and pane:IsShown())
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,

  onProjectLoad = function(self, project)
    fileTasks = {}
    projectPath = project
    mapProject(self)
  end,

  onEditorCharAdded = function(self, editor) --, event)
    mapProject(self, editor)
  end
}
