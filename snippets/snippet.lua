local config        = package_require 'snippets.config'
local log           = package_require 'snippets.log'
local Editor        = package_require 'snippets.editor'
local shell_execute = package_require 'snippets.utils.shell_execute'
local ruby_regexp   = package_require 'snippets.utils.ruby_regexp'
local escape_encode = package_require 'snippets.escape'.encode
local escape_decode = package_require 'snippets.escape'.decode
local escape_remove = package_require 'snippets.escape'.remove

local function get_macros(editor, selected_text)
  -- TODO support more macros
  local macros = {
    SelectedText = selected_text or '',
    I            = Editor.GetIndentString(editor),
  }
  return macros
end

local Snippet = {}
Snippet.__index = Snippet

function Snippet.new(class, editor, cursor_pos, start_pos, snippet_name, snippet)
  local self = setmetatable({}, class)

  local selected_text, selection_pos_start, selection_pos_end = Editor.GetSelText(editor)
  local selected_len = math.abs(selection_pos_end - selection_pos_start)

  local macros = get_macros(editor, selected_text)

  local snippet_text = snippet.text

  local count
  snippet_text = escape_encode(snippet_text)
  snippet_text = self:expand_macros(snippet_text, macros)
  snippet_text = self:expand_shell(snippet_text)
  snippet_text, count = Editor.NormalizeEOL(editor, snippet_text)

  if selected_text == '' then
    selected_text = nil
  end

  if selected_text then
    selected_len = selected_len or #selected_text
  else
    selected_len = nil
  end

  self.index        = 0
  self.nested       = snippet.nested
  self.editor       = editor
  self.name         = snippet_name
  self.cursor_pos   = cursor_pos
  self.start_pos    = start_pos
  self.sel_text     = selected_text
  self.sel_len      = selected_len
  self.text         = escape_decode(snippet_text)
  self.line_count   = count
  self.placeholders = self:collect_placeholders(snippet_text)
  self.snapshots    = {}
  self.cursor       = nil
  self.end_marker   = nil

  return self
end

---
-- Replace selected text in editor to a snippet value
function Snippet:start()
  self.editor:BeginUndoAction()
  self:insert_text()
  self.editor:EndUndoAction()
end

---
-- Insert the snippet and set a mark defining the end of it.
function Snippet:insert_text()
  if self.name then -- use tab activator
    -- this call uses to close autocomplite list
    self.editor:WordLeftExtend()
    -- select snippet name
    self.editor:SetSelection(self.start_pos, self.cursor_pos)
  end
  self.editor:ReplaceSelection(self.text)
  self:set_end_marker()
  self:indent()
end

---
-- Insert end of snippet marker to editor
function Snippet:set_end_marker()
  self.editor:NewLine()
  local line = Editor.GetCurrLineNumber(self.editor)
  self.end_marker = self.editor:MarkerAdd(line, config.MARK_SNIPPET)
end

---
-- Indent all lines inserted.
function Snippet:indent()
  self.editor:SetCurrentPos(self.start_pos)
  local line = Editor.GetCurrLineNumber(self.editor)
  Editor.AlignIndentation(self.editor, line, self.line_count)
end

---
-- Cancels active snippet, reverting to the state before the snippet was
-- activated.
function Snippet:cancel()
  local s_start, s_end = self:get_pos()
  if s_start and s_end then
    Editor.ReplaceTextRange(self.editor, s_start, s_end, '')
    Editor.JoinLines(self.editor)
  end

  if self.sel_text then
    self.editor:AddText(self.sel_text)
    local anchor = self.editor:GetAnchor() - self.sel_len
    self.editor:SetAnchor(anchor)
  elseif self.name then
    self.editor:AddText(self.name)
  end

  self.editor:MarkerDeleteHandle(self.end_marker)
end

---
-- Moves to the next placeholder. Finish snippiet if there no one
function Snippet:next_placeholder(s_start, s_end, s_text)
  local log = log:get('Snippet:next_placeholder')

  self.index = self.index + 1

  if not self.placeholders[self.index] then
    self:finish(s_text)
    return true
  end

  log:debug('next index: %d', self.index)

  self.editor:BeginUndoAction()
  local pass = self:replace_placeholder(s_start, s_end, s_text)
  self.editor:EndUndoAction()

  if not pass then
    return false
  end

  return true
end

---
-- Replace text with the default value for a current placeholder
function Snippet:replace_placeholder(s_start, s_end, s_text)
  local log = log:get('Snippet:replace_placeholder')

  local next_item = self:next_item(s_text)
  if not next_item then
    log:error('no item for placeholder %d', self.index)
    return false
  end
  log:debug('next item:\n%s\n============', next_item)

  s_text = escape_decode(s_text)
  log:debug('unescaped:\n%s\n============', s_text)

  Editor.ReplaceTextRange(self.editor, s_start, s_end, s_text)
  s_start, s_end = self:get_pos()

  local placeholder_start, placeholder_end
  if s_start then
    placeholder_start, placeholder_end = Editor.FindText(self.editor, next_item, 0, s_start, s_end)
  end

  if placeholder_start and placeholder_end and placeholder_start >= 0 then
    self.cursor = placeholder_start
    local default = string.match(next_item, '^%${' .. self.index .. ':(.*)}$')
    Editor.ReplaceTextRange(self.editor, placeholder_start, placeholder_end, default)
    self.editor:SetSelection(placeholder_start, self.editor:GetCurrentPos())
    return true
  end

  log:error('can not find next_item in the editor:\n%s\n============', next_item)
  return false
end

