local G = ...
local id = G.ID("clippy.clippy")
local menuid
local stack
local kStackLimit = 10

local function SaveStack(self)
	local settings = self:GetSettings()
	settings.stack = stack
    self:SetSettings( settings ) 	
end

local function SaveClip()
	local tdo = wx.wxTextDataObject("None")
	if wx.wxClipboard:Get():Open() then
		wx.wxClipboard:Get():GetData(tdo)
		wx.wxClipboard:Get():Close()

		local newclip = tdo:GetText()
		if newclip ~= "" then
			for i,oldclip in ipairs( stack ) do
				if newclip == oldclip then
					table.remove( stack, i )
					table.insert( stack, 1, newclip )
					stack[kStackLimit] = nil
					return
				end
			end
			table.insert( stack, 1, newclip )
			stack[kStackLimit] = nil
		end
	end
end

local function OpenClipList( editor )
	if not editor then
		return
	end
	
	if editor:AutoCompActive() then
		editor:AutoCompCancel()
	end

	editor:AutoCompSetSeparator(string.byte('\n'))
	editor:AutoCompSetTypeSeparator(0)

	local list, firstline, rem = {}
	for i,clip in ipairs(stack) do
		firstline, rem = string.match(clip,'([^\r\n]+)(.*)')
		if rem ~= "" then firstline = firstline .. "..." end
		list[#list+1] = i.."\t "..firstline
	end
	editor:UserListShow(2,table.concat(list,'\n')) 
	editor:AutoCompSelect( list[2] or "" )

	editor:AutoCompSetSeparator(string.byte(' '))
	editor:AutoCompSetTypeSeparator(string.byte('?'))
end

function PasteClip(i)
	local newclip = stack[i]
	local tdo = wx.wxTextDataObject(newclip)
	if wx.wxClipboard:Get():Open() then
		wx.wxClipboard:Get():SetData(tdo)
		wx.wxClipboard:Get():Close()

		if i ~= 1 then		
			table.remove( stack, i )
			table.insert( stack, 1, newclip )
			stack[kStackLimit] = nil
		end
		
		ide.frame:AddPendingEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, ID_PASTE))
		return true
	end
	return false
end

local function OnRegister(self)
	local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
	menuid = menu:Append(id, "Open Clip Stack"..KSC(id, "Ctrl-Shift-V"))
	ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED, function (event)
			OpenClipList(ide:GetEditorWithFocus(ide:GetEditor()))
		end)
	ide:GetMainFrame():Connect(id, wx.wxEVT_UPDATE_UI, function (event)
			event:Check(ide:GetEditorWithFocus(ide:GetEditor()) ~= nil)
		end)
	
	local settings = self:GetSettings()
	stack = settings.stack or {}
	settings.stack = stack
    self:SetSettings(settings)
end

local function OnUnRegister(self)
	local menu = ide:GetMenuBar():GetMenu(ide:GetMenuBar():FindMenu(TR("&Edit")))
	ide:GetMainFrame():Disconnect(id, wx.wxID_ANY, wx.wxID_ANY)
	if menuid then menu:Destroy(menuid) end
end

local function OnEditorAction( self, editor, event )
	local eid = event:GetId()
	if eid == ID_COPY or eid == ID_CUT then
		-- call the original handler first to process Copy/Cut event
		self.onEditorAction = nil
		ide.frame:ProcessEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_MENU_SELECTED, eid))
		self.onEditorAction = OnEditorAction
		SaveClip()
		SaveStack(self)
		return false
	end
end

local function OnEditorUserlistSelection( self, editor, event )
	if event:GetListType() == 2 then			
		local i = tonumber( event:GetText():sub(1,1) );
		PasteClip(i)
		SaveStack(self)
		return false
	end
end

return
{
	name = "Clippy",
	description = "Enables a stack-based clipboard which saves the last 10 entries",
	author = "sclark39",
	dependencies = 0.61,
	version = 0.2,
	onRegister = OnRegister,
	onUnRegister = OnUnRegister,
	onEditorAction = OnEditorAction,
	onEditorUserlistSelection = OnEditorUserlistSelection,
}