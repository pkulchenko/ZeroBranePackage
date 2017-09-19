-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- TODO: on select, go to the relevant line
local id = ID("TODOpanel.referenceview")
local TODOpanel = "TODOpanel"
local refeditor
local spec = {iscomment = {}}

local function mapTODOS(self,editor,event)

  local tasksListStr = "Tasks List: \n\n"
  local taskList = {}
  local text = editor:GetText()
  local i = 0
  local positions = {}

  for _, pattern in ipairs(self.patterns) do
    while true do

      --find next todo index
      i = string.find(text, pattern, i+1)
      if i == nil then
        i = 0
        break
      end
      local j = string.find(text, "\n",i+1)
      local taskStr = string.sub(text, i ,j)
      table.insert(taskList, {line = taskStr, pos = i})
    end
  end

  table.sort(taskList, function(a,b) return a.pos<b.pos end)
  for i, task in ipairs(taskList) do
    positions[i+2] = task.pos
    tasksListStr = tasksListStr .. i ..". " .. task.line
  end  

  refeditor:SetReadOnly(false)
  refeditor:SetText(tasksListStr)
  refeditor:SetReadOnly(true)

  --On click of a task, go to relevant position in the text
  refeditor:Connect(wxstc.wxEVT_STC_DOUBLECLICK,
    function(event)
      local line = refeditor:GetCurrentLine() +1
      local position = positions[line]
      if not position then return end
      editor:GotoPosEnforcePolicy(position - 1)
      if not ide:GetEditorWithFocus(editor) then ide:GetDocument(editor):SetActive() end
    end)

end

return {
  name = "Show TODO panel",
  description = "Adds a panel for showing a tasks list",
  author = "Mark Fainstein",
  version = 1.22,
  dependencies = 0.81,

  onRegister = function(self)
    self.patterns = self:GetConfig().patterns
    if not self.patterns or not next(self.patterns) then
      self.patterns = { "TODO[:;]", "FIXME[:;]" }
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
      ide:AddPanelDocked(ide.frame.projnotebook, e, TODOpanel, TR("Tasks"), conf)
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
      e:Connect(wxstc.wxEVT_STC_UPDATEUI, function(event) MarkupStyle(e,0,e:GetLineCount()) end)
    end

    e:SetReadOnly(true)
    e:SetWrapMode(wxstc.wxSTC_WRAP_WORD)
    e:SetupKeywords("lua",spec,ide:GetConfig().styles,ide:GetOutput():GetFont())

    -- remove all margins
    for m = 0, 4 do e:SetMarginWidth(m, 0) end

    -- disable dragging to the panel
    e:Connect(wxstc.wxEVT_STC_DO_DROP, function(event) event:SetDragResult(wx.wxDragNone) end)

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    menu:InsertCheckItem(4, id, TR("Tasks List")..KSC(id))
    menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function (event)
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

  onEditorFocusSet = function(self, editor, event)
    mapTODOS(self,editor,event)
  end,

  onEditorCharAdded = function(self, editor, event)
    mapTODOS(self, editor, event)
  end,
}

--[[ configuration example:
todo = {
  patterns = { "TODO[%s:;]", "FIXME[%s:;]" },
}
--]]
