
local HttpService = game:GetService("HttpService")

local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
local FileConverter = require(script.Parent:WaitForChild("FileConverter"))
local Cache = require(script.Parent:WaitForChild("Cache"))

local DEFAULT_ROOT = "https://api.wally.run"

-- /v1/package-contents/<scope>/<name>/<version>
local CONTENTS_PATH = "/v1/package-contents/%s/%s/%s"
-- /v1/package-metadata/<scope>/<name>
local METADATA_PATH = "/v1/package-metadata/%s/%s"
-- /v1/package-search?query=<query string>
local SEARCH_PATH = "/v1/package-search?query=%s"

local WALLY_VERSION = "0.3.1"

local WallyApi = {}

local filesCache = Cache.new()
local function getFiles(scope, name, _version)
	
	local cacheKey = scope .. name .. _version
	if filesCache:get(cacheKey) then
		return filesCache:get(cacheKey)
	end
	
	local path = DEFAULT_ROOT .. CONTENTS_PATH

	local formattedPath = string.format(path, scope, name, _version)

	local response = HttpService:RequestAsync({
		Method = "GET",
		Url = formattedPath,
		Headers = {["Wally-Version"] = WALLY_VERSION}	
	})

	local result = VirtualPath.fromZip(response.Body)
	filesCache:set(cacheKey, result)
	return result
end

export type PackageDescription = {
	description: string,
	name: string,
	scope: string,
	versions: {string}
}

function WallyApi:ListPackages(queryPhrase: string?): {PackageDescription}
	
	local path = DEFAULT_ROOT .. SEARCH_PATH
	
	queryPhrase = queryPhrase or ""
	
	local url = string.format(
		path, 
		HttpService:UrlEncode(queryPhrase)
	)
	
	local response = HttpService:RequestAsync({
		Method = "GET",
		Url = url,
		Headers = {["Wally-Version"] = WALLY_VERSION}
	})
	

	local packagesData = HttpService:JSONDecode(response.Body)
	
	return packagesData
end

function WallyApi:GetPackage(scope: string, name: string, _version: string): ModuleScript?
	
	-- Get the virtual files object
	local files = getFiles(scope, name, _version)
	
	-- print("\n" .. tostring(files))
	
	-- Find directory that corresponds to the package
	local defaultProjectFile = files / "default.project.json"
	
	-- Turn Virtual Files into Roblox Instances
	
	local package
	if defaultProjectFile:IsFile() then
		local defaultProject = HttpService:JSONDecode(defaultProjectFile:Read())
		local packageDir = defaultProject["tree"]["$path"]
		package = FileConverter:Convert(files / packageDir)
	else
		package = FileConverter:Convert(files)
		
	end
	
	if not package then
		return
	end
	
	package.Name = string.sub(name, 1, 1):upper() .. string.sub(name, 2, #name)
	
	package:SetAttribute("Scope", scope)
	package:SetAttribute("Name", name)
	package:SetAttribute("Version", _version)
	
	return package
end

export type VersionMetaData = {
	dependencies: {[string]: string},
	["server-dependencies"]: {[string]: string},
	["dev-dependencies"]: {[string]: string},
	package: {
		authors: {string},
		description: string?,
		exclude: {string},
		include: {string},
		license: string?,
		name: string,
		realm: "shared" | "server",
		registry: string,
		["version"]: string
	},
	place: {
		["shared-packages"]: string?,
		["server-packages"]: string?
	}
}

export type PackageMetaData = {
	versions: {
		VersionMetaData
	}
}

local metadataCache = Cache.new()
function WallyApi:GetMetaData(scope: string, name: string): PackageMetaData
	
	local cacheKey = scope .. name
	if metadataCache:get(cacheKey) then
		return metadataCache:get(cacheKey)
	end
	
	local url = DEFAULT_ROOT .. METADATA_PATH
	url = string.format(url, scope, name)
	
	local response = HttpService:RequestAsync({
		Method = "GET",
		Url = url
	})

	local metadata = HttpService:JSONDecode(response.Body)
	
	metadataCache:set(cacheKey, metadata)
	return metadata
end

return WallyApi
