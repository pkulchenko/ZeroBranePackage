-- TODO
--  * add options to not expand snippet inside another snippet

local function Color(param)
  param = (tonumber(param) or 0) % (1+0xFFFFFFFF)
  local r = param % 256; param = math.floor(param / 256)
  local b = param % 256; param = math.floor(param / 256)
  local g = param % 256; param = math.floor(param / 256)
  return wx.wxColour(r, g, b)
end

local SnippetConfig = {
  DEBUG              = false,
  MARK_SNIPPET       = 4,
  MARK_SNIPPET_COLOR = Color("0x4D9999"),
}
SnippetConfig.__index = SnippetConfig

local function merge_set(dst, src)
  for key in pairs(src) do
    dst[key] = true
  end
  return dst
end

local function table_keys(t)
  local r = {}
  for key in pairs(t) do
    table.insert(r, key)
  end
  return r
end

local function table_sort(t, ...)
  table.sort(t, ...)
  return t
end

local function split_scope(str)
  if not str then
    return '*', '*'
  end

  local lang, scope = string.match(str, '^(.-)%.([^%.]*)$')
  if not lang then
    return str, '*'
  end

  if lang == '' then
    lang = '*'
  end

  if scope == '' then
    scope = '*'
  end

  return lang, scope
end

local function add_scope(tree, lang, scope)
  local lang_node = tree[lang] or {}
  tree[lang] = lang_node

  local scope_node = lang_node[scope] or {}
  lang_node[scope] = scope_node

  return scope_node
end

local function find_scope(tree, lang, scope)
  if not tree then
    return
  end

  local node = tree[lang] and (tree[lang][scope] or tree[lang]['*'])
  if node then
    return node
  end

  return tree['*'] and (tree['*'][scope] or tree['*']['*'])
end

function SnippetConfig.new(class)
  local self = setmetatable({}, class)

  return self
end

function SnippetConfig:add_scope(tree, activation_text, snippet)
  local nested = snippet.nested
  if nested == nil then
    nested = self.settings.nested
  end

  local node = tree[activation_text] or {}
  tree[activation_text] = node

  --! TODO support multiple scopes
  local lang, scope = split_scope(snippet.scope)
  node = add_scope(node, lang, scope)

  node.text   = snippet.text
  node.nested = nested
end

function SnippetConfig:build_list()
  for activation_text, lang, scope in self:iterate_tab() do
    local node = add_scope(self._lst, lang, scope)
    node[activation_text] = true
  end

  -- `*.*` merge with any
  -- `*.<SCOPE>` merge with `<LANG>.<SCOPE>`
  local any_lst = self._lst['*']
  if any_lst then
    for lang, scope, node in self:iterate_list() do if lang ~= '*' then
      for any_scope, any_node in pairs(any_lst) do
        if any_scope == '*' or any_scope == scope then
          merge_set(node, any_node)
        end
      end
    end end
  end

  -- `<LANG>.*` merge with `<LANG>.<SCOPE>`
  for lang, scope, any_node in self:iterate_list() do if scope == '*' then
    for scope, scope_node in pairs(self._lst[lang]) do if scope_node ~= any_node then
      merge_set(scope_node, any_node)
    end end
  end end

  for lang, scope, node in self:iterate_list() do
    local lst = table_keys(node)
    self._lst[lang][scope] = table_sort(lst)
  end
end

function SnippetConfig:add_snippet(snippet)
  local activation_type, activation_text 
  if type(snippet.activation) == 'string' then
    activation_type, activation_text = 'tab', snippet.activation
  else
    activation_type = snippet.activation[1]
    activation_text = snippet.activation[2]
  end

  if activation_type == 'tab' then
    self:add_scope(self._tab, activation_text, snippet)
  end

  if activation_type == 'key' then
    self:add_scope(self._key, activation_text, snippet)
  end
end

function SnippetConfig:load(config)
  self._tab = {}
  self._key = {}
  self._lst = {}

  self.settings = config.settings or {}
  if self.settings.nested == nil then
    self.settings.nested = true
  end
  if self.settings.tab_activation == nil then
    self.settings.tab_activation = true
  end

  for _, snippet in ipairs(config) do
    self:add_snippet(snippet)
  end

  self:build_list()

  return self
end

function SnippetConfig:get_key(lang, scope, name)
  return find_scope(self._key[name], lang, scope)
end

function SnippetConfig:get_tab(lang, scope, name)
  return find_scope(self._tab[name], lang, scope)
end

function SnippetConfig:get_key_activators()
  local keys = {}
  for key in pairs(self._key) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

function SnippetConfig:get_list(lang, scope)
  return find_scope(self._lst, lang, scope)
end

function SnippetConfig:iterate_tab()
  return coroutine.wrap(function()
    for activation_text, activation_node in pairs(self._tab) do
      for lang, lang_node in pairs(activation_node) do
        for scope, scope_node in pairs(lang_node) do
          coroutine.yield(activation_text, lang, scope, scope_node)
        end
      end
    end
  end)
