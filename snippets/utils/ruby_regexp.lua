local log           = package_require 'snippets.log'
local tmpfile       = package_require 'snippets.utils.tmpfile'
local shell_execute = package_require 'snippets.utils.shell_execute'
local escape_decode = package_require 'snippets.escape'.decode

local RUBY_CMD = 'ruby'

---
-- Replace regexp using ruby interpreter
local function ruby_regexp(last_item, pattern, replacement, options)
  local log = log:get('ruby_regexp')
  local script = [[
    li  = %q(last_item)
    rep = %q(replacement)
    li  =~ /pattern/options
    if data = $~
      rep.gsub!(/\#\{(.+?)\}/) do
        expr = $1.gsub(/\$(\d\d?)/, 'data[\1]')
        eval expr
      end
      puts rep.gsub(/\$(\d\d?)/) { data[$1.to_i] }
    end
  ]]
  pattern     = escape_decode(pattern)
  replacement = escape_decode(replacement)
  script = script:gsub('last_item', last_item)
  script = script:gsub('pattern', pattern)
  script = script:gsub('options', options or '')
  script = script:gsub('replacement', replacement)

  local file = tmpfile('snp')
  if not file then
    log:error('Can not create temporary file')
    return
  end

  file:write(script)
  file:close()

  log:debug('script:\n%s\n============', script)

  local ret, response, stderr = shell_execute(RUBY_CMD .. ' -cw ' .. file.path)
  if (ret ~= 0) or not (response and response:sub(1, 9) == 'Syntax OK') then
    file:remove()
    log:error('ret code: %d\n%s\n============', ret, stderr)
    return ''
  end

  ret, response, stderr = shell_execute(RUBY_CMD .. ' ' .. file.path)
  file:remove()

  if ret ~= 0 then
    log:error('ret code: %d\n%s\n============', ret, stderr)
    return ''
  end

  return response
end

return ruby_regexp
