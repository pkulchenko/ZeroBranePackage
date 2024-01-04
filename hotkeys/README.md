# HotKeys plugin

This plugin provede a single place to define hot keys for all plugins
Usage:
```Lua
local HotKeys = package_require 'hotkeys.manager'

local Package = {...}

Package.onRegister = function(package)
    HotKeys:add(package, {          'Ctrl-M'}, function() ide:Print('Regular action') end)
    HotKeys:add(package, {'Ctrl-K', 'Ctrl-M'}, function() ide:Print('Chained action') end)
    HotKeys:add(package, {'Ctrl-K',      'M'}, function() ide:Print('Chained hotkey with character') end)
end

Package.onUnRegister = function(package)
    HotKeys:close_package(package)
end

return Package
```

### Installation
1. Copy Lua files to package directory
2. Add to your config (e.g. `user.lua`)
```Lua
if not (...).package_require then
  local package_path = {
    '.',
    'packages/',
    '../packages/',
    MergeFullPath(ide.oshome, '.' .. ide.appname .. '/packages')
  }

  local package_loaded = {}

  (...).package_require = function(m)
    local module = package_loaded[m]
    if module ~= nil then
      if module == false then
        local err = string.format("loop or previous error loading module '%s'", m)
        error(err, 2)
        return
      end
      return module
    end

    package_loaded[m] = false

    local errors = {}
    local rpath = string.gsub(m, '%.', '/') .. '.lua'
    for _, ppath in ipairs(package_path) do
      local full_path = MergeFullPath(ppath, rpath)
      if wx.wxFileExists(full_path) then
        local loader = assert(loadfile(full_path))
        package_loaded[m] = assert(loader(m))
        return package_loaded[m]
      end
      table.insert(errors, string.format("no file '%s'", full_path))
    end

    error(string.format("module '%s' not found:\n\t%s", m, table.concat(errors, '\n\t')), 2)
  end
end
```
