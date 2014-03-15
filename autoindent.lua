return {
  name = "Auto-indent based on source code",
  description = "Sets editor indentation based on file text analysis.",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorLoad = function(self, editor)
    if editor:GetUseTabs() then return end

    local spaces, pspaces, pdiff = {}, 0, 0
    for line = 0, math.min(100, editor:GetLineCount())-1 do
      local tspaces = #(editor:GetLine(line):match("^[ \t]*"))
      local tdiff = math.abs(tspaces-pspaces)
      if tdiff > 0 then pdiff = tdiff end
      if pdiff > 0 and pdiff <= 8 then spaces[pdiff] = (spaces[pdiff] or 0) + 1 end
      pspaces = tspaces
    end

    local maxv, maxn = 0
    for n,v in pairs(spaces) do if v > maxv then maxn, maxv = n, v end end

    local indent = maxn or ide:GetConfig().editor.tabwidth or 2
    editor:SetIndent(indent)
  end,
}
