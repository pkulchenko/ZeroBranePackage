if not package_require then
  local package_path = {
    '.',
    'packages/',
    '../packages/',
    MergeFullPath(ide.oshome, '.' .. ide.appname .. '/packages')
  }

  local package_loaded = {}

  function package_require(m)
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

local HotKeys = package_require 'hotkeys.storage'

return {
  name = "HotKeys",
  description = "Support single place to manage all hot keys for all plagins.",
  author = "Alexey Melnichuk",
  version = '0.0.1',
  dependencies = "1.70",

  onRegister = function(package)end,

  onUnRegister = function(package)
    error('can not be unloaded')
  end,

  onEditorKeyDown = function(self, editor, event)
    if event:GetModifiers() == 0  and event:GetKeyCode() == wx.WXK_ESCAPE then
      HotKeys:clear_chain()
    end

    return true
  end
}
