-- Copyright 2017-18 Paul Kulchenko, ZeroBrane LLC; All rights reserved
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
--      Show list of tasks from every Lua file in the project path and in all subdirectories
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
--     tasks = {
--               singleFileMode = true,
--       showOnlyFilesWithTasks = false,
--                       ignore = { "Export" },
--                     patterns = { { name = "TODOs",    pattern = "TODO[:;>]"  },
--                                  { name = "FIXMEs",   pattern = "FIXME[:;>]" },
--                                  { name = "My tasks", pattern = "@paulr[:;>]"   }
--                                },
--                    showNames = true,
--         dontAlwaysScrollView = false,
--                    noButtons = true,
--                      noIcons = true
--     }
--
--       ... if you don't have this in either of your user.lua files, or if any of the
--       options are omitted, then default settings are used ...
--
--         singleFileMode: default - false
--               Show only one file at a time, like todo.all. Toggle via right click menu.
--
--         showOnlyFilesWithTasks: default - true
--               With this set to false, all project files are always listed. Toggle via
--               right click menu.
--
--         ignore: default - ignore nothing
--               "Export" will ignore all files in eg PROJECTPATH/Export Android/
--               ...but won't ignore eg PROJECTPATH/Export Manager.lua
--
--         patterns: default - TODOs and FIXMEs with [:;>] pattern
--               Note... spaces in the patterns create issues (inc %s). 'name' is what is
--               shown on the list. Can be completely different from pattern.
--
--         showNames: default - false
--               Set to true, this shows tasks/pattern types in their own branches. Toggle
--               via right click menu.
--
--  dontAlwaysScrollView: default - true
--               Set to false to not scroll activated file to top of list, instead just
--               ensuring it's visible and highlighting it
--
--          noButtons: default - false .. set to true to not show  +/- tree buttons
--            noIcons: default - false .. set true to remove icons
--
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
local imglist                         -- icons for tree, set if required in onRegister

local mapProject, fileNameFromPath    -- forward decs


-- parent structure different on Mac so this is cross platform method of
-- getting parent panel
local function getNoteBook()
  local nbc = "wxAuiNotebook"
  return tree.ctrl:GetParent():GetClassInfo():GetClassName() == nbc and
    tree.ctrl:GetParent():DynamicCast(nbc) or nil
end

--
local function openEditorIterator()
  local docs = ide:GetDocuments()
  local doc_idx = nil
  local doc

  return function()
    doc_idx, doc = next(docs, doc_idx)
    return (doc_idx and doc:GetEditor() or nil)
  end
end

-- first level from root contain file nodes for this plugin
tree.addFileNode = function(fn)
  local root = tree.ctrl:GetRootItem()
  return tree.ctrl:AppendItem(root, fn, 0)
end

--
tree.getFileNode = function(fn)
  return tree.getChildByItemText(tree.ctrl:GetRootItem(), fn)
end

--
tree.isFileNode = function(node)
  return tree.ctrl:GetItemParent(node):GetValue() == tree.ctrl:GetRootItem():GetValue()
end

--
tree.getFileNodeOfNode = function(node)
  if tree.isFileNode(node) then return node end
  local parent = tree.ctrl:GetItemParent(node)
  while parent:IsOk() do
    if tree.isFileNode(parent) then return parent end
    parent = tree.ctrl:GetItemParent(parent)
  end
  return false
end

--
tree.getChildByItemText = function(parentItem, childName)
  local child = tree.ctrl:GetFirstChild(parentItem)
  local text
  while child:IsOk() do
    text = tree.ctrl:GetItemText(child)
    if text == childName then return child end
    child = tree.ctrl:GetNextSibling(child)
  end
  return nil
end

--
tree.getChildByDataTableItem = function(parentItem, tableItemName, value)
  local child = tree.ctrl:GetFirstChild(parentItem)
  local data
  while child:IsOk() do
    data = tree.getDataTable(child)
    if data then
      if data[tableItemName] then
        if data[tableItemName] == value then
          return child
        end
      end
    end
    child = tree.ctrl:GetNextSibling(child)
  end
  return nil
end

