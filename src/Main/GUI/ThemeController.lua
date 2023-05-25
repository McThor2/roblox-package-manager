
local Roact = require(script.Parent.Roact)
local ThemeContext = require(script.Parent.ThemeContext)

local ThemeController = Roact.Component:extend("ThemeController")

local StudioSettings = settings().Studio

function ThemeController:init()
    self:setState({
        theme = ThemeContext.getCurrentTheme()
    })

    StudioSettings.ThemeChanged:Connect(function()
        self:setState({
            theme = ThemeContext.getCurrentTheme()
        })
    end)
end

function ThemeController:render()
    return Roact.createElement(ThemeContext.Provider, {
        value = self.state.theme,
    }, self.props[Roact.Children])
end

return ThemeController
