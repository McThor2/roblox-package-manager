
local HttpService = game:GetService("HttpService")

local Logging = require(script.Parent:WaitForChild("Logging"))
local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
local Cache = require(script.Parent:WaitForChild("Cache"))
local PackageManager = require(script.Parent.PackageManager)

type VirtualPath = VirtualPath.VirtualPath

local SemVer = require(script.Parent:WaitForChild("SemVer"))
type SemVer = SemVer.SemVer

local Package = require(script.Parent:WaitForChild("Package"))
type Package = Package.Package

local Requirement = require(script.Parent:WaitForChild("Requirement"))
type Requirement = Requirement.Requirement

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
local function getFiles(scope, name, _version): VirtualPath?

	local cacheKey = `{scope}/{name}@{_version}`
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

	if response.StatusCode ~= 200 or not response.Success then
		Logging:Warning(`RPM HTTP {response.StatusCode} - {response.StatusMessage}`)
		Logging:Debug(`{scope}/{name}@{_version}`)
		return
	end

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

function WallyApi:GetPackage(scope: string, name: string, _version: string): Package?

	local packageMetaData = WallyApi:GetVersionMetaData(scope, name, _version)

	-- Get the virtual files object
	local files = getFiles(scope, name, _version)

	if not files then
		return
	end

	return PackageManager:GetPackageFromPath(
		files,
		scope,
		name,
		_version,
		packageMetaData
	)
end

function WallyApi:GetPackageVersions(scope: string, name: string): {SemVer}
	local metadata = self:GetMetaData(scope, name)
	local versions = {}
	for _, versionData in metadata.versions do
		local semVer = SemVer.fromString(
			versionData.package.version,
			true
		)
		table.insert(versions, semVer)
	end
	table.sort(versions, function(a, b)
		return a > b
	end)
	return versions
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
		version: string
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

	local cacheKey = `{scope}/{name}`
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

function WallyApi:GetVersionMetaData(scope: string, name: string, version: string): VersionMetaData?

	local allMetaData = WallyApi:GetMetaData(scope, name)

	for _, versionData in allMetaData.versions do
		if versionData.package.version == version then
			return versionData
		end
	end

	return nil
end

return WallyApi
