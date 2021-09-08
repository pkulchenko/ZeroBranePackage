local HotKeyToggle = {}
HotKeyToggle.__index = HotKeyToggle

function HotKeyToggle.new(class, key)
  local self = setmetatable({}, class)

  self.key = key

  return self
end

function HotKeyToggle:set(handler)
  assert(self.id == nil)
  self.prev = ide:GetHotKey(self.key)
  self.id = ide:SetHotKey(handler, self.key)
  return self
end

function HotKeyToggle:unset()
  assert(self.id ~= nil)
  if self.id == ide:GetHotKey(self.key) then
    if self.prev then
      ide:SetHotKey(self.prev, self.key)
    else
      --! @todo properly remove handler
      ide:SetHotKey(function()end, self.key)
    end
  end
  self.prev, self.id = nil
end

return HotKeyToggle