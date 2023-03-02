
local HttpService = game:GetService("HttpService")

local Logging = require(script.Parent:WaitForChild("Logging"))
local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
local FileConverter = require(script.Parent:WaitForChild("FileConverter"))
local Cache = require(script.Parent:WaitForChild("Cache"))

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

local IGNORE_PATTERNS = {
	"%.toml$",
	"%.spec.lua$"
}

local filesCache = Cache.new()
local function getFiles(scope, name, _version)

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

local function getRequirements(dependencyList: {[string]: string})
	local requirements = {}
	for reqName, versionPins in dependencyList do
		local requirement = Requirement.fromWallyString(reqName, versionPins)
		table.insert(requirements, requirement)
	end
	return requirements
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

	-- Find directory that corresponds to the package
	local defaultProjectFile = files / "default.project.json"

	-- Turn Virtual Files into Roblox Instances

	local package
	if defaultProjectFile:IsFile() then
		local defaultProject = HttpService:JSONDecode(defaultProjectFile:Read())
		local packageDir = defaultProject["tree"]["$path"]
		package = FileConverter:Convert(
			files / packageDir,
			IGNORE_PATTERNS)
	else
		package = FileConverter:Convert(
			files,
			IGNORE_PATTERNS)
	end

	if not package then
		Logging:Warning(`Unable to convert package to instances - {scope}/{name}@{_version}`)
		return
	end

	package.Name = string.sub(name, 1, 1):upper() .. string.sub(name, 2, #name)

	package:SetAttribute("Scope", scope)
	package:SetAttribute("Name", name)
	package:SetAttribute("Version", _version)

	local sharedDependencies = getRequirements(packageMetaData.dependencies)
	local serverDependencies = getRequirements(packageMetaData["server-dependencies"])

	return Package.new(
		`{scope}/{name}`,
		SemVer.fromString(_version),
		package,
		sharedDependencies,
		serverDependencies
	)
end

local function getDependencies(dependencies: {string}): {ModuleScript}

	local packages = {}
	for _, rawDep in dependencies do

		local sharedDep = Requirement.fromWallyString(rawDep)

		local versions = WallyApi:GetPackageVersions(
			sharedDep.Scope,
			sharedDep.Name
		)
		table.sort(versions, function(a, b)
			return a > b
		end)

		local depPackage = nil
		for _, depVersion in versions do

			if not sharedDep:Check(depVersion) then
				continue
			end

			depPackage = WallyApi:GetPackage(
				sharedDep.Scope,
				sharedDep.Name,
				tostring(depVersion)
			)
			break
		end

		if not depPackage then
			Logging:Error(`Could not resolve dependency: {sharedDep}`)
		end

		table.insert(packages, depPackage)
	end

	return packages
end

function  WallyApi:InstallPackage(
	scope: string,
	name: string,
	_version: string,
	existingPackages: {string}?): (ModuleScript?, {ModuleScript}, {ModuleScript})

	existingPackages = existingPackages or {}

	local packageMetaData = WallyApi:GetMetaData(scope, name)

	if not packageMetaData then
		Logging:Warning(`No metadata for {scope}/{name}`)
		return
	end

	local dependencies = {
		shared = {},
		server = {}
	}
	for _, data in packageMetaData.versions do
		if data.package.version == _version then
			dependencies.shared = data.dependencies
			dependencies.server = data["server-dependencies"]
			break
		end
	end

	local sharedPackages, serverPackages

	sharedPackages = getDependencies(dependencies.shared)
	serverPackages = getDependencies(dependencies.server)

	local package = WallyApi:GetPackage(scope, name, _version)

	return package, sharedPackages, serverPackages
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
