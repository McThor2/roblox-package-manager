
local WallyApi = require(script.Parent:WaitForChild("WallyApi"))
local Version = require(script.Parent:WaitForChild("Version"))
local Config = require(script.Parent:WaitForChild("Config"))
local Logging = require(script.Parent.Logging)
local Roact = require(script.Roact)

type PackageDescription = WallyApi.PackageDescription
type PackageMetaData = WallyApi.PackageMetaData

local GUI = {}

local WIDGET_TITLE = "RPM"

local ICON_ID = "rbxassetid://12457413905"

local WIDGET_DEFAULT_WIDTH = 375
local WIDGET_DEFAULT_HEIGHT = 200

local WIDGET_MIN_WIDTH = 375
local WIDGET_MIN_HEIGHT = 200

local DEFAULT_MENU = "Download"

local SETTINGS_ICON = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png"

local function blankFrame(props)

	local defaultProps = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1)
	}

	for k, v in defaultProps do
		if props[k] then continue end
		props[k] = v
	end

	return Roact.createElement("Frame", props)
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

local openEvent = Instance.new("BindableEvent")
GUI.Opened = openEvent.Event

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

	local widget = plugin:CreateDockWidgetPluginGui(WIDGET_TITLE, widgetInfo)
	widget.Title = WIDGET_TITLE

	local button = toolbar:CreateButton("Open RPM GUI", "Opens the Roblox Package Manager GUI", ICON_ID)
	button.ClickableWhenViewportHidden = true

	local function openGui()
		if not widget.Enabled then
			openEvent:Fire()
		end
		widget.Enabled = true
	end

	button.Click:Connect(openGui)

	return toolbar, widget
end

local function scrollingTextInput(props: {
		Position: UDim2,
		Size: UDim2,
		placeHolderText: string?,
		defaultText: string?,
		[Roact.Ref]: Roact.Ref
	})

	return Roact.createElement("ScrollingFrame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(46, 46, 46),
		BorderSizePixel = 1,
		BorderColor3 = Color3.fromRGB(34, 34, 34),
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Size = props.Size,
		Position = props.Position
	}, {
		TextBox = Roact.createElement("TextBox", {
			PlaceholderText = props.placeHolderText or "",
			Text = props.defaultText or "",

			PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
			TextColor3 = Color3.fromRGB(204, 204, 204),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(1, 1),
			[Roact.Ref] = props[Roact.Ref]
		})
	})
end

local function searchEntry(props: {
		textBoxLabel: string,
		buttonText: string,
		callback: (text: string) -> nil
	})

	local textRef = Roact.createRef()

	local textEntry = Roact.createElement(scrollingTextInput, {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -140, 0, 20),
		placeHolderText = props.textBoxLabel,
		[Roact.Ref] = textRef
	})

	local button = Roact.createElement(customTextButton, {
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1, -15, 0, 10),
		Size = UDim2.fromOffset(100, 20),
		Text = props.buttonText,
		TextSize = 15,
		[Roact.Event.Activated] = function()
			if props.callback then
				props.callback(textRef:getValue().Text)
			end
		end
	})

	return Roact.createElement(blankFrame, {
		Size = UDim2.new(1, 0, 0, 20)
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
		callback = props.downloadCallback
	})

	local browseButton = Roact.createElement(customTextButton, {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 150, 0, 20),
		Position = UDim2.new(0.5, 0, 0, 35),
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
			end
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
		SharedLocation: string,
		ServerLocation: string
	})

	local listLayout = Roact.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder
	})

	local textColour = Color3.fromRGB(204, 204, 204)

	local versionLabel = Roact.createElement("TextLabel", {
		Size = UDim2.fromOffset(100, 20),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `Version: v{props.Version}`,
		TextColor3 = textColour,
		LayoutOrder = 1
	})

	local textLabel = Roact.createElement("TextLabel", {
		Size = UDim2.fromOffset(100, 20),
		Text = `Packages Location: "{props.SharedLocation}"`,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = textColour,
		LayoutOrder = 2
	})

	local serverTextLabel = Roact.createElement("TextLabel", {
		Size = UDim2.fromOffset(100, 20),
		Text = `Server Packages Location: "{props.ServerLocation}"`,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = textColour,
		LayoutOrder = 3
	})

	return Roact.createFragment({
		Layout = listLayout,
		VersionLabel = versionLabel,
		PackageLabel = textLabel,
		ServerPackageLabel = serverTextLabel
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

			local newButton = Roact.createElement(customTextButton, {
				Size = UDim2.new(0, 100, 1, -10),
				LayoutOrder = menuProps.LayoutOrder,
				Text = menuProps.Text,
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
			Size = UDim2.new(1,0,0,40),
			Position = UDim2.fromScale(0,0)
		}, {
			Layout = uiLayout,
			Icon = iconImage,
			Buttons = buttons
		})

		local bottomFrame = Roact.createElement(blankFrame, {
			Size = UDim2.new(1, -10, 1, -45),
			AnchorPoint = Vector2.new(0.5,1),
			Position = UDim2.new(0.5, 0, 1, -5),
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
		OnWallyRow: (scope: string, name: string) -> PackageMetaData?
	})

	--selene: allow(unused_variable)
	local toolbar, widget = createToolbar(props.Plugin)

	local packageLocation = Config:GetPackageLocation()
	local serverPackageLocation = Config:GetServerPackageLocation()

	local menu = Roact.createElement(MenuComponent, {
		Menus = {
			Download = {
				Text = "Download",
				LayoutOrder = 2,
				Element = Roact.createElement(downloadMenu, {
					downloadCallback = props.OnDownload,
					browseCallback = props.OnBrowse
				})
			},
			["Search Wally"] = {
				Text = "Search Wally",
				LayoutOrder = 3,
				Element = Roact.createElement(SearchMenu, {
					searchCallback = props.OnWallySearch,
					rowCallback = props.OnWallyRow
				})
			},
			Settings = {
				Text = "Settings",
				LayoutOrder = 4,
				Element = Roact.createElement(settingsMenu, {
					["Version"] = Version.Value,
					SharedLocation = Config:GetRawLocation(packageLocation),
					ServerLocation = Config:GetRawLocation(serverPackageLocation)
				})
			}
		},
		Default = DEFAULT_MENU
	})



	Roact.mount(menu, widget)

end

return GUI
