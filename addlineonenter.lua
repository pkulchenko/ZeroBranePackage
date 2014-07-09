return {
  name = "Add line on Enter",
  description = "Adds a new line after (on Ctrl/Cmd-Enter) or before (on Ctrl/Cmd-Shift-Enter).",
  author = "Paul Kulchenko",
  version = 0.1,

  onEditorKeyDown = function(self, editor, event)
    local key = event:GetKeyCode()
    local mod = event:GetModifiers()
    local ctrl = mod == wx.wxMOD_CONTROL
    local ctrlshift = mod == wx.wxMOD_CONTROL + wx.wxMOD_SHIFT
    if (key == wx.WXK_RETURN or key == wx.WXK_NUMPAD_ENTER)
    and (ctrl or ctrlshift) then
      local line = editor:LineFromPosition(editor:GetCurrentPos())
      if ctrlshift then line = line - 1 end

      local pos = editor:GetLineEndPosition(line)
      editor:InsertText(pos, "\n")
      editor:SetCurrentPos(pos+1)

      local ev = wxstc.wxStyledTextEvent(wxstc.wxEVT_STC_CHARADDED)
      ev:SetKey(string.byte("\n"))
      editor:AddPendingEvent(ev)

      return false -- don't apply "default" handling
    end
  end,
}
