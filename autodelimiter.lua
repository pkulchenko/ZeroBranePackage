local pairs = {
  ['('] = ')', ['['] = ']', ['{'] = '}', ['"'] = '"', ["'"] = "'"}
local closing = [[)}]'"]]
return {
  name = "Auto-insertion of delimiters",
  description = [[Adds auto-insertion of delimiters (), {}, [], '', and "".]],
  author = "Paul Kulchenko",
  version = 0.2,

  onEditorCharAdded = function(self, editor, event)
    local keycode = event:GetKey()
    if keycode > 255 then return end -- special or unicode characters can be skipped here

    local char = string.char(keycode)
    local curpos = editor:GetCurrentPos()

    if closing:find(char, 1, true) and editor:GetCharAt(curpos) == keycode then
      -- if the entered text matches the closing one
      -- and the current symbol is the same, then "eat" the character
      editor:DeleteRange(curpos, 1)
    elseif pairs[char] then
      -- if the entered matches opening delimiter, then insert the pair
      editor:InsertText(-1, pairs[char])
    end
  end,
}