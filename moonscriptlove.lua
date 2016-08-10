-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local exe = {moonc = nil, love = nil}
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
  name = "Moonscript LÖVE",
  description = "Moonscript LÖVE interpreter",
  api = {"baselib"},
  frun = function(self,wfilename,rundebug)
    exe.moonc = exe.moonc or ide.config.path.moonc -- check if the path is configured
    if not exe.moonc then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('moonscript', sep)..sep or ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(GetPathWithSep(self:fworkdir(wfilename)))..sep
                 ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        exe.moonc = exe.moonc or GetFullPathIfExists(p, win and 'moonc.exe' or 'moonc')
        table.insert(paths, p)
      end
      if not exe.moonc then
        ide:Print("Can't find moonc executable in any of the following folders: "
          ..table.concat(paths, ", "))
        return
      end
    end
    
    exe.love = exe.love or ide.config.path.love -- check if the path is configured
    if not exe.love then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('love', sep)..sep or ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(GetPathWithSep(self:fworkdir(wfilename)))..sep
                 ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        exe.love = exe.love or GetFullPathIfExists(p, win and 'love.exe' or 'love')
        table.insert(paths, p)
      end
      if not exe.love then
        ide:Print("Can't find love executable in any of the following folders: "
          ..table.concat(paths, ", "))
        return
      end
    end

    local filepath = wfilename:GetFullPath()
    if rundebug then
      DebuggerAttachDefault({
          init = init,
          runstart = ide.config.debugger.runonstart == true,
      })

      rundebug = ('require("mobdebug").start()\nrequire("moonscript").dofile [[%s]]'):format(filepath)

      local tmpfile = wx.wxFileName()
      tmpfile:AssignTempFileName(".")
      filepath = tmpfile:GetFullPath()
      local f = io.open(filepath, "w")
      if not f then
        ide:Print("Can't open temporary file '"..filepath.."' for writing")
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
    local cmd = {}
    cmd.moonc = '"'..exe.moonc..'" -t .moonscript-love "'.. self:fworkdir(wfilename) .. '"' .. (params and " "..params or "")
    cmd.love = '"' .. exe.love .. '" .'

    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    ide:Print("Compiling MoonScript")
    return CommandLineRun(cmd.moonc,self:fworkdir(wfilename), true, false, nil, nil,
      function()
        ide:Print("Starting Love2D")
        CommandLineRun(cmd.love, self:fworkdir(wfilename), true, false, nil, nil, function()
          if rundebug then wx.wxRemoveFile(filepath) end
        end)
      end)
  end,
  hasdebugger = true,
  fattachdebug = function(self) DebuggerAttachDefault({init = init}) end,
  skipcompile = true,
  unhideanywindow = true,
  takeparameters = true,
}

local spec = {
  exts = {"moon"},
  lexer = wxstc.wxSTC_LEX_COFFEESCRIPT,
  apitype = "lua",
  linecomment = "--",
  sep = ".\\",

  -- borrow this logic from the Lua spec
  typeassigns = ide.specs.lua and ide.specs.lua.typeassigns,

  lexerstyleconvert = {
    text = {wxstc.wxSTC_COFFEESCRIPT_IDENTIFIER,},

    lexerdef = {wxstc.wxSTC_COFFEESCRIPT_DEFAULT,},
    comment = {wxstc.wxSTC_COFFEESCRIPT_COMMENT,
      wxstc.wxSTC_COFFEESCRIPT_COMMENTLINE,
      wxstc.wxSTC_COFFEESCRIPT_COMMENTDOC,},
    stringtxt = {wxstc.wxSTC_COFFEESCRIPT_STRING,
      wxstc.wxSTC_COFFEESCRIPT_CHARACTER,
      wxstc.wxSTC_COFFEESCRIPT_LITERALSTRING,},
    stringeol = {wxstc.wxSTC_COFFEESCRIPT_STRINGEOL,},
    preprocessor= {wxstc.wxSTC_COFFEESCRIPT_PREPROCESSOR,},
    operator = {wxstc.wxSTC_COFFEESCRIPT_OPERATOR,},
    number = {wxstc.wxSTC_COFFEESCRIPT_NUMBER,},

    keywords0 = {wxstc.wxSTC_COFFEESCRIPT_WORD,},
    keywords1 = {wxstc.wxSTC_COFFEESCRIPT_WORD2,},
    keywords2 = {wxstc.wxSTC_COFFEESCRIPT_GLOBALCLASS,},
  },

  keywords = {
    [[and break do else elseif end for function if in not or repeat return then until while local ]]
    ..[[super with import export class extends from using continue switch when]],

    [[_G _VERSION _ENV false io.stderr io.stdin io.stdout nil math.huge math.pi self true]],

    [[]],

    [[assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring
      module next pairs pcall print rawequal rawget rawlen rawset require
      select setfenv setmetatable tonumber tostring type unpack xpcall
      bit32.arshift bit32.band bit32.bnot bit32.bor bit32.btest bit32.bxor bit32.extract
      bit32.lrotate bit32.lshift bit32.replace bit32.rrotate bit32.rshift
      coroutine.create coroutine.resume coroutine.running coroutine.status coroutine.wrap coroutine.yield
      debug.debug debug.getfenv debug.gethook debug.getinfo debug.getlocal
      debug.getmetatable debug.getregistry debug.getupvalue debug.getuservalue debug.setfenv
      debug.sethook debug.setlocal debug.setmetatable debug.setupvalue debug.setuservalue
      debug.traceback debug.upvalueid debug.upvaluejoin
      io.close io.flush io.input io.lines io.open io.output io.popen io.read io.tmpfile io.type io.write
      close flush lines read seek setvbuf write
      math.abs math.acos math.asin math.atan math.atan2 math.ceil math.cos math.cosh math.deg math.exp
      math.floor math.fmod math.frexp math.ldexp math.log math.log10 math.max math.min math.modf
      math.pow math.rad math.random math.randomseed math.sin math.sinh math.sqrt math.tan math.tanh
      os.clock os.date os.difftime os.execute os.exit os.getenv os.remove os.rename os.setlocale os.time os.tmpname
      package.loadlib package.searchpath package.seeall package.config
      package.cpath package.loaded package.loaders package.path package.preload package.searchers
      string.byte string.char string.dump string.find string.format string.gmatch string.gsub string.len
      string.lower string.match string.rep string.reverse string.sub string.upper
      byte find format gmatch gsub len lower match rep reverse sub upper
      table.concat table.insert table.maxn table.pack table.remove table.sort table.unpack]]
  },
}

local name = 'moonscriptlove'
return {
  name = "Moonscript LÖVE",
  description = "Compile and run Moonscript with LÖVE",
  author = "Paul Kulchenko, Dominik \"Zatherz\" Banaszak",
  version = 0.31,
  dependencies = "1.30",

  onRegister = function(self)
    ide:AddInterpreter(name, interpreter)
    ide:AddSpec(name, spec)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter(name)
    ide:RemoveSpec(name)
  end,
}
