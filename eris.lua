local function makeErisInterpreter( version, name, basename )
basename = basename or 'lua'

assert( basename:match( '^%l+$' ), 'Executable basename must be all lowercase' )

local capbasename = basename:sub( 1, 1 ):upper() .. basename:sub( 2 )

local function exePath(self, version)
  local version = tostring(version or ""):gsub('%.','')
  local mainpath = ide:GetRootPath()
  local macExe = mainpath..([[bin/%s.app/Contents/MacOS/%s%s]]):format(basename, basename, version)
  return (ide.config.path[basename..version]
    or (ide.osname == "Windows" and mainpath..([[bin\%s%s.exe]]):format(basename, version))
    or (ide.osname == "Unix" and mainpath..([[bin/linux/%s/%s%s]]):format(ide.osarch, basename, version))
    or (wx.wxFileExists(macExe) and macExe or mainpath..([[bin/%s%s]]):format(basename, version))),
  ide.config.path[basename..version] ~= nil
end

return {
  name = ("%s%s"):format(capbasename, name or version or ""),
  description = ("%s%s interpreter with debugger"):format(capbasename, name or version or ""),
  api = {"baselib"},
  luaversion = version or '5.1',
  fexepath = exePath,
  frun = function(self,wfilename,rundebug)
    local exe, iscustom = self:fexepath(version or "")
    local filepath = wfilename:GetFullPath()

    do
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if ide.osname == 'Windows' and pcall(require, "winapi")
      and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        local shortpath = winapi.short_path(filepath)
        if shortpath == filepath then
          ide:Print(
            ("Can't get short path for a Unicode file name '%s' to open the file.")
            :format(filepath))
          ide:Print(
            ("You can enable short names by using `fsutil 8dot3name set %s: 0` and recreate the file or directory.")
            :format(wfilename:GetVolume()))
        end
        filepath = shortpath
      end
    end

    if rundebug then
      ide:GetDebugger():SetOptions({runstart = ide.config.debugger.runonstart == true})

      -- update arg to point to the proper file
      rundebug = ('if arg then arg[0] = [[%s]] end '):format(filepath)..rundebug

      local tmpfile = wx.wxFileName()
      tmpfile:AssignTempFileName(".")
      filepath = tmpfile:GetFullPath()
      local f = io.open(filepath, "w")
      if not f then
        ide:Print("Can't open temporary file '"..filepath.."' for writing.")
        return
      end
      f:write(rundebug)
      f:close()
    end
    local params = self:GetCommandLineArg("lua")
    local code = ([[-e "io.stdout:setvbuf('no')" "%s"]]):format(filepath)
    local cmd = '"'..exe..'" '..code..(params and " "..params or "")

    -- modify CPATH to work with other Lua versions
    local envname = "LUA_CPATH"
    if version then
      local env = "LUA_CPATH_"..string.gsub(version, '%.', '_')
      if os.getenv(env) then envname = env end
    end

    local cpath = os.getenv(envname)
    if rundebug and cpath and not iscustom then
      -- prepend osclibs as the libraries may be needed for debugging,
      -- but only if no path.lua is set as it may conflict with system libs
      wx.wxSetEnv(envname, ide.osclibs..';'..cpath)
    end
    if version and cpath then
      local cpath = os.getenv(envname)
      local clibs = string.format('/clibs%s/', version):gsub('%.','')
      if not cpath:find(clibs, 1, true) then cpath = cpath:gsub('/clibs/', clibs) end
      wx.wxSetEnv(envname, cpath)
    end

    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    local pid = CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil,
      function() if rundebug then wx.wxRemoveFile(filepath) end end)

    if (rundebug or version) and cpath then wx.wxSetEnv(envname, cpath) end
    return pid
  end,
  hasdebugger = true,
  scratchextloop = false,
  unhideanywindow = true,
  takeparameters = true,
}
end

return {
	name = "Eris",
	description = "Integration with the Lua + Eris interpreter (5.3)",
	author = "raingloom",
	version = 0.1,
	onRegister = function()
		ide:AddInterpreter( 'eris53', makeErisInterpreter(5.3, '5.3', 'eris'))
		ide:AddInterpreter( 'eris53', makeErisInterpreter(5.3, '5.3', 'eris'))
	end,
	onUnRegister = function()
		ide:RemoveInterpreter( 'eris53' )
	end,
	--TODO: ????
}