--
tree.getTaskByPosition = function(parentItem, pos)
  local child = tree.ctrl:GetFirstChild(parentItem)
  local data
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
-- leaving only unmatched - deleted ones - as false
tree.deleteUncheckedChildren = function(parentItem, reset)
  local child = tree.ctrl:GetFirstChild(parentItem)
  local data
  while child:IsOk() do
    data = tree.getDataTable(child)
    if data then
      if not data.isChecked then -- delete
        if tree.ctrl:GetNextSibling(child):IsOk() then
          child = tree.ctrl:GetNextSibling(child)
          tree.ctrl:Delete(tree.ctrl:GetPrevSibling(child))
        else
          tree.ctrl:Delete(child)
          break
        end
      else
        if reset then
          data.isChecked = false -- reset for next round of checking
        end
        tree.setDataTable(child, data)
        child = tree.ctrl:GetNextSibling(child)
      end
    else
      child = tree.ctrl:GetNextSibling(child)
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
      pattNode = tree.ctrl:AppendItem(fileNode, name, 3)
      tree.ctrl:SetItemTextColour(pattNode,
                           wx.wxColour(table.unpack(ide.config.styles.keywords5.fg)))
    else
      return nil
    end
  end
  return pattNode
end

--
tree.itemIsOrIsDescendantOf = function(item, ancestor)
  if item == nil or ancestor == nil then return nil end
  local parent = tree.ctrl:GetItemParent(item)
  while parent:IsOk() do
    if parent:GetValue() == ancestor:GetValue() then return true end
    parent = tree.ctrl:GetItemParent(parent)
  end
  return false
end

--
tree.reset = function()
  tree.ctrl:DeleteAllItems()
  local root = tree.ctrl:AddRoot("Project Tasks", 0)
  tree.ctrl:ExpandAllChildren(root)
end

--
tree.scrollTo = function(self, node)
  if tree.ctrl:IsVisible(node) then return end
  local nb = getNoteBook()
  if nb then nb:Freeze() end
  if not config.dontAlwaysScrollView then
    tree.ctrl:ScrollTo(node)
  else
    tree.ctrl:EnsureVisible(node)
  end
  tree.ctrl:SetScrollPos(wx.wxHORIZONTAL, 0, true)
  if nb then nb:Thaw() end
end

--
tree.ensureFileNodeVisible = function(fileNode)
  -- ensure file node and last grandchild/child is visible so that
  -- it's all in view
  if not config.dontAlwaysScrollView then
    tree:scrollTo(fileNode)
    return
  else
    local lastChild = tree.ctrl:GetLastChild(fileNode)
    if lastChild then
      if config.showNames then
        local lastGrandChild = tree.ctrl:GetLastChild(lastChild)
        if lastGrandChild then
          tree:scrollTo(lastGrandChild)
        else
          tree:scrollTo(lastChild)
        end
      else
        tree:scrollTo(lastChild)
      end
    end
    -- do this last in case the window is small and scrolling to the last grand/child
    -- pushes the filename out of the top
    tree:scrollTo(fileNode)
  end
end

-- insert task, either at end of tree or if unsorted is false, in order
-- of position from data table
tree.insertTask = function(parent, itemText, unsorted, pos)
  if unsorted then
    return tree.ctrl:AppendItem(parent, itemText, 1)
  else
    local child = tree.ctrl:GetFirstChild(parent)
    if not child:IsOk() then
      return tree.ctrl:AppendItem(parent, itemText, 1)
    end
    while child:IsOk() do
      local t = tree.getDataTable(child)
      if pos < t.pos then
        return tree.ctrl:InsertItem(parent, tree.ctrl:GetPrevSibling(child), itemText, 1)
      end
      child = tree.ctrl:GetNextSibling(child)
    end
    return tree.ctrl:AppendItem(parent, itemText, 1)
  end
end

-- declared locally above
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
local function countNewLinesBetweenPositions(text, startPos, endPos)
  local lineCount = 0
  local nextNewLine = string.find(text, "\n", startPos + 1)
  -- handle end of file when no more newlines
  if nextNewLine == nil then nextNewLine = #text end
  while nextNewLine < endPos do
    lineCount = lineCount + 1
    nextNewLine = string.find(text, "\n", nextNewLine + 1)
    if nextNewLine == nil then nextNewLine = #text end
  end
  return lineCount
end

