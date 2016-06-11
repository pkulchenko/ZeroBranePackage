-- Copyright 2014-16 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local mappanel = "documentmappanel"
local markers = {CURRENT = "docmap.current", BACKGROUND = "docmap.background"}
local editormap, editorlinked
local id
local win = ide.osname == 'Windows'
local needupdate
local colors = { -- default values if no style colors are set
  text = {64, 64, 64},
  background = {208, 208, 208},
  current = {240, 240, 230},
}
local function switchEditor(editor)
  if editorlinked == editor then return end
  if editormap then
    if editor then
      local font = editor:GetFont()
      editormap:SetFont(font)
      editormap:StyleSetFont(wxstc.wxSTC_STYLE_DEFAULT, font)

      -- reset styles when switching the editor
      local styles = ide:GetConfig().styles
      markers[markers.BACKGROUND] = ide:AddMarker(markers.BACKGROUND,
        wxstc.wxSTC_MARK_BACKGROUND,
        styles.text.fg or colors.text,
        styles.sel.bg or colors.background)
      editormap:MarkerDefine(ide:GetMarker(markers.BACKGROUND))
    
      markers[markers.CURRENT] = ide:AddMarker(markers.CURRENT,
        wxstc.wxSTC_MARK_BACKGROUND,
        styles.text.fg or colors.text,
        styles.caretlinebg.bg or colors.current)
      editormap:MarkerDefine(ide:GetMarker(markers.CURRENT))
    end

    editormap:MarkerDeleteAll(markers[markers.CURRENT])
    editormap:MarkerDeleteAll(markers[markers.BACKGROUND])
  end
  if editorlinked then
    -- clear the editor in case the last editor tab was closed
    if editormap and not editor
    and ide:GetEditorNotebook():GetPageCount() == 1 then
      editormap:SetDocPointer()
    end
  end
  if editor then
    editormap:SetDocPointer(editor:GetDocPointer())
  end
  editorlinked = editor
end

local function screenFirstLast(e)
  local firstline = e:DocLineFromVisible(e:GetFirstVisibleLine())
  local linesvisible = (e:DocLineFromVisible(e:GetFirstVisibleLine()+e:LinesOnScreen()-1)
    - firstline)
  return firstline, math.min(e:GetLineCount(), firstline + linesvisible)
end

local function sync(e1, e2)
  local firstline, lastline = screenFirstLast(e1)

  e2:MarkerDeleteAll(markers[markers.BACKGROUND])
  for line = firstline, lastline do
    e2:MarkerAdd(line, markers[markers.BACKGROUND])
  end

  local currline = e1:GetCurrentLine()
  e2:MarkerDeleteAll(markers[markers.CURRENT])
  e2:MarkerAdd(currline, markers[markers.CURRENT])

  local linesmax1 = math.max(1, e1:GetLineCount() - (lastline-firstline))
  local linesmax2 = math.max(1, e2:GetLineCount() - e2:LinesOnScreen())
  local line2 = firstline * linesmax2 / linesmax1
  e2:SetFirstVisibleLine(e2:VisibleFromDocLine(math.floor(line2)))

  -- force refresh to keep the map editor up-to-date and reduce jumpy scroll
  if win then e2:Refresh() e2:Update() end
end

