return {
  name = "Move line up/down",
  description = "Move line or selection up or down (Ctrl-Shift-Up/Down).",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorKeyDown = function(self, editor, event)
    local key = event:GetKeyCode()
    local mod = event:GetModifiers()
    if (key == wx.WXK_UP or key == wx.WXK_DOWN)
    and (mod == wx.wxMOD_CONTROL + wx.wxMOD_SHIFT) then
      local line1 = editor:LineFromPosition(editor:GetSelectionStart())
      local line2 = editor:LineFromPosition(editor:GetSelectionEnd())
      local cut, insert
      if key == wx.WXK_UP and line1 > 0 then
        cut, insert = line1-1, line2
      elseif key == wx.WXK_DOWN and line2 < editor:GetLineCount()-1 then
        insert, cut = line1, line2+1
      else
        return
      end

      local line = editor:GetLine(cut)

      editor:BeginUndoAction()
      editor:DeleteRange(editor:PositionFromLine(cut), #line)
      local pos = editor:PositionFromLine(insert)
      local current, anchor = editor:GetCurrentPos(), editor:GetAnchor()
      -- inserting at current position requires a fix as the cursor is
      -- anchored to the beginning of the line, which won't move
      if pos == current then editor:SetCurrentPos(current+1) end
      if pos == anchor then editor:SetAnchor(anchor+1) end
      editor:SetTargetStart(pos)
      editor:SetTargetEnd(pos)
      editor:ReplaceTarget(line)
      if pos == current then editor:SetCurrentPos(editor:GetCurrentPos()-1) end
      if pos == anchor then editor:SetAnchor(editor:GetAnchor()-1) end
      editor:EndUndoAction()

      return false -- don't apply "default" handling
    end
  end,
}
