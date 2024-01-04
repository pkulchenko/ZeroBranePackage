local function table_keys(t)
  local r = {}
  for key in pairs(t) do
    table.insert(r, key)
  end
  return r
end

return table_keys