local updateneeded, cfg
local indicname = "highlightfunctioncalls"
local function onUpdate(event, editor)
  if bit.band(event:GetUpdated(), wxstc.wxSTC_UPDATE_CONTENT) > 0 then updateneeded = editor end
end
return {
  name = "Highlight function calls",
  description = "Highlights all function calls.",
  author = "David Krawiec",
  version = 0.1,
  dependencies = "1.20",

  onRegister = function(package)
    ide:AddIndicator(indicname)
    cfg = package:GetConfig()
    ide:GetOutput():Connect(wxstc.wxEVT_STC_UPDATEUI, function(event)
        onUpdate(event, ide:GetOutput())
      end)
  end,
  onUnRegister = function()
    ide:RemoveIndicator(indicname)
    ide:GetOutput():Disconnect(wxstc.wxEVT_STC_UPDATEUI)
  end,

  onEditorUpdateUI = function(self, editor, event) onUpdate(event, editor) end,

  onIdle = function(self)
    if not updateneeded then return end
    local editor = updateneeded
    updateneeded = false

    local length = editor:GetLength()
    local indicator = ide:GetIndicator(indicname)

    local function clearIndicator()
      editor:SetIndicatorCurrent(indicator)
      editor:IndicatorClearRange(0, length)
    end

    local style = bit.band(editor:GetStyleAt(editor:GetSelectionStart()),31)
    local color = cfg and type(cfg.color) == "table" and #(cfg.color) == 3 and
      wx.wxColour((table.unpack or unpack)(cfg.color)) or editor:StyleGetForeground(style)
    editor:IndicatorSetStyle(indicator, cfg and cfg.indicator or wxstc.wxSTC_INDIC_TEXTFORE)
    editor:IndicatorSetForeground(indicator, color)
    editor:SetIndicatorCurrent(indicator)
    editor:IndicatorClearRange(0, length)

    local searchFlag = editor:GetSearchFlags()
    editor:SetSearchFlags(wxstc.wxSTC_FIND_REGEXP)

    local pos, num = 0, 0
    while true do
      editor:SetTargetStart(pos)
      editor:SetTargetEnd(length)
      pos = editor:SearchInTarget('\\w+\\s*+(.*?)')
      posEnd = editor:SearchInTarget('(')

      if pos == -1 then break end

      --ide:Print("Found function call position", pos)

      editor:IndicatorFillRange(pos, posEnd - pos)
      pos = pos + posEnd - pos
    end

    editor:SetSearchFlags(searchFlag)
  end,
}

--[[ configuration example:
    highlightfunctioncalls = {indicator = wxstc.wxSTC_INDIC_TEXTFORE, color = {255, 0, 0}}
--]]
