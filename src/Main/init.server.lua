
-- McThor2

local WallyApi = require(script:WaitForChild("WallyApi"))
local GUI = require(script:WaitForChild("GUI"))
local Config = require(script:WaitForChild("Config"))
local PackageManager = require(script:WaitForChild("PackageManager"))
local Logging = require(script:WaitForChild("Logging"))

local StudioService = game:GetService("StudioService")
local Selection = game:GetService("Selection")

local RPM_SETTINGS_KEY = "rpm_settings"

local WALLY_PACKAGE_PATTERN = "^([%w-]+)/([%w-]+)@(%w+.%w+.%w+)$"

local function onDownload(inputText: string)

	Logging:Debug(`Download button with '{inputText}'`)

	local scope, name, ver = string.match(inputText, WALLY_PACKAGE_PATTERN)

	if not (scope and name and ver) then
		return
	end

	-- TODO: Search for existing package

	local package = WallyApi:GetPackage(scope, name, ver)

	if not package then
		Logging:Warning(`Could not download package: {scope}/{name}@{ver}`)
		return
	end

	local installedPackages = PackageManager:InstallPackages(
		{package},
		function(...)
			return WallyApi:GetPackageVersions(...)
		end,
		function(...)
			return WallyApi:GetPackage(...)
		end
	)
	Logging:Info("Installed", installedPackages)
	Selection:Add(installedPackages)
end

local function onResultRow(scope: string, name: string): WallyApi.PackageMetaData?
	return WallyApi:GetMetaData(scope, name)
end

local function onWallySearch(rawText: string)
	local packagesInfo = WallyApi:ListPackages(rawText)
	return packagesInfo
end

local function onBrowse()

	local file = StudioService:PromptImportFile({"zip", "gz"})

	Logging:Debug(file)

	if not file then
		return
	end

	Logging:Info(`Using file {file}`)

	local installedPackage = PackageManager:InstallArchive(file)
	Selection:Add({installedPackage})
end

local function init()

	Logging:SetRootInstance(script.Parent)

	if not Config:Get("Logging Level") then
		Config:Set("Logging Level", Logging.INFO)
	end

	Config.Changed:Connect(function()
		Logging:SetLevel(Config:Get("Logging Level"))
	end)
	Logging:SetLevel(Config:Get("Logging Level"))

	GUI:Init({
		Plugin = plugin,
		OnDownload = onDownload,
		OnBrowse = onBrowse,
		OnWallySearch = onWallySearch,
		OnWallyRow = onResultRow
	})

	local pluginSettings = plugin:GetSetting(RPM_SETTINGS_KEY)

	if pluginSettings == nil then
		plugin:SetSetting(RPM_SETTINGS_KEY, {})
	end

end

init()
