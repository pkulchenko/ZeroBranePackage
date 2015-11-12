local win = ide.osname == 'Windows'
local sep = win and ';' or ':'

local debinit = [[
local mdb = require('mobdebug')
local line = mdb.line
mdb.line = function(...)
  local r = line(...)
  return type(r) == 'string' and loadstring("return "..r)() or r
end]]

local function setEnv(torchroot)
  local tluapath = ''
  for _, val in pairs({"share/lua/5.1/?.lua", "share/lua/5.1/?/init.lua", "./?.lua", "./?/init.lua"}) do
    tluapath = tluapath .. MergeFullPath(torchroot, val) .. ";"
  end
  local _, luapath = wx.wxGetEnv("LUA_PATH")
  wx.wxSetEnv("LUA_PATH", tluapath..(#luapath > 0 and luapath or ""))

  local ext = win and 'dll' or 'so'
  local tluacpath = ''
  for _, val in pairs({"lib/lua/5.1/?."..ext, "lib/lua/5.1/loadall."..ext, "?."..ext}) do
    tluacpath = tluacpath .. MergeFullPath(torchroot, val) .. ";"
  end
  local _, luacpath = wx.wxGetEnv("LUA_CPATH")
  wx.wxSetEnv("LUA_CPATH", tluacpath..(#luacpath > 0 and luacpath or ""))

  local _, path = wx.wxGetEnv("PATH")
  wx.wxSetEnv("PATH", torchroot..(#path > 0 and sep..path or ""))

  return {LUA_PATH = luapath, LUA_CPATH = luacpath, PATH = path}
end

local function unsetEnv(env)
  for env, val in ipairs(env) do
    if val then
      if #val > 0 then wx.wxSetEnv(env, val) else wx.wxUnsetEnv(env) end
    end
  end
end

local function findCmd(cmd, env)
  local path = (os.getenv('PATH') or '')..sep
             ..(env or '')..sep
             ..(os.getenv('HOME') and os.getenv('HOME') .. '/bin' or '')
  local paths = {}
  local res
  for p in path:gmatch("[^"..sep.."]+") do
    res = res or GetFullPathIfExists(p, cmd)
    table.insert(paths, p)
  end

  if not torch then
    DisplayOutput(("Can't find %s in any of the folders in PATH or TORCH_BIN: "):format(cmd)
      ..table.concat(paths, ", ").."\n")
    return
  end
  return res
end

local qluaInterpreter = {
  name = "QLua-LuaJIT",
  description = "Qt hooks for luajit",
  api = {"baselib", "qlua"},
  frun = function(self,wfilename,rundebug)
    local qlua = ide.config.path.qlua or findCmd('qlua', os.getenv('QLUA_BIN'))
    if not qlua then return end

    -- make minor modifications to the cpath to take care of OSX
    -- make sure the root is using Torch exe location
    local torchroot = MergeFullPath(GetPathWithSep(qlua), "../")
    local env = setEnv(torchroot)

    local filepath = wfilename:GetFullPath()
    local script
    if rundebug then
      DebuggerAttachDefault({runstart = ide.config.debugger.runonstart == true, init = debinit})
      script = rundebug
    else
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if win and pcall(require, "winapi")
      and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        filepath = winapi.short_path(filepath)
      end

      script = ('dofile [[%s]]'):format(filepath)
    end
    local code = ([[xpcall(function() io.stdout:setvbuf('no'); %s end,function(err) print(debug.traceback(err)) end)]]):format(script)
    local cmd = '"'..qlua..'" -e "'..code..'"'
    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    local pid = CommandLineRun(cmd,self:fworkdir(wfilename),true,false)
    unsetEnv(env)
    return pid
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  scratchextloop = true,
}

local torchInterpreter = {
  name = "Torch-7",
  description = "Torch machine learning package",
  api = {"baselib", "torch"},
  frun = function(self,wfilename,rundebug)
    -- check if the path is configured
    local torch = ide.config.path.torch or findCmd(win and 'th.bat ' or 'th', os.getenv('TORCH_BIN'))
    if not torch then return end

    local filepath = wfilename:GetFullPath()
    if rundebug then
      DebuggerAttachDefault({runstart = ide.config.debugger.runonstart == true, init = debinit})
      -- update arg to point to the proper file
      rundebug = ('if arg then arg[0] = [[%s]] end '):format(filepath)..rundebug

      local tmpfile = wx.wxFileName()
      tmpfile:AssignTempFileName(".")
      filepath = tmpfile:GetFullPath()
      local f = io.open(filepath, "w")
      if not f then
        DisplayOutputLn("Can't open temporary file '"..filepath.."' for writing.")
        return
      end
      f:write("io.stdout:setvbuf('no'); " .. rundebug)
      f:close()
    else
      -- if running on Windows and can't open the file, this may mean that
      -- the file path includes unicode characters that need special handling
      local fh = io.open(filepath, "r")
      if fh then fh:close() end
      if win and pcall(require, "winapi")
      and wfilename:FileExists() and not fh then
        winapi.set_encoding(winapi.CP_UTF8)
        filepath = winapi.short_path(filepath)
      end
    end

    -- make sure the root is using Torch exe location
    -- for non-exe configurations, it's allowed to pass Torch path
    local uselua = wx.wxDirExists(torch)
    local torchroot = uselua and torch or MergeFullPath(GetPathWithSep(torch), "../")
    local env = setEnv(torchroot)

    local params = ide.config.arg.any or ide.config.arg.lua or ''
    local cmd = ([["%s" "%s" %s]]):format(
      uselua and ide:GetInterpreters().luadeb:fexepath("") or torch, filepath, params)
    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    local pid = CommandLineRun(cmd,self:fworkdir(wfilename),true,false,
      function(s) -- provide string callback to eliminate backspaces from Torch output
        while s:find("\b") do
          s = s
            :gsub("[^\b\r\n]\b","") -- remove a backspace and a previous character
            :gsub("^\b+","") -- remove all leading backspaces (if any)
            :gsub("([\r\n])\b+","%1") -- remove a backspace and a previous character
        end
        return s
      end, nil,
      function()
        if rundebug then wx.wxRemoveFile(filepath) end
      end
    )
    unsetEnv(env)
    return pid
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  scratchextloop = true,
}

return {
  name = "Torch7",
  description = "Integration with torch7 environment",
  author = "Paul Kulchenko",
  version = 0.47,
  dependencies = 1.10,

  onRegister = function(self)
    ide:AddInterpreter("torch", torchInterpreter)
    ide:AddInterpreter("qlua", qluaInterpreter)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter("torch")
    ide:RemoveInterpreter("qlua")
  end,

  onInterpreterLoad = function(self, interpreter)
    if interpreter:GetFileName() ~= "torch" then return end
    local torch = ide.config.path.torch or findCmd(win and 'th.bat ' or 'th', os.getenv('TORCH_BIN'))
    local uselua = wx.wxDirExists(torch)
    local torchroot = uselua and torch or MergeFullPath(GetPathWithSep(torch), "../")
    interpreter.env = setEnv(torchroot)
  end,
  onInterpreterClose = function(self, interpreter)
    if interpreter:GetFileName() ~= "torch" then return end
    if interpreter.env then unsetEnv(interpreter.env) end
  end,
}
