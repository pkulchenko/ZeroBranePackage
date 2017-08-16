-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local winapi

local function setvalue(key, name, val)
  local k, err = winapi.create_reg_key(key)
  k, err = winapi.open_reg_key(key, true)
  if not k then
    ide:Print(("Failed to create key %s: %s"):format(key, err))
    return
  end
  if not k:set_value(name, val, winapi.REG_SZ) then
    ide:Print(("Failed to update key %s"):format(key))
    return
  end
  ide:Print(("Registered '%s'"):format(key))
  return true
end

local function register()
  local exts = ide:GetKnownExtensions()
  if #exts == 0 then
    ide:Print("No known extensions to register.")
    return
  end

  local extensions = table.concat(exts, ", ")
  extensions = wx.wxGetTextFromUser("Enter extensions to associate with the IDE",
    "Register extensions", extensions)

  if #extensions == 0 then return end
  ide:Print(("Registering extensions '%s' for the current user.")
    :format(extensions))

  if not setvalue([[HKEY_CURRENT_USER\Software\Classes\ZeroBrane.Studio\shell\edit\command]],
    "", ide:GetRootPath('zbstudio.exe')..[[ "%1"]]) then
    return
  end
  for ext in extensions:gmatch("(%w+)") do
    if not setvalue(([[HKEY_CURRENT_USER\Software\Classes\.%s]]):format(ext),
      "", [[ZeroBrane.Studio]])
    or not setvalue(([[HKEY_CURRENT_USER\Software\Classes\.%s\OpenWithProgids]]):format(ext),
      [[ZeroBrane.Studio]], "") then
      return
    end
  end
end

return {
  name = "Extension register",
  description = "Registers known extensions to launch the IDE on Windows.",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = {"1.30", osname = "Windows"},

  onRegister = function(self)
    local ok
    ok, winapi = pcall(require, 'winapi')
    if not ok then return false end

    ide:AddTool("Register Known Extensions", register)
  end,

  onUnRegister = function(self)
    ide:RemoveTool("Register Known Extensions")
  end,
}
