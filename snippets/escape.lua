local Escape = {}

local function char_to_byte(char)
  return string.format('\\%03d', string.byte(char))
end

local function byte_to_char(value)
  value = tonumber(value)
  return '\\'..string.char(value)
end

---
-- Replace escaped snippet characters with their octal
-- equivalents.
function Escape.encode(text)
  return string.gsub(text, '\\([$/}`])', char_to_byte)
end

---
-- Replace octal snippet characters with their escaped
-- equivalents.
function Escape.decode(text)
  return string.gsub(text, '\\(%d%d%d)', byte_to_char)
end

---
-- Remove escaping forward-slashes from escaped snippet
-- characters.
-- At this point, they are no longer necessary.
function Escape.remove(text)
  return text:gsub('\\([$/}`])', '%1')
end

return Escape