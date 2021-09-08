local shell_execute = package_require 'snippets.utils.shell_execute'
local write_file    = package_require 'snippets.utils.write_file'
local remove_file   = package_require 'snippets.utils.remove_file'
local tmpname       = package_require 'snippets.utils.tmpname'
local escape_decode = package_require 'snippets.escape'.decode

local RUBY_CMD = 'ruby'

---
-- Replace regexp using ruby interpreter
local function ruby_regexp(last_item, pattern, replacement, options)
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
  script = script:gsub('options', options)
  script = script:gsub('replacement', replacement)

  local file = tmpname()
  write_file(file, script)

  local ret, response, stderr = shell_execute(RUBY_CMD .. ' -cw ' .. file)
  if (ret ~= 0) or not (response and response:sub(1, 9) == 'Syntax OK') then
    remove_file(file)
    local log = log:get('ruby_regexp')
    log:error('%s\n============', stderr)
    return ''
  end

  ret, response, stderr = shell_execute(RUBY_CMD .. ' ' .. file)
  remove_file(file)

  if ret ~= 0 then
    local log = log:get('ruby_regexp')
    log:error('%s\n============', stderr)
    return ''
  end

  return response
end

return ruby_regexp
