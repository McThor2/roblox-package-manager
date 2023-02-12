
--!nonstrict
-- McThor2

local _version = "0.1.0"

local root = script.Parent

local GitHubApi = require(script:WaitForChild("GitHubApi")) 
local WallyApi = require(script:WaitForChild("WallyApi"))
local GUI = require(script:WaitForChild("GUI"))

local Selection = game:GetService("Selection")
local ChangeHistory = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local StudioService = game:GetService("StudioService")

local textHistory = {}


local GH_TAG_PATTERN = "^([%w-]+)/([%w-]+)@(%w+.%w+.%w+)$"
local GH_PATTERN = "^(%a+)/(%a+)$"

local function onDownload(url: string)
	table.insert(textHistory, url)

	local scope, name, ver = string.match(url, GH_TAG_PATTERN)

	local selected = Selection:Get()

	local parent = ServerStorage.Packages
	if #selected > 0 then
		--parent = selected[1]
	end
	
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

GUI:Init(plugin)
GUI:RegisterDownloadCallback(onDownload)
GUI:RegisterWallySearch(onWally)
