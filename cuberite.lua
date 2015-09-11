-- Implements Cuberite interpreter description and interface for ZBStudio.
-- Cuberite executable can have a postfix depending on the compilation mode (debug / release).

local function MakeCuberiteInterpreter(a_Self, a_InterpreterPostfix, a_ExePostfix)
	assert(a_Self)
	assert(type(a_InterpreterPostfix) == "string")
	assert(type(a_ExePostfix) == "string")

	return
	{
		name = "Cuberite" .. a_InterpreterPostfix,
		description = "Cuberite - the custom C++ minecraft server",
		api = {
			"baselib",
			"mcserver_api",  -- Keep the old MCServer name for compatibility reasons
			"cuberite_api"
		},

		frun = function(self, wfilename, withdebug)
			-- Cuberite plugins are always in a "Plugins/<PluginName>" subfolder located at the executable level
			-- Get to the executable by removing the last two dirs:
			local ExePath = wx.wxFileName(wfilename)
			ExePath:RemoveLastDir()
			ExePath:RemoveLastDir()
			ExePath:ClearExt()
			ExePath:SetName("")
			local ExeName = wx.wxFileName(ExePath)

			-- The executable name depends on the debug / non-debug build mode, it can have a postfix
			ExeName:SetName("Cuberite" .. a_ExePostfix)

			-- Executable has a .exe ext on Windows
			if (ide.osname == 'Windows') then
				ExeName:SetExt("exe")
			end

			-- Check if we're in a subfolder inside the plugin folder, try going up one level if executable not found:
			if not(ExeName:FileExists()) then
				DisplayOutputNoMarker("The Cuberite executable cannot be found in \"" .. ExeName:GetFullPath() .. "\". Trying one folder up.\n")
				ExeName:RemoveLastDir()
				ExePath:RemoveLastDir()
				if not(ExeName:FileExists()) then
					DisplayOutputNoMarker("The Cuberite executable cannot be found in \"" .. ExeName:GetFullPath() .. "\". Aborting the debugger.\n")
					return
				end
			end

			-- Start the debugger server:
			if withdebug then
				DebuggerAttachDefault({
					runstart = (ide.config.debugger.runonstart == true),
					basedir = ExePath:GetFullPath(),
				})
			end

			-- Add a "nooutbuf" cmdline param to the server, causing it to call setvbuf to disable output buffering:
			local Cmd = ExeName:GetFullPath() .. " --no-output-buffering"

			-- Force ZBS not to hide Cuberite window, save and restore previous state:
			local SavedUnhideConsoleWindow = ide.config.unhidewindow.ConsoleWindowClass
			ide.config.unhidewindow.ConsoleWindowClass = 1  -- show if hidden
			
			-- Create the !EnableMobDebug.lua file so that the Cuberite plugin starts the debugging session, when loaded:
			local EnablerPath = wx.wxFileName(wfilename)
			EnablerPath:SetName("!EnableMobDebug")
			EnablerPath:SetExt("lua")
			local f = io.open(EnablerPath:GetFullPath(), "w")
			if (f ~= nil) then
				f:write(
[[
-- !EnableMobDebug.lua

-- This file is created by the ZeroBrane Studio debugger, do NOT commit it to your repository!
-- It is safe to delete this file once the debugger is stopped.

-- When this file is loaded in the ZeroBrane Studio, the debugger will pause when Cuberite detects a problem in your plugin
-- If you close this file, the debugger will no longer pause on problems

local g_mobdebug = require("mobdebug")
g_mobdebug.start()

function BreakIntoDebugger(a_Message)
	g_mobdebug:pause()
	-- If your plugin breaks here, it means that Cuberite has run into a problem in your plugin
	-- Inspect the stack and the server console for the error report
	-- If you close this file while the debugger is paused here, Cuberite will be terminated!
	LOG("Broken into debugger: " .. a_Message)
end
]]
				)
				f:close()
			end

			-- Open the "!EnableMobDebug.lua" file in the editor, if not already open (so that breakpoints work):
			local enablerEditor
			local fullEnablerPath = EnablerPath:GetFullPath()
			if not(ide:FindDocument(fullEnablerPath)) then
				enablerEditor = LoadFile(fullEnablerPath)
			end

			-- When the enabler gets closed, invalidate our enablerEditor variable:
			a_Self.onEditorClose = function(self, a_Editor)
				if (a_Editor == enablerEditor) then
					enablerEditor = nil
				end
			end

			-- Create the closure to call upon debugging finish:
			local OnFinished = function()
				-- Close the "!EnableMobDebug.lua" file editor:
				if (enablerEditor) then
					local doc = ide.openDocuments[enablerEditor:GetId()]
					ClosePage(doc.id)
				end

				-- Remove the editor-close watcher:
				a_Self.onEditorClose = nil

				-- Restore the Unhide status:
				ide.config.unhidewindow.ConsoleWindowClass = SavedUnhideConsoleWindow
			
				-- Remove the !EnableMobDebug.lua file:
				os.remove(EnablerPath:GetFullPath())
			end

			-- Run the server:
			local pid = CommandLineRun(
				Cmd,                    -- Command to run
				ExePath:GetFullPath(),  -- Working directory for the debuggee
				false,                  -- Redirect debuggee output to Output pane? (NOTE: This force-hides the Cuberite window, not desirable!)
				true,                   -- Add a no-hide flag to WX
				nil,                    -- StringCallback, whatever that is
				nil,                    -- UID to identify this running program; nil to auto-assign
				OnFinished              -- Callback to call once the debuggee terminates
			)
		end,

		hasdebugger = true,
	}
