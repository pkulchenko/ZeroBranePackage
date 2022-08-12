-- Copyright 2022 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local pathcache
local win = ide and ide.osname == "Windows"

local interpreter = {
  name = "Redbean",
  description = "Redbean Lua debugger",
  api = {"baselib"},
  frun = function(self,wfilename,rundebug)
    local projdir = self:fworkdir(wfilename)
    local redbean = ide.config.path.redbean or pathcache and pathcache[projdir]
    if redbean and not wx.wxFileExists(redbean) then
      ide:Print(("Can't find configured redbean executable: '%s'."):format(redbean))
      redbean = nil
    end
    if not redbean then
      local sep = win and ';' or ':'
      local default = win and GenerateProgramFilesPath('', sep)..sep or ''
      local path = default
                 ..(os.getenv('PATH') or '')..sep
                 ..projdir..sep
                 ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
      local paths = {}
      for p in path:gmatch("[^"..sep.."]+") do
        redbean = redbean or GetFullPathIfExists(p, 'redbean.com')
        table.insert(paths, p)
      end
      if not redbean then
        ide:Print("Can't find redbean executable in any of the following folders: "
          ..table.concat(paths, ", "))
        return
      end
    end

    local filepath = wfilename:GetFullPath()
    if rundebug then
      ide:GetDebugger():SetOptions({ runstart = ide.config.debugger.runonstart ~= false })
      local mdb = MergeFullPath(GetPathWithSep(ide.editorFilename), "lualibs/mobdebug/")
      rundebug = ([[-e "package.path=[=[%s]=] package.loaded['socket']=require'redbean'"]])
        :format(ide:GetPackage("redbean"):GetFilePath())
        .." "..([[-e "package.path=[=[%s]=]
MDB=require('mobdebug')
MDB.start()
function OnServerStart()
  local OHR=OnHttpRequest
  if OHR then
    OnHttpRequest=function(...) MDB.on() return OHR(...) end
  end
end"]]):format(MergeFullPath(GetPathWithSep(ide.editorFilename), "lualibs/mobdebug/?.lua"))
       :gsub("\r?\n%s*"," ")
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
    local params = ide.config.arg.any or ide.config.arg.redbean
    local code = rundebug or ""
    local cmd = '"'..redbean..'" '..code..(params and " "..params or "")

    -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
    return CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil)
  end,
  hasdebugger = true,
  skipcompile = true,
  unhideanywindow = true,
  takeparameters = true,
}

local name = 'redbean'
return {
  name = "Redbean",
  description = "Implements integration with Redbean server.",
  author = "Paul Kulchenko",
  version = 0.11,
  dependencies = "1.60",

  onRegister = function(self)
    ide:AddInterpreter(name, interpreter)
  end,
  onUnRegister = function(self)
    ide:RemoveInterpreter(name)
  end,
  -- socket.lua mock to allow redbean.lua to be required from the app when debugged
  -- since it needs to be loaded form the IDE, which may be running a Lua version
  -- that doesn't include bit-wise operators, load the fragment at run-time.
  tcp = function()
    return load[[return {
      _ = assert(unix.socket()),
      buf = "",
      settimeout = function(self, t) self._timeout = t and t*1000 or -1 end,
      connect = function(self, ip, port)
        return assert(unix.connect(self._, assert(ResolveIp(ip)), port))
      end,
      close = function(self) return assert(unix.close(self._)) end,
      send = function(self, data)
        local CANWRITE = unix.POLLOUT | unix.POLLWRNORM
        local events = assert(unix.poll({[self._] = unix.POLLOUT}, self._timeout))
        if not events[self._] then return nil, "timeout" end
        if events[self._] & CANWRITE == 0 then return nil, "close" end
        local sent, err = unix.send(self._, data)
        if not sent and err:name() == "EAGAIN" then return nil, "timeout" end
        return sent, err
      end,
      receive = function(self, pattern)
        local CANREAD = unix.POLLIN | unix.POLLRDNORM | unix.POLLRDBAND
        local size = tonumber(pattern)
        if size then
          if #self.buf < size then
            local events = assert(unix.poll({[self._] = unix.POLLIN}, self._timeout))
            if not events[self._] then return nil, "timeout" end
            if events[self._] & CANREAD == 0 then return nil, "close" end
            self.buf = self.buf .. assert(unix.recv(self._, size-#self.buf))
          end
          local res = self.buf:sub(1, size)
          self.buf = self.buf:sub(size+1)
          return res
        end
        while not self.buf:find("\n") do
          self.buf = self.buf .. assert(unix.recv(self._, 4096))
        end
        local pos = self.buf:find("\n")
        local res = self.buf:sub(1, pos-1):gsub("\r","")
        self.buf = self.buf:sub(pos+1)
        return res
      end,
    }]]()
  end,
}

--[[ configuration example:
-- if `redbean` executable is not in the project folder or PATH, set the path to it manually
path.redbean = "/full/path/redbean.com"
--]]
