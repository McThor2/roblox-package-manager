
local WallyApi = require(script.Parent:WaitForChild("WallyApi"))
local Version = require(script.Parent:WaitForChild("Version"))
local Config = require(script.Parent:WaitForChild("Config"))
local Roact = require(script.Roact)

local ThemeContext = require(script.ThemeContext)
local ThemeController = require(script.ThemeController)

local TextService = game:GetService("TextService")

type PackageDescription = WallyApi.PackageDescription
type PackageMetaData = WallyApi.PackageMetaData
type Theme = ThemeContext.Theme

local GUI = {}

local WIDGET_TITLE = "RPM"

local ICON_ID = "rbxassetid://12457413905"

local WIDGET_DEFAULT_WIDTH = 375
local WIDGET_DEFAULT_HEIGHT = 200

local WIDGET_MIN_WIDTH = 375
local WIDGET_MIN_HEIGHT = 200

local DEFAULT_MENU = "Download"

local SETTINGS_ICON = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png" --45x45
local IMPORT_ICON = "rbxasset://textures/StudioSharedUI/import@2x.png" -- 48x48
local SEARCH_ICON = "rbxasset://textures/DevConsole/Search.png" -- 26x26

local function setDefaults(props, defaultProps)
	props = table.clone(props)
	for k, v in defaultProps do
		props[k] = props[k] or v
	end
	return props
end

local function blankFrame(props)
	return Roact.createElement(ThemeContext.Consumer, {
		render = function(theme: Theme)

			local defaultProps = {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = theme.Background,
				BorderColor3 = theme.Border
			}

			for k, v in defaultProps do
				if props[k] then continue end
				props[k] = v
			end

			return Roact.createElement("Frame", props)
		end
	})
end

local function customTextButton(props)

	local ImageIdDefault = "rbxasset://textures/TerrainTools/button_default.png"
	local ImageIdHovered = "rbxasset://textures/TerrainTools/button_hover.png"
	local ImageIdPressed = "rbxasset://textures/TerrainTools/button_pressed.png"

	return Roact.createElement("ImageButton", {
		LayoutOrder = props.LayoutOrder,
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.fromScale(0, 0),

		BackgroundTransparency = 1,
		Image = ImageIdDefault,
		HoverImage = ImageIdHovered,
		PressedImage = ImageIdPressed,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(7, 7, 156, 36),
		AutoButtonColor = false,
		[Roact.Event.Activated] = props[Roact.Event.Activated]
	}, {
		TextLabel = Roact.createElement("TextLabel", {
			Text = props.Text,
			TextSize = props.TextSize or 18,

			Font = Enum.Font.SourceSans,
			Size = UDim2.new(1, 0, 1, -5),
			BackgroundTransparency = 1,
		})
	})
end

local CustomImageButton = Roact.Component:extend("CustomImageButton")

function CustomImageButton:init(props: {
	Image: string,
	ImagePadding: Vector2,
	Size: UDim2,
	LayoutOrder: number,
	Description: string?,
	[Roact.Symbol]: () -> nil,
	})
	self:setState({
		descriptionVisible = false
	})
end

function CustomImageButton:_render(theme: Theme)

	local descriptionVisible = (self.props.Description ~= nil) and self.state.descriptionVisible	

	return Roact.createElement("ImageButton",
		{
			Size = self.props.Size,
			LayoutOrder = self.props.LayoutOrder,
			BackgroundTransparency = 0,
			BackgroundColor3 = theme.Background,
			BorderSizePixel = 0,
			[Roact.Event.Activated] = self.props[Roact.Event.Activated],
			[Roact.Event.MouseEnter] = function()
				self:setState({descriptionVisible = true})
			end,
			[Roact.Event.MouseLeave] = function()
				self:setState({descriptionVisible = false})
			end,
		},
		{
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4)
			}),
			AspectRatio = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Height
			}),
			Icon = Roact.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				BorderSizePixel = 0,
				Image = self.props.Image,
				Size = UDim2.new(1, -self.props.ImagePadding.X, 1, -self.props.ImagePadding.Y),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5)
			}),
			Description = Roact.createElement("TextLabel", {
				Text = self.props.Description or "",
				Visible = descriptionVisible,
				Position = UDim2.new(0, 0, 1, 5),
				Size = UDim2.fromOffset(100, 25),
				BackgroundColor3 = theme.Background,
				BorderColor3 = theme.Border,
				TextColor3 = theme.TextColour,
				ZIndex = 100,
			})
		}
	)
end

function CustomImageButton:render()
	return Roact.createElement(ThemeContext.Consumer, {
		render = function(theme: Theme)
			return self:_render(theme)
		end
	})
end

