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
  self.wait_interval = 5 -- Wait next key

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

function Keys:_current_status(editor)
  editor = editor or ide:GetEditor()
  return editor, editor and editor:GetCurrentPos()
end

function Keys:clear_chain()
  self.chain       = ''
  self.last_time   = nil
  self.last_editor = nil
  self.last_pos    = nil
end

function Keys:is_chain_valid(editor)
  if self.chain == '' then
    return true
  end

  local interval = self:interval()
  if interval > self.wait_interval then
    return false
  end

  local e, p = self:_current_status(editor)

  if self.last_editor ~= e then
    return false
  end

  if self.last_pos ~= p then
    return false
  end

  return true
end

function Keys:set_chain(key)
  self.chain        = key
  self.last_time    = os.time()
  self.last_editor, self.last_pos = self:_current_status()
end

function Keys:interval()
  if not self.last_time then
    return 0
  end

  local now = os.time()
  if self.last_time > now then -- time shift
    return 3600
  end

  return os.difftime(now, self.last_time)
end

function Keys:handler(key)
  if not self:is_chain_valid() then
    self:clear_chain()
  end

  local full_key = (self.chain == '') and key or (self.chain .. ':' .. key)

  local handler = self.key_handlers[full_key]
  if handler then
    self:clear_chain()
    handler()
    return true
  end

  if self.key_nodes[full_key] then
    self:set_chain(full_key)
    return true
  end

  handler = self.key_handlers[key]
  if handler then
    self:clear_chain()
    handler()
    return true
  end

  if self.key_nodes[key] then
    self:set_chain(key)
    return true
  end

  self:clear_chain()
  return false
end

function Keys:normalize_key(key)
  if #key == 1 then
    return key
  end

  -- Ctrl+A => CTRL-A
  return string.upper(key):gsub('%+', '-')
end

function Keys:get_package_by_key(key)
  for package, info in pairs(self.packages) do
    if info.full_keys[key] then
      return package
    end
  end
end

function Keys:add(package, keys, handler, ide_override)
  assert(handler, 'no handler')

  if type(keys) == 'string' then
    local t = {}
    for k in string.gmatch(keys, '[^%s,]+') do
      table.insert(t, k)
    end
    keys = t
  end

  local full_key
  for i, key in ipairs(keys) do
    if KEYMAP[key] and not ide_override then
      return error(string.format("Fail to set hotkey %s for the package '%s'. Hotkey alrady has action in the IDE config", key, package and package.name or 'UNKNOWN'), 2)
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
      return error(string.format("Fail to set hotkey %s for the package '%s'. Hotkey alrady used in chain", key, package and package.name or 'UNKNOWN'), 2)
    end

    if not is_last then -- mark as middle node
      self.key_nodes[full_key] = true
    end

    if is_last then
      if self.key_handlers[full_key] then -- can not update hotkey action
        local first_package = self:get_package_by_key(full_key)
        local package_name = first_package and first_package.name or 'UNKNOWN'
        return error(string.format("Fail to set hotkey %s for the package '%s'. Hotkey alrady has action in the package '%s'", key, package and package.name or 'UNKNOWN', package_name), 2)
      end
      self.key_handlers[full_key] = handler
    end

    if #norm_key == 1 and not (is_last and i > 1) then
        return error(string.format("Fail to set hotkey %s for the package '%s'. Single char allowed only as last node in chain", key, package and package.name or 'UNKNOWN'), 2)
    end

    -- create internal handler
    if #norm_key > 1 then
        if not self.hot_keys[norm_key] then
          self.hot_keys[norm_key] = HotKeyToggle:new(key):set(function() self:handler(norm_key) end)
        end
    end

    if is_last then
      local package_info = self.packages[package]
      if not package_info then
        package_info = {full_keys = {}}
        self.packages[package] = package_info
      end
      package_info.full_keys[full_key] = true
    end
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

-- Event Provided by onchar plugin
function Keys:onEditorKey(editor, event)
  if self.chain == '' then
    return true
  end

  local modifier = event:GetModifiers()
  if not (modifier == 0 or modifier == wx.wxMOD_SHIFT) then
    return true
  end

  local code = event:GetKeyCode()
  if code == 0 or code == nil or code == wx.WXK_SHIFT then
    return true
  end

  if code > 255 then
    self:clear_chain()
    return true
  end

  local key = string.char(code)
  if self:handler(key) then
    return false
  end

  return true
end

function Keys:onEditorKeyDown(editor, event)
  if self.chain ~= '' then
    local modifier = event:GetModifiers()
    if modifier == 0  and event:GetKeyCode() == wx.WXK_ESCAPE then
      self:clear_chain()
    end
  end

  return true
end

function Keys:onIdle(editor, event)
  if not self:is_chain_valid() then
    self:clear_chain()
  end
end

return Keys:new()
