-- Copyright 2015-16 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local updateneeded
local indicname = "highlightselected.selected"
return {
  name = "Highlight selected",
  description = "Highlights all instances of a selected word.",
  author = "Paul Kulchenko",
  version = 0.14,
  dependencies = 1.11,

  onRegister = function() ide:AddIndicator(indicname) end,
  onUnRegister = function() ide:RemoveIndicator(indicname) end,

  onEditorUpdateUI = function(self, editor, event)
    if bit.band(event:GetUpdated(), wxstc.wxSTC_UPDATE_SELECTION) > 0 then updateneeded = editor end
  end,

  onIdle = function(self)
    if not updateneeded then return end
    local editor = updateneeded
    updateneeded = false

    local length, curpos = editor:GetLength(), editor:GetCurrentPos()
    local value = editor:GetTextRange(editor:GetSelectionStart(), editor:GetSelectionEnd())
    local indicator = ide:GetIndicator(indicname)

    local function clearIndicator()
      editor:SetIndicatorCurrent(indicator)
      editor:IndicatorClearRange(0, length)
    end

    if #value == 0 or not value:find('%w') then return clearIndicator() end

    local word = editor:GetTextRange( -- try to select a word under caret
      editor:WordStartPosition(curpos, true), editor:WordEndPosition(curpos, true))
    if #word == 0 then
      word = editor:GetTextRange( -- try to select a non-word under caret
        editor:WordStartPosition(curpos, false), editor:WordEndPosition(curpos, false))
    end
    if value ~= word then return clearIndicator() end

    local style = bit.band(editor:GetStyleAt(editor:GetSelectionStart()),31)
    local color = editor:StyleGetForeground(style)
    editor:IndicatorSetStyle(indicator, wxstc.wxSTC_INDIC_BOX)
    editor:IndicatorSetForeground(indicator, color)
    editor:SetIndicatorCurrent(indicator)
    editor:IndicatorClearRange(0, length)
    editor:SetSearchFlags(wxstc.wxSTC_FIND_WHOLEWORD + wxstc.wxSTC_FIND_MATCHCASE)

    local pos = 0
    while true do
      editor:SetTargetStart(pos)
      editor:SetTargetEnd(length)
      pos = editor:SearchInTarget(value)
      if pos == -1 then break end

      editor:IndicatorFillRange(pos, #value)
      pos = pos + #value
    end
  end,
}
