local config         = package_require 'snippets.config'
local log            = package_require 'snippets.log'
local Editor         = package_require 'snippets.editor'
local shell_execute  = package_require 'snippets.utils.shell_execute'
local ruby_regexp    = package_require 'snippets.utils.ruby_regexp'
local string_replace = package_require 'snippets.utils.string_replace'
local Parser         = package_require 'snippets.parser'

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

local function get_macros(editor, selected_text)
  -- TODO support more macros
  local document = Editor.GetDocument(editor)
  local spec = editor.spec or {}

  local macros = {
    SelectedText = selected_text or '',
    I            = Editor.GetIndentString(editor),
    FilePath     = document and document:GetFilePath() or '',
    FileName     = document and document:GetFileName() or '',
    LineNumber   = Editor.GetCurrLineNumber(editor) + 1,
    LineComment  = spec.linecomment or '',
    DateTime     = function() return os.date('%Y-%m-%d %H:%M:%S') end,
    Time         = function() return os.date('%H:%M:%S') end,
    Date         = function() return os.date('%Y-%m-%d') end,
  }

  return function(s, ...)
    local v = macros[s]
    if not v then return nil end
    if type(v) == 'function' then return v(s, ...) end
    return v
  end
end

local Snippet = {}
Snippet.__index = Snippet

function Snippet.new(class, editor, cursor_pos, start_pos, snippet_name, snippet)
  local self = setmetatable({}, class)

  local selected_text, selection_pos_start, selection_pos_end = Editor.GetSelText(editor)
  local selected_len = math.abs(selection_pos_end - selection_pos_start)

  local macros = get_macros(editor, selected_text)

  local placeholders = {}
  local snippet_text = Parser.expand_macros_and_shell(snippet.text, _expand_shell, macros, placeholders)
  local count
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
  self.text         = snippet_text
  self.line_count   = count
  self.placeholders = placeholders
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
  local s, e = self.editor:GetSelection()
  Editor.ReplaceTextRange(self.editor, s, e, self.text)
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
function Snippet:next_placeholder()
  local log = log:get('Snippet:next_placeholder')

  local _, _, s_text = self:get_text()

  -- If something went wrong and the snippet has been 'messed' up
  -- (e.g. by undo/redo commands).
  if not s_text then
    log:error('no text')
    return false
  end

  self:push_snapshot(s_text)
  log:debug('snapshot[%d]:\n%s\n============', self.index, s_text)

  s_text = self:mirror(s_text)
  log:debug('mirrored:\n%s\n============', s_text)

  if not self.placeholders[self.index + 1] then
    self:finish(s_text)
    return true
  end

  self.index = self.index + 1

  log:debug('next index: %d', self.index)

  if not self:replace_placeholder(s_text) then
    -- this should not happened because of we callect all known placeholders
    -- in the `self.placeholders` map
    log:error('can not replace placeholder: %d', self.index)
    return self:next_placeholder()
  end

  return true
end

---
-- Replace text with the default value for a current placeholder
function Snippet:replace_placeholder(s_text)
  self.editor:BeginUndoAction()
  local pass = self:insert_placeholder(s_text)
  self.editor:EndUndoAction()
  return pass
end

local CURSOR_MARKER = '|3563F9B7-0818-4E94-AFB3-3024DBD2C4E6|'

---
-- s_text - escaped text
function Snippet:insert_placeholder(s_text, index, s_start, s_end)
  local log = log:get('Snippet:insert_placeholder')

  index = index or self.index

  local item_start, item_end, item_default = Parser.next_placeholder(s_text, index)
  if not item_start then
    log:debug('Item %d not found', index)
    return false
  end

  log:debug('next item:\n%s\n============', s_text:sub(item_start, item_end))

  if not s_start then
    s_start, s_end = self:get_pos()
  end

  if not s_start then
    log:debug('Snipped body not found')
    return false
  end

  s_text = string_replace(s_text, CURSOR_MARKER, item_start, item_end)

  if index == 0 then -- TODO check this out
    s_text = Parser.unescape(s_text)
    log:debug('escapes removed:\n%s\n============', s_text)
  end

  Editor.ReplaceTextRange(self.editor, s_start, s_end, s_text)

  s_start, s_end = self:get_pos()
  if not s_start then
    log:error('Can not find snippet range')
    return false
  end

  if index == 0 then -- remove last line
    self.editor:SetSelection(s_end, s_end)
    Editor.JoinLines(self.editor)
  end

  -- Find placeholder in editor
  local placeholder_start, placeholder_end = Editor.FindText(self.editor, CURSOR_MARKER, wxstc.wxSTC_FIND_MATCHCASE, s_start, s_end)
  if not placeholder_start and placeholder_start >= 0 then
    log:error('Can not find placeholder marker')
    return false
  end

  self.cursor = placeholder_start

  log:debug('Cursor position: search range [%s, %s]; result [%s, %s]', tostring(s_start), tostring(s_end), tostring(placeholder_start), tostring(placeholder_end))

  if type(item_default) == 'table' and item_default[1] == nil then
    item_default = ''
  end

  if type(item_default) == 'string' then
    Editor.ReplaceTextRange(self.editor, placeholder_start, placeholder_end, item_default)
    self.editor:SetSelection(placeholder_start, self.editor:GetCurrentPos())
    return true
  end

  assert(type(item_default) == 'table')
  Editor.ReplaceTextRange(self.editor, placeholder_start, placeholder_end, '')

  local sep = string.char(self.editor:AutoCompGetSeparator())
  local list = table.concat(item_default, sep)
  self.editor:DoWhenIdle(function()
    self.editor:UserListShow(1, list)
  end)

  return true
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

function Snippet:finish_cleanup(s_text, s_start, s_end)
  local log = log:get('Snippet:finish')

  s_text = Parser.unescape(s_text)

  Editor.ReplaceTextRange(self.editor, s_start, s_end, s_text)

  s_start, s_end = self:get_pos()
  if not s_start then
    log:error('Can not find snipped body')
    return
  end

  self.editor:SetSelection(s_end, s_end)
  Editor.JoinLines(self.editor)
end

function Snippet:finish(s_text)
  local log = log:get('Snippet:finish')
  log:debug('Starting...')
  local s_start, s_end = self:get_pos()
  if s_start then
    self.editor:BeginUndoAction()
    if not self:insert_placeholder(s_text, 0, s_start, s_end) then
      log:debug('No zero tabstopper')
      self:finish_cleanup(s_text, s_start, s_end)
    end
    self.editor:EndUndoAction()
  end

  -- undo should not back marker
  if self.end_marker then
    -- try to remove in any case
    self.editor:MarkerDeleteHandle(self.end_marker)
    self.end_marker = nil
  end

  self.index = nil
  log:debug('Done')
end

-- Mirror and transform.
function Snippet:mirror(s_text)
  if self.index <= 0 then
    return s_text
  end

  if self.cursor then
    self.editor:SetSelection(self.cursor, self.editor:GetCurrentPos())
  else
    self.editor:WordLeftExtend()
  end

  local last_item = Editor.GetSelText(self.editor)

  s_text = Parser.mirror(s_text, self.index, last_item, ruby_regexp)

  return s_text
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

function Snippet:active()
  return self.index ~= nil
end

return Snippet
