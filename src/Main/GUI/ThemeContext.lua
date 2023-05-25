
local Roact = require(script.Parent.Roact)

local StudioSettings = settings().Studio

export type Theme = {
	Background: Color3,
	InputBackground: Color3,
	TextColour: Color3,
	Border: Color3,
	PlaceHolderText: Color3
}
local function getCurrentTheme(): Theme
	local theme = StudioSettings.Theme
	return {
		Background = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		InputBackground = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground),
		TextColour = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		Border = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		PlaceHolderText = theme:GetColor(Enum.StudioStyleGuideColor.DimmedText)
	}
end

local ThemeContext = Roact.createContext(getCurrentTheme())

return {
    Provider = ThemeContext.Provider,
    Consumer = ThemeContext.Consumer,
    getCurrentTheme = getCurrentTheme,
}
