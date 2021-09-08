-- TODO
--  * add options to not expand snippet inside another snippet

local IS_WINDOWS = package.config:sub(1,1) == '\\'

local function Color(param)
  param = (tonumber(param) or 0) % (1+0xFFFFFFFF)
  local r = param % 256; param = math.floor(param / 256)
  local b = param % 256; param = math.floor(param / 256)
  local g = param % 256; param = math.floor(param / 256)
  return wx.wxColour(r, g, b)
end

local SnippetConfig = {
  DEBUG              = true,
  MARK_SNIPPET       = 4,
  MARK_SNIPPET_COLOR = Color(IS_WINDOWS and 5085593 or tonumber("0x4D9999")),
}
SnippetConfig.__index = SnippetConfig

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

function SnippetConfig:add_list(lang, scope, activation_text)
    local node = add_scope(self._lst, lang, scope, activation_text)
    local set = node.set or {}
    node.set = set
    set[activation_text] = true
end

function SnippetConfig:build_list()
    for activation_text, node in pairs(self._tab) do
        for lang, lang_node in pairs(node) do
            for scope, scope_node in pairs(lang_node) do
                self:add_list(lang, scope, activation_text)
            end
        end
    end

    -- scopes `*.<SCOPE>` add to `lang.<SCOPE>` or `lang.*`
    --   and scopes `*.*` add  to all `lang.`
    local any_lst = self._lst['*']
    if any_lst then
        for lang, lang_node in pairs(self._lst) do
            if lang ~= '*' then
                for scope, scope_node in pairs(lang_node) do
                    for any_scope, any_node in pairs(any_lst) do
                        if any_scope == scope or scope == '*' then
                            for activation_text in pairs(any_node.set) do
                                scope_node.set[activation_text] = true
                            end
                        end
                    end
                end
            end
        end
    end

    for lang, lang_node in pairs(self._lst) do
        local any_node = lang_node['*']
        if any_node then
            -- scopes `lang.*` add to all `lang.<SCOPE>` nodes
            for scope, scope_node in pairs(lang_node) do
                if scope ~= '*' then
                    for activation_text in pairs(any_node.set) do
                        scope_node.set[activation_text] = true
                    end
                end
            end
            -- scopes `lang.*` add to all `*.<SCOPE>` nodes
            if any_lst and lang ~= '*' then
                for _, any_lang_node in pairs(any_lst) do
                    for activation_text in pairs(any_node.set) do
                        any_lang_node.set[activation_text] = true
                    end
                end
            end
        end
    end

    for lang, lang_node in pairs(self._lst) do
        for scope, scope_node in pairs(lang_node) do
            local lst = {}
            for activation_text in pairs(scope_node.set) do
                table.insert(lst, activation_text)
            end
            table.sort(lst)
            scope_node.set = nil
            scope_node.lst = lst
        end
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
    local list = find_scope(self._lst, lang, scope)
    return list and list.lst or nil
end

return SnippetConfig:new()
