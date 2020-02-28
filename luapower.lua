--[=[ 
Luapower interpreter support 

This will remove the default env and use an empty one 

For the debugger to work, luapower needs to load the mobdebug library. 
The easiest way is to copy the mobdebug.lua 
  from  <ZeroBrane>/lualibs/mobdebug/ 
  to    <luapower>/

Alternately, you can fetch it using mgit
  
  mgit clone https://github.com/chowette/mobdebug

]=]--
dofile "interpreters/luabase.lua"
local interpreter =  MakeLuaInterpreter("", "power")

interpreter.description = "Luapower interpreter with debugger"
interpreter.api = {"baselib", "luajit2"}  -- TODO: add luapower api


-- hijack the base execpath function to use power as suffix for exe
local basefexepath = interpreter.fexepath
interpreter.fexepath = function (self, version) 
  return basefexepath(self, "power")
end

-- hijack the base run function to remove the Zerobrane environement
local basefrun = interpreter.frun
interpreter.frun = function (self, wfilename, rundebug)
  -- remove the default env and use an empty one  
  wx.wxSetEnv("LUA_CPATH", "")
  wx.wxSetEnv("LUA_PATH", "")
  -- run original function
  ide:Print( "cpath :", os.getenv("LUA_CPATH"))
  ide:Print( "lpath :", os.getenv("LUA_PATH"))
  
  return basefrun(self, wfilename, rundebug)
end 

-- return pluging info
return {
  name = interpreter.name,
  description = interpreter.description,
  author = "Chowette",
  version = 0.1,

  onRegister = function(self)
    -- add interpreter
    ide:AddInterpreter(interpreter.name, interpreter)    
  end,

  onUnRegister = function(self)
    -- add interpreter
    ide:RemoveInterpreter(interpreter.name)    
  end,

}

