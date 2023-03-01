
-- McThor2

local GitHubApi = require(script:WaitForChild("GitHubApi"))
local WallyApi = require(script:WaitForChild("WallyApi"))
local GUI = require(script:WaitForChild("GUI"))
local Config = require(script:WaitForChild("Config"))
local Logging = require(script:WaitForChild("Logging"))

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

local function installPackages(packages: {Instance}, parent: Instance)

	local installedPackages = {}
	for _, depPackage in packages do

		local attributes = getPackageAttributes(depPackage)
		if getExistingPackage(attributes.Scope, attributes.Name, attributes.Version) then
			Logging:Info(
				"Dependency already satisfied: "..
				`{attributes.Scope}/{attributes.Name}@{attributes.Version}`
			)
			continue
		end

		depPackage.Parent = parent
		table.insert(installedPackages, depPackage)
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

	local package, sharedPackages, serverPackages = WallyApi:InstallPackage(scope, name, ver)

	if not package then
		Logging:Warning(`Could not download package: {scope}/{name}@{ver}`)
		return
	end

	local existing = getExistingPackage(scope, name, ver)

	if existing then
		Logging:Info(`Found existing installation of {scope}/{name}@{ver}`)
	else
		package.Parent = parent
		Selection:Add({package})
	end

	Logging:Info("Installing dependencies...")

	installPackages(sharedPackages, parent)
	installPackages(serverPackages, serverParent)

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

end

init()
