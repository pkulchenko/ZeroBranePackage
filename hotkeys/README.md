# HotKeys plugin

This plugin provede a single place to define hot keys for all plugins
Usage:
```
local HotKeys = require 'hotkeys.storage'

local Package = {...}

Package.onRegister = function(package)
    HotKeys:add(package, {          'Ctrl-M'}, function() ide:Print('Regular action') end)
    HotKeys:add(package, {'Ctrl-K', 'Ctrl-M'}, function() ide:Print('Chained action') end)
end

Package.onUnRegister = function(package)
    HotKeys:close_package(package)
end

return Package
```