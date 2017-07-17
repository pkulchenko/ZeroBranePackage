-- Copyright 2015-16 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local updateneeded, cfg
local indicname = "highlightselected.selected"
return {
  name = "Highlight selected",
  description = "Highlights all instances of a selected word.",
  author = "Paul Kulchenko",
  version = 0.18,
  dependencies = "1.20",

  onRegister = function(package)
    ide:AddIndicator(indicname)
    cfg = package:GetConfig()
  end,
  onUnRegister = function() ide:RemoveIndicator(indicname) end,

  onEditorUpdateUI = function(self, editor, event)
    if bit.band(event:GetUpdated(), wxstc.wxSTC_UPDATE_SELECTION) > 0 then updateneeded = editor end
  end,

  onIdle = function(self)
    if not updateneeded then return end
    local editor = updateneeded
    updateneeded = false

    local length, curpos = editor:GetLength(), editor:GetCurrentPos()
    local ssel, esel = editor:GetSelection()
    local value = editor:GetTextRange(ssel, esel)
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
    local color = cfg and type(cfg.color) == "table" and #(cfg.color) == 3 and
      wx.wxColour((table.unpack or unpack)(cfg.color)) or editor:StyleGetForeground(style)
    editor:IndicatorSetStyle(indicator, cfg and cfg.indicator or wxstc.wxSTC_INDIC_ROUNDBOX)
    editor:IndicatorSetForeground(indicator, color)
    editor:SetIndicatorCurrent(indicator)
    editor:IndicatorClearRange(0, length)

    -- save the flags to restore after the search is done to not affect other searches
    local flags = editor:GetSearchFlags()
    editor:SetSearchFlags(wxstc.wxSTC_FIND_WHOLEWORD + wxstc.wxSTC_FIND_MATCHCASE)

    local pos, num = 0, 0
    while true do
      editor:SetTargetStart(pos)
      editor:SetTargetEnd(length)
      pos = editor:SearchInTarget(value)
      if pos == -1 then break end

      editor:IndicatorFillRange(pos, #value)
      pos = pos + #value
      num = num + 1
    end
    ide:SetStatusFor(("Found %d instance(s)."):format(num), 5)
    editor:SetSearchFlags(flags)
  end,
}

--[[ configuration example:
highlightselected = {indicator = wxstc.wxSTC_INDIC_ROUNDBOX, color = {255, 0, 0}}
--]]
