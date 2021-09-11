local HotKeyToggle = package_require 'snippets.hot_key_toggle'

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

function Keys:add(package, keys, handler)
  assert(handler, 'no handler')

  if type(keys) == 'string' then
    keys = {keys}
  end

  local full_key
  for i, key in ipairs(keys) do
    local is_last = (i == #keys)
    local norm_key = self:normalize_key(key)
    if not full_key then
      full_key = norm_key
    else
      full_key = full_key .. ':' .. norm_key
    end

    if self.key_nodes[full_key] and is_last then -- can not attach action to hot key that is part of chain
      return error(string.format('Hotkey %s alrady uses in chain', key), 2)
    end

    if not is_last then -- mark as middle node
      self.key_nodes[full_key] = true
    end

    if is_last then
      if self.key_handlers[full_key] then -- can not update hotkey action
        return error(string.format('Hotkey %s alrady has action', key), 2)
      end
      self.key_handlers[full_key] = handler
    end

    -- create internal handler
    if not self.hot_keys[norm_key] then
      self.hot_keys[norm_key] = HotKeyToggle:new(key):set(function() self:handler(ide:GetEditor(), norm_key) end)
    end
    
    local package_info = self.packages[package]
    if not package_info then
      package_info = {keys = {}, full_keys = {}}
      self.packages[package] = package_info
    end
    package_info.keys[norm_key] = true
    package_info.full_keys[full_key] = true
  end
end

function Keys:close_package(package)
  local package_info = self.packages[package]
  if not package_info then
    return
  end

  for full_key in pairs(package_info.full_keys) do
    self.key_nodes[full_key] = nil
    self.key_handlers[full_key] = nil
  end

  for norm_key in pairs(package_info.keys) do
    local hot_key = self.hot_keys[norm_key]
    if hot_key then
      hot_key:unset()
    end
    self.hot_keys[norm_key] = nil
  end

  self.packages[package] = nil
end

return Keys:new()