---
-- Some useful functions
local Editor = {}

local SC_EOL_CRLF = 0
local SC_EOL_CR   = 1
local SC_EOL_LF   = 2

local LEXER_NAMES = {}
for k, v in pairs(wxstc) do
  if string.find(tostring(k), 'wxSTC_LEX') then
    local name = string.lower(string.sub(k, 11))
    LEXER_NAMES[ v ] = name
  end
end

-- Get from ru-SciTE. So there no gurantee about correctness for ZBS
local IS_COMMENT, COMMENTS = {}, {
  abap       = {1, 2},
  ada        = {10},
  asm        = {1, 11},
  au3        = {1, 2},
  baan       = {1, 2},
  bullant    = {1, 2, 3},
  caml       = {12, 13, 14, 15},
  cpp        = {1, 2, 3, 15, 17, 18},
  csound     = {1, 9},
  css        = {9},
  d          = {1, 2, 3, 4, 15, 16, 17},
  escript    = {1, 2, 3},
  euphoria   = {1, 18},
  flagship   = {1, 2, 3, 4, 5, 6},
  forth      = {1, 2, 3},
  gap        = {9},
  hypertext  = {9, 20, 29, 42, 43, 44, 57, 58, 59, 72, 82, 92, 107, 124, 125},
  xml        = {9, 29},
  inno       = {1, 7},
  latex      = {4},
  lua        = {1, 2, 3},
  script_lua = {4, 5},
  mmixal     = {1, 17},
  nsis       = {1, 18},
  opal       = {1, 2},
  pascal     = {2, 3, 4},
  perl       = {2},
  bash       = {2},
  pov        = {1, 2},
  ps         = {1, 2, 3},
  python     = {1, 12},
  rebol      = {1, 2},
  ruby       = {2},
  scriptol   = {2, 3, 4, 5},
  smalltalk  = {3},
  specman    = {2, 3},
  spice      = {8},
  sql        = {1, 2, 3, 13, 15, 17, 18},
  tcl        = {1, 2, 20, 21},
  verilog    = {1, 2, 3},
  vhdl       = {1, 2}
}
for lang, styles in pairs(COMMENTS) do
  local set = {}
  for _, style in ipairs(styles) do
    set[style] = true
  end
  IS_COMMENT[lang] = set
end

local function IsComment(spec, lang, style)
  local is_comment = spec and spec.iscomment or IS_COMMENT[lang]

  if is_comment then
    return is_comment[style]
  end

  -- For most other lexers comment has style 1
  -- asn1, ave, blitzbasic, cmake, conf, eiffel, eiffelkw, erlang, euphoria, fortran,
  -- f77, freebasic, kix, lisp, lout, octave, matlab, metapost, nncrontab, props, batch,
  -- makefile, diff, purebasic, vb, yaml
  return style == 1
end

local function IsString(spec, lang, style)
  local is_string = spec and spec.isstring
  return is_string and is_string[style] or false
end

local function GetStyleName(spec, lang, style)
  if IsComment(spec, lang, style) then
    return 'comment'
  end

  if IsString(spec, lang, style) then
    return 'string'
  end

  return 'text'
end

function Editor.GetLexer(editor)
  return editor.spec and editor.spec.lexer or editor:GetLexer()
end

function Editor.GetLanguage(editor)
  local lexer = Editor.GetLexer(editor)
  local name = LEXER_NAMES[lexer]
  if name then return name end
  if type(lexer) == 'string' then
    name = string.match(lexer, '^lexlpeg%.(.+)$')
  end
  return name or 'UNKNOWN'
end

function Editor.GetEOL(editor)
  local eol = "\r\n"
  if editor.EOLMode == SC_EOL_CR then
    eol = "\r"
  elseif editor.EOLMode == SC_EOL_LF then
    eol = "\n"
  end
  return eol
end

---
-- Replace all EOL according to editor settings
function Editor.NormalizeEOL(editor, text)
  local eol = Editor.GetEOL(editor)
  text = string.gsub(text, '\r?\n', eol)

  local count, i = -1, -1
  repeat
    count = count + 1
    i = string.find(text, eol, i + 1, true)
  until i == nil

  return text, count
end

---
-- Joins current line with the line below it, eliminating
-- whitespace.
-- This is used to remove the empty line containing the end of snippet marker.
function Editor.JoinLines(editor)
  -- Move to first non blanck character
  editor:LineDown() editor:VCHome()
  if Editor.GetCurrColNumber(editor) == 0 then
    editor:VCHome()
  end

  if Editor.GetCurrColNumber(editor) > 0 then
    editor:HomeExtend()
    editor:DeleteBack()
  end

  editor:DeleteBack()