local function createToolbar(plugin)
	local toolbar = plugin:CreateToolbar(WIDGET_TITLE)

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,  -- Widget will be initialized in floating panel
		true,   -- Widget will be initially enabled
		false,  -- Don't override the previous enabled state
		WIDGET_DEFAULT_WIDTH,    -- Default width of the floating window
		WIDGET_DEFAULT_HEIGHT,    -- Default height of the floating window
		WIDGET_MIN_WIDTH,    -- Minimum width of the floating window
		WIDGET_MIN_HEIGHT     -- Minimum height of the floating window
	)

	local widget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui(WIDGET_TITLE, widgetInfo)
	widget.Title = WIDGET_TITLE
	widget.Name = WIDGET_TITLE

	local button = toolbar:CreateButton(
		"Open RPM GUI", "Opens the Roblox Package Manager GUI", ICON_ID)
	button.ClickableWhenViewportHidden = true

	local function onClick()
		widget.Enabled = not widget.Enabled
		--button:SetActive(widget.Enabled)
	end

	button:SetActive(widget.Enabled)

	button.Click:Connect(onClick)

	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		button:SetActive(widget.Enabled)
	end)

	return toolbar, widget
end

local function scrollingTextInput(props: {
		Position: UDim2,
		Size: UDim2,
		placeHolderText: string?,
		defaultText: string?,
		[Roact.Ref]: Roact.Ref
	})

	props[Roact.Ref] = props[Roact.Ref] or Roact.createRef()

	local ref = props[Roact.Ref]
	local frameRef = Roact.createRef()

	local function updateCanvasPosition()
		local textBox: TextBox? = ref:getValue()
		local frame: ScrollingFrame? = frameRef:getValue()
		if not textBox or not frame then
			return
		end

		local cursorPos = textBox.CursorPosition

		if cursorPos == -1 then
			return
		end

		local textBounds = textBox.TextBounds

		if textBounds.X < frame.AbsoluteSize.X then
			return
		end

		-- Check if cursor is within visible region

		local leftString = string.sub(textBox.Text, 1, cursorPos-1)
		local leftSize = TextService:GetTextSize(
			leftString,
			textBox.TextSize,
			textBox.Font,
			Vector2.new(1_000, 200)
		)

		local xOffset = leftSize.X - frame.CanvasPosition.X

		local isVisible = (
			xOffset > 0 and
			xOffset < frame.AbsoluteSize.X - 5
		)

		local delta = xOffset > 0 and xOffset - frame.AbsoluteSize.X + 15  or xOffset

		if not isVisible then
			frame.CanvasPosition = Vector2.new(
				frame.CanvasPosition.X + delta,
				0
			)
		end

	end

	local function updateCanvasSize()
		local textBox: TextBox? = ref:getValue()
		local frame: ScrollingFrame? = frameRef:getValue()
		if not textBox or not frame then
			return
		end

		frame.CanvasSize = UDim2.fromOffset(
			textBox.AbsoluteSize.X + 10,
			0
		)
	end

	return Roact.createElement(ThemeContext.Consumer, {
		render = function(theme: Theme)
			return Roact.createElement("ScrollingFrame", {
				BackgroundTransparency = 0,
				BackgroundColor3 = theme.InputBackground,
				BorderSizePixel = 1,
				BorderColor3 = theme.Border,
				CanvasSize = UDim2.fromScale(0, 0),
				ScrollBarThickness = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.None,
				Size = props.Size,
				Position = props.Position,
				[Roact.Ref] = frameRef
			}, {
				TextBox = Roact.createElement("TextBox", {
					PlaceholderText = props.placeHolderText or "",
					Text = props.defaultText or "",

					PlaceholderColor3 = theme.PlaceHolderText,
					TextColor3 = theme.TextColour,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					AutomaticSize = Enum.AutomaticSize.X,

					Size = UDim2.new(1, -10, 1, -5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 3, 0.5, 0),

					[Roact.Ref] = props[Roact.Ref],
					[Roact.Change.TextBounds] = updateCanvasPosition,
					[Roact.Change.CursorPosition] = updateCanvasPosition,
					[Roact.Change.AbsoluteSize] = updateCanvasSize,
				})
			})
		end
	})
end

local function searchEntry(props: {
		textBoxLabel: string,
		buttonText: string,
		callback: (text: string) -> nil,
		size: UDim2,
		position: UDim2
	})

	local textRef = Roact.createRef()

	local textEntry = Roact.createElement(scrollingTextInput, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -140, 1, 0),
		placeHolderText = props.textBoxLabel,
		[Roact.Ref] = textRef
	})

	local button = Roact.createElement(customTextButton, {
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1, -15, 0, 0),
		Size = UDim2.new(0, 100, 1, 0),
		Text = props.buttonText,
		TextSize = 15,
		[Roact.Event.Activated] = function()
			if props.callback then
				props.callback(textRef:getValue().Text)
			end
		end
	})

	return Roact.createElement(blankFrame, {
		Size = props.size or UDim2.new(1, 0, 0, 20),
		Position = props.position or UDim2.new(0,0,0,0)
	}, {
		TextEntry = textEntry,
		Button = button
	})
