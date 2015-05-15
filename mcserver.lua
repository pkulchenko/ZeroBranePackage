-- Implements MCServer interpreter description and interface for ZBStudio.
-- MCServer executable can have a postfix depending on the compilation mode (debug / release).

local function MakeMCServerInterpreter(a_InterpreterPostfix, a_ExePostfix)
	assert(type(a_InterpreterPostfix) == "string")
	assert(type(a_ExePostfix) == "string")

	return
	{
		name = "MCServer" .. a_InterpreterPostfix,
		description = "MCServer - the custom C++ minecraft server",
		api = {"baselib", "mcserver_api"},

		frun = function(self, wfilename, withdebug)
			-- MCServer plugins are always in a "Plugins/<PluginName>" subfolder located at the executable level
			-- Get to the executable by removing the last two dirs:
			local ExePath = wx.wxFileName(wfilename)
			ExePath:RemoveLastDir()
			ExePath:RemoveLastDir()
			ExePath:ClearExt()
			ExePath:SetName("")
			local ExeName = wx.wxFileName(ExePath)

			-- The executable name depends on the debug / non-debug build mode, it can have a postfix
			ExeName:SetName("MCServer" .. a_ExePostfix)

			-- Executable has a .exe ext on Windows
			if (ide.osname == 'Windows') then
				ExeName:SetExt("exe")
			end

			-- Start the debugger server:
			if withdebug then
				DebuggerAttachDefault({
					runstart = (ide.config.debugger.runonstart == true),
					basedir = ExePath:GetFullPath(),
				})
			end

			-- Add a "nooutbuf" cmdline param to the server, causing it to call setvbuf to disable output buffering:
			local Cmd = ExeName:GetFullPath() .. " nooutbuf"

			-- Force ZBS not to hide MCS window, save and restore previous state:
			local SavedUnhideConsoleWindow = ide.config.unhidewindow.ConsoleWindowClass
			ide.config.unhidewindow.ConsoleWindowClass = 1  -- show if hidden
			
			-- Create the @EnableMobDebug.lua file so that the MCS plugin starts the debugging session, when loaded:
			local EnablerPath = wx.wxFileName(wfilename)
			EnablerPath:SetName("@EnableMobDebug")
			EnablerPath:SetExt("lua")
			local f = io.open(EnablerPath:GetFullPath(), "w")
			if (f ~= nil) then
				f:write([[require("mobdebug").start()]])
				f:close()
			end
			
			-- Create the closure to call upon debugging finish:
			local OnFinished = function()
				-- Restore the Unhide status:
				ide.config.unhidewindow.ConsoleWindowClass = SavedUnhideConsoleWindow
			
				-- Remove the @EnableMobDebug.lua file:
				os.remove(EnablerPath:GetFullPath())
			end

			-- Run the server:
			local pid = CommandLineRun(
				Cmd,                    -- Command to run
				ExePath:GetFullPath(),  -- Working directory for the debuggee
				false,                  -- Redirect debuggee output to Output pane? (NOTE: This force-hides the MCS window, not desirable!)
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
		DisplayOutputNoMarker("No project path has been defined.")
		return
	end
	
	-- Get a list of all the files in the order in which MCS loads them (Info.lua is always last):
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





local G = ...




return {
	name = "MCServer integration",
	description = "Integration with MCServer - the custom C++ minecraft server.",
	author = "Mattes D (https://github.com/madmaxoft)",
	version = 0.3,
	dependencies = 0.71,

	AnalysisMenuID = G.ID("analyze.mcs_analyzeall"),
	
	InterpreterDebug   = MakeMCServerInterpreter(" - debug mode",   "_debug"),
	InterpreterRelease = MakeMCServerInterpreter(" - release mode", ""),

	onRegister = function(self)
		-- Add the interpreters
		ide:AddInterpreter("mcserver_debug",   self.InterpreterDebug)
		ide:AddInterpreter("mcserver_release", self.InterpreterRelease)

		-- Add the analysis menu item:
		local _, menu, analyzepos = ide:FindMenuItem(ID_ANALYZE)
		if analyzepos then
			menu:Insert(analyzepos + 1, self.AnalysisMenuID, TR("Analyze as MCServer") .. KSC(id), TR("Analyze the project source code as MCServer"))
			ide:GetMainFrame():Connect(self.AnalysisMenuID, wx.wxEVT_COMMAND_MENU_SELECTED, analyzeProject)
		end
	end,
	
	onUnRegister = function(self)
		-- Remove the interpreters:
		ide:RemoveInterpreter("mcserver_debug")
		ide:RemoveInterpreter("mcserver_release")
		
		-- Remove the analysis menu item:
		ide:RemoveMenuItem(self.AnalysisMenuID)
	end,
}




