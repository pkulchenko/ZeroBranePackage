local HotKeys = package_require 'hotkeys.manager'

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
    return HotKeys:onEditorKeyDown(editor, event)
  end,

  onEditorKey = function(self, editor, event)
    return HotKeys:onEditorKey(editor, event)
  end,

  -- TODO need this in case of show current chain in status bar
  -- onIdle = function(self, editor, event)
  --   return HotKeys:onIdle(editor, event)
  -- end,
}
