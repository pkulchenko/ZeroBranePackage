-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

-- based on the moonscript plugin

-- TODO: only activate when in a .fnl file?
-- TODO: how to run a repl vs running the file?

local exe
local win = ide.osname == "Windows"

local fennel = {
  name = "Fennel",
  description = "Fennel runner",
  api = {"baselib"},
  frun = function(self,wfilename)
    exe = exe or ide.config.path.fennel -- check if the path is configured
    if not exe then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('fennel', sep)..sep or ''
      local path = default
        ..(os.getenv('PATH') or '')..sep
        ..(GetPathWithSep(self:fworkdir(wfilename)))..sep
        ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        exe = exe or GetFullPathIfExists(p, win and 'fennel.exe' or 'fennel')
        table.insert(paths, p)
      end
      if not exe then
        ide:Print("Can't find fennel executable in any of the following folders: "
                    ..table.concat(paths, ", "))
        return
      end
    end

    local filepath = wfilename:GetFullPath()
    -- if running on Windows and can't open the file, this may mean that
    -- the file path includes unicode characters that need special handling
    local fh = io.open(filepath, "r")
    if fh then fh:close() end
    if ide.osname == 'Windows' and pcall(require, "winapi")
    and wfilename:FileExists() and not fh then
      winapi.set_encoding(winapi.CP_UTF8)
      filepath = winapi.short_path(filepath)
    end

    local params = ide.config.arg.any or ide.config.arg.fennel
    local code = ([["%s"]]):format(filepath)
    local cmd = '"'..exe..'" '..code..(params and " "..params or "")

    return CommandLineRun(cmd,self:fworkdir(wfilename),true)
  end,
  fprojdir = function(self,wfilename)
    return wfilename:GetPath(wx.wxPATH_GET_VOLUME)
  end,
  fworkdir = function(self,wfilename)
    return ide.config.path.projectdir or wfilename:GetPath(wx.wxPATH_GET_VOLUME)
  end,
  hasdebugger = false,
  skipcompile = true,
  unhideanywindow = true,
  takeparameters = true,
}

return {
  name = "Fennel",
  description = "Implements integration with Fennel language.",
  author = "Phil Hagelberg",
  version = 0.1,
  dependencies = "1.60",

  onRegister = function(self)
    ide:AddInterpreter("fennel", fennel)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter("fennel")
  end,
}

--[[ configuration example:
-- if `fennel` executable is not in PATH, set the path to it manually
path.fennel = "/full/path/to/fennel"
--]]
