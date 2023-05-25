
local Logging = {}
Logging.DEBUG = 1
Logging.INFO = 2
Logging.WARNING = 3
Logging.ERROR = 4

local currentLevel = 1
local rootInstance = nil

local ROOT_LOGGER = "root"
local DEFAULT_PREFIX = ROOT_LOGGER

local Logger = {}
do
    Logger.__index = Logger

    local function formatSource(source: string)
        if rootInstance == nil then
            return source
        end

        local split = string.split(source, rootInstance.Parent:GetFullName() .. ".")
        return split[2]
    end

    local function getPrefix()
        return `[{rootInstance and rootInstance.Name or DEFAULT_PREFIX}]`
    end

    function Logger.new(name: string)
        local self = {}
        self.Name = name
        return setmetatable(self, Logger)
    end

    function Logger:Debug(msg: string, debugLevel: number?)
        debugLevel = debugLevel or 2
        local line = debug.info(debugLevel, "l")
        local source = debug.info(debugLevel, "s")
        source = formatSource(source)
        local funcName = debug.info(debugLevel, "n")
        local debugInfo = `{source}, Line {line}`

        if funcName and funcName ~= "" then
            debugInfo ..= ` - function {funcName}`
        end

        if currentLevel > Logging.DEBUG then
            return
        end

        print(`[{debugInfo}]`, msg)
    end

    function Logger:Info(...)
        if currentLevel > Logging.INFO then
            return
        end
        local prefix = getPrefix()
        print(prefix, ...)
    end

    function Logger:Warning(...)
        if currentLevel > Logging.WARNING then
            return
        end
        local prefix = getPrefix()
        warn(prefix, ...)
    end

    function Logger:Error(...)
        local args = {...}
        local message = (
            table.concat(args, " ") .. "\n" ..
            debug.traceback(2)
        )
        if currentLevel > Logging.ERROR then
            return
        end

        error(message, 2)
    end
end

local loggerPool = {}
loggerPool.root = Logger.new("root")

function Logging:GetLogger(name: string)
    if not loggerPool[name] then
        loggerPool[name] = Logger.new(name)
    end

    return loggerPool[name]
end

function Logging:SetLevel(level: number)
    currentLevel = level
end

function Logging:SetRootInstance(instance: Instance?)
    rootInstance = instance
end

function Logging:Debug(msg)
    self:GetLogger(ROOT_LOGGER):Debug(msg, 3)
end

function Logging:Info(...)
    self:GetLogger(ROOT_LOGGER):Info(...)
end

function Logging:Warning(...)
    self:GetLogger(ROOT_LOGGER):Warning(...)
end

function Logging:Error(...)
    self:GetLogger(ROOT_LOGGER):Error(...)
end

return Logging
