
local Config = {}

local CONFIG_INSTANCE_NAME = "RPM-Config"
local CONFIG_ATTRIBUTE_NAME = "rpm_config"

local SHARED_PACKAGE_KEY = "PackageLocation"
local DEFAULT_PACKAGE_LOCATION = "ReplicatedStorage/Packages"

local SERVER_PACKAGE_KEY = "ServerPackageLoction"
local DEFAULT_SERVER_PACKAGE_LOCATION = "ServerStorage/Packages"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local HttpService = game:GetService("HttpService")

local LOCATION_LOOKUP = {
    ["ReplicatedStorage"] = ReplicatedStorage,
    ["ServerStorage"] = ServerStorage,
    ["StarterPlayer"] = StarterPlayer
}

local INVERTED_LOCATION_LOOKUP = {}
for k, v in LOCATION_LOOKUP do
    assert(
        INVERTED_LOCATION_LOOKUP[v] == nil,
        `Multiple locations labels detected for {v}`
    )
    INVERTED_LOCATION_LOOKUP[v] = k
end

local Logging = require(script.Parent.Logging)

Config._decoded = nil

local changedEvent = Instance.new("BindableEvent")
Config.Changed = changedEvent.Event

local function parseLocation(rawLocation: string)

    local tokens = string.split(rawLocation, "/")
    --print(tokens)

    local rootLocation = tokens[1]

    local root = LOCATION_LOOKUP[rootLocation]
    if not root then
        error(`Invalid root location for package: \"{rootLocation}\"`)
    end

    local location = root
    for i = 2, #tokens do
        local name = tokens[i]
        local node = location:FindFirstChild(tokens[i])
        if not node then
            node = Instance.new("Folder")
            node.Name = name
            node.Parent = location
        end
        location = node
    end

    return location
end

local function createConfiguration()
    local newConfiguration = Instance.new("Configuration")
    newConfiguration.Name = CONFIG_INSTANCE_NAME
    return newConfiguration
end

local function getConfiguration()
    local existingConfiguration = ServerStorage:FindFirstChild(CONFIG_INSTANCE_NAME)
    if existingConfiguration then
        return existingConfiguration
    end

    local newConfig = createConfiguration()
    newConfig.Parent = ServerStorage
    return newConfig
end

function Config:Save()
    local configInstance = getConfiguration()

    local encodedConfig = HttpService:JSONEncode(self._decoded)

    Logging:Debug("set", encodedConfig)
    configInstance:SetAttribute(
        CONFIG_ATTRIBUTE_NAME,
        encodedConfig
    )
end

function Config:Load()
    local configInstance = getConfiguration()
    local rawConfig = configInstance:GetAttribute(CONFIG_ATTRIBUTE_NAME)

    rawConfig = rawConfig or "{}"

    local success, config = pcall(function()
        return HttpService:JSONDecode(rawConfig)
    end)

    if not success then
        Logging:Warning("Invalid RPM config detected - ")
        Logging:Warning(config)
        return
    end

    self._decoded = config

    return config
end

function Config:Set(key, value)

    local config = self._decoded

    local success, encodedConfig = pcall(function()
        return HttpService:JSONEncode(config)
    end)

    if not success then
        Logging:Warning("Invalid config key/value - ", key, value)
        Logging:Warning(encodedConfig)
        return
    end

    config[key] = value

    Config:Save()
end

function Config:Get(key)

    if not self._decoded then
        Logging:Warning("Config not loaded")
        return nil
    end

    return self._decoded[key]
end

function Config:GetRawLocation(object: Instance)
    local result = object.Name
	object = object.Parent
	while object and object ~= game do
		-- Prepend parent name
		result = object.Name .. "/" .. result
		-- Go up the hierarchy
		object = object.Parent

        if object.Parent == game and INVERTED_LOCATION_LOOKUP[object] ~= nil then
            Logging:Error(`Invalid root location for package: {object}`)
        end
	end
	return result
end

function Config:GetPackageLocation()
    local rawLocation = self:Get(SHARED_PACKAGE_KEY)
    return parseLocation(rawLocation)
end

function Config:GetServerPackageLocation()
    local rawLocation = self:Get(SERVER_PACKAGE_KEY)
    return parseLocation(rawLocation)
end

local function onUpdate(attribute)
    if attribute ~= CONFIG_ATTRIBUTE_NAME then
        return
    end

    Config:Load()

    changedEvent:Fire()
end

local function init()

    Config:Load()

	if not Config:Get(SHARED_PACKAGE_KEY) then
        Config:Set(SHARED_PACKAGE_KEY, DEFAULT_PACKAGE_LOCATION)
	end

    if not Config:Get(SERVER_PACKAGE_KEY) then
        Config:Set(SERVER_PACKAGE_KEY, DEFAULT_SERVER_PACKAGE_LOCATION)
    end

    local configInstance = getConfiguration()
    configInstance.AttributeChanged:Connect(onUpdate)

end

init()

return Config
