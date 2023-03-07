
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

	Logging:SetRootInstance(script.Parent)

	if not Config:Get("Logging Level") then
		Config:Set("Logging Level", Logging.DEBUG)
	end

	Config.Changed:Connect(function()
		Logging:SetLevel(Config:Get("Logging Level"))
	end)
	Logging:SetLevel(Config:Get("Logging Level"))

	GUI:Init(plugin)
	GUI:RegisterDownloadCallback(onDownload)
	GUI:RegisterWallySearch(onWallySearch)

	GUI.BrowseActivated:Connect(function()
		local file = StudioService:PromptImportFile({"zip", "gz"})

		Logging:Debug(file)

		PackageManager:InstallArchive(file)
	end)

	local pluginSettings = plugin:GetSetting(RPM_SETTINGS_KEY)

	if pluginSettings == nil then
		plugin:SetSetting(RPM_SETTINGS_KEY, {})
	end

end

init()
