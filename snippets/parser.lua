local lpeg = require 'lpeg'

local P, S, R, V = lpeg.P, lpeg.S, lpeg.R, lpeg.V
local C, Cp, Cs, Carg, Cc = lpeg.C, lpeg.Cp, lpeg.Cs, lpeg.Carg, lpeg.Cc

local escape_patt = P'\\' * S'$`\\{}()'
local int         = R'19' * R'09' ^ 0

-- Nested balanced pattern
local function inside(name, exclude)
  return (escape_patt + (1 - S(exclude)) + V(name))^0
end

local function unescape_symbol(s)
  return s:sub(-1)
end

local unescape_patt = Cs(((escape_patt / unescape_symbol) + 1) ^ 0)
local function unescape(s)
  return unescape_patt:match(s)
end

local function escape(s)
  return (string.gsub(s, '([$`\\{}()])', '\\%1'))
end

local function split_list(str)
  local list = {}
  for s in string.gmatch(str, '[^,]+') do
    table.insert(list, s)
  end
  return list
end

local function macro(name, macros)
  local value
  if type(macros) == 'table' then
    value = macros[name]
  else
    value = macros(name)
  end
  return value or ''
end

local function set(t, v)
  t[tonumber(v)] = true
end

local function replace(fn, what, patt, replace, flags)
  return fn(what, patt, replace, flags)
end

local function forward(value)
  return value or ''
end

-- unescape and expand macros inside shell command
local shell_patt = P{'command',
  command = Cs(((escape_patt / unescape_symbol) + V'macro' + 1) ^ 0),
  macro   = P'$(' * Cs(inside('macro', '()') / unescape) * Carg(1) * ')' / macro,
}

local function shell_command(cmd, macros)
  return shell_patt:match(cmd, nil, macros)
end

local function shell(execute, cmd, macros)
  cmd = shell_command(cmd, macros)
  return execute(cmd) or ''
end

local text_escape_pat = P{'text',
  text   = Cs((V'escape' + 1) ^ 0),
  escape = Cs(P'\\' ^ 0) * Cs(P'${' * int * S':|/}') / function(s, v) return '\\' .. s:rep(2) .. v end
}

