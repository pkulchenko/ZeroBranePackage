local id = ID("projectsettings.settingsmenu")
local filename
return {
  name = "Project settings",
  description = "Adds project settings loaded on project switch.",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.30",

  onRegister = function(self)
    local menu = ide:FindTopMenu("&Edit")
    local prefs = menu:FindItem(ID.PREFERENCES):GetSubMenu()
    menuid = prefs:Append(id, "Settings: Project")

    local config = self:GetConfig()
    filename = config.filename or {'.zbstudio/user.lua'}
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event)
        local project = ide:GetProject()
        if not project then return end
        for _, file in pairs(filename) do
          LoadFile(MergeFullPath(project, file))
        end
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Enable(#filename > 0) end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,

  onProjectPreLoad = function(self, project) ide:AddConfig(project, filename) end,
  onProjectClose = function(self, project) ide:RemoveConfig(project) end,
}
