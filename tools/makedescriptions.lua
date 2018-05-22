-- Copyright 2017-18 Paul Kulchenko, ZeroBrane LLC; All rights reserved
-- Contributed by Chronos Phaenon Eosphoros (@cpeosphoros)

local lfs = require("lfs")

-- Usage: run this script from ZeroBrane Studio with the directory with the packages
-- set as the project directory.
-- The results are saved to DESCRIPTIONS.md and can be copied into README.md as a section.
local path = "./"
local includecomments = false
local abridged = true

-- These are dummy zbstudio "globals" needed for plugins to load. No api event
-- will actually be called. Only zbstudio "globals" used in the main chunk of
-- the plugin need to be included. Be sure to commit and PR changes in this
-- string together with the plugins'.
local env = [[
	local function ID() return "a" end
	local function GetPathSeparator() return "" end
	local ide = {}
	local temp = {}
	temp.keymap = {}
	function ide:GetConfig() return temp end
	ide.specs = {}
	ide.config = {}
	local wxstc = {}
]]

local function errorf(...)
	error(string.format(...), 2)
end

local function printf(...)
	print(string.format(...))
end

local function readfile(filePath)
	local input = io.open(filePath)
	local data = input:read("*a")
	input:close()
	return data
end

local function sortedKeys(tbl)
	local sorted = {}
	for k, _ in pairs (tbl) do
		table.insert(sorted, k)
	end
	table.sort(sorted, function(i, j)
			if type(i) == type(j) then return i < j end
			return type(i) == "number"
		end)
	return sorted
end

local blockComment = false
local function isComment(line)
	if blockComment then
		local _,_, block = string.find(line, "^%s*([-]*%]%])")
		if block then
			blockComment = false
		end
		return true
	end
	local text = line:gsub("^%s*", "")
	if text == "" then return true end
	local _,_, block = string.find(line, "^%s*([-]*%[%[)")
	if block then
		blockComment = true
		return true
	end
	local _,_, dashes = string.find(line, "^%s*([-]*)")
	return dashes ~= "" and dashes ~= "-"
end

local files = {}
local cache = {}

local function process(key)
	printf("Loading %s ", key)
	local package, err = load(env.." "..files[key], key)
	if not package then
		print(err)
		errorf("Error loading %s.", key)
		return
	end

	local ok
	ok, package = pcall(package)
	if not ok then
		print(package)
		errorf("Error calling %s. Package not loaded.", key)
		return
	end

	cache[key] = {}
	cache[key].name         = package.name         or "Not given."
	cache[key].description  = package.description  or "Not given."
	cache[key].author       = package.author       or "Not given."
	cache[key].version      = package.version      or 0
	cache[key].dependencies = package.dependencies or "None."

	if not(	type(cache[key].dependencies) == "string" or
			type(cache[key].dependencies) == "number" or
			type(cache[key].dependencies) == "table"
			) then
		errorf("Invalid dependencies in %s. Package not loaded.", key)
	end

	cache[key].comments     = {}
	for line in string.gmatch(files[key], "([^\n]*)\n") do
		if not isComment(line) then break end
		table.insert(cache[key].comments, line)
	end
end

--------------------------------------------------------------------------------
-- Main execution block
--------------------------------------------------------------------------------

for file in lfs.dir(path) do
	local filePath = path..file
	local extension = file:match("[^.]+$")
	if extension == "lua" then
		local ok, attrs = pcall(lfs.attributes, filePath)
		if ok and attrs.mode ~= "directory" then
			files[file] = readfile(filePath)
		end
	end
end

local keys = sortedKeys(files)

local result = {}

local function insert(str)
	table.insert(result,str)
end

insert("## Package List")
insert("")

local gitUrl = ""

for _, key in ipairs(keys) do
	process(key)
	insert(("* [%s](%s): %s%s"):format(
      key, gitUrl..key, cache[key].description, abridged and "" or (" ([details](#%s))"):format(key)))
end

if not abridged then
  insert("")
  insert("## Plugin Details")

  for _, key in ipairs(keys) do
    insert("")
    insert("### "..key)
    insert("* **Name:** "..cache[key].name)
    insert("* **Description:** "..cache[key].description)
    insert("* **Author:** "..cache[key].author)
    insert("* **Version:** "..cache[key].version)
    local dependencies = cache[key].dependencies
    if type(dependencies) == "string" or type(dependencies) == "number" then
      insert("* **Dependencies:** "..dependencies)
    else --We have a table
      insert("* **Dependencies:**")
      local depKeys = sortedKeys(dependencies)
      for _, depKey in ipairs(depKeys) do
        if type(depKey) == "number" then
          insert("\t* "..dependencies[depKey])
        else
          insert("\t* "..depKey..": "..dependencies[depKey])
        end
      end
    end
    local comments = cache[key].comments
    if #comments > 0 and includecomments then
      insert("* **Comments:**")
      insert("")
      insert("```")
      for _, v in ipairs(comments) do
        insert(v)
      end
      insert("```")
    end
  end
end

print()

local output = io.open(path.."DESCRIPTIONS.md", "w")
for _, v in ipairs(result) do
	output:write(v.."\n")
end
output:close()
