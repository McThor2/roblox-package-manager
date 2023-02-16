
local Version = {}

local pluginFolder = script.Parent.Parent

Version.Value = pluginFolder:GetAttribute("version")

pluginFolder.AttributeChanged:Connect(function(attribute)
    if attribute == "version" then
        pluginFolder:SetAttribute("version", Version.Value)
    end
end)

return Version