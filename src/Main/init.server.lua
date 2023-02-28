
--!nonstrict
-- McThor2

local root = script.Parent

local GitHubApi = require(script:WaitForChild("GitHubApi"))
local WallyApi = require(script:WaitForChild("WallyApi"))
local GUI = require(script:WaitForChild("GUI"))
local Config = require(script:WaitForChild("Config"))
local Version = require(script:WaitForChild("Version"))

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local RPM_SETTINGS_KEY = "rpm_settings"

local WALLY_PACKAGE_PATTERN = "^([%w-]+)/([%w-]+)@(%w+.%w+.%w+)$"
local GH_PATTERN = "^(%a+)/(%a+)$"

local function onDownload(url: string)

	local scope, name, ver = string.match(url, WALLY_PACKAGE_PATTERN)

	if not scope then
		return
	end

	local parent = Config:GetPackageLocation()
	local serverParent = Config:GetServerPackageLocation()

	-- TODO: Search for existing package

	local package, sharedPackages, serverPackages = WallyApi:InstallPackage(scope, name, ver)

	local metaData = WallyApi:GetMetaData(scope, name)

	if not package then
		warn("Could not download package")
		return
	end

	local installedModules = {package}
	package.Parent = parent

	for _, depPackage in sharedPackages do
		depPackage.Parent = parent
		table.insert(installedModules, depPackage)
	end

	for _, depPackage in serverPackages do
		depPackage.Parent = serverParent
		table.insert(installedModules, depPackage)
	end

	Selection:Add(installedModules)
end

local function onResultRow(row: GUI.ResultRow)
	
	print(row)
	
	local scope = row.Description.scope
	local name = row.Description.name
	
	if row.MetaData == nil then
		print("set meta")
		local metaData = WallyApi:GetMetaData(scope, name)
		row:SetMetaData(metaData)
	end
end

local function onWally(rawText: string)
	local packagesInfo = WallyApi:ListPackages(rawText)
	GUI:UpdateSearchResults(packagesInfo, onResultRow)

end

local function init()

	GUI:Init(plugin)
	GUI:RegisterDownloadCallback(onDownload)
	GUI:RegisterWallySearch(onWally)

	local placeSettings = plugin:GetSetting(RPM_SETTINGS_KEY)

	if placeSettings == nil then
		plugin:SetSetting(RPM_SETTINGS_KEY, {})
	end

end

init()
