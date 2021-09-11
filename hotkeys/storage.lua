local KEYMAP = {} do
  local config = ide:GetConfig()
  for _, key in pairs(config and config.keymap or {}) do
    KEYMAP[key] = true
  end
end

local HotKeyToggle = package_require 'hotkeys.hot_key_toggle'

local Keys = {}
Keys.__index = Keys

function Keys.new(class)
  local self = setmetatable({}, class)

  self:_reset()

  return self
end

function Keys:_reset()
  self.packages     = {}
  self.key_handlers = {}
  self.hot_keys     = {}
  self.key_nodes    = {}
  self.chain        = ''
  self.last_pos     = nil
  self.last_editor  = nil
end

function Keys:clear_chain()
    self.chain = ''
end

function Keys:handler(editor, key)
  if (self.chain ~= '') and (self.last_editor ~= editor) or self.last_pos ~= editor:GetCurrentPos() then
    self.chain = ''
  end

  local full_key = (self.chain == '') and key or (self.chain .. ':' .. key)

  local handler = self.key_handlers[full_key]
  if handler then
    self.chain = ''
    return handler(editor)
  end

  if self.key_nodes[full_key] then
    self.last_editor = editor
    self.last_pos    = editor:GetCurrentPos()
    self.chain       = full_key
    return
  end

  self.chain = ''
end

function Keys:normalize_key(key)
  -- Ctrl+A => ctrl-a
  return string.lower(key):gsub('%+', '-')
end

function Keys:get_package_by_key(key)
  for package, info in pairs(self.packages) do
    if info.full_keys[key] then
      return package
    end
  end
end

function Keys:add(package, keys, handler)
  assert(handler, 'no handler')

  if type(keys) == 'string' then
    keys = {keys}
  end

  local full_key
  for i, key in ipairs(keys) do
    if KEYMAP[key] then
      return error(string.format('Hotkey %s alrady has action in the IDE config', key), 2)
    end

    local is_last = (i == #keys)
    local norm_key = self:normalize_key(key)
    if not full_key then
      full_key = norm_key
    else
      full_key = full_key .. ':' .. norm_key
    end

    if self.key_nodes[full_key] and is_last then -- can not attach action to hot key that is part of chain
      -- partial key can be defined for multiple packages
      -- e.g. first package define `Ctrl-K Ctrl-U` and the second one - `Ctrl-K Ctrl-D`
      -- in this case partial key `Ctrl-K` uses by both packages
      return error(string.format('Hotkey %s alrady uses in chain', key), 2)
    end

    if not is_last then -- mark as middle node
      self.key_nodes[full_key] = true
    end

    if is_last then
      if self.key_handlers[full_key] then -- can not update hotkey action
        local package = self:get_package_by_key(full_key)
        local package_name = package and package.name or 'UNKNOWN'
        return error(string.format('Hotkey %s alrady has action in package %s', key, package_name), 2)
      end
      self.key_handlers[full_key] = handler
    end

    -- create internal handler
    if not self.hot_keys[norm_key] then
      self.hot_keys[norm_key] = HotKeyToggle:new(key):set(function() self:handler(ide:GetEditor(), norm_key) end)
    end

    local package_info = self.packages[package]
    if not package_info then
      package_info = {full_keys = {}}
      self.packages[package] = package_info
    end
    package_info.full_keys[full_key] = true
  end
end

function Keys:close_package(package)
  local package_info = self.packages[package]
  if not package_info then
    return
  end

  for full_key in pairs(package_info.full_keys) do
    self.key_nodes[full_key]    = nil
    self.key_handlers[full_key] = nil
  end

  self.packages[package] = nil
end

function Keys:close()
  for _, hot_key in pairs(self.hot_keys) do
    hot_key:unset()
  end

  self:_reset()
end

return Keys:new()