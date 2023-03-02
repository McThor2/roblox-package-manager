

local WallyApi = require(script.Parent:WaitForChild("WallyApi"))
local Config = require(script.Parent:WaitForChild("Config"))
local Requirement = require(script.Parent:WaitForChild("Requirement"))
local Package = require(script.Parent:WaitForChild("Package"))
local Logging = require(script.Parent:WaitForChild("Logging"))

type Package = Package.Package
type Requirement = Requirement.Requirement

local PackageManager = {}

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

local function resolveRequirements(requirements: {Requirement})

	local installedPackages = {}
	for _, requirement in requirements do

		local availableVersions = WallyApi:GetPackageVersions(
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

		local package = WallyApi:GetPackage(
			requirement.Scope,
			requirement.Name,
			tostring(installVersion)
		)

		local installedDeps = PackageManager:InstallPackages({package})

		installedPackages = join(installedPackages, installedDeps)
	end

	return installedPackages
end

function PackageManager:InstallPackages(packages: {Package})

    local sharedParent = Config:GetPackageLocation()
    local serverParent = Config:GetServerPackageLocation()

	local installedPackages = {}
	for _, package in packages do

        Logging:Info(`Installing {package}`)

		local sharedDeps = resolveRequirements(package.SharedDependencies)
		local serverDeps = resolveRequirements(package.ServerDependencies)

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

return PackageManager
