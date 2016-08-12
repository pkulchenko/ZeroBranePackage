local id = ID("wordwrapmenu.wordwrapmenu")
return {
  name = "Wordwrap menu",
  description = "Adds word wrap option to the menu.",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.0",

  onRegister = function(self)
    local menu = ide:FindTopMenu("&Edit")
    local pos = self:GetConfig().insertat and
      self:GetConfig().insertat-1 or menu:GetMenuItemCount()
    menu:InsertCheckItem(pos, id, "WordWrap\tAlt-W")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function(event)
        local wrap = event:IsChecked() and wxstc.wxSTC_WRAP_WORD or wxstc.wxSTC_WRAP_NONE
        local ed = ide:GetEditor()
        if ed then ed:SetWrapMode(wrap) end
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function(event)
        local ed = ide:GetEditor()
        event:Check(ed and ed:GetWrapMode() ~= wxstc.wxSTC_WRAP_NONE)
        event:Enable(ed ~= nil)
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