--
local function mapTasks(fileName, text, isTextRawFile)
  local fileNode = tree.getOrCreateFileNode(true, fileName)
  for _, pattern in ipairs(patterns) do
    local pattNode = nil
    local pos, pattEnd
    local pattStart, numLines = 0, 0
    while true do
      pos = pattStart
      pattStart, pattEnd = string.find(text, pattern.pattern, pattStart+1)

      -- pattern not found, or it's filtered so don't want to show it
      if pattStart == nil or not pattern.visible then
        if pos == 0 then
          -- this pattern is not found, but maybe all nodes have been deleted, so
          -- check if the pattern exists, so that pattNode can be used by
          -- tree.deleteUncheckedChildren to delete after we break from loop
          if pattNode == nil then
            if config.showNames then
            -- false = just try to get it, do not create if not found
              pattNode = tree.getOrCreatePatternNode(false, fileNode, pattern.name)
            else
              pattNode = fileNode
            end
          end
        end
        break
      end

      -- we have found a pattern, get node for pattern or
      -- create it if it does not exist...
      if pattNode == nil then
        if config.showNames then
          pattNode = tree.getOrCreatePatternNode(true, fileNode, pattern.name)
        else -- ... unless it's flat view...
          pattNode = fileNode -- ... where tasks are direct childen of fileNode
        end
      end

      -- there's a difference in file lengths with lua file reading and
      -- wx editor length, so if it's a file read adjust for line endings
      -- so that we have a correct position to locate
      if isTextRawFile then
        numLines = numLines + countNewLinesBetweenPositions(text, pos, pattStart)
      end
      local adj = numLines

      local lineEnd = string.find(text, "\n", pattStart+1)
      if lineEnd == nil then lineEnd = #text else lineEnd = lineEnd - 1 end --  handle EOF
      -- 1 is for the extra char after the task name
      local taskStr = string.sub(text, pattEnd + 1, lineEnd)
      pos = pattStart + adj

      -- hasTask checks if entry exists and marks as checked so we can
      -- remove unmarked/checked orphans
      if not tree.hasTask(pattNode, taskStr, pos, true) then
        local task = tree.insertTask(pattNode, taskStr, config.showNames, pos)
        tree.setDataTable(task, { file = fileName, pos = pos, isChecked = true })
      end
    end -- while

    -- here we remove any children that weren't checked by hasTask
    if pattNode and config.showNames then
      tree.deleteUncheckedChildren(pattNode, true)
      -- if flat view, only pattNode is fileNode so only delete later
      -- if completely empty
      if tree.ctrl:GetChildrenCount(pattNode, false) == 0 then
        tree.ctrl:Delete(pattNode)
      end
    end
  end -- for

  -- remove file node if no children, unless we want to keep it
  if fileNode then
    -- remove unchecked here in flat view
    if not config.showTasks then tree.deleteUncheckedChildren(fileNode, true) end

    if not tree.ctrl:ItemHasChildren(fileNode) then
      if config.showOnlyFilesWithTasks and not config.singleFileMode then
        tree.ctrl:Delete(fileNode)
        return
      end
    else
      if config.singleFileMode then tree.setHighlightedFileItem(fileNode) end
    end
    tree.ctrl:ExpandAllChildren(fileNode)
  end
end

--
local highlightedFileItem
tree.setHighlightedFileItem = function(item)
  if not tree.isFileNode(item) then return false end
  if highlightedFileItem then
    tree.ctrl:SetItemBold(highlightedFileItem, false)
    if highlightedFileItem:GetValue() ~= item:GetValue() then
      -- active file has changed so reset highlight
      if not tree.itemIsOrIsDescendantOf(tree.ctrl:GetSelection(), item) then
        pcall( function() tree.ctrl:UnselectAll() end)
      end
    end
  end
  tree.ctrl:SetItemBold(item, true)
  highlightedFileItem = item
end

--
local function updateTree(editor)
  mapProject(editor, config.singleFileMode)
  local fileItem = tree.getFileNode(fileNameFromPath(ide:GetDocument(editor):GetFilePath()))
  if fileItem then
    currentEditor = editor
    tree.setHighlightedFileItem(fileItem)
    ide:DoWhenIdle(function() tree.ensureFileNodeVisible(fileItem) end)
  else
    if highlightedFileItem ~= nil then
      tree.ctrl:SetItemBold(highlightedFileItem, false)
      tree.ctrl:UnselectAll()
    end
  end
end

-- called from onProjectLoad and onIdleOnce
local function scanAllOpenEditorsAndMap()
  if config.singleFileMode then return end
  -- scan all open files here, in case there are non-project path files
  -- that remain open from last session that have tasks we want

  for editor in openEditorIterator() do
    -- skip project files or current file that's already been scanned
    local path = ide:GetDocument(editor):GetFilePath()
    if path ~= nil then
      local treeItem = tree.getFileNode(fileNameFromPath(path))
      if treeItem == nil then
        mapProject(editor)
      else
        tree.ensureFileNodeVisible(treeItem)
      end
    end
  end
end

