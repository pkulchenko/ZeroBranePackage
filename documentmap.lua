-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local mappanel = "documentmappanel"
local markers = {CURRENT = "docmap.current", BACKGROUND = "docmap.background"}
local editormap, editorlinked, docpointer
local id, menuid
local markbeg, markend, markcur
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
        styles.text.fg,
        styles.sel.bg)
      editormap:MarkerDefine(ide:GetMarker(markers.BACKGROUND))
    
      markers[markers.CURRENT] = ide:AddMarker(markers.CURRENT,
        wxstc.wxSTC_MARK_BACKGROUND,
        styles.text.fg,
        styles.caretlinebg.bg)
      editormap:MarkerDefine(ide:GetMarker(markers.CURRENT))
    end

    editormap:MarkerDeleteAll(markers[markers.CURRENT])
    editormap:MarkerDeleteAll(markers[markers.BACKGROUND])
  end
  if editorlinked then
    editorlinked:ReleaseDocument(docpointer)
    -- clear the editor in case the last editor tab was closed
    if editormap and not editor then editormap:SetText("") end
  end
  if editor then
    docpointer = editor:GetDocPointer()
    editor:AddRefDocument(docpointer)
    editormap:SetDocPointer(docpointer)
  end
  editorlinked = editor

  -- reset cached values for markers
  markbeg, markend, markcur = -1, -1, -1
end

function screenFirstLast(e)
  local firstline = e:DocLineFromVisible(e:GetFirstVisibleLine())
  local linesvisible = (e:DocLineFromVisible(e:GetFirstVisibleLine()+e:LinesOnScreen()-1)
    - firstline)
  return firstline, math.min(e:GetLineCount(), firstline + linesvisible)
end

local function sync(e1, e2)
  local firstline, lastline = screenFirstLast(e1)
  local currline = e1:GetCurrentLine()

  if markbeg ~= firstline or markend ~= lastline then
    -- quick sanity check for those cases when different content is reloaded
    -- into the same file; only check for first and last markers
    local markervalue = 2^markers[markers.BACKGROUND]
    if bit.band(e2:MarkerGet(markbeg), markervalue) == 0
    or bit.band(e2:MarkerGet(markend), markervalue) == 0 then
      markbeg, markend, markcur = -1, -1, -1
    end

    for line = markbeg, markend do
      if line < firstline or line > lastline then
        e2:MarkerDelete(line, markers[markers.BACKGROUND])
      end
    end
    for line = firstline, lastline do
      if line < markbeg or line > markend then
        e2:MarkerAdd(line, markers[markers.BACKGROUND])
      end
    end
    markbeg, markend = firstline, lastline

    -- force refresh to keep the map editor up-to-date and reduce jumpy scroll
    e2:Refresh() e2:Update()
  end
  if markcur ~= currline then
    e2:MarkerDelete(markcur, markers[markers.CURRENT])
    e2:MarkerAdd(currline, markers[markers.CURRENT])
    markcur = currline
  end

  local linesmax1 = math.max(1, e1:GetLineCount() - (lastline-firstline))
  local linesmax2 = math.max(1, e2:GetLineCount() - e2:LinesOnScreen())
  local line2 = firstline * linesmax2 / linesmax1
  e2:SetFirstVisibleLine(e2:VisibleFromDocLine(math.floor(line2)))
end

return {
  name = "Document Map",
  description = "Adds document map.",
  author = "Paul Kulchenko",
  version = 0.11,
  dependencies = 0.71,

  onRegister = function(self)
    local e = wxstc.wxStyledTextCtrl(ide:GetMainFrame(), wx.wxID_ANY,
      wx.wxDefaultPosition, wx.wxSize(20, 20), wx.wxBORDER_NONE)
    editormap = e

    local w, h = 150, 150
    ide:AddPanel(e, mappanel, TR("Document Map"), function(pane)
        pane:Dock():Right():TopDockable(false):BottomDockable(false)
          :MinSize(w,-1):BestSize(w,-1):FloatingSize(w,h)
      end)

    for m = 1, 4 do e:SetMarginWidth(m, 0) end
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

    local function scrollLinked(point)
      local pos = e:PositionFromPoint(point)
      local firstline, lastline = screenFirstLast(editorlinked)
      local onscreen = lastline-firstline
      local topline = math.floor(e:LineFromPosition(pos)-onscreen/2)
      editorlinked:SetFirstVisibleLine(editorlinked:VisibleFromDocLine(topline))
    end

    local scroll
    e:Connect(wx.wxEVT_LEFT_DOWN, function(event)
        if not editorlinked then return end

        local pos = e:PositionFromPoint(event:GetPosition())
        local line = e:LineFromPosition(pos)
        local firstline, lastline = screenFirstLast(editorlinked)
        if line >= firstline and line <= lastline then
          scroll = true
          e:CaptureMouse()
        else
          scrollLinked(event:GetPosition())
          editorlinked:SetFocus()
        end
      end)
    e:Connect(wx.wxEVT_LEFT_UP, function(event)
        if not editorlinked then return end

        if scroll then scroll = nil end
        e:ReleaseMouse()
      end)
    e:Connect(wx.wxEVT_MOTION, function(event)
        if not editorlinked then return end
        if not scroll then event:Skip() e:ReleaseMouse() return end

        scrollLinked(event:GetPosition())
      end)
    -- ignore all double click events as they cause selection in the editor
    e:Connect(wx.wxEVT_LEFT_DCLICK, function(event) end)
    -- set the cursor so it doesn't look like vertical beam
    e:Connect(wx.wxEVT_SET_CURSOR, function(event)
        event:SetCursor(wx.wxCursor(wx.wxCURSOR_ARROW))
      end)

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    id = ID("documentmap.documentmapview")
    menuid = menu:InsertCheckItem(4, id, TR("Document Map Window")..KSC(id))
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

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxID_ANY)
    if menuid then menu:Destroy(menuid) end
  end,

  onEditorFocusSet = function(self, editor)
    if editorlinked ~= editor then
      switchEditor(editor)

      -- fix markers in the editor, otherwise they are shown as default markers
      editor:MarkerDefine(markers[markers.CURRENT], wxstc.wxSTC_MARK_EMPTY)
      editor:MarkerDefine(markers[markers.BACKGROUND], wxstc.wxSTC_MARK_EMPTY)

      local doc = ide:GetDocument(editor)
      if editormap and doc then editor.SetupKeywords(editormap, doc:GetFileExt()) end
    end
  end,

  onEditorClose = function(self, editor)
    if editor == editorlinked then switchEditor() end
  end,

  onEditorPainted = function(self, editor)
    if editormap and editor == editorlinked then sync(editorlinked, editormap) end
  end,
}

--[[ configuration example:
documentmap = {zoom = -7} -- zoom can be set from -10 (smallest) to 0 (normal)
--]]
