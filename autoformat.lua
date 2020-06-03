return {
    name = "Auto format files on save (Correct Indentation).",
    description = "Re-indents files before saving them.",
    author = "Ryan P. C. McQuen",
    version = 0.1,

    onEditorPreSave = function(self, editor)
        ide:GetMainFrame():ProcessEvent(
            wx.wxCommandEvent(
                wx.wxEVT_COMMAND_MENU_SELECTED,
                ID.REINDENT
            )
        )
    end,
}
