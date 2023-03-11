
local SemVer = require(script.Parent:WaitForChild("SemVer"))
type SemVer = SemVer.SemVer

local Logging = require(script.Parent:WaitForChild("Logging"))

local Requirement = {}
Requirement.__index = Requirement

local DEP_PATTERN = "([<>=]*)(%d+%.%d+%.%d+)"

local GT = ">"
local GE = ">="
local LT = "<"
local LE = "<="
local EQ = "="
local NE = "!="

local QUALIFIERS = {
    [GT] = GT,
    [GE] = GE,
    [LT] = LT,
    [LE] = LE,
    [EQ] = EQ,
    [NE] = NE
}


function Requirement.new(
        reqName: string,
        scope: string,
        name: string,
        min: SemVer,
        minEqual: boolean,
        max: SemVer,
        maxEqual: boolean,
        blacklist: {SemVer}?)

    local self = {}
    self.ReqName = reqName
    self.Scope = scope
    self.Name = name
    self.Blacklist = blacklist or {}

    self.Min = min
    self._minEqual = minEqual

    self.Max = max
    self._maxEqual = maxEqual

    setmetatable(self, Requirement)

    return self
end

function Requirement.fromWallyString(reqName: string, rawDependency: string): Requirement
    local rawVersions = string.split(rawDependency, "@")
    local scope, name = string.match(rawVersions[1], "(%l+)/(%l+)")
    local versionPins = string.split(rawVersions[2], ",")

    local requirements = {}
    for _, pin in versionPins do
        local rawQual, _ver = string.match(pin, DEP_PATTERN)

        if not _ver then
            Logging:Warning(`'{pin}' - Unkown version '{_ver}'`)
            continue
        end

        local qualifier = QUALIFIERS[rawQual]
        if rawQual and not qualifier then
            Logging:Warning(`'{pin}' - Unknown qualifier '{rawQual}'`)
            continue
        end

        table.insert(requirements, {
            qualifier = qualifier,
            version = _ver
        })

    end

    local blacklist = {}

    local minVer, maxVer
    local minEqual, maxEqual
    for _, req in requirements do
        if req.qualifier == LE then
            maxVer = SemVer.fromString(req.version, true)
            maxEqual = true
        elseif req.qualifier == LT then
            maxVer = SemVer.fromString(req.version, true)
            maxEqual = false
        elseif req.qualifier == GE then
            minVer = SemVer.fromString(req.version, true)
            minEqual = true
        elseif req.qualifier == GT then
            minVer = SemVer.fromString(req.version, true)
            minEqual = false
        elseif req.qualifier == NE then
            table.insert(blacklist, SemVer.fromString(req.version, true))
        end
    end

    return Requirement.new(
        reqName,
        scope,
        name,
        minVer,
        minEqual,
        maxVer,
        maxEqual,
        blacklist
    )
end

function Requirement:Check(version: SemVer)

    for _, blacklistedVersion in self.Blacklist do
        if blacklistedVersion == version then
            return false
        end
    end

    return (
        ((self._minEqual and self.Min <= version) or self.Min < version) and
        ((self._maxEqual and self.Max >= version) or self.Max > version)
    )
end

export type Requirement = typeof(Requirement.new())

return Requirement
