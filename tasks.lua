-- Copyright 2017 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- 
-- Contributed by Paul Reilly (@paul-reilly)
--
-- Based on:
--    todoall.lua: Contributed by Chronos Phaenon Eosphoros (@cpeosphoros)
-- (Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved)
--
----------------------------------------------------------------------------------------------------
--
-- PROJECT TASKS (tasks.lua):
--      Show list of tasks from every Lua file in the project path  and in all subdirectories
--      that haven't been excluded (see ignore below). 
--
--      It also shows tasks from every open file, but will remove those from the list when the
--      file is closed if it is not in the project directory. TODOs from project file are from
--      from project files are always listed, even when  the file has not been opened at all.
--
-- Configuration:
--      In your system or user config/preferences file, you can set the tokens used by this package 
--      and the beginning of paths relative to the project path to ignore...
--
--    e.g.
--        todoall = {
--            singleFileMode = true,
--            showOnlyFilesWithTasks = false,
--            ignore = { "Export" },
--          patterns = { { name = "TODOs",  pattern = "TODO[:;>]"  },
--                       { name = "FIXMEs", pattern = "FIXME[:;>]" },
--                       { name = "WTFs",   pattern = "WTF[:;>]"   }
--                     }
--        }
-- 
--       ... if you don't have this in either of your user.lua files, the default settings are
--       used...
-- 
--       singleFileMode: default - false
--             Show only one file at a time, like todo.all. Toggle via right click menu.
--             
--       showOnlyFilesWithTasks: default - true
--             With this set to false, all project files are always listed. Toggle via right click 
--             menu.
--
--       ignore: default - ignore nothing
--             "Export" will ignore all files in eg PROJECTPATH/Export Android/
--             ...but won't ignore eg PROJECTPATH/Export Manager.lua
--
--       patterns: default - TODOs and FIXMEs with [:;>] pattern
--             Note... spaces in the patterns create issues (inc %s). 'name' is what is shown on the
--             list. Can be completely different from pattern.
--
-- Tests:
--        TODO: this is a test TODO with more than one TODO to ignore
--        FIXME: this is a test FIXME too
--        this next one should also be a TODO> another TODO check
--
----------------------------------------------------------------------------------------------------


local id = ID("taskspanel.referenceview")
local tasksPanel = "taskspanel"
local zeroBraneLoaded = false         -- set in onIdleOnce
local needRefresh = false             -- set in onEditorUIUpdate event
local timer = {}                      -- tree.ctrl is updated on editor
timer.lastTick = os:clock()           -- events, but we can use this for 
timer.interval = 0.33                 -- minimum time between updates
local projectPath                     -- set in onProjectLoad
local config = {}
local tree = {}                       -- helper functions for wxTreeCtrl
local patterns = {}                   -- our task patterns from user.lua (or default)
local DEBUG = false                   -- set to true to get output from any _DBG calls
local _DBG -- (...)                   -- function for console output, definition at EOF
local currentEditor                   -- set in onEditorFocusSet, used in onProjectLoad
local dontSelectOnFocusSet = false

local mapProject, fileNameFromPath    -- forward decs


-- first level from root contain file nodes for this plugin
tree.addFileNode = function(fn)
  local root = tree.ctrl:GetRootItem()
  return tree.ctrl:AppendItem(root, fn, 1)
end

--
tree.getFileNode = function(fn)
  return tree.getChildByItemText(tree.ctrl:GetRootItem(), fn)
end

-- 
tree.getChildByItemText = function(parentItem, childName)
  local child, text = tree.ctrl:GetFirstChild(parentItem), nil
  while child:IsOk() do
    text = tree.ctrl:GetItemText(child)
    if text == childName then return child end
    child = tree.ctrl:GetNextSibling(child)
  end
  return nil
end

--
tree.getTaskByPosition = function(parentItem, pos)
  local child, data = tree.ctrl:GetFirstChild(parentItem), nil
  while child:IsOk() do
    data = tree.getDataTable(child)
    if data then
      if data.pos == pos then 
        return child
      end
    end
    child = tree.ctrl:GetNextSibling(child)
  end
  return nil
end

