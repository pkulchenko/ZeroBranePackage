-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local G = ...
local id = G.ID("evalinconsole.evalinconsole")
local menuid
return {
  name = "Evaluate in console",
  description = "Evaluates selected fragment in console.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = 0.80,

  onRegister = function(self)
    local menu = ide:FindMenuItem(ID_SOURCE):GetSubMenu()
    menu:Append(id, "Evaluate in Console"..KSC(id, "Ctrl-E"))
    menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function () ShellExecuteCode(GetEditor():GetSelectedText()) end)
    menu:Connect(id, wx.wxEVT_UPDATE_UI,
      function (event) event:Enable(GetEditor() and #GetEditor():GetSelectedText() > 0) end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,
}