end

function SnippetConfig:iterate_list()
  return coroutine.wrap(function()
    for lang, lang_node in pairs(self._lst) do
      for scope, scope_node in pairs(lang_node) do
        coroutine.yield(lang, scope, scope_node)
      end
    end
  end)
end

function SnippetConfig.__self_test__()
  local config = SnippetConfig:new()

  local function assert_list(expected, got)
    assert(#expected == #got)
    for k, v in ipairs(expected) do
      assert(v == got[k])
    end
  end

  do -- build list and find tab
    config:load{
      {scope = '*.*',      activation = '1'}; -- perl.comment
      {scope = '*.text',   activation = '2'}; -- perl.text
      {scope = 'lua.*',    activation = '3'}; -- lua.comment
      {scope = 'lua.text', activation = '4'}; -- lua.text
    }

    assert(    config:get_tab('perl', 'comment',  '1'))
    assert(not config:get_tab('perl', 'comment',  '2'))
    assert(not config:get_tab('perl', 'comment',  '3'))
    assert(not config:get_tab('perl', 'comment',  '4'))

    assert(    config:get_tab('perl', 'text',  '1'))
    assert(    config:get_tab('perl', 'text',  '2'))
    assert(not config:get_tab('perl', 'text',  '3'))
    assert(not config:get_tab('perl', 'text',  '4'))

    assert(    config:get_tab('lua', 'comment',  '1'))
    assert(not config:get_tab('lua', 'comment',  '2'))
    assert(    config:get_tab('lua', 'comment',  '3'))
    assert(not config:get_tab('lua', 'comment',  '4'))

    assert(    config:get_tab('lua', 'text',  '1'))
    assert(    config:get_tab('lua', 'text',  '2'))
    assert(    config:get_tab('lua', 'text',  '3'))
    assert(    config:get_tab('lua', 'text',  '4'))

    assert(config:get_list('perl', 'comment') == config._lst['*']['*']     )
    assert(config:get_list('perl', 'text')    == config._lst['*']['text']  )
    assert(config:get_list('lua',  'comment') == config._lst['lua']['*']   )
    assert(config:get_list('lua',  'text')    == config._lst['lua']['text'])

    assert_list({'1'},                config._lst['*']['*']     )
    assert_list({'1', '2'},           config._lst['*']['text']  )
    assert_list({'1', '3'},           config._lst['lua']['*']   )
    assert_list({'1', '2', '3', '4'}, config._lst['lua']['text'])

    config:load{
      {scope = '*.*',      activation = '1'}; -- perl.comment
      {scope = 'lua.text', activation = '4'}; -- lua.text
    }

    assert(    config:get_tab('perl', 'comment',  '1'))
    assert(not config:get_tab('perl', 'comment',  '4'))

    assert(    config:get_tab('perl', 'text',  '1'))
    assert(not config:get_tab('perl', 'text',  '4'))

    assert(    config:get_tab('lua', 'comment',  '1'))
    assert(not config:get_tab('lua', 'comment',  '4'))

    assert(    config:get_tab('lua', 'text',  '1'))
    assert(    config:get_tab('lua', 'text',  '4'))

    assert(config:get_list('perl', 'comment') == config._lst['*']['*']     )
    assert(config:get_list('perl', 'text')    == config._lst['*']['*']     )
    assert(config:get_list('lua',  'comment') == config._lst['*']['*']     )
    assert(config:get_list('lua',  'text')    == config._lst['lua']['text'])

    assert_list({'1'},      config._lst['*']['*']     )
    assert_list({'1', '4'}, config._lst['lua']['text'])

    config:load{
      {scope = '*.*',      activation = '1'}; -- perl.comment
      {scope = '*.text',   activation = '2'}; -- perl.text
    }

    assert(    config:get_tab('perl', 'comment',  '1'))
    assert(not config:get_tab('perl', 'comment',  '2'))

    assert(    config:get_tab('perl', 'text',  '1'))
    assert(    config:get_tab('perl', 'text',  '2'))

    assert(    config:get_tab('lua', 'comment',  '1'))
    assert(not config:get_tab('lua', 'comment',  '2'))

    assert(    config:get_tab('lua', 'text',  '1'))
    assert(    config:get_tab('lua', 'text',  '2'))

    assert(config:get_list('perl', 'comment') == config._lst['*']['*']     )
    assert(config:get_list('perl', 'text')    == config._lst['*']['text']  )
    assert(config:get_list('lua',  'comment') == config._lst['*']['*']     )
    assert(config:get_list('lua',  'text')    == config._lst['*']['text']  )

    assert_list({'1'},                config._lst['*']['*']     ) -- perl.comment
    assert_list({'1', '2'},           config._lst['*']['text']  ) -- perl.text
  end
end

return SnippetConfig:new()
