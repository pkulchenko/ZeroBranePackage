local function write_file(name, data)
  local f = assert(io.open(name, 'w'))
  f:write(data)
  f:close()
end

return write_file