end




local function analyzeProject()
	local projectPath = ide:GetProject()
	if not(projectPath) then
		DisplayOutputNoMarker("No project path has been defined.\n")
		return
	end
	
	-- Get a list of all the files in the order in which Cuberite loads them (Info.lua is always last):
	local files = {}
	for _, filePath in ipairs(FileSysGetRecursive(projectPath, false, "*.lua")) do
		table.insert(files, filePath)
	end
	table.sort(files,
		function (a_File1, a_File2)
			if (a_File1:match("[/\\]Info.lua")) then
				return false
			elseif (a_File2:match("[/\\]Info.lua")) then
				return true
			else
				return a_File1 < a_File2
			end
		end
	)
	
	-- List all files in the console:
	DisplayOutputNoMarker("Files for analysis:\n")
	for _, file in ipairs(files) do
		DisplayOutputNoMarker(file .. "\n")
	end
	DisplayOutputNoMarker("Analyzing...\n")
	
	-- Concatenate all the files, remember their line begin positions:
	local lineBegin = {}  -- array of {File = "filename", LineBegin = <linenum>, LineEnd = <linenum>}
	local whole = {}  -- array of individual files' contents
	local curLineBegin = 1
	for _, file in ipairs(files) do
		local curFile = { "do" }
		local lastLineNum = 0
		for line in io.lines(file) do
			table.insert(curFile, line)
			lastLineNum = lastLineNum + 1
		end
		table.insert(curFile, "end")
		table.insert(lineBegin, {File = file, LineBegin = curLineBegin + 1, LineEnd = curLineBegin + lastLineNum + 1})
		curLineBegin = curLineBegin + lastLineNum + 2
		table.insert(whole, table.concat(curFile, "\n"))
	end
	
	-- Analyze the concatenated files:
	local warn, err, line, pos = AnalyzeString(table.concat(whole, "\n"))
	if (err) then
		DisplayOutputNoMarker("Error: " .. err .. "\n")
		return
	end
	
	-- Function that translates concatenated-linenums back into source + linenum
	local function findSourceByLine(a_LineNum)
		for _, begin in ipairs(lineBegin) do
			if (a_LineNum < begin.LineEnd) then
				return begin.File, a_LineNum - begin.LineBegin + 1
			end
		end
	end
	
	-- Parse the analysis results back to original files:
	for _, w in ipairs(warn) do
		local wtext = w:gsub("^<string>:(%d*):(.*)",
			function (a_LineNum, a_Message)
				local srcFile, srcLineNum = findSourceByLine(tonumber(a_LineNum))
				DisplayOutputNoMarker(srcFile .. ":" .. srcLineNum .. ": " .. a_Message .. "\n")
			end
		)
	end
	DisplayOutputNoMarker("Analysis completed.\n")
