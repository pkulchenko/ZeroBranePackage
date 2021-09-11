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

local HotKeys        = package_require 'snippets.hot_keys'
local SnippetManager = package_require 'snippets.manager'

local manager = SnippetManager:new()

local Package = {
  name = "Code snippets",
  description = [[
  Code based on Mitchell Foral' scite-tools pacakage.
]],
  author = "Alexey Melnichuk",
  version = "0.0.1",
  dependencies = "1.80",
}

local actions = {
    insert     = function (editor) manager:insert(editor)                  end,
    prev       = function (editor) manager:prev(editor)                    end,
    cancel     = function (editor) manager:cancel_current(editor)          end,
    cancel_all = function (editor) manager:cancel(editor)                  end,
    list       = function (editor) manager:snippet_list(editor)            end,
    show_scope = function (editor) manager:show_scope(editor)              end,
    finish     = function (editor) manager:finish_current(editor)          end,
    __test     = function (editor) SnippetManager.__self_test__(editor)    end,
}

local function OnTabActivation(self, editor, event)
  local mod = event:GetModifiers()
  if (mod ~= 0) and (mod ~= wx.wxMOD_SHIFT) then
    return true
  end

  local key = event:GetKeyCode()
  if key ~= wx.WXK_TAB then
    return true
  end

  -- tab activation does not work when selected text
  local selections = editor:GetSelections()
  if selections > 1 then
    return true
  end

  if not manager:has_active_snippet(editor) then
    local selection_pos_start, selection_pos_end = editor:GetSelection()
    if selection_pos_start ~= selection_pos_end then
      return true
    end
  end

  if mod == wx.wxMOD_SHIFT then
    if not manager:has_active_snippet(editor) then
      return true
    end
    manager:prev(editor)
    return false
  end

  if manager:insert(editor) then
    return false
  end

  return true
end

Package.onRegister = function(package)
  local config = manager:load_config(package:GetConfig())

  for key, handler in pairs(config.settings.keys) do
    handler = assert(actions[handler], 'Unsupported action: ' .. tostring(handler))
    HotKeys:add(package, key, handler)
  end

  for _, key in ipairs(config:get_key_activators()) do
    HotKeys:add(package, key, function(editor) manager:insert(editor, key) end)
  end

  if config.settings.tab_activation then
    Package.onEditorKeyDown = OnTabActivation
  end
end

Package.onUnRegister = function(package)
  HotKeys:close_package(package)
end

Package.onEditorClose = function(_, editor)
  manager:release(editor)
end

Package.onEditorLoad = function(_, editor)
  manager:cancel(editor)
end

return Package
