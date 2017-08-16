-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local winapi

local flags

local needrefresh = {}
local function refreshProjectTree()
  for file, kind in pairs(needrefresh) do
    -- if the file is removed, try to find a non-existing file in the same folder
    -- as this will trigger a refresh of that folder
    ide:GetProjectTree():FindItem(
      file..(kind == winapi.FILE_ACTION_REMOVED and "/../\1"  or ""))
  end
  needrefresh = {}
end
local function handler(plugin, kind, file)
  needrefresh[file] = kind
  plugin.onIdleOnce = refreshProjectTree
end

local watches = {}
return {
  name = "Refresh project tree",
  description = "Refresh project tree when files change (Windows only).",
  author = "Paul Kulchenko",
  version = 0.2,
  dependencies = {0.71, osname = "Windows"},

  onRegister = function(self)
    local ok
    ok, winapi = pcall(require, 'winapi')
    if not ok then return false end
	flags = winapi.FILE_NOTIFY_CHANGE_DIR_NAME + winapi.FILE_NOTIFY_CHANGE_FILE_NAME
  end,

  onIdle = function(self) if next(watches) then winapi.sleep(1) end end,

  onProjectLoad = function(plugin, project)
    if watches[project] then return end

    for _, watcher in pairs(watches) do watcher:kill() end
    watches = {}

    local enc = winapi.get_encoding(winapi.CP_UTF8)
    winapi.set_encoding(winapi.CP_UTF8)
    local watcher, err = winapi.watch_for_file_changes(project, flags, true,
      function(...) return handler(plugin, ...) end)
    winapi.set_encoding(enc)

    if not watcher then
      error(("Can't set watcher for project '%s': %s"):format(project, err))
    end
    watches[project] = watcher
  end,
}