-- (declared locally above) main function, called from events
-- (declared locally above) main function, called from events
function mapProject(editor, newTree)
  -- prevent UI updates in control to stop flickering
  local nb = getNoteBook()
  if nb then nb:Freeze() end
  -- we have frozen the whole notebook, so protect code in between freeze/thaw calls
  -- in case an error in this event keeps it frozen
  pcall(
    function()
      if newTree then tree.reset() end

      if editor then
        mapTasks(fileNameFromPath(ide:GetDocument(editor):GetFilePath()), editor:GetText())
      else
        -- map whole project, excluding paths begining with entries in ignore list/table
        -- in user.lua, tasks.ignore
        local masks = {}
        for i in ipairs(config.ignoreTable) do masks[i] = "^"..path2mask(config.ignoreTable[i]) end
        for _, filePath in ipairs(ide:GetFileList(projectPath, true, "*.lua")) do
          local fileName = fileNameFromPath(filePath)
          local ignore = false or editor
          for _, spec in ipairs(masks) do
            -- don't ignore if it's just the beginning of a filename
            ignore = ignore or (fileName:find(spec) and fileName:find("[\\/]"))
          end
          if not ignore then
            mapTasks(fileName, FileRead(filePath) or "", true)
          end
        end
      end
    end
  )
  -- allow UI updates
  if nb then nb:Thaw() end
end

