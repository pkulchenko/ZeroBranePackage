local id = ID("wordcount.wordcount")
ide:GetConfig().keymap[id] = ide:GetConfig().keymap[id] or "Alt-C"

local function displayHTML(page)
  local dlg = wx.wxDialog(ide:GetMainFrame(), wx.wxID_ANY, "Word Count")

  local normalfont = ide:CreateTreeCtrl():GetFont()
  local fixedfont = (ide:GetEditor() or ide:CreateEditor()):GetFont()
  local tmp = wx.wxLuaHtmlWindow(dlg, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(400, 360))
  tmp:SetFonts(normalfont:GetFaceName(), fixedfont:GetFaceName())
  tmp:SetPage(page)
  local w = tmp:GetInternalRepresentation():GetWidth()
  local h = tmp:GetInternalRepresentation():GetHeight()
  tmp:Destroy()

  local html = wx.wxLuaHtmlWindow(dlg, wx.wxID_ANY,
    wx.wxDefaultPosition, wx.wxSize(w, h), wx.wxHW_SCROLLBAR_NEVER)

  html:SetBorders(0)
  html:SetFonts(normalfont:GetFaceName(), fixedfont:GetFaceName())
  html:SetPage(page)

  local line = wx.wxStaticLine(dlg, wx.wxID_ANY)
  local button = wx.wxButton(dlg, wx.wxID_OK, "OK")
  button:SetDefault()

  local topsizer = wx.wxBoxSizer(wx.wxVERTICAL)
  topsizer:Add(html, 1, wx.wxEXPAND + wx.wxALL, 10)
  topsizer:Add(line, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 10)
  topsizer:Add(button, 0, wx.wxALL + wx.wxALIGN_RIGHT, 10)

  dlg:SetSizerAndFit(topsizer)
  dlg:Center()
  dlg:ShowModal()
  dlg:Destroy()
end

local function showWordCount(event)
  local editor = ide:GetEditor()
  if not editor then return end

  local selected = editor:GetSelectedText()
  local text = #selected > 0 and selected or editor:GetTextDyn()
  local sn, sv, sw, sl, sa, sc = 0, 0, 0, 0, 0, 0
  for sentence in (text.." "):gmatch("(.-[%.%?!]+)") do
    local osw = sw
    for word in sentence:gmatch("(%w+)") do
      local v = select(2, word:gsub("[aeiouyAYIOUY]+",""))
      v = v - (v > 1 and word:find("[eE]$") and 1 or 0)
      if v > 0 then
        sl = sl + #word -- chars in words
        sw = sw + 1 -- words
        sv = sv + v -- syllables
      end
    end
    -- skip sentences without words; this excludes `1.` from `1. Some Text` and `.2` from `Section 1.2.`
    if sw > osw then -- if this sentence has any words
      sn = sn + 1 -- sentences
      sa = sa + #sentence -- total chars in sentences
      sc = sc + #(sentence:gsub("%s+","")) -- chars in sentences
    end
  end
  -- reading difficulty level based on the average number of words per sentence
  local difficultylevel = {
    {29, "very difficult"},
    {25, "difficult"},
    {21, "fairly difficult"},
    {17, "standard"},
    {14, "fairly easy"},
    {11, "easy"},
    {8, "very easy"},
  }
  local function difficulty(n)
    for _, level in ipairs(difficultylevel) do
      if n > level[1] then return level[2] end
    end
    return "super easy"
  end

  local msg = ([[
<html>
 <body>
  <table border="0" width="100%%" cellspacing="2" cellpadding="1">
<tr><td colspan="2"><strong>Document Statistics</strong></td><tr>
<tr><td align="right">Sentences:</td><td>%d</td></tr>
<tr><td align="right">Words:</td><td>%d</td></tr>
<tr><td align="right">Characters (no spaces):</td><td>%d</td></tr>
<tr><td align="right">Characters (with spaces):</td><td>%d</td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td colspan="2"><strong>Sentence Statistics</strong></td><tr>
<tr><td align="right">Words:</td><td>%.1f (%s)</td></tr>
<tr><td align="right">Syllables:</td><td>%d</td></tr>
<tr><td align="right">Characters:</td><td>%d</td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td colspan="2"><strong>Word Statistics</strong></td><tr>
<tr><td align="right">Syllables:</td><td>%.1f</td></tr>
<tr><td align="right">Characters:</td><td>%.1f</td></tr>
  </table>
 </body>
</html>]]):format(sn, sw, sc, sa, sw/sn, difficulty(sw/sn), sv/sn, sa/sn, sv/sw, sa/sw)

  displayHTML(msg)
end

return {
  name = "Word count",
  description = "Counts the number of words and other statistics in the document.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = "1.30",

  onRegister = function()
    local menu = ide:FindTopMenu("&Edit")
    menu:Append(id, "Word Count"..KSC(id))
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function(event)
        event:Enable(ide:GetEditor() ~= nil)
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, showWordCount)
  end,
  onUnRegister = function()
    ide:RemoveMenuItem(id)
  end,
}