-- each node item in a wxTreeCtrl can store a table of data
tree.getDataTable = function(item)
  local itemData = tree.ctrl:GetItemData(item)
  if not itemData then return nil end
  local data = itemData:GetData()
  return data
end

--
tree.setDataTable = function(item, t)
  local itemData = tree.ctrl:GetItemData(item)
  if itemData == nil then itemData = wx.wxLuaTreeItemData() end
  itemData:SetData(t)
  tree.ctrl:SetItemData(item, itemData)
end

--
tree.hasTask = function(pattNode, taskStr, taskPos, checkIfFound)
  local str, pos = false, false
  local item = tree.getChildByItemText(pattNode, taskStr)
  if item == nil then 
    item = tree.getTaskByPosition(pattNode, taskPos)
    if item == nil then return false end
    pos = true -- only pos matches so text has changed
  else
    str = true -- item text has been matched
  end
  local data = tree.getDataTable(item)
  if data then
    if checkIfFound then
      data.isChecked = true
    end
    if pos then tree.ctrl:SetItemText(item, taskStr)
    elseif str then data.pos = taskPos end -- update in case it's changed
    tree.setDataTable(item, data)
    return true
  end
  return false
end

-- go through children and delete any that don't have isChecked set to true
-- this is because new/different and matched children were set to true
-- leaving only unmatched - deleted or moved ones - as false
tree.deleteUncheckedChildren = function(parentItem)
  local child, data = tree.ctrl:GetFirstChild(parentItem), nil
  while child:IsOk() do
    data = tree.getDataTable(child)
    if data then
      if not data.isChecked then -- delete
        if tree.ctrl:GetNextSibling(child):IsOk() then
          child = tree.ctrl:GetNextSibling(child)
          tree.ctrl:Delete(tree.ctrl:GetPrevSibling(child))
        else
          tree.ctrl:Delete(child)
          child = tree.ctrl:GetNextSibling(child)
        end
      else
        data.isChecked = false -- reset for next round of checking
        tree.setDataTable(child, data)
        child = tree.ctrl:GetNextSibling(child)
      end
    end
  end
end

--
tree.getOrCreateFileNode = function(createIfNotFound, fileName)
  local fileNode = tree.getFileNode(fileName)
  if fileNode == nil then 
    if createIfNotFound then 
      fileNode = tree.addFileNode(fileName)
      tree.setDataTable(fileNode, { file = fileName })
      tree.ctrl:SetItemBold(fileNode, true)
    else
      return nil
    end
  end
  return fileNode
end

--
tree.getOrCreatePatternNode = function(createIfNotFound, fileNode, name)
  local pattNode = tree.getChildByItemText(fileNode, name) 
  if pattNode == nil then
    if createIfNotFound then
      pattNode = tree.ctrl:AppendItem(fileNode, name, 2)
      tree.ctrl:SetItemTextColour(pattNode, 
                            wx.wxColour(table.unpack(ide.config.styles.keywords1.fg)))
    else
      return nil
    end
  end
  return pattNode
end

--
tree.reset = function()
  tree.ctrl:DeleteAllItems() 
  local root = tree.ctrl:AddRoot("Project Tasks", 0)
  tree.ctrl:ExpandAllChildren(root)
end

--
tree.ensureFileNodeVisible = function(fileNode)
  -- ensure file node and last gradnchild/child is visible so that
  -- it's all in view
  tree.ctrl:EnsureVisible(fileNode)
  local lastChild = tree.ctrl:GetLastChild(fileNode)
  if lastChild then
    local lastGrandChild = tree.ctrl:GetLastChild(lastChild)
    if lastGrandChild then 
      tree.ctrl:EnsureVisible(lastGrandChild)
    else
      tree.ctrl:EnsureVisible(lastChild)
    end
  end
end

--
function fileNameFromPath(filePath)
  return filePath:gsub(projectPath, "")
end

--
local function path2mask(s)
  return s
  :gsub('([%(%)%.%%%+%-%?%[%^%$%]])','%%%1') -- escape all special symbols
  :gsub("%*", ".*") -- but expand asterisk into sequence of any symbols
  :gsub("[\\/]","[\\\\/]") -- allow for any path
end

