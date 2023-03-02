
local SemVer = require(script.Parent:WaitForChild("SemVer"))
type SemVer = SemVer.SemVer

local Requirement = require(script.Parent:WaitForChild("Requirement"))
type Requirement = Requirement.Requirement

local Package = {}
Package.__index = Package

function Package.new(
    name: string,
    version: SemVer,
    instance: Instance,
    sharedDependencies: {Requirement}?,
    serverDependencies: {Requirement}?)

    sharedDependencies = sharedDependencies or {}
    serverDependencies = serverDependencies or {}

    local self = {}
    self.Name = name
    self.Version = version
    self.Instance = instance
    self.SharedDependencies = sharedDependencies
    self.ServerDependencies = serverDependencies
    setmetatable(self, Package)
    return self
end

export type Package = typeof(Package.new())

return Package