---
-- Revers the state before last placeholder was activated.
-- Returns true in case of success
function Snippet:prev_placeholder()
  local log = log:get('Snippet:prev_placeholder')
  local index = self.index - 2
  if index >= 0 then
    self.index = index
    log:debug('next index: %d', index)

    local s_text = self.snapshots[index]
    log:debug('snapshot[%d]:\n%s\n============', index, s_text)

    local s_start, s_end = self:get_pos()
    if s_start then
      Editor.ReplaceTextRange(self.editor, s_start, s_end, s_text)
    end

    return true
  end
end

---
-- Saves snapshot for current placeholder
function Snippet:push_snapshot(s_text)
  self.snapshots[self.index] = s_text
end

function Snippet:finish_reset_text(s_text)
  local log = log:get('Snippet:finish')
  local s_start, s_end = self:get_pos()
  if not s_start then
    log:debug('snippet not found')
    return
  end

  -- TODO support default value for ${0}
  s_text = s_text:gsub('${0}', '$CURSOR', 1)
  s_text = escape_decode(s_text)
  log:debug('unescaped:\n%s\n============', s_text)

  s_text = escape_remove(s_text)
  log:debug('escapes removed:\n%s\n============', s_text)
  Editor.ReplaceTextRange(self.editor, s_start, s_end, s_text)

  s_start, s_end = self:get_pos()
  if not s_start then
    log:error('Can not find snippet after cursor replacement')
    return
  end

  log:debug('Move cursor to pos: %d (at line %d)',
    s_end, self.editor:LineFromPosition(s_end)
  )
  self.editor:SetSelection(s_end, s_end)
  Editor.JoinLines(self.editor)

  local s, e = Editor.FindText(self.editor, '$CURSOR', wxstc.wxSTC_FIND_MATCHCASE, s_start, s_end)
  log:debug('search cursor: search range [%s, %s]; result [%s, %s]', tostring(s_start), tostring(s_end), tostring(s), tostring(e))
  if s and e and s >= 0 then
    Editor.ReplaceTextRange(self.editor, s, e, '')
  else
    self.editor:SetSelection(s_end, s_end) -- at snippet end marker
  end
end

function Snippet:finish(s_text)
  local log = log:get('Snippet:finish')
  log:debug('Starting...')
  self.editor:BeginUndoAction()
  self:finish_reset_text(s_text)
  self.editor:MarkerDeleteHandle(self.end_marker)
  self.editor:EndUndoAction()
  self.index = nil
  log:debug('Done')
end

function Snippet:next_item(s_text)
  local start = string.find(s_text, '${' .. self.index .. ':', nil, true)
  if not start then
    return nil
  end

  local next_item = string.match(s_text, '($%b{})', start)
  if not next_item then
    return nil
  end

  return escape_decode(next_item)
end

-- Mirror and transform.
function Snippet:mirror(s_text)
  s_text = escape_encode(s_text)

  if self.index > 0 then
    if self.cursor then
      self.editor:SetSelection(self.cursor, self.editor:GetCurrentPos())
    else
      self.editor:WordLeftExtend()
    end

    local last_item = Editor.GetSelText(self.editor)

    -- Regex mirror.
    s_text = self:expand_pattern(s_text, last_item)

    -- Plain text mirror.
    s_text = self:expand_plain(s_text, last_item)
  end

  return s_text
end

local function _expand_shell(code)
    local log = log:get('Snippet:expand_shell')
    log:debug('execute: %s', code)
    local ret, stdout, stderr = shell_execute(code)
    if ret ~= 0 then
      log:error('code: %d\n%s\n============', ret, stderr)
      return ''
    end
    return stdout
end

function Snippet:expand_shell(text)
  return text:gsub('`(.-)`', _expand_shell)
end

function Snippet:expand_macros(text, macros)
  return (string.gsub(text, '%$%((.-)%)', macros))
end

function Snippet:expand_pattern(text, last_item)
  local patt = '%${' .. self.index .. '/(.-)/(.-)/([iomxneus]*)}'
  text = string.gsub(text, patt, function(pattern, replacement, options)
    return ruby_regexp(last_item, pattern, replacement, options)
  end)
  return text
end

function Snippet:expand_plain(text, last_item)
  local mirror = '%${' .. self.index .. '}'
  text = string.gsub(text, mirror, last_item)
  return text
end

function Snippet:collect_placeholders(text)
  local placeholders = {}

  local item_patt, index_patt = '()($%b{})', '^%${(%d+):.*}$'

  local pos, item = string.match(text, item_patt)
  while item do
    local index = string.match(item, index_patt)
    if index then
      placeholders[ tonumber(index) ] = true
    end
    pos, item = string.match(text, item_patt, pos + 1)
  end

  return placeholders
end

---
-- [Local function] Gets the text of the snippet.
-- This is the text bounded by the start of the trigger word to the end snippet
-- marker on the line after the snippet's end.
function Snippet:get_text()
  local snippet_start, snippet_end = self:get_pos()
  if not snippet_start then
    return
  end

  local text = self.editor:GetTextRange(snippet_start, snippet_end)
  return snippet_start, snippet_end, text
end

---
-- [Local function] Gets the snippet start and end position
function Snippet:get_pos()
  local snippet_start = self.start_pos
  local snippet_end   = self:get_end_pos()

  if snippet_start > snippet_end then
    return
  end

  return snippet_start, snippet_end
end

function Snippet:get_end_pos()
  local eol = Editor.GetEOL(self.editor)
  local line = self.editor:MarkerLineFromHandle(self.end_marker)
  return self.editor:PositionFromLine(line) - #eol
end

function Snippet:support_nested()
  return self.nested
end

return Snippet
