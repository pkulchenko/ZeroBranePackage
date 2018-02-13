-- Copyright 2013 Paul Kulchenko

local script = ([==[
io.stdout:setvbuf('no')
local conf = require 'dist.config'
for k, v in pairs(%s) do conf[k] = v end
for k, v in pairs(%s) do conf.variables[k] = v end
os.exit = function() error('done') end
local s = os.time()
local ok, err = pcall(require('luadist').%s.run, [[%s]], %s)
if not ok and not err:find('done$') then print(err) end
print('Completed in '..(os.time()-s)..' second(s).')]==]):gsub('\n', '; ')

local echoscript = ([==[
print('PATH: ', os.getenv('PATH'))
print('LUA_PATH: ', os.getenv('LUA_PATH'))
print('LUA_CPATH: ', os.getenv('LUA_CPATH'))
print([[params: %s]])
print([[variables: %s]])
--[[%s]]
print([[root: %s]])
print([[libs: %s]])
]==]):gsub('\n', '; ')

local win, mac = ide.osname == 'Windows', ide.osname == 'Macintosh'
local ext = win and 'dll' or 'so'
local distarch = mac and 'Darwin' or win and 'Windows' or 'Linux'
local disttype = ide.osarch
local function serialize(s)
  return require('mobdebug').line(s, {comment = false}):gsub('"',"'") end

