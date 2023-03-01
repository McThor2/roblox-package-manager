
local Logging = {}

function Logging:Debug(...)
    print(...)
end

function Logging:Info(...)
    print(...)
end

function Logging:Warning(...)
    warn(...)
end

function Logging:Error(...)
    error(...)
end

return Logging
