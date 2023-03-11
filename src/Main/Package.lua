
local SemVer = require(script.Parent:WaitForChild("SemVer"))
type SemVer = SemVer.SemVer

local Requirement = require(script.Parent:WaitForChild("Requirement"))
type Requirement = Requirement.Requirement

local Package = {}
Package.__index = Package

export type SHARED = "shared"
export type SERVER = "server"

Package.SHARED = "shared" :: SHARED
Package.SERVER = "server" :: SERVER

function Package.new(
    scope: string,
    name: string,
    version: SemVer,
    instance: Instance,
    location: SHARED | SERVER,
    sharedDependencies: {Requirement}?,
    serverDependencies: {Requirement}?)

    sharedDependencies = sharedDependencies or {}
    serverDependencies = serverDependencies or {}

    local self = {}
    self.Scope = scope
    self.Name = name
    self.Version = version
    self.Instance = instance
    self.Location = location or Package.SHARED
    self.SharedDependencies = sharedDependencies
    self.ServerDependencies = serverDependencies
    setmetatable(self, Package)
    return self
end

function Package:__tostring()
    return `{self.Scope}/{self.Name}@{self.Version}`
end

export type Package = typeof(Package.new())

return Package