--
local function mapTasks(fileName, text, isTextRawFile)
  local fileNode = tree.getOrCreateFileNode(true, fileName)
  for _, pattern in ipairs(patterns) do
    local pattNode = nil
    local pattStart, pattEnd, pos, numLines = 0, 0, 0, 0
    while true do
      pos = pattStart
      pattStart, pattEnd = string.find(text, pattern.pattern, pattStart+1)
      
      -- pattern not found
      if pattStart == nil then
        if pos == 0 then
          -- this pattern is not found, but maybe all nodes have been deleted, so 
          -- check if the pattern exists, so that pattNode can be used by 
          -- tree.deleteUncheckedChildren to delete after we break from loop
          if fileNode and pattNode == nil then
            -- false = just try to get it, do not create if not found
            pattNode = tree.getOrCreatePatternNode(false, fileNode, pattern.name)
          end
        end
        break
      end
      
      -- we have found a pattern, get node for pattern or
      -- create it if it does not exist
      if pattNode == nil then
        pattNode = tree.getOrCreatePatternNode(true, fileNode, pattern.name)
      end
      
      -- there's a difference in file lengths with lua file reading and
      -- wx editor length, so if it's a file read adjust for line endings
      -- so that we have a correct position to locate
      local adj = 0
      local nextNewLine = string.find(text, "\n", pos + 1)
      -- handle end of file when no more newlines
      if nextNewLine == nil then nextNewLine = #text end
      if isTextRawFile then
        while nextNewLine < pattStart do
          numLines = numLines + 1
          nextNewLine = string.find(text, "\n", nextNewLine + 1)
          if nextNewLine == nil then nextNewLine = #text end
        end
        adj = numLines
      end
      
      local lineEnd = string.find(text, "\n", pattStart+1)
      if lineEnd == nil then lineEnd = #text else lineEnd = lineEnd - 1 end --  handle EOF
      -- 1 is for the extra char after the task name
      local taskStr = string.sub(text, pattEnd + 1, lineEnd)
      pos = pattStart + adj
      
      -- hasTask checks if entry exists and marks as checked so we can 
      -- remove unmarked/checked orphans
      if not tree.hasTask(pattNode, taskStr, pos, true) then
        local task = tree.ctrl:AppendItem(pattNode, taskStr, 2)
        tree.setDataTable(task, { file = fileName, pos = pos, isChecked = true })
      end
    end -- while                                  
    
    -- here we remove any children that weren't checked by hasTask
    if pattNode then
      tree.deleteUncheckedChildren(pattNode)
      if tree.ctrl:GetChildrenCount(pattNode, false) == 0 then 
        tree.ctrl:Delete(pattNode)
      end
    end
  end
  
  -- remove file node if no children, unless we want to keep it
  if fileNode then
    if config.showOnlyFilesWithTasks and tree.ctrl:GetChildrenCount(fileNode, false) == 0 
       and not config.singleFileMode then
      tree.ctrl:Delete(fileNode)
    else
      tree.ctrl:ExpandAllChildren(fileNode)
    end
  end
end

--
local function readfile(filePath)
  local input = io.open(filePath)
  local data = input:read("*a")
  input:close()
  return data
end


-- called from onProjectLoad and onIdleOnce
local function scanAllOpenEditorsAndMap()
  if config.singleFileMode then return end
  -- scan all open files here, in case there are non-project path files
  -- that remain open from last session that have tasks we want
  local edNum = 0
  local editor = ide:GetEditor(edNum)
  while editor do
    -- skip project files or current file that's already been scanned
    if ide:GetDocument(editor):GetFilePath() ~= nil then
      local treeItem = tree.getFileNode(fileNameFromPath(ide:GetDocument(editor):GetFilePath()))
      if treeItem == nil then
        mapProject(self, editor)
      else
        tree.ensureFileNodeVisible(treeItem)
      end
    end
    edNum = edNum + 1
    editor = ide:GetEditor(edNum)
  end
end

