local function set_merge(dst, src)
  for key in pairs(src) do
    dst[key] = true
  end
  return dst
end

return set_merge