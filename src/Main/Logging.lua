
local Logging = {}
Logging.DEBUG = 1
Logging.INFO = 2
Logging.WARNING = 3
Logging.ERROR = 4

local currentLevel = 1
local rootInstance = nil

local Logger = {}
do
    Logger.__index = Logger

    local function formatSource(source: string)
        if rootInstance == nil then
            return source
        end

        local split = string.split(source, rootInstance:GetFullName() .. ".")
        return split[2]
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

        if funcName then
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
        print(...)
    end

    function Logger:Warning(...)
        if currentLevel > Logging.WARNING then
            return
        end
        warn(...)
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
    self:GetLogger("root"):Debug(msg, 3)
end

function Logging:Info(...)
    self:GetLogger("root"):Info(...)
end

function Logging:Warning(...)
    self:GetLogger("root"):Warning(...)
end

function Logging:Error(...)
    self:GetLogger("root"):Error(...)
end

return Logging