end

type RowData = {
	Description: PackageDescription,
	IsOpen: boolean,
	OnActivate: (scope: string, name: string) -> nil,
	MetaData: PackageMetaData?,
}

local function resultRow(props: RowData)

	local HEIGHT = 50

	local scope = props.Description.scope
	local name = props.Description.name

	local mainButton = Roact.createElement("TextButton", {
		Size = UDim2.new(1, -25, 0, HEIGHT - 10),
		TextSize = 10,
		ZIndex = 5,
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.new(0.5, -8, 0, 0.5 * HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = (
			` Scope: {props.Description.scope}\n` ..
			` Name: {props.Description.name}`
		),
		[Roact.Event.Activated] = function()
			props.OnActivated(scope, name)
		end
	})

	local size = UDim2.new(1, 0, 0, HEIGHT)
	local text = " Loading ..."

	if props.IsOpen and props.MetaData then

		text = " Versions:\n"

		local totalLines = 0
		for i, versionMetaData in props.MetaData.versions do
			local _version = versionMetaData.package.version

			text ..= `  - {tostring(_version)}\n`
			totalLines = i + 1
		end

		size = UDim2.new(1, 0, 0, HEIGHT + (totalLines) * 15)
	end

	local versionsInfo = Roact.createElement("TextLabel", {
		Size = UDim2.new(1, -40, 1, -HEIGHT + 2),
		TextSize = 10,
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = text,
		Visible = props.IsOpen
	})

	return Roact.createElement("Frame", {
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	}, {
		MainButton = mainButton,
		VersionsInfo = versionsInfo
	})

end

local function searchResults(props: {
		RowsData: {RowData}
	})

	local PADDING = 5
	local SHADE = 40

	local listLayout = Roact.createElement("UIListLayout", {
		Padding = UDim.new(0, PADDING),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	local rowElements = {}
	for i, data in props.RowsData do
		local newElement = Roact.createElement(resultRow, data)
		rowElements[`row {i}`] = newElement
	end

	return Roact.createElement("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(SHADE, SHADE, SHADE),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y
	}, {
		Layout = listLayout,
		ResultRows = Roact.createFragment(rowElements)
	})
end

local function downloadMenu(props: {
		downloadCallback: ((url: string) -> nil)?,
		browseCallback: (() -> nil)?
	})

	local downloadEntry = Roact.createElement(searchEntry, {
		textBoxLabel = "<scope>/<name>@<version>",
		buttonText = "Download",
		callback = props.downloadCallback,
		position = UDim2.fromOffset(10, 10)
	})

	local browseButton = Roact.createElement(customTextButton, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 150, 0, 20),
		Position = UDim2.new(0.5, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "Browse files",
		TextSize = 15,
		[Roact.Event.Activated] = props.browseCallback
	})

	return Roact.createFragment({
		DownloadEntry = downloadEntry,
		BrowseButton = browseButton
	})
end

local SearchMenu = Roact.Component:extend("SearchMenu")
do

	function SearchMenu:init(props: {
		searchCallback: (rawText: string) -> {PackageDescription},
		rowCallback: (scope: string, name: string) -> PackageMetaData?,
		results: {RowData}?
		})

		self:setState({
			Results = props.results or {}
		})
	end

	function SearchMenu:_rowCallback(index: number, scope: string, name: string)
		local results = table.clone(self.state.Results)
		local row: RowData = results[index]

		row.MetaData = row.MetaData or self.props.rowCallback(scope, name)
		row.IsOpen = not row.IsOpen

		self:setState({
			Results = results
		})
	end

	function SearchMenu:_searchCallback(text: string)

		local packageResults = self.props.searchCallback(text)
		local results: {RowData} = {}
		for index, description in packageResults do
			table.insert(results, {
				Description = description,
				MetaData = nil,
				IsOpen = false,
				OnActivated = function(scope: string, name: string)
					self:_rowCallback(index, scope, name)
				end
			})
		end

		self:setState({
			Results = results
		})
	end

	function SearchMenu:render()

		local wallySearch = Roact.createElement(searchEntry, {
			textBoxLabel = "search...",
			buttonText = "Go",
			callback = function(text: string)
				self:_searchCallback(text)
			end,
			position = UDim2.fromOffset(10, 10)
		})

		return Roact.createFragment({
			SearchBar = wallySearch,
			["SearchResults"] = Roact.createElement(searchResults, {
				RowsData = self.state.Results
			})
		})
	end
end

local function settingsMenu(props: {
		Version: string,
	})

	--local packageLocation = Config:GetPackageLocation()
	--local serverPackageLocation = Config:GetServerPackageLocation()

	local sharedLocation = "shared"--packageLocation and Config:GetRawLocation(packageLocation) or ""
	local serverLocation = "server"--serverPackageLocation and Config:GetRawLocation(serverPackageLocation) or ""

	return Roact.createElement(ThemeContext.Consumer, {
		render = function(theme: Theme)

			local listLayout = Roact.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder
			})

			local versionLabel = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(100, 20),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = `Version: v{props.Version}`,
				TextColor3 = theme.TextColour,
				LayoutOrder = 1
			})

			local textLabel = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(100, 20),
				Text = `Packages Location: "{sharedLocation}"`,
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = theme.TextColour,
				LayoutOrder = 2
			})

			local serverTextLabel = Roact.createElement("TextLabel", {
				Size = UDim2.fromOffset(100, 20),
				Text = `Server Packages Location: "{serverLocation}"`,
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = theme.TextColour,
				LayoutOrder = 3
			})

			return Roact.createFragment({
				Layout = listLayout,
				VersionLabel = versionLabel,
				PackageLabel = textLabel,
				ServerPackageLabel = serverTextLabel
			})
		end
	})

