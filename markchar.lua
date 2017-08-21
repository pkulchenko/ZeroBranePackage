return {
  name = "Mark character",
  description = "Marks characters when typed with specific indicators.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorCharAdded = function(self, editor, event)
    local cfg = self:GetConfig()
    if type(cfg.chars) ~= "table" or not cfg.chars[event:GetKey()] then return end
    if not self.indic then
      local indicname = "utf8char"
      ide:AddIndicator(indicname)
      self.indic = ide:GetIndicator(indicname)
    end
    local indicator = self.indic
    local pos = editor:GetCurrentPos()-1
    local style = bit.band(editor:GetStyleAt(pos),31)
    local color = cfg and type(cfg.color) == "table" and #(cfg.color) == 3 and
      wx.wxColour((table.unpack or unpack)(cfg.color)) or editor:StyleGetForeground(style)
    editor:IndicatorSetStyle(indicator, cfg and cfg.indicator or wxstc.wxSTC_INDIC_STRIKE)
    editor:IndicatorSetForeground(indicator, color)
    editor:SetIndicatorCurrent(indicator)
    editor:IndicatorFillRange(pos, 1)
  end,
}

--[[ configuration example:
markchar = {chars = {[160] = true}, color = {255, 0, 0}, indicator = wxstc.wxSTC_INDIC_STRIKE}
--]]
