
local Logging = {}

function Logging:Debug(...)
    local info = debug.info(1, "")
    print(...)
end

function Logging:Info(...)
    print(...)
end

function Logging:Warning(...)
    warn(...)
end

function Logging:Error(...)
    local args = {...}
    local message = (
        table.concat(args, " ") .. "\n" ..
        debug.traceback(1)
    )
    error(message, 1)
end

return Logging
