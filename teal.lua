-- Copyright 2022 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local exe
local win = ide.osname == "Windows"

local init = [=[
(loadstring or load)([[
if pcall(require, "mobdebug") then
  io.stdout:setvbuf('no')
  local cache = {}
  local lt = require("teal.line_tables")
  local rln = require("teal.errors").reverse_line_number
  local mdb = require "mobdebug"
  mdb.linemap = function(line, src)
    return src:find('%.tl$') and (tonumber(lt[src] and rln(src:gsub("^@",""), lt[src], line, cache) or line) or 1) or nil
  end
  mdb.loadstring = require("tl").loadstring
end
]])()
]=]

local interpreter = {
  name = "Teal",
  description = "Teal interpreter",
  api = {"baselib"},
  frun = function(self,wfilename,rundebug)
    exe = exe or ide.config.path.teal -- check if the path is configured
    if not exe then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('teal', sep)..sep or ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..(GetPathWithSep(self:fworkdir(wfilename)))..sep
                 ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        exe = exe or GetFullPathIfExists(p, win and 'tl.exe' or 'tl')
        table.insert(paths, p)
      end
      if not exe then
        ide:Print("Can't find Teal executable in any of the following folders: "
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

      rundebug = ('require("mobdebug").start()\nrequire("teal").dofile [[%s]]'):format(filepath)

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
    local cmd = '"'..exe..'" run '..code..(params and " "..params or "")

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


local teallexer = [=[
-- Teal lexer.
-- Currently a slightly modified copy of the lua lexer
local lexer = require('lexer')
local token, word_match = lexer.token, lexer.word_match
local P, S = lpeg.P, lpeg.S

local lex = lexer.new('teal')

-- Whitespace.
lex:add_rule('whitespace', token(lexer.WHITESPACE, lexer.space^1))

-- Keywords.
lex:add_rule('keyword', token(lexer.KEYWORD, word_match[[
  and break do else elseif end false for function if in local global not or repeat
  return then true until while
  -- Added in 5.2.
  goto
]]))

-- Functions and deprecated functions.
local func = token(lexer.FUNCTION, word_match[[
  assert collectgarbage dofile error getmetatable ipairs load loadfile next
  pairs pcall print rawequal rawget rawset require select setmetatable tonumber
  tostring xpcall
  -- Added in 5.2.
  rawlen
]])
local typefunc = token(lexer.FUNCTION, lpeg.P("type("))
local deprecated_func = token('deprecated_function', word_match[[
  -- Deprecated in 5.2.
  getfenv loadstring module setfenv unpack
]])
lex:add_rule('function', func + typefunc + deprecated_func)
lex:add_style(
  'deprecated_function', lexer.styles['function'] .. {italics = true})

-- Constants.
lex:add_rule('constant', token(lexer.CONSTANT, word_match[[
  _G _VERSION
  -- Added in 5.2.
  _ENV
]]))

-- Libraries and deprecated libraries.
local library = token('library', word_match[[
  -- Coroutine.
  coroutine coroutine.create coroutine.resume coroutine.running coroutine.status
  coroutine.wrap coroutine.yield
  -- Coroutine added in 5.3.
  coroutine.isyieldable
  -- Module.
  package package.cpath package.loaded package.loadlib package.path
  package.preload
  -- Module added in 5.2.
  package.config package.searchers package.searchpath
  -- UTF-8 added in 5.3.
  utf8 utf8.char utf8.charpattern utf8.codepoint utf8.codes utf8.len utf8.offset
  -- String.
  string.byte string.char string.dump string.find string.format
  string.gmatch string.gsub string.len string.lower string.match string.rep
  string.reverse string.sub string.upper
  -- String added in 5.3.
  string.pack string.packsize string.unpack
  -- Table.
  table table.concat table.insert table.remove table.sort
  -- Table added in 5.2.
  table.pack table.unpack
  -- Table added in 5.3.
  table.move
  -- Math.
  math math.abs math.acos math.asin math.atan math.ceil math.cos math.deg
  math.exp math.floor math.fmod math.huge math.log math.max math.min math.modf
  math.pi math.rad math.random math.randomseed math.sin math.sqrt math.tan
  -- Math added in 5.3.
  math.maxinteger math.mininteger math.tointeger math.type math.ult
  -- IO.
  io io.close io.flush io.input io.lines io.open io.output io.popen io.read
  io.stderr io.stdin io.stdout io.tmpfile io.type io.write
  -- OS.
  os os.clock os.date os.difftime os.execute os.exit os.getenv os.remove
  os.rename os.setlocale os.time os.tmpname
  -- Debug.
  debug debug.debug debug.gethook debug.getinfo debug.getlocal
  debug.getmetatable debug.getregistry debug.getupvalue debug.sethook
  debug.setlocal debug.setmetatable debug.setupvalue debug.traceback
  -- Debug added in 5.2.
  debug.getuservalue debug.setuservalue debug.upvalueid debug.upvaluejoin
]])
local deprecated_library = token('deprecated_library', word_match[[
  -- Module deprecated in 5.2.
  package.loaders package.seeall
  -- Table deprecated in 5.2.
  table.maxn
  -- Math deprecated in 5.2.
  math.log10
  -- Math deprecated in 5.3.
  math.atan2 math.cosh math.frexp math.ldexp math.pow math.sinh math.tanh
  -- Bit32 deprecated in 5.3.
  bit32 bit32.arshift bit32.band bit32.bnot bit32.bor bit32.btest bit32.extract
  bit32.lrotate bit32.lshift bit32.replace bit32.rrotate bit32.rshift bit32.xor
  -- Debug deprecated in 5.2.
  debug.getfenv debug.setfenv
]])
lex:add_rule('library', library + deprecated_library)
lex:add_style('library', lexer.styles.type)
lex:add_style('deprecated_library', lexer.styles.type .. {italics = true})

-- Types
lex:add_rule('type', token(lexer.TYPE, word_match[[
  any nil boolean integer number string thread enum record type
]]))

-- Identifiers.
lex:add_rule('identifier', token(lexer.IDENTIFIER, lexer.word))

local longstring = lpeg.Cmt('[' * lpeg.C(P('=')^0) * '[',
  function(input, index, eq)
    local _, e = input:find(']' .. eq .. ']', index, true)
    return (e or #input) + 1
  end)

-- Strings.
local sq_str = lexer.range("'")
local dq_str = lexer.range('"')
lex:add_rule('string', token(lexer.STRING, sq_str + dq_str) +
  token('longstring', longstring))
lex:add_style('longstring', lexer.styles.string)

-- Comments.
local line_comment = lexer.to_eol('--')
local block_comment = '--' * longstring
lex:add_rule('comment', token(lexer.COMMENT, block_comment + line_comment))

-- Numbers.
local lua_integer = P('-')^-1 * (lexer.hex_num + lexer.dec_num)
lex:add_rule('number', token(lexer.NUMBER, lexer.float + lua_integer))

-- Labels.
lex:add_rule('label', token(lexer.LABEL, '::' * lexer.word * '::'))

-- Operators.
lex:add_rule('operator', token(lexer.OPERATOR, '..' +
  S('+-*/%^#=<>&|~;:,.{}[]()')))

-- Fold points.
local function fold_longcomment(text, pos, line, s, symbol)
  if symbol == '[' then
    if line:find('^%[=*%[', s) then return 1 end
  elseif symbol == ']' then
    if line:find('^%]=*%]', s) then return -1 end
  end
  return 0
end
lex:add_fold_point(lexer.KEYWORD, 'if', 'end')
lex:add_fold_point(lexer.KEYWORD, 'do', 'end')
lex:add_fold_point(lexer.KEYWORD, 'function', 'end')
lex:add_fold_point(lexer.KEYWORD, 'repeat', 'until')
lex:add_fold_point(lexer.COMMENT, '[', fold_longcomment)
lex:add_fold_point(lexer.COMMENT, ']', fold_longcomment)
lex:add_fold_point(lexer.COMMENT, lexer.fold_consecutive_lines('--'))
lex:add_fold_point('longstring', '[', ']')
lex:add_fold_point(lexer.OPERATOR, '(', ')')
lex:add_fold_point(lexer.OPERATOR, '[', ']')
lex:add_fold_point(lexer.OPERATOR, '{', '}')

return lex
]=]

local spec = {
  exts = {"tl"},
  lexer = "lexlpeg.teal",
  apitype = "lua",
  linecomment = "--",
  sep = ".:",
}


local name = "teal"
return {
  name = "Teal",
  description = "Implements integration for Teal language.",
  author = "Paul Kulchenko",
  version = 0.1,
  dependencies = "1.91", -- Be sure to use the most recent master version, as the 1.90 release doesn't support this package yet

  onRegister = function(self)
    ide:AddInterpreter(name, interpreter)
    ide:AddLexer("lexlpeg.teal", teallexer)
    ide:AddSpec(name, spec)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter(name)
    ide:RemoveLexer("lexlpeg.teal")
    ide:RemoveSpec(name)
  end,
}

--[[ configuration:
-- Install Teal to a preferred location on your system
-- For Windows, it's recommended to just download the precompiled package from https://github.com/teal-language/tl/releases
-- if `teal` executable is not in PATH, set the path to it manually in user.lua (if you don't have one already, create it in "cfg" folder)
path.teal = "full/path/tl.exe"
-- If everything worked, you should have a new Interpreter called "Teal" in Project -> Lua Interpreter
-- Since Teal supports Lua 5.4, you can also use it for writing Lua 5.4 code
-- Teal will treat .lua files as Lua code and .tl files as Teal code, so you can safely code and run both Lua and Teal in ZBS
-- For starting out with Teal syntax, look here: https://github.com/teal-language/tl/blob/master/docs/tutorial.md
-- If you want to compile your Teal code to Lua, you can't do this within ZBS. Just call "tl.exe gen filename.lua" in a shell.
--]]
