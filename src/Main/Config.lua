
local Config = {}

local CONFIG_ATTRIBUTE_NAME = "rpm_config"
local DEFAULT_PACKAGE_LOCATION = "ReplicatedStorage/Packages"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local HttpService = game:GetService("HttpService")

local LOCATION_LOOKUP = {
    ["ReplicatedStorage"] = ReplicatedStorage,
    ["ServerStorage"] = ServerStorage,
    ["StarterPlayer"] = StarterPlayer
}

Config._decoded = nil

local changedEvent = Instance.new("BindableEvent")
Config.Changed = changedEvent.Event

local function parseLocation(rawLocation: string)

    local tokens = string.split(rawLocation, "/")
    print(tokens)

    local rootLocation = tokens[1]

    local root = LOCATION_LOOKUP[rootLocation]
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

function Config:Load()
    local rawConfig = ServerStorage:GetAttribute(CONFIG_ATTRIBUTE_NAME)

    rawConfig = rawConfig or "{}"

    local success, config = pcall(function()
        return HttpService:JSONDecode(rawConfig)
    end)

    if not success then
        warn("Invalid RPM config detected - ")
        warn(config)
        return
    end

    Config._decoded = config

    return config
end

function Config:Set(key, value)

    local config = self._decoded

    config[key] = value

    local success, encodedConfig = pcall(function()
        return HttpService:JSONEncode(config)
    end)

    if not success then
        warn("Invalid config key/value - ", key, value)
        warn(encodedConfig)
        return
    end

    print("set", encodedConfig)
    ServerStorage:SetAttribute(
        CONFIG_ATTRIBUTE_NAME,
        encodedConfig
    )
end

function Config:Get(key)

    if not self._decoded then
        warn("Config not loaded")
        return nil
    end
    
    return self._decoded[key]
end

function Config:GetPackageLocation()

    local rawLocation = self:Get("PackageLocation")

    print(rawLocation)

    return parseLocation(rawLocation)
end

local function init()
    
    local placeConfig = Config:Load()

	if not placeConfig or not placeConfig["PackageLocation"] then
        Config:Set("PackageLocation", DEFAULT_PACKAGE_LOCATION)
	end

    ServerStorage.AttributeChanged:Connect(function(attribute)
        if attribute ~= CONFIG_ATTRIBUTE_NAME then
            return
        end

        Config:Load()

        changedEvent:Fire()
    end)

end

init()

return Config