local function run(plugin, command, ...)
  local libs = {...}
  local ver = tonumber(libs[1]) and tostring(table.remove(libs, 1)) or '5.1'
  local opt = type(libs[#libs]) == 'table' and table.remove(libs) or {}
  local int = ide:GetConfig().default.interpreter
  local exe = ide:GetInterpreters()[int]:fexepath("")
  local root = plugin:GetConfig().root or MergeFullPath(ide.oshome, 'luadist/'..ver)
  local install = command == 'install'
  local params = {
    distinfos_dir = 'dists',
    source = not (install and (win or mac)),
    arch = distarch,
    type = disttype,
    -- caching doesn't work well when mixing binary and source installs;
    -- can still be enabled manually from `install` call ({cache = true})
    cache = false,
    -- only specify components when installing, otherwise
    -- removing components doesn't work (as only listed ones are removed).
    components = install and {'Runtime', 'Documentation', 'Header', 'Library', 'Unspecified'} or nil,
    -- need to reset all *_dir and *_file references as they are generated
    -- before arch is set, which makes separators not always correct.
    cache_dir      = MergeFullPath('tmp', 'cache'),
    log_file       = MergeFullPath('tmp', 'luadist.log'),
    manifest_file  = MergeFullPath('tmp/cache', '.gitmodules'),
    dep_cache_file = MergeFullPath('tmp/cache', '.depcache'),
    -- "manifest download" has clever logic to figure out root directory
    -- based on package.path, which is not quite correct when Lua5.2 is
    -- the current interpreter; set it explicitly.
    root_dir = root,
  }
  local variables = {
    CMAKE_SHARED_MODULE_CREATE_C_FLAGS = mac and "-bundle -undefined dynamic_lookup" or nil,
    CMAKE_FIND_FRAMEWORK = mac and "LAST" or nil,
    CMAKE_OSX_ARCHITECTURES = mac and "i386 -arch x86_64" or nil,
  }
  -- update manually specified parameters:
  -- upper-case only -- CMake, all others -- LuaDist parameters
  for k,v in pairs(opt) do
    if k:match('^[A-Z_]+$') then variables[k] = v else params[k] = v end
  end

  -- .depcache keeps track of installed modules, but doesn't reset the
  -- cache when switching between binary/source, so when lpeg-0.12 (source)
  -- is in the cache and (binary) is requested, the error is returned.
  -- reset cache timeout to avoid binary/source mismatch
  if not params.cache_timeout and not params.source then
    params.cache_timeout = 0 end

  -- not the best way to hardcode the Lua versions, but LuaDist doesn't
  -- accept lua-5.2 as a version to install and doesn't report the latest.
  local realver = ver == '5.2' and '5.2.2' or '5.1.5'
  local fakedist = MergeFullPath(root, 'dists/lua-'..ver..'/dist.info')
  local realdist = GetFullPathIfExists(root, 'dists/lua-'..realver..'/dist.info')

  if install and #libs > 0 then
    local installlua = libs[1]:find('^lua-')
    if params.source then
      if wx.wxFileExists(fakedist) then
        -- remove file and the folder
        wx.wxRemoveFile(fakedist)
        wx.wxRmdir(GetPathWithSep(fakedist))
      end
      if not realdist then -- maybe a different Lua version installed?
        local distdir = MergeFullPath(root, params.distinfos_dir)
        local candidates = ide:GetFileList(distdir, true, 'dist.info')
        for _, file in ipairs(candidates) do
          local luaver = file:match('[/\\]lua%-([%d%.]+)[/\\]dist.info$')
          if luaver then realver = luaver; break end
        end
      end
      if not installlua then table.insert(libs, 1, 'lua-'..realver) end
    elseif not installlua
    and not wx.wxFileExists(fakedist) and not realdist then
      local distinfo = ('version="%s"\nname="lua"\narch="%s"\ntype="%s"\nfiles={Runtime={}}')
        :format(ver, distarch, disttype)
      local ok, err = FileWrite(fakedist, distinfo)
      if not ok then
        ide:GetConsole():Error(("Can't write dist.info file to '%s': %s")
          :format(fakedist, err))
        return
      end
      table.insert(libs, 1, 'lua-'..ver)
    end
  end

  if command ~= 'help' then
    ide:GetConsole():Print(("Running '%s' for Lua %s in '%s'."):format(command, ver, root))
  end

  local cmd = ('"%s" -e "%s"'):format(
    exe,
    (command == 'echo' and echoscript or script):format(
      serialize(params), serialize(variables), command, root, serialize(libs))
  )

  -- add "clibs" to PATH to allow required DLLs to load
  local _, path = wx.wxGetEnv("PATH")
  if win and path then
    local clibs = MergeFullPath(GetPathWithSep(exe), 'clibs')
    -- set it first in case the current interpreter is Lua 5.2 and PATH is already modified
    wx.wxSetEnv("PATH", clibs..';'..path)
  end
  -- set LUA_DIR as LuaDist sometime picks up proxy liblua,
  -- which is not suitable for linking
  local _, ldir = wx.wxGetEnv("LUA_DIR")
  if win then wx.wxSetEnv("LUA_DIR", root) end

  local workdir = wx.wxFileName.SplitPath(ide.editorFilename)
  CommandLineToShell(CommandLineRun(cmd,workdir,true,false), true)

  -- restore environment
  if win and path then wx.wxSetEnv("PATH", path) end
  if win and ldir then wx.wxSetEnv("LUA_DIR", ldir) end
end

local paths = {}

return {
  name = "LuaDist integration",
  description = "Provides LuaDist integration to install modules from LuaDist.",
  author = "Paul Kulchenko",
  version = 0.21,
  dependencies = "1.70",

  onRegister = function(self)
    -- force loading liblua.dll on windows so that it's available if needed;
    -- load something that requires liblua.dll so that it's in memory and
    -- can be used by modules that require it from local console.
    local _, path = wx.wxGetEnv("PATH")
    if win and path then
      local clibs = ide.osclibs:gsub('%?%.dll','')
      wx.wxSetEnv("PATH", clibs..';'..path)
      local ok = pcall(require, 'git.core')
      wx.wxSetEnv("PATH", path)
      if not ok then
        ide:Print("Couldn't find LuaDist dependency ('git.core'); 'luadist' commands may not work.")
      end
    end

    -- update path/cpath so that LuaDist modules are available from the console
    local root = MergeFullPath(ide.oshome, 'luadist/5.1')
    local lib = MergeFullPath(root, 'lib/lua')
    if not package.path:find(lib, 1, true) then
      package.path = package.path..(';%s/?.lua;%s/?/init.lua'):format(lib, lib)
    end
    if not package.cpath:find(lib, 1, true) then
      package.cpath = package.cpath..(';%s/?.%s'):format(lib, ext)
    end

    -- register all LuaDist commands
    local commands = {}
    for _, command in ipairs({
      'help', 'install', 'remove', 'refresh', 'list', 'info', 'search', 
      'fetch', 'make', 'upload', 'tree', 'selftest', 'echo',
    }) do commands[command] = function(...) return run(self, command, ...) end end

    ide:AddConsoleAlias("luadist", commands)
  end,
  onUnRegister = function(self) ide:RemoveConsoleAlias("luadist") end,

  onInterpreterLoad = function(self, interpreter)
    if not interpreter.luaversion then return end

    local version = tostring(interpreter.luaversion)
    local root = self:GetConfig().root or MergeFullPath(ide.oshome, ('luadist/%s'):format(version))
    local lib = MergeFullPath(root, 'lib/lua')
    local bin = MergeFullPath(root, 'bin')

    -- need to set PATH on windows to allow liblua.dll from LuaDist to load
    -- need to reference bin/, but it may also include liblua.dll if lua
    -- is installed through LuaDist, so put bin/ after clibs/ to make sure
    -- that proxy liblua.dll is loaded instead of the real one.
    local _, path = wx.wxGetEnv("PATH")
    if win and path then
      local clibs = ide.osclibs:gsub('%?%.dll','')
        :gsub('/clibs', '/clibs' .. (version > '5.1' and version:gsub('%.','') or ''))
      wx.wxSetEnv("PATH", clibs..';'..bin..';'..path)
    end

    -- keep "libs" last as luadist dependencies need to be loaded from
    -- the IDE location first as dist/* module has been modified.
    local libs = (';%s/?.%s;'):format(lib, ext)
    local _, lcpath = wx.wxGetEnv('LUA_CPATH')
    if lcpath then wx.wxSetEnv('LUA_CPATH', lcpath..libs) end

    local libs = (';%s/?.lua;%s/?/init.lua;'):format(lib, lib)
    local _, lpath = wx.wxGetEnv('LUA_PATH')
    if lpath then wx.wxSetEnv('LUA_PATH', lpath..libs) end

    paths = {PATH = path, LUA_CPATH = lcpath, LUA_PATH = lpath}
  end,
  onInterpreterClose = function(self, interpreter)
    local version = interpreter.luaversion
    if not version then return end

    for p,v in pairs(paths) do if v then wx.wxSetEnv(p, v) end end
  end,
}
