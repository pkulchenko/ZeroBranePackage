-- Copyright 2017 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- Contributed by Chronos Phaenon Eosphoros (@cpeosphoros)
-- Enhanced by Paul Reilly, inc borrowing Mark Fainstein's new  
-- pattern matching from todo.lua
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
-- used by this package and the beginning of paths relative to the 
-- project path to ignore...
--
-- Example: 
--
-- todoall = { 
--     ignore = { "Export" },
--   patterns = { { name = "TODO",  pattern = "TODO[:;>]"  },
--                { name = "FIXME", pattern = "FIXME[:;>]" },
--                { name = "WTF",   pattern = "WTF[:;>]"   }
--              }
-- } 
--
-- This will ignore all files in eg PROJECTPATH/Export Android/
--
-- Note: spaces in the patterns create issues (inc %s)
--
-- Tests:
--    TODO: this is a test TODO with more than one TODO to ignore
--    FIXME: this is a test FIXME too
--    this next one should also be a TODO> #2 TODO check
--

local id = ID("TODOAllpanel.referenceview")
local TODOpanel = "TODOAllpanel"
local refeditor
local spec = {iscomment = {}}
local projectLoaded = false

local function path2mask(s)
  return s
  :gsub('([%(%)%.%%%+%-%?%[%^%$%]])','%%%1') -- escape all special symbols
  :gsub("%*", ".*") -- but expand asterisk into sequence of any symbols
  :gsub("[\\/]","[\\\\/]") -- allow for any path
end

local fileTasks
local patterns = {}

local function mapTODOS(fileName, text, isTextRawFile)
  local tasks = {}
  for _, pattern in ipairs(patterns) do
    local first = false
    local i = 0
    local numLines = 0
    while true do
      --find next todo index
      local pos = i
      i = string.find(text, pattern.pattern, i+1)
      
      if i == nil then
        break
      end
      
      -- there's a difference in file lengths with lua file reading and
      -- wx editor length, so if it's a file read adjust for line endings
      local adj = 0
      local nl = string.find(text, "\n", pos + 1)
      -- handle end of file when no more newlines
      if nl == nil then nl = #text end
      if isTextRawFile then
        while nl < i do
          numLines = numLines + 1
          nl = string.find(text, "\n", nl+1)
          if nl == nil then nl = #text end
        end
        adj = numLines
      end
      
      local j = string.find(text, "\n",i+1)
      if j == nil then j = #text end --  handle EOF
      local taskStr
      -- 1 is for the extra char after the task name
      taskStr = string.sub(text, i+1+#pattern.name, j)
      if j == #text and isTextRawFile then taskStr = taskStr .. "\n" end -- add newline if EOF
      if first == false then
        first = true
        tasks[#tasks+1] = {pos = -1, str = pattern.name .. "s\n"}
        tasks[#tasks+1] = {pos = i + adj,  str = taskStr}
      else
        tasks[#tasks+1] = {pos = i + adj,  str = taskStr}
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
    -- ignore paths that start with our path masks set in config
    -- table todoall.ignore
    for i in ipairs(specs) do masks[i] = "^"..path2mask(specs[i]) end
    for _, filePath in ipairs(FileSysGetRecursive(projectPath, true, "*.lua")) do
      local fileName = fileNameFromPath(filePath)
      local ignore = false or editor
      for _, spec in ipairs(masks) do
        -- ignore only if it's not just the beginning of a filename
        ignore = ignore or (fileName:find(spec) and fileName:find("[\\/]"))
      end
      if not ignore then
        local f = readfile(filePath)
        mapTODOS(fileName, readfile(filePath), true)
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

  --On double click of a task, go to relevant position in the text
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
      refeditor:SetEmptySelection(0)
    end)
end

return {
  name = "Show project-wise TODO panel",
  description = "Adds a project-wise panel for showing a tasks list.",
  author = "Chronos Phaenon Eosphoros",
  version = 0.25,
  dependencies = 1.60,

  onRegister = function(self)
    patterns = self:GetConfig().patterns 
    if not patterns or not next(patterns) then
       patterns = { { name = "TODO",  pattern = "TODO[:;>]"  },
                    { name = "FIXME", pattern = "FIXME[:;>]" }
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
  
  -- this fires after project is completely loaded
  onIdleOnce = function(self, event)
    projectLoaded = true
    -- scan all open files here, in case there are non-project files
    -- that remain open from last session that have tasks we want
    local edNum = 0
    local editor = ide:GetEditor(edNum)
    while editor do
      -- skip project files or current file that's already been scanned
      if not fileTasks[fileNameFromPath(ide:GetDocument(editor):GetFilePath())] then
        mapProject(self, editor)
      end
      edNum = edNum + 1
      editor = ide:GetEditor(edNum)
    end
  end,
  
  onEditorClose = function(self, editor)
    -- remove non project file tasks from list on close
    -- non project files don't have path stripped so check...
    local fullPath = ide:GetDocument(editor):GetFilePath()
    if fileTasks[fullPath] then
      fileTasks[fullPath] = nil
      mapProject(self)
    end
  end,

  onEditorLoad = function(self, editor) 
    if projectLoaded then
      mapProject(self, editor)
    end
  end,
  
  -- implemented for saving new file, so list updates on save
  onEditorSave = function(self, editor)
    if not fileTasks[fileNameFromPath(ide:GetDocument(editor):GetFilePath())] then
      mapProject(self, editor)
    end
  end,

  onEditorCharAdded = function(self, editor) --, event)
    -- might be in new, unsaved file
    if ide:GetDocument(editor):GetFilePath() then
      mapProject(self, editor)
    end
  end
}

