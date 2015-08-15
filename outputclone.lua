local G = ...
local id = G.ID("outputclone.outputclone")
local frame
return {
  name = "Clone Output window",
  description = "Clones Output window to keep it on the screen when the application loses focus (OSX).",
  author = "Paul Kulchenko",
  version = 0.2,

  onRegister = function(self)
    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    local pos = self.GetConfig and self:GetConfig().insertat and
      self:GetConfig().insertat-1 or 4
    menu:InsertCheckItem(pos, id, "Output Window Clone\tCtrl-Shift-C")
    ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,
      function (event)
        if not frame then
          local output = ide:GetOutput()

          frame = wx.wxFrame(ide:GetMainFrame(), wx.wxID_ANY, "Output Clone",
            wx.wxDefaultPosition, wx.wxDefaultSize,
            wx.wxDEFAULT_FRAME_STYLE + wx.wxFRAME_FLOAT_ON_PARENT)
          frame:SetClientSize(output:GetSize():GetWidth(), output:GetSize():GetHeight())
          frame:Move(output:GetScreenPosition())
          frame:Connect(wx.wxEVT_CLOSE_WINDOW,
            function(event)
              frame:Hide()
              menu:Check(id, false)
              event:Veto()
            end)

          local clone = wxstc.wxStyledTextCtrl(frame, wx.wxID_ANY,
            wx.wxDefaultPosition, wx.wxSize(0, 0), wx.wxBORDER_STATIC)
          local docpointer = output:GetDocPointer()
          output:AddRefDocument(docpointer)
          clone:SetDocPointer(docpointer)

          if self:GetConfig().autoscroll ~= false then
            clone:Connect(wxstc.wxEVT_STC_MODIFIED, function(event)
              if bit.band(event:GetModificationType(), wxstc.wxSTC_MOD_INSERTTEXT) ~= 0 then
                clone:ScrollToLine(clone:GetLineCount()-1)
              end
            end)
          end

          -- set styles to make it look similar to the output window
          clone:MarkerDefine(StylesGetMarker("message"))
          clone:MarkerDefine(StylesGetMarker("prompt"))
          StylesApplyToEditor(ide:GetConfig().stylesoutshell,clone,ide.font.oNormal,ide.font.oItalic)
        end

        frame:Show(event:IsChecked())
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,

  onAppClose = function(self, app)
    if frame then frame:Destroy() end
  end
}