local text_unescape_pat = P{'text',
  text   = Cs((V'unescape' + 1) ^ 0),
  unescape = Cs(P'\\' ^ 0) * Cs(P'${' * int * S':|}') / function(s, v) return ('\\'):rep(math.floor(#s/2)) .. v end
}

local function text_escape(s)
  return text_escape_pat:match(s)
end

local function text_unescape(s)
  return text_unescape_pat:match(s)
end

local tab_patterns = setmetatable({}, {__index = function(self, eol)
  local patt = P{'text',
    text = Cs((V'line' * V'eol') ^ 0 * V'line' ^ -1),
    line = V'tab' ^ 0 * V'neol' ^ 0,
    tab  = P'\t' * Carg(1) / forward,
    neol = 1 - V'eol',
    eol  = P(eol),
  }
  self[eol] = patt
  return patt
end})

local snippet_patt = P{'body',
  body        = Cs((escape_patt + V'upper_node' + 1) ^ 0),
  upper_node  = V'placeholder' + (V'shell' / text_escape) + (V'macro' / text_escape) + V'mirror' + V'transform',
  node        = V'placeholder' + (V'shell' / escape)      + (V'macro' / escape)      + V'mirror' + V'transform',
  placeholder = '${' * (Carg(3) * C(int) / set) * ':' * (escape_patt + V'node' + (1 - S'{}')) ^ 0 * '}',
  list        = '${' * (Carg(3) * C(int) / set) * '|' * inside('braces', '{}') * '}',
  mirror      = '${' * int * '}',
  transform   = '${' * int * '/' * V'regexp' * '}',
  macro       = ('$(' * Cs(inside('macro', '()') / unescape) * Carg(1) * ')') / macro,
  shell       = ('`' * Carg(2) * Cs(inside('shell', '`' )) * Carg(1) * '`') / shell,
  braces      = '{' * inside('braces', '{}') * '}',
  regexp      = V'repat' * '/' * V'repat' * '/' * (V'reflag' ^ -1),
  repat       = (P'\\/' + (1 - S('/'))) ^ 0,
  reflag      = S'iomxneus' ^ 0,
}

local mirror_patterns = setmetatable({}, {__index = function(self, i)
  local patt = P{'body',
    body        = Cs((escape_patt + V'mirror' + V'transform' + 1) ^ 0),
    mirror      = P'${' * Carg(1) * string.format('%d', i) * '}' / forward,
    transform   = P'${' * Carg(2) * Carg(1) * string.format('%d', i) * '/' * V'regexp' * '}' / replace,
    regexp      = Cs(V'repat') * '/' * Cs(V'repat') * '/' * (Cs(V'reflag') ^ -1),
    repat       = ((P'\\/' / '/') + (1 - S('/'))) ^ 0,
    reflag      = S'iomxneus' ^ 0,
  }
  self[i] = patt
  return patt
end})

local placeholder_patterns = setmetatable({}, {__index = function(self, i)
  local patt = {'body',
    body        = V('text') * Cp() * V('node') * Cp(),
    text        = (escape_patt + 1 - V'node') ^ 0,
    node        = V'default' + V'list',
    list        = P'${' * string.format('%d', i) * '|' * (inside('braces', '{}') / split_list) * '}',
    default     = P'${' * string.format('%d', i) * ':' * Cs(inside('braces', '{}'))  * '}',
    braces      = P'{' * inside('braces', '{}') * '}',
  }
  if i == 0 then
    patt.cursor = Cc'' * P'${0}'
    patt.node   = patt.node + V'cursor'
  end
  patt = P(patt)
  self[i] = patt
  return patt
end})

local escape_placeholder_patt = P{'body',
  body        = Cs(
    (
      V'text' * V'node' + V'node' + V'text'
      ) ^ 1
  ),
  text        = Cs(((escape_patt / unescape_symbol) + (1 - V'node')) ^ 1) / text_escape,

  node        = V'placeholder' + V'mirror' + V'transform',
  placeholder = '${' * int * ':' * (escape_patt + V'node' + (1 - S'{}')) ^ 0 * '}',
  list        = '${' * int * '|' * inside('braces', '{}') * '}',
  mirror      = '${' * int * '}',
  transform   = '${' * int * '/' * V'regexp' * '}',

  braces      = '{' * inside('braces', '{}') * '}',
  regexp      = V'repat' * '/' * V'repat' * '/' * (V'reflag' ^ -1),
  repat       = (P'\\/' + (1 - S('/'))) ^ 0,
  reflag      = S'iomxneus' ^ 0,
}

local function escape_placeholder_default(s)
  if s == '' then
    return ''
  end
  return escape_placeholder_patt:match(s)
end

local function expand(str, shell_execute, macros, placeholders)
  return snippet_patt:match(str, nil, macros, shell_execute, placeholders)
end

local function next_placeholder(str, index)
  local patt = placeholder_patterns[index]
  local start_pos, default, end_pos = patt:match(str)
  if not start_pos then
    return
  end
  if type(default) == 'string' then
    default = escape_placeholder_default(default)
  end
  return start_pos, end_pos - 1, default
end

local function mirror(str, index, text, regexp)
  local patt = mirror_patterns[index]
  return patt:match(str, nil, text, regexp)
end

local function normalize_tab(text, eol, indent)
  local patt = tab_patterns[eol]
  return patt:match(text, nil, indent)
end

local __self_test__ do

local macros = {VAR1 = '${HELLO}', VAR2 = '${1:HELLO}'}

local function assert_equal(expected, got)
  if got ~= expected then
    error(string.format('Expected %s; got %s', tostring(expected), tostring(got)), 2)
  end
end

local function assert_next_placeholder(str, index, expected_start, expected_end, expected_default)
  local s, e, d = next_placeholder(str, index)
  assert_equal(expected_start,   s)
  assert_equal(expected_end,     e)
  assert_equal(expected_default, d)
end

local function assert_expand(str, expected_string, expected_command)
  local got_command

  local function shell_execute(cmd)
    got_command = cmd
    return "<" .. cmd .. ">"
  end

  local got = expand(str, shell_execute, macros, {})
  if expected_command ~= nil then
    expected_command = expected_command or nil
    assert_equal(expected_command, got_command)
  end

  assert_equal(expected_string, got)
end

local function test_shell_command()
  assert_expand(
    [[`cmd \`var\`\$(VAR1)\\$(VAR1)`]],
    [[<cmd `var`$(VAR1)\${HELLO}>]],
    [[cmd `var`$(VAR1)\${HELLO}]]
  )
  assert_equal([[<cmd `var`$(VAR1)\${HELLO}>]], text_unescape [[<cmd `var`$(VAR1)\${HELLO}>]])

  assert_expand(
    [[`cmd \\$(VAR2)`]],
    [[<cmd \\\${1:HELLO}>]],
    [[cmd \${1:HELLO}]]
  )
  assert_equal([[<cmd \${1:HELLO}>]], text_unescape [[<cmd \\\${1:HELLO}>]])
  assert_next_placeholder([[<cmd \\\${1:HELLO}>]], 1, nil, nil, nil)

  assert_expand(
    [[${2:`cmd \\$(VAR2)`}]],
    [[${2:<cmd \\\$\{1:HELLO\}>}]],
    [[cmd \${1:HELLO}]]
  )
  assert_equal([[${2:<cmd \\\$\{1:HELLO\}>}]], text_unescape [[${2:<cmd \\\$\{1:HELLO\}>}]])
  assert_next_placeholder([[${2:<cmd \\\$\{1:HELLO\}>}]], 1, nil, nil, nil)
  assert_next_placeholder([[${2:<cmd \\\$\{1:HELLO\}>}]], 2, 1, 26, [[<cmd \\\${1:HELLO}>]])
end

local function test_text_escape()
  local shell_execute = error -- no call expected

  local s = [[${HELLO}]]
  assert(s == expand(s, shell_execute, macros, {}))

  local s = [[${1:${HELLO}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '${HELLO}')

  local s = [[${1:${2:HELLO}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '${2:HELLO}')

  local s = [[${1:\${2:HELLO}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '\\${2:HELLO}')

  local s = [[${1:$\{2:HELLO\}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '\\${2:HELLO}')

  local s = [[${1:\$\{2:HELLO\}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '\\${2:HELLO}')

  local s = [[${1:${2:$\{3:HELLO\}}}]]
  assert(s == expand(s, shell_execute, macros, {}))
  assert_next_placeholder(s, 1, 1, #s, '${2:$\\{3:HELLO\\}}')
end

local function test_tab_norm()
  local s = table.concat({
    '\t\tline1\t',
    'line2\t',
    '',
    '\t\tline4\t',
  }, '\r\n')

  local expected = table.concat({
    '****line1\t',
    'line2\t',
    '',
    '****line4\t',
  }, '\r\n')

  assert_equal(expected, normalize_tab(s, '\r\n', '**'))

  local s = table.concat({
    '\t\tline1\t',
    'line2\t',
    '',
    '\t\tline4\t',
  }, '\n')

  local expected = table.concat({
    '****line1\t',
    'line2\t',
    '',
    '\t\tline4\t',
  }, '\n')

  assert_equal(expected, normalize_tab(s, '\r\n', '**'))
end

function __self_test__()
  test_text_escape()
  test_shell_command()
  test_tab_norm()
end

end

__self_test__()

local M = {
  expand_macros_and_shell = expand,
  next_placeholder        = next_placeholder,
  mirror                  = mirror,
  unescape                = text_unescape,
  normalize_tab           = normalize_tab,
  __self_test__           = __self_test__,
}

return M
