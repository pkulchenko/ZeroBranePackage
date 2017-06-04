-- Modified version of autodelimiter.lua
-- This version supports sorround selection and autoremoving alone pairs
-- Please see pull request #33 (https://github.com/pkulchenko/ZeroBranePackage/pull/33) for more information
-- If you load this module and standard autodelimiter, the standard autodelimiter will be turned off to prevent collisions
local cpairs = {
  ['('] = ')', ['['] = ']', ['{'] = '}', ['"'] = '"', ["'"] = "'"}
local closing = [[)}]'"]]
local selection = ""
return {
  name = "Auto-insertion of delimiters",
  description = [[Adds auto-insertion of delimiters (), {}, [], '', and "".]],
  author = "Paul Kulchenko (modified by Dominik Banaszak)",
  version = 0.3,
onEditorKeyDown = function(self, editor, event)
    ide.packages["autodelimiter"] = nil -- prevent loading the autodelimiter package
    local currentpos = editor:GetCurrentPos()
    local keycode = event:GetKeyCode()
    if keycode == 8 then -- backslash
      if cpairs[string.char(editor:GetCharAt(currentpos - 1))] == string.char(editor:GetCharAt(currentpos)) then
        editor:DeleteRange(currentpos, 1)
      end
    end
    selection = editor:GetSelectedText()
  end,
  onEditorCharAdded = function(self, editor, event)
    local keycode = event:GetKey()
    local hyphen = string.byte("-")
    local backslash = string.byte("\\")
    if keycode > 255 then return end -- special or unicode characters can be skipped here

    local char = string.char(keycode)
    local curpos = editor:GetCurrentPos()

    if closing:find(char, 1, true) and editor:GetCharAt(curpos) == keycode then
      -- if the entered text matches the closing one
      -- and the current symbol is the same, then "eat" the character
      if editor:GetCharAt(curpos - 2) ~= backslash then
        editor:DeleteRange(curpos, 1)
      end
    elseif cpairs[char] then
      if editor:GetCharAt(curpos - 2) ~= hyphen and editor:GetCharAt(curpos - 3) ~= hyphen then
      -- if the entered matches opening delimiter, then insert the pair
        editor:InsertText(-1, selection .. cpairs[char])
      end
    end
  end,
}
