
local HttpService = game:GetService("HttpService")

local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
local FileConverter = require(script.Parent:WaitForChild("FileConverter"))
local Cache = require(script.Parent:WaitForChild("Cache"))
local SemVer = require(script.Parent:WaitForChild("SemVer"))

type SemVer = SemVer.SemVer

local DEFAULT_ROOT = "https://api.wally.run"

-- /v1/package-contents/<scope>/<name>/<version>
local CONTENTS_PATH = "/v1/package-contents/%s/%s/%s"
-- /v1/package-metadata/<scope>/<name>
local METADATA_PATH = "/v1/package-metadata/%s/%s"
-- /v1/package-search?query=<query string>
local SEARCH_PATH = "/v1/package-search?query=%s"

local WALLY_VERSION = "0.3.1"

local WallyApi = {}

local DEP_PATTERN = "([<>=]*)(%d+%.%d+%.%d+)"

local GT = ">"
local GE = ">="
local LT = "<"
local LE = "<="
local EQ = "="
local NE = "!="

local QUALIFIERS = {
	[GT] = GT,
	[GE] = GE,
	[LT] = LT,
	[LE] = LE,
	[EQ] = EQ,
	[NE] = NE
}

local IGNORE_PATTERNS = {
	"%.toml$",
	"%.spec.lua$"
}

local Requirement = {}
do
	Requirement.__index = Requirement

	function Requirement.new(
			scope: string,
			name: string,
			min: SemVer,
			minEqual: boolean,
			max: SemVer,
			maxEqual: boolean,
			blacklist: {SemVer}?)

		local self = {}
		self.Scope = scope
		self.Name = name
		self.Blacklist = blacklist or {}

		self.Min = min
		self._minEqual = minEqual

		self.Max = max
		self._maxEqual = maxEqual

		setmetatable(self, Requirement)

		return self
	end

	function Requirement:Check(version: SemVer)
		return (
			((self._minEqual and self.Min <= version) or self.Min < version) and
			((self._maxEqual and self.Max >= version) or self.Max > version)
		)
	end

end

type Requirement = typeof(Requirement.new())

local function parseDependency(rawDependency: string): Requirement
	local rawVersions = string.split(rawDependency, "@")
	local scope, name = string.match(rawVersions[1], "(%l+)/(%l+)")
	local versionPins = string.split(rawVersions[2], ",")

	local requirements = {}
	for _, pin in versionPins do
		local rawQual, _ver = string.match(pin, DEP_PATTERN)

		if not _ver then
			warn(`'{pin}' - Unkown version '{_ver}'`)
			continue
		end

		local qualifier = QUALIFIERS[rawQual]
		if rawQual and not qualifier then
			warn(`'{pin}' - Unknown qualifier '{rawQual}'`)
			continue
		end

		table.insert(requirements, {
			qualifier = qualifier,
			version = _ver
		})

	end

	local blacklist = {}

	local minVer, maxVer
	local minEqual, maxEqual
	for _, req in requirements do
		if req.qualifier == LE then
			maxVer = SemVer.fromString(req.version, true)
			maxEqual = true
		elseif req.qualifier == LT then
			maxVer = SemVer.fromString(req.version, true)
			maxEqual = false
		elseif req.qualifier == GE then
			minVer = SemVer.fromString(req.version, true)
			minEqual = true
		elseif req.qualifier == GT then
			minVer = SemVer.fromString(req.version, true)
			minEqual = false
		elseif req.qualifier == NE then
			table.insert(blacklist, SemVer.fromString(req.version, true))
		end
	end

	return Requirement.new(
		scope,
		name,
		minVer,
		minEqual,
		maxVer,
		maxEqual,
		blacklist
	)
end

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
		warn(`RPM HTTP {response.StatusCode} - {response.StatusMessage}`)
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

function WallyApi:GetPackage(scope: string, name: string, _version: string): ModuleScript?

	-- Get the virtual files object
	local files = getFiles(scope, name, _version)

	if not files then
		return
	end

	-- print("\n" .. tostring(files))

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
		return
	end

	package.Name = string.sub(name, 1, 1):upper() .. string.sub(name, 2, #name)

	package:SetAttribute("Scope", scope)
	package:SetAttribute("Name", name)
	package:SetAttribute("Version", _version)

	return package
end

local function getDependencies(dependencies: {string}): {ModuleScript}

	local packages = {}
	for _, rawDep in dependencies do

		local sharedDep = parseDependency(rawDep)

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
			error(`Could not resolve dependency: {sharedDep}`)
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
		warn(`No metadata for {scope}/{name}`)
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

	--print(dependencies)

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

return WallyApi