return {
  name = "Document Map",
  description = "Adds document map.",
  author = "Paul Kulchenko",
  version = 0.28,
  dependencies = 0.90,

  onRegister = function(self)
    local e = wxstc.wxStyledTextCtrl(ide:GetMainFrame(), wx.wxID_ANY,
      wx.wxDefaultPosition, wx.wxSize(20, 20), wx.wxBORDER_NONE)
    editormap = e

    local w, h = 150, 150
    ide:AddPanel(e, mappanel, TR("Document Map"), function(pane)
        pane:Dock():Right():TopDockable(false):BottomDockable(false)
          :MinSize(w,-1):BestSize(w,-1):FloatingSize(w,h)
      end)

    -- remove all margins
    for m = 0, 4 do e:SetMarginWidth(m, 0) end
    e:SetUseHorizontalScrollBar(false)
    e:SetUseVerticalScrollBar(false)
    e:SetZoom(self:GetConfig().zoom or -7)
    e:SetSelBackground(false, wx.wxBLACK)
    e:SetCaretStyle(0) -- disable caret as it may be visible when selecting on inactive map
    e:SetCursor(wx.wxCursor(wx.wxCURSOR_ARROW))

    -- disable dragging from or to the map
    e:Connect(wxstc.wxEVT_STC_START_DRAG, function(event) event:SetDragText("") end)
    e:Connect(wxstc.wxEVT_STC_DO_DROP, function(event) event:SetDragResult(wx.wxDragNone) end)

    do -- set readonly when switched to
      local ro
      e:Connect(wx.wxEVT_SET_FOCUS, function() ro = e:GetReadOnly() e:SetReadOnly(true) end)
      e:Connect(wx.wxEVT_KILL_FOCUS, function() e:SetReadOnly(ro or false) end)
    end

    local function setFocus(editor)
      editor:SetFocus()
      if ide.osname == 'Macintosh' then
        -- manually trigger KILL_FOCUS event on OSX: http://trac.wxwidgets.org/ticket/14142
        editormap:GetEventHandler():ProcessEvent(wx.wxFocusEvent(wx.wxEVT_KILL_FOCUS))
      end
    end

    local function jumpLinked(point)
      local pos = e:PositionFromPoint(point)
      local firstline, lastline = screenFirstLast(editorlinked)
      local onscreen = lastline-firstline
      local topline = math.floor(e:LineFromPosition(pos)-onscreen/2)
      editorlinked:SetFirstVisibleLine(editorlinked:VisibleFromDocLine(topline))
    end

    local scroll
    local function scrollLinked(point)
      local onscreen = math.min(editorlinked:LinesOnScreen(), editorlinked:GetLineCount())
      local line = e:LineFromPosition(e:PositionFromPoint(point))
      local lineheight = e:TextHeight(line)
      local count = e:GetLineCount()
      local height = math.min(count * lineheight, e:GetClientSize():GetHeight())
      local scrollnow = (point:GetY() - scroll) / (height - onscreen * lineheight)
      local topline = math.floor((count-onscreen)*scrollnow)
      editorlinked:SetFirstVisibleLine(editorlinked:VisibleFromDocLine(topline))
    end

    e:Connect(wx.wxEVT_LEFT_DOWN, function(event)
        if not editorlinked then return end

        local point = event:GetPosition()
        local pos = e:PositionFromPoint(point)
        local line = e:LineFromPosition(pos)
        local firstline, lastline = screenFirstLast(editorlinked)
        if line >= firstline and line <= lastline then
          scroll = (line-firstline) * e:TextHeight(line)
          if win then e:CaptureMouse() end
        else
          jumpLinked(point)
          setFocus(editorlinked)
        end
      end)
    e:Connect(wx.wxEVT_LEFT_UP, function(event)
        if not editorlinked then return end
        if scroll then
          scroll = nil
          setFocus(editorlinked)
          if win then e:ReleaseMouse() end
        end
      end)
    e:Connect(wx.wxEVT_MOTION, function(event)
        if not editorlinked then return end
        if scroll then scrollLinked(event:GetPosition()) end
      end)
    -- ignore all double click events as they cause selection in the editor
    e:Connect(wx.wxEVT_LEFT_DCLICK, function(event) end)
    -- ignore context menu
    e:Connect(wx.wxEVT_CONTEXT_MENU, function(event) end)
    -- set the cursor so it doesn't look like vertical beam
    e:Connect(wx.wxEVT_SET_CURSOR, function(event)
        event:SetCursor(wx.wxCursor(wx.wxCURSOR_ARROW))
      end)

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    id = ID("documentmap.documentmapview")
    menu:InsertCheckItem(4, id, TR("Document Map Window")..KSC(id))
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function (event)
        local uimgr = ide:GetUIManager()
        uimgr:GetPane(mappanel):Show(not uimgr:GetPane(mappanel):IsShown())
        uimgr:Update()
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function (event)
        local pane = ide:GetUIManager():GetPane(mappanel)
        ide:GetMenuBar():Enable(event:GetId(), pane:IsOk()) -- disable if doesn't exist
        ide:GetMenuBar():Check(event:GetId(), pane:IsOk() and pane:IsShown())
      end)
  end,

  onUnRegister = function(self)
    switchEditor()
    ide:RemoveMenuItem(id)
    -- `RemovePanel` is available in 1.21+, so check if it is present
    if ide.RemovePanel then ide:RemovePanel(mappanel) end
  end,

  onEditorFocusSet = function(self, editor)
    if editorlinked ~= editor then
      switchEditor(editor)

      -- fix markers in the editor, otherwise they are shown as default markers
      editor:MarkerDefine(markers[markers.CURRENT], wxstc.wxSTC_MARK_EMPTY)
      editor:MarkerDefine(markers[markers.BACKGROUND], wxstc.wxSTC_MARK_EMPTY)

      local doc = ide:GetDocument(editor)
      if editormap and doc then editor.SetupKeywords(editormap, doc:GetFileExt()) end
      needupdate = true
    end
  end,

  onEditorClose = function(self, editor)
    if editor == editorlinked then switchEditor() end
  end,

  onEditorUpdateUI = function(self, editor)
    needupdate = true
  end,

  onEditorPainted = function(self, editor)
    if editormap and editor == editorlinked and needupdate then
      needupdate = false
      sync(editorlinked, editormap)
    end
  end,
}

--[[ configuration example:
documentmap = {zoom = -7} -- zoom can be set from -10 (smallest) to 0 (normal)
--]]
