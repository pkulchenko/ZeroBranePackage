-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local exe
local win = ide.osname == "Windows"

local init = [=[
(loadstring or load)([[
if pcall(require, "mobdebug") then
  io.stdout:setvbuf('no')
  local cache = {}
  local lt = require("moonscript.line_tables")
  local rln = require("moonscript.errors").reverse_line_number
  local mdb = require "mobdebug"
  mdb.linemap = function(line, src)
    return src:find('%.moon$') and (tonumber(lt[src] and rln(src:gsub("^@",""), lt[src], line, cache) or line) or 1) or nil
  end
  mdb.loadstring = require("moonscript").loadstring
end
]])()
]=]

local interpreter = {
  name = "Moonscript",
  description = "Moonscript interpreter",
  api = {"baselib"},
  frun = function(self,wfilename,rundebug)
    exe = exe or ide.config.path.moonscript -- check if the path is configured
    if not exe then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('moonscript', sep)..sep or ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(GetPathWithSep(self:fworkdir(wfilename)))..sep
                 ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        exe = exe or GetFullPathIfExists(p, win and 'moon.exe' or 'moon')
        table.insert(paths, p)
      end
      if not exe then
        ide:Print("Can't find moonscript executable in any of the following folders: "
          ..table.concat(paths, ", "))
        return
      end
    end

    local filepath = wfilename:GetFullPath()
    if rundebug then
      ide:GetDebugger():SetOptions({
          init = init,
          runstart = ide.config.debugger.runonstart == true,
      })

      rundebug = ('require("mobdebug").start()\nrequire("moonscript").dofile [[%s]]'):format(filepath)

      local tmpfile = wx.wxFileName()
      tmpfile:AssignTempFileName(".")
      filepath = tmpfile:GetFullPath()
      local f = io.open(filepath, "w")
      if not f then
        ide:Print("Can't open temporary file '"..filepath.."' for writing.")
        return
      end
      f:write(init..rundebug)
      f:close()
    else
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if ide.osname == 'Windows' and pcall(require, "winapi")
      and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        filepath = winapi.short_path(filepath)
      end
    end
    local params = ide.config.arg.any or ide.config.arg.moonscript
    local code = ([["%s"]]):format(filepath)
    local cmd = '"'..exe..'" '..code..(params and " "..params or "")

    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    return CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil,
      function() if rundebug then wx.wxRemoveFile(filepath) end end)
  end,
  fprojdir = function(self,wfilename)
    return wfilename:GetPath(wx.wxPATH_GET_VOLUME)
  end,
  fworkdir = function(self,wfilename)
    return ide.config.path.projectdir or wfilename:GetPath(wx.wxPATH_GET_VOLUME)
  end,
  hasdebugger = true,
  fattachdebug = function(self) ide:GetDebugger():SetOptions({init = init}) end,
  skipcompile = true,
  unhideanywindow = true,
  takeparameters = true,
}

local name = 'moonscript'
return {
  name = "Moonscript",
  description = "Integration with Moonscript language",
  author = "Paul Kulchenko",
  version = 0.34,
  dependencies = "1.60",

  onRegister = function(self)
    ide:AddInterpreter(name, interpreter)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter(name)
  end,
}

--[[ configuration example:
-- if `moon` executable is not in PATH, set the path to it manually
path.moonscript = "/full/path/moon.exe"
--]]
