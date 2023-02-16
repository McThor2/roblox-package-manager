
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

local GH_TAG_PATTERN = "^([%w-]+)/([%w-]+)@(%w+.%w+.%w+)$"
local GH_PATTERN = "^(%a+)/(%a+)$"

local function onDownload(url: string)

	local scope, name, ver = string.match(url, GH_TAG_PATTERN)

	local selected = Selection:Get()

	local parent = Config:GetPackageLocation()
	
	-- TODO: Search for existing package

	local package = WallyApi:GetPackage(scope, name, ver)
	
	local metaData = WallyApi:GetMetaData(scope, name)
	
	if not package then
		warn("Could not download package")
		return
	end

	package.Parent = parent
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

	print("RPM version v" .. tostring(Version.Value))

	GUI:Init(plugin)
	GUI:RegisterDownloadCallback(onDownload)
	GUI:RegisterWallySearch(onWally)

	GUI.Opened:Connect(function()
		local packageLocation = Config:GetPackageLocation()
		print( string.format("RPM v%s", Version.Value) )
		print( "RPM using location: " .. packageLocation:GetFullName())
	end)

	local placeSettings = plugin:GetSetting(RPM_SETTINGS_KEY)

	if placeSettings == nil then
		plugin:SetSetting(RPM_SETTINGS_KEY, {})
	end

end

init()