end





local function runInfoDump()
	local projectPath = ide:GetProject()
	if not(projectPath) then
		DisplayOutputNoMarker("No project path has been defined.\n")
		return
	end
	
	-- Get the path to InfoDump.lua file, that is one folder up from the current project:
	local dumpScriptPath = wx.wxFileName(projectPath)
	local pluginName = dumpScriptPath:GetDirs()[#dumpScriptPath:GetDirs()]
	dumpScriptPath:RemoveLastDir()
	local dumpScript = wx.wxFileName(dumpScriptPath)
	dumpScript:SetName("InfoDump")
	dumpScript:SetExt("lua")
	local fullPath = dumpScript:GetFullPath()
	if not(wx.wxFileExists(fullPath)) then
		DisplayOutputNoMarker("The InfoDump.lua script was not found (tried " .. fullPath .. ")\n")
		return
	end
	
	-- Execute the script:
	local cmd = "lua " .. fullPath .. " " .. pluginName
	CommandLineRun(
		cmd,                           -- Command to run
		dumpScriptPath:GetFullPath(),  -- Working directory for the debuggee
		true,                          -- Redirect debuggee output to Output pane?
		true                           -- Add a no-hide flag to WX
	)
	DisplayOutputNoMarker("The InfoDump.lua script was executed.\n")
end





local G = ...




return {
	name = "Cuberite integration",
	description = "Integration with Cuberite - the custom C++ minecraft server.",
	author = "Mattes D (https://github.com/madmaxoft)",
	version = 0.5,
	dependencies = 0.71,

	AnalysisMenuID = G.ID("analyze.cuberite_analyzeall"),
	InfoDumpMenuID = G.ID("project.cuberite_infodump"),
	
	onRegister = function(self)
		-- Add the interpreters
		self.InterpreterDebug   = MakeCuberiteInterpreter(self, " - debug mode",   "_debug")
		self.InterpreterRelease = MakeCuberiteInterpreter(self, " - release mode", "")
		ide:AddInterpreter("cuberite_debug",   self.InterpreterDebug)
		ide:AddInterpreter("cuberite_release", self.InterpreterRelease)

		-- Add the analysis menu item:
		local _, menu, pos = ide:FindMenuItem(ID_ANALYZE)
		if pos then
			menu:Insert(pos + 1, self.AnalysisMenuID, TR("Analyze as Cuberite") .. KSC(id), TR("Analyze the project source code as Cuberite"))
			ide:GetMainFrame():Connect(self.AnalysisMenuID, wx.wxEVT_COMMAND_MENU_SELECTED, analyzeProject)
		end
		
		-- Add the InfoDump menu item:
		_, menu, pos = ide:FindMenuItem(ID_INTERPRETER)
		if (pos) then
			self.Separator1 = menu:AppendSeparator()
			menu:Append(self.InfoDumpMenuID, TR("Cuberite InfoDump") .. KSC(id), TR("Run the InfoDump script on the current plugin"))
			ide:GetMainFrame():Connect(self.InfoDumpMenuID, wx.wxEVT_COMMAND_MENU_SELECTED, runInfoDump)
		end
	end,
	
	onUnRegister = function(self)
		-- Remove the interpreters:
		ide:RemoveInterpreter("cuberite_debug")
		ide:RemoveInterpreter("cuberite_release")
		
		-- Remove the menu items:
		ide:RemoveMenuItem(self.AnalysisMenuID)
		ide:RemoveMenuItem(self.InfoDumpMenuID)
		self.Separator1:GetParent():Delete(self.Separator1)
	end,
}




