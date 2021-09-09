local function string_replace(text, str, s, e)
  return string.format('%s%s%s', string.sub(text, 1, s - 1), str, string.sub(text, e + 1))
end

return string_replace