end

---
-- When snippets are inserted, match their indentation level
-- with their surroundings.
function Editor.AlignIndentation(editor, ref_line, num_lines)
  if num_lines == 0 then return end

  local base_level  = Editor.GetLineIndentationLevel(editor, ref_line)
  local indent = editor:GetIndent()
  for i = 1, num_lines do
    local line_indent = editor:GetLineIndentation(ref_line + i)
    editor:SetLineIndentation(ref_line + i, line_indent + base_level * indent)
  end
end

function Editor.GetCurrLineNumber(editor)
  local pos = editor:GetCurrentPos()
  return editor:LineFromPosition(pos)
end

function Editor.GetCurrColNumber(editor)
  local pos = editor:GetCurrentPos()
  return editor:GetColumn(pos)
end

function Editor.GetIndentString(editor)
  if editor:GetUseTabs() then
    return '\t'
  end

  local size = editor:GetIndent()
  if (not size) or (size < 1) then
    size = 1
  end

  return string.rep(' ', size)
end

function Editor.FindText(editor, text, flags, start, finish)
  editor:SetSearchFlags(flags or 0)
  editor:SetTargetStart(start or 0)
  editor:SetTargetEnd(finish or editor:GetLength())
  local posFind = editor:SearchInTarget(text)
  if posFind ~= wx.wxNOT_FOUND then
    start, finish = editor:GetTargetStart(), editor:GetTargetEnd()
    if start >= 0 and finish >= 0 then
      return start, finish
    end
  end
  return wx.wxNOT_FOUND, 0
end

function Editor.ReplaceTextRange(editor, start_pos, end_pos, text)
  editor:SetSelection(start_pos, end_pos)
  editor:ReplaceSelection(text)
end

function Editor.GetSelText(editor)
  local selection_pos_start, selection_pos_end = editor:GetSelection()
  local selection_line_start = editor:LineFromPosition(selection_pos_start)
  local selection_line_end   = editor:LineFromPosition(selection_pos_end)

  local selection = {
    pos_start    = selection_pos_start,
    pos_end      = selection_pos_end,
    first_line   = selection_line_start,
    last_line    = selection_line_end,
    is_rectangle = editor:SelectionIsRectangle(),
    is_multiple  = editor:GetSelections() > 1,
    text         = ''
  }

  if selection_pos_start ~= selection_pos_end then
    if selection.is_rectangle then
      local EOL = Editor.GetEOL(editor)
      local selected, not_empty = {}, false
      for line = selection_line_start, selection_line_end do
        local selection_line_pos_start = editor:GetLineSelStartPosition(line)
        local selection_line_pos_end   = editor:GetLineSelEndPosition(line)
        not_empty = not_empty or selection_line_pos_start ~= selection_line_pos_end
        local text = editor:GetTextRange(selection_line_pos_start, selection_line_pos_end)
        table.insert(selected, text)
      end
      selection.text = not_empty and (table.concat(selected, EOL) .. EOL) or ''
    else
      selection.text = editor:GetTextRange(selection_pos_start, selection_pos_end)
    end
  end

  return selection.text, selection.pos_start, selection.pos_end
end

function Editor.GetStyleAt(editor, pos)
  local mask = bit.lshift(1, editor:GetStyleBitsNeeded()) - 1
  return bit.band(mask, editor:GetStyleAt(pos))
end

function Editor.GetStyleNameAt(editor, pos)
  local style = Editor.GetStyleAt(editor, pos)
  local lang  = Editor.GetLanguage(editor)
  return GetStyleName(editor.spec, lang, style), lang
end

function Editor.GetLineIndentationLevel(editor, num_line)
  if num_line < 0 then num_line = 0 end
  local count = editor:GetLineCount()
  if num_line >= count then num_line = count - 1 end

  local line_indent = editor:GetLineIndentation(num_line)
  local indent = editor:GetIndent()
  if indent <= 0 then indent = 1 end

  return math.floor(line_indent / indent)
end

function Editor.HasFocus(editor)
  return editor == ide:GetEditorWithFocus() and editor
end

function Editor.GetDocument(editor)
  return ide:GetDocument(editor)
end

function Editor.GetCurrentFilePath(editor)
  local doc = Editor.GetDocument(editor)
  return doc and doc:GetFilePath()
end

return Editor
