local G = ...
local id = G.ID("showluareference.showluareferencemenu")
local menuid
local ident = "([a-zA-Z_][a-zA-Z_0-9%.%:]*)"
return {
  name = "Show lua reference",
  description = "Adds 'show lua reference' option to the editor menu.",
  author = "Paul Kulchenko",
  version = 0.1,

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

    if ref then
      menu:Append(id, ("Show Lua Reference: %s"):format(ref))
      menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
        function()
          local url = ('http://www.lua.org/manual/%s/manual.html#%s'):
            format(ide:GetInterpreter().luaversion or '5.1',
              ref:find('^luaL?_') and ref or 'pdf-'..ref)
          wx.wxLaunchDefaultBrowser(url, 0)
        end)
    end
  end
}
