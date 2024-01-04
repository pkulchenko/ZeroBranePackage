local config = package_require 'snippets.config'

local function print(...)
  ide:Print(...)
end

local Log = {} do
  Log.__index = Log

  Log.ERROR   = 0
  Log.WARNING = 1
  Log.DEBUG   = 2

  function Log.new(class, prefix, lvl)
    local self = setmetatable({}, class)
    self.prefix = prefix
    self.level = lvl or Log.WARNING
    self.loggers = {}
    return self
  end

  function Log:get(prefix, lvl)
    local log = self.loggers[prefix]
    if not log then
      local class = getmetatable(self)
      log = Log.new(class, self.prefix .. ':' .. prefix, lvl or self.level)
      self.loggers[prefix] = log
    end
    return log
  end

  function Log:format(lvl, ...)
    local msg = string.format(...)
    return string.format('%s [%s][%s] %s',  os.date('%H:%M:%S'), lvl, self.prefix, msg)
  end

  function Log:write(...)
    local msg = self:format(...)
    print(msg)
  end

  function Log:debug(...)
    if self.level >= Log.DEBUG then
      self:write('DEBUG', ...)
    end
  end

  function Log:warning(...)
    if self.level >= Log.WARNING then
      self:write('WARNING', ...)
    end
  end

  function Log:error(...)
    if self.level >= Log.ERROR then
      self:write('ERROR', ...)
    end
  end
end

return Log:new('snippets', config.DEBUG and Log.DEBUG or Log.WARNING)
