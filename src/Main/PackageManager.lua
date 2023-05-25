
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent:WaitForChild("Config"))
local Requirement = require(script.Parent:WaitForChild("Requirement"))
local Package = require(script.Parent:WaitForChild("Package"))
local Logging = require(script.Parent:WaitForChild("Logging"))
local FileConverter = require(script.Parent:WaitForChild("FileConverter"))
local SemVer = require(script.Parent:WaitForChild("SemVer"))
local VirtualPath = require(script.Parent:WaitForChild("VirtualPath"))
local Toml = require(script.Parent.Toml)

type VirtualPath = VirtualPath.VirtualPath
type SemVer = SemVer.SemVer
type Package = Package.Package
type Requirement = Requirement.Requirement

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

local PackageManager = {}


local IGNORE_PATTERNS = {
	"%.toml$",
	"%.spec.lua$"
}

local function join(a, b)
	local result = table.clone(a)
	for _, element in b do
		table.insert(result, element)
	end
	return result
end

local function getPackageAttributes(package: Instance)
	local attributes = {}
	attributes.Scope = package:GetAttribute("Scope")
	attributes.Name = package:GetAttribute("Name")
	attributes.Version = package:GetAttribute("Version")

	return attributes
end

local function getPackageFromLocation(location: Instance, scope, name, version)
	for _, child in location:GetChildren() do
		local attributes = getPackageAttributes(child)
		if
			attributes.Scope == scope and
			attributes.Name == name and
			attributes.Version == version
			then return child
		end
	end
	return nil
end

local function getExistingPackage(scope, name, version)

	local sharedLocation = Config:GetPackageLocation()
	local serverLocation = Config:GetServerPackageLocation()

	local sharedPackage = getPackageFromLocation(
		sharedLocation, scope, name, version)

	if sharedPackage then
		return sharedPackage
	end

	local serverPackage =  getPackageFromLocation(
		serverLocation, scope, name, version)

	if serverPackage then
		return serverPackage
	end

	return nil
end

local function getRequirements(dependencyList: {[string]: string})
	local requirements = {}
	for reqName, versionPins in dependencyList do
		local requirement = Requirement.fromWallyString(reqName, versionPins)
		table.insert(requirements, requirement)
	end
	return requirements
end

local function resolveRequirements(
	requirements: {Requirement},
	metaDataStore,
	packageStore)

	local installedPackages = {}
	for _, requirement in requirements do

		local availableVersions = metaDataStore(
			requirement.Scope,
			requirement.Name
		)

		Logging:Debug(`Checking versions for {requirement.Scope}/{requirement.Name}`)
		Logging:Debug(availableVersions)

		local installVersion = nil
		for _, _ver in availableVersions do
			if requirement:Check(_ver) then
				installVersion = _ver
				break
			end
		end

		if not installVersion then
			Logging:Warning(`Could not satisfy requirement - {requirement}`)
			continue
		end

		if getExistingPackage(requirement.Scope, requirement.Name, tostring(installVersion)) then
			Logging:Info(
				"Dependency already satisfied: "..
				`{requirement.Scope}/{requirement.Name}@{installVersion}`
			)
			continue
		end

		local package = packageStore(
			requirement.Scope,
			requirement.Name,
			tostring(installVersion)
		)

		local installedDeps = PackageManager:InstallPackages({package})

		installedPackages = join(installedPackages, installedDeps)
	end

	return installedPackages
end

function PackageManager:GetPackageFromPath(
	virtualPath: VirtualPath,
	scope: string,
	name: string,
	_version: string,
	packageMetaData)

	-- Find directory that corresponds to the package
	local defaultProjectFile = virtualPath / "default.project.json"

	-- Turn Virtual Files into Roblox Instances

	local package
	if defaultProjectFile:IsFile() then
		local defaultProject = HttpService:JSONDecode(defaultProjectFile:Read())
		local packageDir = defaultProject["tree"]["$path"]
		package = FileConverter:Convert(
			virtualPath / packageDir,
			IGNORE_PATTERNS)
	else
		package = FileConverter:Convert(
			virtualPath,
			IGNORE_PATTERNS)
	end

	if not package then
		Logging:Warning(`Unable to convert package to instances - {scope}/{name}@{_version}`)
		return
	end

	-- TODO: Just using capitalised name, need to update to use metadata + package deps
	package.Name = string.sub(name, 1, 1):upper() .. string.sub(name, 2, #name)

	package:SetAttribute("Scope", scope)
	package:SetAttribute("Name", name)
	package:SetAttribute("Version", _version)

	local sharedDependencies = getRequirements(packageMetaData.dependencies)
	local serverDependencies = getRequirements(packageMetaData["server-dependencies"])

	return Package.new(
		scope,
		name,
		SemVer.fromString(_version),
		package,
		nil,
		sharedDependencies,
		serverDependencies
	)
end

function PackageManager:InstallPackages(
	packages: {Package},
	metaDataStore,
	packageStore
	): {Instance}

    local sharedParent = Config:GetPackageLocation()
    local serverParent = Config:GetServerPackageLocation()

	local installedPackages = {}
	for _, package in packages do

        Logging:Info(`Installing {package}`)

		local sharedDeps = resolveRequirements(package.SharedDependencies, metaDataStore, packageStore)
		local serverDeps = resolveRequirements(package.ServerDependencies, metaDataStore, packageStore)

		installedPackages = join(installedPackages, sharedDeps)
		installedPackages = join(installedPackages, serverDeps)

		if getExistingPackage(package.Scope, package.Name, tostring(package.Version)) then
			Logging:Info(`Package already installed {package}`)
			continue
		end

		package.Instance.Parent = if package.Location == Package.SHARED then sharedParent else serverParent
		table.insert(installedPackages, package.Instance)
	end

	return installedPackages
end

function PackageManager:InstallArchive(file: File)

	local content = file:GetBinaryContents()
	local success, path = pcall(VirtualPath.fromZip, content)
	if not success then
		Logging:Warning(`Failed to unzip archive {file}`)
		Logging:Debug(path)
		return
	end

	local wallyFile = path / "wally.toml"
	local rawMetaData = wallyFile:IsFile() and wallyFile:Read()

	if not rawMetaData then
		local fileExtension = string.find(file.Name, ".zip")
		Logging:Debug(fileExtension)

		local unzippedName = string.sub(file.Name, 1, fileExtension - 1)

		Logging:Debug(unzippedName)

		local subFolder = path / unzippedName

		if subFolder:IsDir() then
			path = subFolder
			wallyFile = path / "wally.toml"
			rawMetaData = wallyFile:IsFile() and wallyFile:Read()
		end
	end

	if not rawMetaData then
		Logging:Warning(`Could not find package meta data in file {file}`)
		return
	end

	local metaData = Toml.parse(rawMetaData)
	Logging:Debug(metaData)

	local scope, name = table.unpack(string.split(metaData["package"]["name"], "/"))
	local _version = metaData["package"]["version"]

	Logging:Info(`Installing {scope}/{name}@{_version}`)

	local packageMetaData = {}

	packageMetaData.dependencies = metaData["dependencies"]
	packageMetaData["server-dependencies"] = {}

	local package = PackageManager:GetPackageFromPath(
		path,
		scope,
		name,
		_version,
		packageMetaData
	)

	package.Instance.Parent = Config:GetPackageLocation()

	return package.Instance
end

return PackageManager
