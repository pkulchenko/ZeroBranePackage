local G = ...
local id = G.ID("showreference.showreferencemenu")
local menuid
local ident = "([a-zA-Z_][a-zA-Z_0-9%.%:]*)"
return {
  name = "Show reference",
  description = "Adds 'show reference' option to the editor menu.",
  author = "Paul Kulchenko",
  version = 0.21,

  onMenuEditor = function(self, menu, editor, event)
    local point = editor:ScreenToClient(event:GetPosition())
    local pos = editor:PositionFromPointClose(point.x, point.y)
    if not pos then return end

    local line = editor:LineFromPosition(pos)
    local linetx = editor:GetLine(line)
    local localpos = pos-editor:PositionFromLine(line)
    local selected = editor:GetSelectionStart() ~= editor:GetSelectionEnd()
      and pos >= editor:GetSelectionStart() and pos <= editor:GetSelectionEnd()

    local start = linetx:sub(1,localpos):find(ident.."$")
    local right = linetx:sub(localpos+1,#linetx):match("^([a-zA-Z_0-9]*)%s*['\"{%(]?")
    local ref = selected
      and editor:GetTextRange(editor:GetSelectionStart(), editor:GetSelectionEnd())
      or (start and linetx:sub(start,localpos)..right or nil)

    local target = self:GetConfig().target
    local transform = self:GetConfig().transform
    if ref and target then
      menu:Append(id, ("Show Reference: %s"):format(ref))
      if transform then ref = select(2, pcall(transform, ref)) end
      menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
        function() wx.wxLaunchDefaultBrowser(target:format(ref), 0) end)
    end
  end
}

--[[ configuration example:
showreference = {
  target = 'http://love2d.org/wiki/%s',
}

or

local G = ...
showreference = {
  target = 'http://docs.coronalabs.com/api/%s.html',
  transform = function(s)
    local tip = G.GetTipInfo(G.ide:GetEditor(), s)
    if tip then s = tip:match("%)%s*(%S+)") or s end
    s = (G.type(G[s]) == "function" and "global." or "")..s
    s = s..(s:find("[%.%:]") and "" or ".index")
    s = s:find("^_") and "type."..s:sub(2) or "library."..s
    return(s:gsub("[%.%:]","/"))
  end,
}
--]]