-- our plugin/package object/table
local package = {
  name = "Tasks panel",
  description = "Provides project wide tasks panel.",
  author = "Paul Reilly",
  version = 1.0,
  dependencies = 1.61,

  onRegister = function(self)
    patterns = self:GetConfig().patterns
    if not patterns or not next(patterns) then
       patterns = { { name = "TODOs",  pattern = "TODO[:;>]"  },
                    { name = "FIXMEs", pattern = "FIXME[:;>]" }
                  }
    end

    -- init visibility for filtering diplay of task type
    for _, v in pairs(patterns) do
      v.visible = true
    end

    config.ignoreTable = self:GetConfig().ignore or {}
    config.showNames = self:GetConfig().showNames or false-- flatten tree
    -- option to use Ensurevisible instead of Scroll, to stop jumping to top
    config.dontAlwaysScrollView = self:GetConfig().dontAlwaysScrollView or false
    -- default is true, so don't want nil being false
    local sOFWT = self:GetConfig().showOnlyFilesWithTasks
    config.showOnlyFilesWithTasks = sOFWT == nil or sOFWT == true
    config.singleFileMode = self:GetConfig().singleFileMode or false

    local w, h = 200, 600

    -- configure whether to show +/- buttons
    local hasButtons, linesAtRoot
    if self:GetConfig().noButtons then
      hasButtons, linesAtRoot = 0, 0
    else
      hasButtons, linesAtRoot =  wx.wxTR_HAS_BUTTONS, wx.wxTR_LINES_AT_ROOT
    end

    tree.ctrl = ide:CreateTreeCtrl(
      ide:GetProjectNotebook(),
      wx.wxID_ANY,
      wx.wxDefaultPosition,
      wx.wxSize(w, h),
      wx.wxTR_HIDE_ROOT + hasButtons + wx.wxNO_BORDER +
      wx.wxTR_ROW_LINES + linesAtRoot
    )

    if self:GetConfig().noIcons ~= true then
      imglist = ide:CreateImageList("OUTLINE", "FILE-NORMAL", "VALUE-LCALL",
                                      "VALUE-GCALL", "VALUE-ACALL", "VALUE-SCALL", "VALUE-MCALL")
      tree.ctrl:SetImageList(imglist)
    end

    tree.reset()

    local conf = function(panel)
      panel:Dock():MinSize(w, -1):BestSize(w, -1):FloatingSize(w, h)
    end

    ide:AddPanelFlex(ide:GetProjectNotebook(), tree.ctrl, tasksPanel, TR("Tasks"), conf)

    -- right click menu
    local ID_FILESWITHTASKS = NewID()
    local ID_SINGLEFILEMODE = NewID()
    local ID_FLATMODE = NewID()

    local rcMenu = ide:MakeMenu(
      {
        { ID_FILESWITHTASKS, TR("Show Only Files With Tasks"), "", wx.wxITEM_CHECK },
        { ID_SINGLEFILEMODE, TR("Single File Mode"), "", wx.wxITEM_CHECK },
        { ID_FLATMODE, TR("View With Task Names"), "", wx.wxITEM_CHECK },
      }
    )
    rcMenu:Check(ID_FILESWITHTASKS, config.showOnlyFilesWithTasks)
    rcMenu:Check(ID_SINGLEFILEMODE, config.singleFileMode)
    rcMenu:Check(ID_FLATMODE, config.showNames)

    tree.ctrl:Connect(
      wx.wxEVT_RIGHT_DOWN,
      function(event)
        tree.ctrl:PopupMenu(rcMenu)
      end
    )

    local function remapProject()
      if config.singleFileMode then
        mapProject(ide:GetEditor(), true)
      else
        mapProject(nil, true)
        scanAllOpenEditorsAndMap()
      end
    end

    tree.ctrl:Connect(
      ID_FLATMODE,
      wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event)
        config.showNames = not config.showNames
        remapProject()
      end
    )

    tree.ctrl:Connect(
      ID_FILESWITHTASKS,
      wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event)
        config.showOnlyFilesWithTasks = not config.showOnlyFilesWithTasks
        remapProject()
      end
    )

    tree.ctrl:Connect(
      ID_SINGLEFILEMODE,
      wx.wxEVT_COMMAND_MENU_SELECTED,
      function(event)
        config.singleFileMode = not config.singleFileMode
        remapProject()
      end
    )

    rcMenu:AppendSeparator()
    local tasksSubMenu = ide:MakeMenu()
    rcMenu:AppendSubMenu(tasksSubMenu, TR("Filter Tasks..."))

    -- create menu entries for filtering
    for _,pattern in pairs(patterns) do
      local menuItemID = NewID()
      tasksSubMenu:Append(menuItemID, TR(pattern.name), "", wx.wxITEM_CHECK)
      tasksSubMenu:Check(menuItemID, pattern.visible)

      tree.ctrl:Connect(
        menuItemID,
        wx.wxEVT_COMMAND_MENU_SELECTED,
        function(event)
          pattern.visible = not pattern.visible
          if config.singleFileMode then
            mapProject(ide:GetEditor(), true)
          else
            mapProject(nil, true)
            scanAllOpenEditorsAndMap()
          end
        end
      )
    end
    -- end of right click menu

    tree.ctrl:Connect(
      wx.wxEVT_LEFT_DOWN,
      function(event)
        local mask = (wx.wxTREE_HITTEST_ONITEMINDENT + wx.wxTREE_HITTEST_ONITEMLABEL
          + wx.wxTREE_HITTEST_ONITEMICON + wx.wxTREE_HITTEST_ONITEMRIGHT)
        local item_id, flags = tree.ctrl:HitTest(event:GetPosition())

        if not (item_id and item_id:IsOk() and bit.band(flags, mask) > 0) then
          event:Skip()
          return
        end
        --getNoteBook():Freeze() -- this makes SelectItem cause tree to scroll/jump around
        tree.ctrl:SelectItem(item_id)
        tree.setHighlightedFileItem(tree.getFileNodeOfNode(item_id))
        --getNoteBook():Thaw()
        local item = item_id
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
      end
    )

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Project")))
    menu:InsertCheckItem(4, id, TR("Project Tasks")..KSC(id))

    menu:Connect(
      id,
      wx.wxEVT_COMMAND_MENU_SELECTED,
      function ()
        local uimgr = ide:GetUIManager()
        uimgr:GetPane(tasksPanel):Show(not uimgr:GetPane(tasksPanel):IsShown())
        uimgr:Update()
      end
    )

    ide:GetMainFrame():Connect(
      id,
      wx.wxEVT_UPDATE_UI,
      function (event)
        local pane = ide:GetUIManager():GetPane(tasksPanel)
        menu:Enable(event:GetId(), pane:IsOk()) -- disable if doesn't exist
        menu:Check(event:GetId(), pane:IsOk() and pane:IsShown())
      end
    )
  end,

  --
  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,

  -- called in between onEditorFocusSet calls when app first opens. Called after
  -- on subsequent project loads.
  onProjectLoad = function(self, project)
    local newProject = projectPath == nil or projectPath ~= project
    projectPath = project
    ide:DoWhenIdle(
      function()
        if not config.singleFileMode then
          mapProject(nil, newProject)
          scanAllOpenEditorsAndMap()
        else
          mapProject(currentEditor, newProject)
        end
      end
    )
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
      mapProject()
    end
  end,

  --
  onEditorLoad = function(self, editor)
    if zeroBraneLoaded then
      mapProject(editor)
    end
  end,

  -- implemented for saving new file or save as, so list updates
  onEditorSave = function(self, editor)
    if tree.getFileNode(fileNameFromPath(ide:GetDocument(editor):GetFilePath())) == nil then
      mapProject(editor)
    end
  end,

  --
  onEditorFocusSet = function(self, editor)
    if DEBUG then require('mobdebug').on() end -- start debugger for coroutine
    -- event called when loading file, but filename is nil then
    if ide:GetDocument(editor):GetFilePath() then
      updateTree(editor)
    end
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
      mapProject(editor)
    end
  end
}

function _DBG(...)
  if DEBUG then
    local msg = "" for _,v in ipairs{...} do msg = msg .. tostring(v) .. "\t" end ide:Print(msg)
  end
end

return package