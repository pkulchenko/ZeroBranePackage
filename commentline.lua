
--[[
	This package allows users to comment out lines by pressing Ctrl + [Assigned Key]
	This can be used on a single line, and multiple lines.
]]





-- This is the key you use to comment lines out, or in.
local m_Key = "e"





return {
	name = "Comment Line",
	description = "Comment or uncomment a line (Ctrl-E).",
	author = "NiLSPACE",
	version = 0.1,

	onEditorKeyDown = function(self, editor, event)
		if (not event:ControlDown()) then
			-- Ctrl isn't pressed. Bail out
			return true
		end
		
		local key = event:GetKeyCode()
		if (key ~= m_Key:upper():byte()) then
			-- The key to comment lines out isn't pressed
			return true
		end
		
		local SelectionStart = editor:GetSelectionStart()
		local SelectionEnd   = editor:GetSelectionEnd()
		
		local StartLine = editor:LineFromPosition(SelectionStart)
		local EndLine   = editor:LineFromPosition(SelectionEnd)
		
		SelectionStart = SelectionStart + (editor:GetLine(StartLine):match("^(%s*)%-%-") and -3 or 3)
		SelectionEnd   = SelectionEnd + (editor:GetLine(EndLine):match("^(%s*)%-%-") and -3 or 3)
		
		editor:BeginUndoAction()
		
		-- Loop through the selected lines, and comment/uncomment them.
		for LineNr = StartLine, EndLine, 1 do
			local line = editor:GetLine(LineNr)
			local LineContent;
			
			-- Check if this line already is a comment.
			if (line:match("^(%s*)%-%-")) then
				LineContent = line:gsub("^(%s*)--[%s](.*)", "%1%2")
			else
				LineContent = line:gsub("^(%s*)(.*)$", "%1-- %2")
			end
			
			editor:DeleteRange(editor:PositionFromLine(LineNr), #line)
			editor:SetTargetStart(editor:PositionFromLine(LineNr))
			editor:SetTargetEnd(editor:PositionFromLine(LineNr) - 1)
			editor:ReplaceTarget(LineContent)
		end
		
		editor:SetAnchor(SelectionStart)
		editor:SetCurrentPos(SelectionEnd)
		
		editor:EndUndoAction()
		return false -- block default action
	end,
}
