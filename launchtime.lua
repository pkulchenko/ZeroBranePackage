local log = {}
local call = {}
local function logit(msg) table.insert(log, ("%.3f %s"):format(os.clock(), msg)) end

logit('started')
return {
  name = "Measures startup performance",
  description = "Measures IDE startup performance up to the first IDLE event.",
  author = "Paul Kulchenko",
  version = 0.1,

  onRegister = function(self)
    logit('OnRegister')
    debug.sethook(function(event, line)
      local src = debug.getinfo(2, "Sn")
      local name = src.name
      if not name then return end

      if event == "call" then
        call[name] = os.clock()
      else
        -- we may be returning from methods we haven't seen
        if not name or not call[name] then return end

        local calltime = os.clock()-call[name]
        if calltime >= 0.005 then
          logit(("%.3f+%.3f %s"):format(call[name], calltime, name..src.source..':'..src.linedefined))
        end
      end
    end, "cr")
  end,

  onUnRegister = function(self) debug.sethook() end,

  onAppLoad = function(self)
    debug.sethook()
    logit('onAppLoad')
  end,

  onIdleOnce = function(self)
    logit('onIdleOnce')
    ide:Print(table.concat(log, "\n"))
    log = {}
  end,
}