-- main function, called from events
function mapProject(self, editor, newTree)
  -- prevent UI updates in control to stop flickering
  ide.frame.projnotebook:Freeze() 
  
  if newTree then 
    tree.reset()
  end
  
  if editor then
    mapTasks(fileNameFromPath(ide:GetDocument(editor):GetFilePath()), editor:GetText())
  else
    -- map whole project, excluding paths begining with entries in ignore list/table
    -- in user.lua, todoall.ignore
    local masks = {}
    for i in ipairs(config.ignoreTable) do masks[i] = "^"..path2mask(config.ignoreTable[i]) end
    for _, filePath in ipairs(FileSysGetRecursive(projectPath, true, "*.lua")) do
      local fileName = fileNameFromPath(filePath)
      local ignore = false or editor
      for _, spec in ipairs(masks) do
        -- don't ignore if it's just the beginning of a filename
        ignore = ignore or (fileName:find(spec) and fileName:find("[\\/]"))
      end
      if not ignore then
        mapTasks(fileName, readfile(filePath), true)
      end
    end
  end        
  -- allow UI updates 
  ide.frame.projnotebook:Thaw()
end

-- our plugin/package object/table
local package = {
  name = "Tasks panel",
  description = "Project wide tasks panel.",
  author = "Paul Reilly",
  version = 0.90,
  dependencies = 1.60,

  onRegister = function(self)
    patterns = self:GetConfig().patterns 
    if not patterns or not next(patterns) then
       patterns = { { name = "TODOs",  pattern = "TODO[:;>]"  },
                    { name = "FIXMEs", pattern = "FIXME[:;>]" }
                  }
    end
    
    config.ignoreTable = self:GetConfig().ignore or {}
    
    -- default is true, so don't want nil being false
    local sOFWT = self:GetConfig().showOnlyFilesWithTasks
    if sOFWT == nil or sOFWT == true then
      config.showOnlyFilesWithTasks = true
    else
      config.showOnlyFilesWithTasks = false
    end
    
    config.singleFileMode = self:GetConfig().singleFileMode or false
    
    local w, h = 200, 600
    tree.ctrl = ide:CreateTreeCtrl(ide.frame.projnotebook, wx.wxID_ANY,
                            wx.wxDefaultPosition, wx.wxSize(w, h),
                            wx.wxTR_TWIST_BUTTONS + wx.wxTR_HIDE_ROOT + 
                            wx.wxTR_ROW_LINES)
    
    tree.reset()
    
    local conf = function(panel)
      panel:Dock():MinSize(w,-1):BestSize(w,-1):FloatingSize(w,h)
    end
    
    local layout = ide:GetSetting("/view", "uimgrlayout")
    
    local panel
    if not layout or not layout:find(tasksPanel) then
      panel = ide:AddPanelDocked(ide.frame.projnotebook, tree.ctrl, tasksPanel, 
                                 TR("ProTasks"), conf)
    else
      panel = ide:AddPanel(tree.ctrl, tasksPanel, TR("ProTasks"), conf)
    end
    
    -- right click menu  
    local ID_FILESWITHTASKS = NewID()
    local ID_SINGLEFILEMODE = NewID()
    
    local rcMenu = ide:MakeMenu {
        { ID_FILESWITHTASKS, TR("Toggle: &Show &only &files &with &tasks") },
        { ID_SINGLEFILEMODE, TR("Toggle: &Single &file &mode") }
    }
    
    tree.ctrl:Connect( wx.wxEVT_RIGHT_DOWN, 
      function(event)
        -- see filetree.lua for detailed reasons for GC stop here 
        -- (tl;dr - might crash Linux)
        collectgarbage("stop")
        tree.ctrl:PopupMenu(rcMenu)
        collectgarbage("restart")
      end
    )
    
    tree.ctrl:Connect(ID_FILESWITHTASKS, wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event)
        config.showOnlyFilesWithTasks = not config.showOnlyFilesWithTasks
        if config.singleFileMode then return end
        mapProject(self, nil, true)
        scanAllOpenEditorsAndMap()
      end
    )
  
    tree.ctrl:Connect(ID_SINGLEFILEMODE, wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event)
        config.singleFileMode = not config.singleFileMode
        if config.singleFileMode then
          mapProject(self, ide:GetEditor(editor), true)
        else
          mapProject(self, nil, true)
          scanAllOpenEditorsAndMap()
        end
      end
    )
    -- end of right click menu
    
    -- on double-click or Enter
    tree.ctrl:Connect( wx.wxEVT_COMMAND_TREE_ITEM_ACTIVATED,
      function(event)
        -- stop onFocusSet changing selection to file node
        dontSelectOnFocusSet = true
        local item = event:GetItem()
        if not item then return end
        local data = tree.getDataTable(item)
        if not data then return end
        local filePath = projectPath .. data.file
        
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
        
        -- pos not stored with file nodes, just task nodes
        if data.pos then editor:GotoPosEnforcePolicy(data.pos - 1) end
        if not ide:GetEditorWithFocus(editor) then
         ide:GetDocument(editor):SetActive()
        end
        dontSelectOnFocusSet = false
      end
    ) 

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Project")))
    menu:InsertCheckItem(4, id, TR("Project Tasks")..KSC(id))

    menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function ()
        local uimgr = ide:GetUIManager()
        uimgr:GetPane(tasksPanel):Show(not uimgr:GetPane(tasksPanel):IsShown())
        uimgr:Update()
      end)

    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function (event)
        local pane = ide:GetUIManager():GetPane(tasksPanel)
        menu:Enable(event:GetId(), pane:IsOk()) -- disable if doesn't exist
        menu:Check(event:GetId(), pane:IsOk() and pane:IsShown())
      end)
  end,

  --
  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
  
  -- called in between onEditorFocusSet calls when app first opens. Called after
  -- on subsequent project loads.
  onProjectLoad = function(self, project)
    local newProject = ( projectPath == nil or projectPath ~= project )
    projectPath = project
    if not config.singleFileMode then
      mapProject(self, nil, newProject)
      scanAllOpenEditorsAndMap()
    else
      mapProject(self, currentEditor, newProject)
    end
  end,
  
  -- this fires after project is completely loaded when ZBS is first opened
  onIdleOnce = function(self, event)
    zeroBraneLoaded = true
  end,
  
  --
  onEditorClose = function(self, editor)
    -- remove non project file tasks from list on close
    -- non project files don't have path stripped so check...
    local fullPath = ide:GetDocument(editor):GetFilePath()
    local treeItem = tree.getFileNode(fullPath)
    if treeItem then
      tree.ctrl:Delete(treeItem)
      mapProject(self)
    end
  end,
  
  --
  onEditorLoad = function(self, editor)
    if zeroBraneLoaded then
      mapProject(self, editor)
    end
  end,
  
  -- implemented for saving new file or save as, so list updates
  onEditorSave = function(self, editor)
    if tree.getFileNode(fileNameFromPath(ide:GetDocument(editor):GetFilePath())) == nil then
      mapProject(self, editor)
    end
  end,
  
  --
  onEditorFocusSet = function(self, editor)
    -- event called when loading file, but filename is nil then
    if ide:GetDocument(editor):GetFilePath() then 
      local fileItem = tree.getFileNode(fileNameFromPath(ide:GetDocument(editor):GetFilePath()))
      mapProject(self, editor, config.singleFileMode)
      if fileItem then
        currentEditor = editor
        tree.ensureFileNodeVisible(fileItem)
        if not dontSelectOnFocusSet then tree.ctrl:SelectItem(fileItem) end
      else
        tree.ctrl:UnselectAll()
      end
    end
    dontSelectOnFocusSet = false
  end,

  --
  onEditorUpdateUI = function(self, editor, event)
    -- only flag update when content changes; ignore scrolling events
    if bit.band(event:GetUpdated(), wxstc.wxSTC_UPDATE_CONTENT) > 0 then
      needRefresh = editor
    end
  end,
  
  --
  onIdle = function(self, event)
    -- limit update time to minimum of timer.interval in case of rapid events
    if os:clock() > timer.lastTick + timer.interval then
        timer.lastTick = os:clock()
    else
      return
    end
    local editor = needRefresh
    if not editor then return end
    needRefresh = nil
  
    if ide:GetDocument(editor):GetFilePath() then
      mapProject(self, editor)
    end
  end
}

function _DBG(...)
  if DEBUG then 
    local msg = "" for _,v in ipairs{...} do msg = msg .. tostring(v) .. "\t" end ide:Print(msg)
  end
end

return package

-- TODO: end of file test