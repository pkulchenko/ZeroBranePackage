local config        = package_require 'snippets.config'
local log           = package_require 'snippets.log'
local Editor        = package_require 'snippets.editor'
local SnippetStack  = package_require 'snippets.stack'

local function pget(t, ...)
  for i = 1, select('#', ...) do
    local idx = select(i, ...)
    if type(t) ~= 'table' then
      return nil
    end
    t = t[idx]
  end
  return t
end

local function pget_string(...)
  local value = pget(...)
  return type(value) == 'string' and value or nil
end

local function re_match(re, str)
  if not re:Matches(str) then
    return nil
  end
  return re:GetMatch(str, 1)
end

local re = wx.wxRegEx('([^ ]+)$')
local function get_last_word(str)
  if str == '' then
    return nil
  end

  local s = re_match(re, str)
  if s == '' then
    s = nil
  end

  return s
end

local function get_line_start(editor)
  local current_pos    = editor:GetCurrentPos()
  local line_start_pos = editor:PositionFromLine(editor:LineFromPosition(current_pos))
  if line_start_pos == current_pos then
    return ''
  end
  return editor:GetTextRange(line_start_pos, current_pos)
end

local SnippetManager = {} do
  SnippetManager.__index = SnippetManager

  function SnippetManager.new(class)
    local self = setmetatable({}, class)

    self._stack = {} or setmetatable({}, {__mode = 'v'})

    return self
  end

  function SnippetManager:create_stack(editor)
    local stack = self._stack[tostring(editor)]
    if not stack then
      stack = SnippetStack:new(editor)
      self._stack[tostring(editor)] = stack
      editor:MarkerSetBackground(config.MARK_SNIPPET, config.MARK_SNIPPET_COLOR)
    end
    return stack
  end

  function SnippetManager:get_stack(editor)
    return self._stack[tostring(editor)]
  end

  function SnippetManager:has_active_snippet(editor)
    local stack = self:get_stack(editor)
    if not stack then
      return false
    end
    return stack:active()
  end

  function SnippetManager:allow_new_snippet(editor)
    local stack = self:get_stack(editor)
    if not stack then
      return true
    end
    return stack:allow_new_snippet()
  end

  function SnippetManager:release(editor)
    local log = log:get('SnippetManager:release')
    if self._stack[tostring(editor)] then
      log:debug('editor %s', tostring(editor))
      self._stack[tostring(editor)] = nil
    end
  end

  function SnippetManager:get_last_word(editor)
    local str = get_line_start(editor)
    return get_last_word(str)
  end

  function SnippetManager:find_snippet_text(editor, snippet_arg)
    local log = log:get('SnippetManager:find_snippet_text')

    if snippet_arg then
      local cursor_pos  = editor:GetCurrentPos()
      local scope, lang = Editor.GetStyleNameAt(editor, cursor_pos)
      log:debug('Cursor: %d; Lexer: %s; Scope: %s; Key: %s', cursor_pos, lang, scope, snippet_arg)

      local snippet_text = config:get_key(lang, scope, snippet_arg)
      if not (snippet_text and snippet_text.text) then
        log:debug('Snippet not found')
        return
      end

      -- Move Cursor to the beginning of selection
      local anchor = editor:GetAnchor()
      if cursor_pos > anchor then
        editor:SetCurrentPos(anchor)
        editor:SetAnchor(cursor_pos)
        cursor_pos = editor:GetCurrentPos()
      end

      return cursor_pos, cursor_pos, snippet_text
    end

    local snippet_name = self:get_last_word(editor)
    if not snippet_name then
      log:debug('Snippet name not found')
      return
    end

    local cursor_pos   = editor:GetCurrentPos()
    local scope, lang = Editor.GetStyleNameAt(editor, cursor_pos)
    log:debug('Cursor: %d; Lexer: %s; Scope: %s, Name: %s', cursor_pos, lang, scope, snippet_name)

    local snippet_text = config:get_tab(lang, scope, snippet_name)

    if not snippet_text then
      log:debug('Snippet not found')
      return
    end

    local start_pos  = cursor_pos - #snippet_name

    log:debug('Origin cursor pos: %d (at line %d) Start pos: %d (at line %d)',
      cursor_pos, editor:LineFromPosition(cursor_pos),
      start_pos,  editor:LineFromPosition(start_pos)
    )

    return cursor_pos, start_pos, snippet_text, snippet_name
  end

  function SnippetManager:cancel_current(editor)
    local stack = self:get_stack(editor)
    if not stack then
      return
    end
    stack:cancel_current()
  end

  function SnippetManager:cancel(editor)
    local log = log:get('SnippetManager:cancel')
    local stack = self:get_stack(editor)
    if stack then
      log:debug('editor %s', tostring(editor))
      stack:cancel_all()
    end
  end

  function SnippetManager:prev(editor)
    local stack = self:get_stack(editor)
    if not stack then
      return
    end
    stack:prev()
  end

  function SnippetManager:next(editor)
    local stack = self:get_stack(editor)
    if not stack then
      log:get('SnippetManager:next'):debug('Stack not found')
      return
    end
    stack:next()
  end

  function SnippetManager:start_snippet(editor, snippet_arg)
    local cursor_pos, start_pos, snippet_text, snippet_name = self:find_snippet_text(editor, snippet_arg)

    if cursor_pos then
      local stack = self:create_stack(editor)
      stack:push(cursor_pos, start_pos, snippet_name, snippet_text)
    end
  end

  function SnippetManager:insert(editor, snippet_arg)
    if self:allow_new_snippet(editor) then
      self:start_snippet(editor, snippet_arg)
    end

    local is_active = self:has_active_snippet(editor)
    self:next(editor)
    return is_active
  end

  ---
  -- Show the scope/style at the current caret position as a calltip.
  function SnippetManager:show_scope(editor)
    local pos          = editor:GetCurrentPos()
    local scope, lexer = Editor.GetStyleNameAt(editor, pos)

    local text = 'Lexer: ' .. lexer .. '\nScope: ' .. scope
    editor:CallTipShow(pos, text)
  end

  ---
  -- List available snippet triggers as an autocompletion list.
  -- Global snippets and snippets in the current lexer and scope are used.
  function SnippetManager:snippet_list(editor)
    if not Editor.HasFocus(editor) then
      return
    end

    local pos   = editor:GetCurrentPos()
    local lexer, scope = Editor.GetStyleNameAt(editor, pos)
    local list = config:get_list(lexer, scope)
    if not (list and list[1]) then
        return
    end

    local sep = string.char(editor:AutoCompGetSeparator())
    list = table.concat(list, sep)
    editor:AutoCompShow(0, list)
  end

  function SnippetManager:load_config(cfg)
    config:load(cfg)
    return config
  end

end

return SnippetManager
