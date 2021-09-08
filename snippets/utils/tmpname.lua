local DIR_SEP    = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

local function splitpath(P)
  return string.match(P,"^(.-)[\\/]?([^\\/]*)$")
end

local function tmpdir()
  if IS_WINDOWS then
    for _, p in ipairs{'TEMP', 'TMP'} do
      local dir = os.getenv(p)
      if dir and dir ~= '' then
        return dir
      end
    end
  end
  return (splitpath(os.tmpname()))
end

local TMP_DIR = tmpdir()

local function tmpname()
  local dir, file = splitpath(os.tmpname())
  return TMP_DIR .. DIR_SEP .. file
end

return tmpname