end

local MenuComponent = Roact.Component:extend("Menu")
do

	function MenuComponent:init(props)
		self:setState({
			CurrentMenu = props.Default,
			MenuElement = props.Menus[props.Default].Element
		})
	end

	function MenuComponent:render()

		local uiLayout = Roact.createElement("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal
		})

		local iconImage = Roact.createElement("ImageLabel", {
			Image = ICON_ID,
			Size = UDim2.new(0, 50, 1, -5),
			BackgroundTransparency = 1,
			LayoutOrder = 1
		}, {
			AspectRatio = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Height
			})
		})

		local menuFrames = {}
		for menuName, menuProps in self.props.Menus do

			local newButton = Roact.createElement(CustomImageButton, {
				Size = UDim2.new(0, 50, 1, -10),
				LayoutOrder = menuProps.LayoutOrder,
				Image = menuProps.Image,
				ImagePadding = menuProps.ImagePadding,
				Description = menuProps.Description,
				[Roact.Event.Activated] = function()
					self:setState({
						CurrentMenu = menuName,
						MenuElement = menuProps.Element
					})
				end
			})

			menuFrames[menuName] = newButton
		end

		local buttons = Roact.createFragment(menuFrames)

		local topBar = Roact.createElement(blankFrame, {
			Size = UDim2.new(1,-5,0,40),
			Position = UDim2.fromOffset(5,0)
		}, {
			Layout = uiLayout,
			Icon = iconImage,
			Buttons = buttons
		})

		local bottomFrame = Roact.createElement(blankFrame, {
			Size = UDim2.new(1, -10, 1, -45),
			AnchorPoint = Vector2.new(0.5,1),
			Position = UDim2.new(0.5, 0, 1, -5)
		}, {
			ActiveMenu = self.state.MenuElement
		})

		return Roact.createElement(blankFrame, {}, {
			TopPanel = topBar,
			BottomPanel = bottomFrame
		})
	end

end

function GUI:Init(props: {
		Plugin: any,
		OnDownload: (url: string) -> nil,
		OnBrowse: () -> nil,
		OnWallySearch: (rawText: string) -> {PackageDescription},
		OnWallyRow: (scope: string, name: string) -> PackageMetaData?,
		OnInit: () -> nil
	})

	--selene: allow(unused_variable)
	local toolbar, widget = createToolbar(props.Plugin)

	local menu = Roact.createElement(MenuComponent, {
		Menus = {
			Download = {
				Description = "Download",
				Image = IMPORT_ICON,
				ImagePadding = Vector2.new(5, 5),
				LayoutOrder = 2,
				Element = Roact.createElement(downloadMenu, {
					downloadCallback = props.OnDownload,
					browseCallback = props.OnBrowse
				})
			},
			["Search Wally"] = {
				Description = "Search Wally",
				Image = SEARCH_ICON,
				ImagePadding = Vector2.new(7, 7),
				LayoutOrder = 3,
				Element = Roact.createElement(SearchMenu, {
					searchCallback = props.OnWallySearch,
					rowCallback = props.OnWallyRow
				})
			},
			Settings = {
				Description = "Settings",
				Image = SETTINGS_ICON,
				ImagePadding = Vector2.new(0, 0),
				LayoutOrder = 4,
				Element = Roact.createElement(settingsMenu, {
					["Version"] = Version.Value,
				})
			}
		},
		Default = DEFAULT_MENU
	})

	local themedMenu = Roact.createElement(ThemeController, {}, {
		Menu = menu
	})

	Roact.mount(themedMenu, widget)

end

return GUI
