local plugin = {
  name = "Mark edge",
  description = "Marks column edge for long lines.",
  author = "Paul Kulchenko",
  version = 0.2,

  onEditorLoad = function(self, editor)
    local config = self.GetConfig and self:GetConfig()
    editor:SetEdgeMode(wxstc.wxSTC_EDGE_LINE)
    editor:SetEdgeColumn(config and config.column or 80)
    if config and config.color then
      editor:SetEdgeColour(wx.wxColour((table.unpack or unpack)(config.color)))
    end
  end,
}
plugin.onEditorNew = plugin.onEditorLoad
return plugin
