

local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
type VirtualPath = typeof(VirtualPath.new())

local FileConverter = {}

local DIR_SERVER_SCRIPT = "init.server.lua"
local DIR_LOCAL_SCRIPT = "init.client.lua"
local DIR_MODULE_SCRIPT = "init.lua"

local DIR_META_FILE = "init.meta.json"

local FILE_SERVER_SCRIPT_EXT = ".server.lua"
local FILE_LOCAL_SCRIPT_EXT = ".client.lua"
local FILE_MODULE_SCRIPT_EXT = ".lua"

local function checkMatches(toCheck: string, patterns: {string})
	for _, pattern in patterns do
		local match = string.match(toCheck, pattern)
		if match then
			return true
		end
	end
	return false
end

local function convertFile(virtualPath: VirtualPath)

	assert(virtualPath:IsFile(), virtualPath:GetAbsolutePath() .. " is not a valid file")

	local scriptInstance
	if string.find(virtualPath.path, FILE_SERVER_SCRIPT_EXT) then
		scriptInstance = Instance.new("Script")
		scriptInstance.Name = string.sub(virtualPath.path, 1, #virtualPath - #FILE_SERVER_SCRIPT_EXT - 1)
		
	elseif string.find(virtualPath.path, FILE_LOCAL_SCRIPT_EXT) then
		scriptInstance = Instance.new("LocalScript")
		scriptInstance.Name = string.sub(virtualPath.path, 1, #virtualPath - #FILE_LOCAL_SCRIPT_EXT - 1)
		
	elseif string.find(virtualPath.path, FILE_MODULE_SCRIPT_EXT) then
		scriptInstance = Instance.new("ModuleScript")
		scriptInstance.Name = string.sub(virtualPath.path, 1, #virtualPath - #FILE_MODULE_SCRIPT_EXT - 1)
	end

	if scriptInstance then
		scriptInstance.Source = virtualPath:Read()
		return scriptInstance
	end

	warn("not implemented " .. virtualPath.path)
end

local function convertDir(virtualPath: VirtualPath, ignorePatterns: {string}?)

	assert(virtualPath:IsDir(), virtualPath:GetAbsolutePath() .. " is not a valid directory")

	ignorePatterns = ignorePatterns or {}

	local initModuleScript = virtualPath / DIR_MODULE_SCRIPT
	local initServerScript = virtualPath / DIR_SERVER_SCRIPT
	local initLocalScript = virtualPath / DIR_LOCAL_SCRIPT

	-- local metaFile = virtualPath / DIR_META_FILE

	local dirInstance

	if initModuleScript:IsFile() then
		dirInstance = Instance.new("ModuleScript")
		dirInstance.Source = initModuleScript:Read()
	end

	if initServerScript:IsFile() then
		assert(dirInstance == nil, `Expected dirInstance to be nil, actually {dirInstance}`)
		dirInstance = Instance.new("Script")
		dirInstance.Source = initServerScript:Read()
	end

	if initLocalScript:IsFile() then
		assert(dirInstance == nil, `Expected dirInstance to be nil, actually {dirInstance}`)
		dirInstance = Instance.new("LocalScript")
		dirInstance.Source = initLocalScript:Read()
	end

	if not dirInstance then

		if not virtualPath:GetChildren() or #virtualPath:GetChildren() == 0 then
			return
		end

		dirInstance = Instance.new("Folder")
	end

	dirInstance.Name = virtualPath.path

	-- TODO: Implement meta file usage

	for _, child in virtualPath:GetChildren() do

		-- selene: allow (parenthese_conditions)
		if (
			child.path == DIR_LOCAL_SCRIPT or
			child.path == DIR_SERVER_SCRIPT or
			child.path == DIR_MODULE_SCRIPT or
			child.path == DIR_META_FILE) then
			continue
		end

		if checkMatches(child.path, ignorePatterns) then
			continue
		end

		local childInstance = FileConverter:Convert(child, ignorePatterns)
		if childInstance then
			childInstance.Parent = dirInstance
		end

	end

	return dirInstance

end

function FileConverter:Convert(virtualPath: VirtualPath, ignorePatterns: {string}?)
	if virtualPath:IsFile() then
		return convertFile(virtualPath)
	else
		return convertDir(virtualPath, ignorePatterns)
	end
end

return FileConverter
