-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC; All rights reserved

local G = ...
local id = G.ID("referencepanel.referenceview")
local refpanel = "referencepanel"
local refeditor
local spec = {iscomment = {}}
return {
  name = "Show Reference in a panel",
  description = "Adds a panel for showing documentation based on tooltips.",
  author = "Paul Kulchenko",
  version = 0.11,
  dependencies = 0.81,

  onRegister = function(self)
    local e = ide:CreateBareEditor()
    refeditor = e

    local w, h = 250, 250
    local conf = function(pane)
      pane:Dock():MinSize(w,-1):BestSize(w,-1):FloatingSize(w,h)
    end
    if ide:IsPanelDocked(refpanel) then
      ide:AddPanelDocked(ide:GetOutputNotebook(), e, refpanel, TR("Reference"), conf)
    else
      ide:AddPanel(e, refpanel, TR("Reference"), conf)
    end

    do -- markup handling in the reference panel
      -- copy some settings from the lua spec
      for _, s in ipairs({'lexer', 'lexerstyleconvert'}) do
        spec[s] = ide.specs.lua[s]
      end
      -- this allows the markup to be recognized in all token types
      for i = 0, 16 do spec.iscomment[i] = true end
      e:Connect(wxstc.wxEVT_STC_UPDATEUI, function(event) MarkupStyle(e,0,e:GetLineCount()) end)
    end

    e:SetReadOnly(true)
    e:SetWrapMode(wxstc.wxSTC_WRAP_WORD)
    e:SetupKeywords("lua",spec,ide:GetConfig().styles,ide:GetOutput():GetFont())

    -- remove all margins
    for m = 0, 4 do e:SetMarginWidth(m, 0) end

    -- disable dragging to the panel
    e:Connect(wxstc.wxEVT_STC_DO_DROP, function(event) event:SetDragResult(wx.wxDragNone) end)

    local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&View")))
    menu:InsertCheckItem(4, id, TR("Reference Window")..KSC(id))
    menu:Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function (event)
        local uimgr = ide:GetUIManager()
        uimgr:GetPane(refpanel):Show(not uimgr:GetPane(refpanel):IsShown())
        uimgr:Update()
      end)
    ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function (event)
        local pane = ide:GetUIManager():GetPane(refpanel)
        menu:Enable(event:GetId(), pane:IsOk()) -- disable if doesn't exist
        menu:Check(event:GetId(), pane:IsOk() and pane:IsShown())
      end)
  end,

  onUnRegister = function(self)
    ide:RemoveMenuItem(id)
  end,

  onEditorCallTip = function(self, editor, tip, value, eval)
    if not refeditor or eval then return end

    -- update the reference text
    refeditor:SetReadOnly(false)
    refeditor:SetText(tip)
    refeditor:SetReadOnly(true)

    local pane = ide:GetUIManager():GetPane(refpanel)
    -- if the reference tab is docked or the pane is shown,
    -- then suppress the normal tooltip (`return false`)
    if not pane:IsOk() or pane:IsShown() then return false end
  end,
}
