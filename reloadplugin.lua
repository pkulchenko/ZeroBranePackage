-- @LICENSE MIT
-- Copyright 2017 Paul Kulchenko, ZeroBrane LLC;
-- Contributed by Chronos Phaenon Eosphoros (@cpeosphoros)
-- Hot reloads the plugin in the current editor. It will unregister and register
-- again the plugin, in order to avoid sideffects like duplicate menu entries,
-- etc.

local id = ID("reloadplugin.reloadplugin")

local function print(...)
	ide:Print(...)
end

local function printf(...)
	ide:Print(string.format(...))
end

-- snippet taken from plugin analyzeall.lua
-- Copyright 2014 Paul Kulchenko, ZeroBrane LLC;
local function analyze(filePath)
	local warn, err = AnalyzeFile(filePath)
	local errors, warnings = 0, 0
	if err then
		print(err)
		errors = errors + 1
	elseif #warn > 0 then
		for _, msg in ipairs(warn) do print(msg) end
		warnings = warnings + #warn
	end
	return errors, warnings
end

local function splitName(fname)
	local _,_, name, extension = string.find(fname, "^(.+)%.(.+)$")
	name = name or ""
	extension  = extension or ""
	return name, extension
end

local function doFile (filename)
	local res = {pcall(loadfile, filename)}
	local ok = table.remove(res, 1)
	return ok, table.unpack(res)
end

-- If you use a directory different than ide:GetPackagePath() for plugin
-- development, an OS fylesystem link from your plugin to
-- ide:GetPackagePath(yourplugin) will be needed. It could have been implemented
-- with doc:GetFilePath(), but wasn't to avoid versioning errors.
local function loadPlugin()
	local editor = ide:GetEditorWithFocus()
	if not editor then print("Error: No editor.") return end
	local doc = ide:GetDocument(editor)
	if doc:IsNew() then print("Error: New document.") return end
	if doc:IsModified() and not doc:Save() then
		print("Error: Document not saved.")
		return
	end
	local fname = doc:GetFileName()
	local name, extension = splitName(fname)
	if extension ~= "lua" then print("Error: Not a .lua file.") return end
	local _package = ide:GetPackage(name)
	if not _package then print ("Error: Package not registered.") return end
	--local fpath = doc:GetFilePath()
	local fpath = ide:GetPackagePath() .. fname
	local errors = analyze(fpath)
	if errors ~= 0 then return end
	printf("Loading %s.", fname)
	local ok, package = doFile(fpath)
	if not ok then
		print(package)
		print("Error: Not a valid plugin.")
		return
	end
	ok, package = pcall(package)
	if not ok then
		print(package)
		printf("Error calling %s. Package not loaded.", fpath)
		return
	end
	if _package.onUnRegister then _package.onUnRegister(_package) end
	if package.onRegister and package.onRegister(package) == false then
		ide:RemovePackage(_package.fname)
		print("onRegister returned false. Package unloaded.")
		return
	end
	package = ide:AddPackage(name, package)
	printf("Done loading %s.", package.fname)
end

return {
	name = "Plugin hot reloader",
	description = [[Hot reloads the plugin in the current editor, in order to
avoid closing/reopening the IDE when developing plugins.]],
	author = "Chronos Phaenon Eosphoros",
	version = 0.1,
	dependencies = "1.60",

	onRegister = function(self)
		ide:FindTopMenu("&Project"):Append(id, "Hot reload plugin\tAlt-R")
		ide:GetMainFrame():Connect(id, wx.wxEVT_COMMAND_MENU_SELECTED,loadPlugin)
	 end,

	onUnRegister = function(self)
		ide:RemoveMenuItem(id)
	end,
}