local win = ide.osname == 'Windows'

local debinit = [[
local mdb = require('mobdebug')
local line = mdb.line
mdb.line = function(...)
  local r = line(...)
  return type(r) == 'string' and loadstring("return "..r)() or r
end]]

local qlua
local qluaInterpreter = {
  name = "QLua-LuaJIT",
  description = "Qt hooks for luajit",
  api = {"baselib", "qlua"},
  frun = function(self,wfilename,rundebug)
    qlua = qlua or ide.config.path.qlua -- check if the path is configured
    -- Go search for qlua
    if not qlua then
      local sep = win and ';' or ':'
      local default = ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(os.getenv('QLUA_BIN') or '')..sep
                 ..(os.getenv('HOME') and os.getenv('HOME') .. '/bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        qlua = qlua or GetFullPathIfExists(p, 'qlua')
        table.insert(paths, p)
      end
      if not qlua then
        DisplayOutput("Can't find qlua executable in any of the folders in PATH or QLUA_BIN: "
          ..table.concat(paths, ", ").."\n")
        return
      end
    end

    -- make minor modifications to the cpath to take care of OSX
    -- make sure the root is using Torch exe location
    local torchroot = MergeFullPath(GetPathWithSep(qlua), "../")
    local tluapath = ''
    for _, val in pairs({"share/lua/5.1/?.lua", "share/lua/5.1/?/init.lua", "./?.lua", "./?/init.lua"}) do
      tluapath = tluapath .. MergeFullPath(torchroot, val) .. ";"
    end
    local _, luapath = wx.wxGetEnv("LUA_PATH")
    wx.wxSetEnv("LUA_PATH", tluapath..(#luapath > 0 and luapath or ""))

    local ext = win and 'dll' or ide.osname == 'Macintosh' and 'dylib' or 'so'
    local tluacpath = ''
    for _, val in pairs({"lib/lua/5.1/?."..ext, "lib/lua/5.1/loadall."..ext, "?."..ext}) do
      tluacpath = tluacpath .. MergeFullPath(torchroot, val) .. ";"
    end
    local _, luacpath = wx.wxGetEnv("LUA_CPATH")
    wx.wxSetEnv("LUA_CPATH", tluacpath..(#luacpath > 0 and luacpath or ""))

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

    for env, val in ipairs({LUA_PATH = luapath, LUA_CPATH = luacpath}) do
      if val then
        if #val > 0 then wx.wxSetEnv(env, val) else wx.wxUnsetEnv(env) end
      end
    end
    return pid
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault() end,
  scratchextloop = true,
}

local torch
local torchInterpreter = {
  name = "Torch-7",
  description = "Torch machine learning package",
  api = {"baselib", "torch"},
  frun = function(self,wfilename,rundebug)
    local sep = win and ';' or ':'
    torch = torch or ide.config.path.torch -- check if the path is configured
    -- go search for torch
    if not torch then
      local default = ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(os.getenv('TORCH_BIN') or '')..sep
                 ..(os.getenv('HOME') and os.getenv('HOME') .. '/bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        torch = torch or GetFullPathIfExists(p, (win and 'th.bat ' or 'th'))
        table.insert(paths, p)
      end
      
      if not torch then
        DisplayOutput("Can't find torch executable in any of the folders in PATH or TORCH_BIN: "
          ..table.concat(paths, ", ").."\n")
        return
      end
    end

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
    local tluapath = ''
    for _, val in pairs({"share/lua/5.1/?.lua", "share/lua/5.1/?/init.lua", "./?.lua", "./?/init.lua"}) do
      tluapath = tluapath .. MergeFullPath(torchroot, val) .. ";"
    end
    local _, luapath = wx.wxGetEnv("LUA_PATH")
    wx.wxSetEnv("LUA_PATH", tluapath..(#luapath > 0 and luapath or ""))

    local ext = win and 'dll' or ide.osname == 'Macintosh' and 'dylib' or 'so'
    local tluacpath = ''
    for _, val in pairs({"lib/lua/5.1/?."..ext, "lib/lua/5.1/loadall."..ext, "?."..ext}) do
      tluacpath = tluacpath .. MergeFullPath(torchroot, val) .. ";"
    end
    local _, luacpath = wx.wxGetEnv("LUA_CPATH")
    wx.wxSetEnv("LUA_CPATH", tluacpath..(#luacpath > 0 and luacpath or ""))

    local _, path = wx.wxGetEnv("PATH")
    wx.wxSetEnv("PATH", torchroot..(#path > 0 and sep..path or ""))

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

    for env, val in ipairs({LUA_PATH = luapath, LUA_CPATH = luacpath, PATH = path}) do
      if val then
        if #val > 0 then wx.wxSetEnv(env, val) else wx.wxUnsetEnv(env) end
      end
    end
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
  version = 0.46,
  dependencies = 1.10,

  onRegister = function(self)
    ide:AddInterpreter("torch", torchInterpreter)
    ide:AddInterpreter("qlua", qluaInterpreter)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter("torch")
    ide:RemoveInterpreter("qlua")
  end,
}
