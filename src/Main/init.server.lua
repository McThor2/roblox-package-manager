
-- McThor2

local WallyApi = require(script:WaitForChild("WallyApi"))
local GUI = require(script:WaitForChild("GUI"))
local Config = require(script:WaitForChild("Config"))
local Requirement = require(script:WaitForChild("Requirement"))
local Logging = require(script:WaitForChild("Logging"))

type Requirement = Requirement.Requirement

local Selection = game:GetService("Selection")

local RPM_SETTINGS_KEY = "rpm_settings"

local WALLY_PACKAGE_PATTERN = "^([%w-]+)/([%w-]+)@(%w+.%w+.%w+)$"

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

local function installPackages(requirements: {Requirement}, parent: Instance)

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

		package.Instance.Parent = parent
		table.insert(installedPackages, package.Instance)
	end

	Selection:Add(installedPackages)
end

local function onDownload(inputText: string)

	Logging:Debug(`Download button with '{inputText}'`)

	local scope, name, ver = string.match(inputText, WALLY_PACKAGE_PATTERN)

	if not (scope and name and ver) then
		return
	end

	local parent = Config:GetPackageLocation()
	local serverParent = Config:GetServerPackageLocation()

	-- TODO: Search for existing package

	local package = WallyApi:GetPackage(scope, name, ver)

	if not package then
		Logging:Warning(`Could not download package: {scope}/{name}@{ver}`)
		return
	end

	local existing = getExistingPackage(scope, name, ver)

	if existing then
		Logging:Info(`Found existing installation of {scope}/{name}@{ver}`)
	else
		package.Instance.Parent = parent
		Selection:Add({package.Instance})
	end

	Logging:Info("Installing dependencies...")

	installPackages(package.SharedDependencies, parent)
	installPackages(package.ServerDependencies, serverParent)

end

local function onResultRow(row: GUI.ResultRow)

	Logging:Debug(row)

	local scope = row.Description.scope
	local name = row.Description.name

	if row.MetaData == nil then
		Logging:Debug("set meta")
		local metaData = WallyApi:GetMetaData(scope, name)
		row:SetMetaData(metaData)
	end
end

local function onWallySearch(rawText: string)
	local packagesInfo = WallyApi:ListPackages(rawText)
	GUI:UpdateSearchResults(packagesInfo, onResultRow)

end

local function init()

	GUI:Init(plugin)
	GUI:RegisterDownloadCallback(onDownload)
	GUI:RegisterWallySearch(onWallySearch)

	local pluginSettings = plugin:GetSetting(RPM_SETTINGS_KEY)

	if pluginSettings == nil then
		plugin:SetSetting(RPM_SETTINGS_KEY, {})
	end

	Logging:SetRootInstance(script.Parent)

end

init()
