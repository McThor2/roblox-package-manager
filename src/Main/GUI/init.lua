
local StudioWidgets = require(script:WaitForChild("StudioWidgets"))
local WallyApi = require(script.Parent:WaitForChild("WallyApi"))
local Version = require(script.Parent:WaitForChild("Version"))
local Config = require(script.Parent:WaitForChild("Config"))
local Logging = require(script.Parent.Logging)
local Roact = require(script.Roact)

local GuiUtilities = StudioWidgets.GuiUtilities

type PackageDescription = WallyApi.PackageDescription
type PackageMetaData = WallyApi.PackageMetaData

local downloadCallback, wallyCallback

local GUI = {}

local WIDGET_TITLE = "RPM"

local ICON_ID = "rbxassetid://12457413905"

local WIDGET_DEFAULT_WIDTH = 375
local WIDGET_DEFAULT_HEIGHT = 200

local WIDGET_MIN_WIDTH = 375
local WIDGET_MIN_HEIGHT = 200

local DEFAULT_MENU = "Download"

local SETTINGS_ICON = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png"

local function blankFrame()
	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0)
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
		placeHolderText: string?,
		defaultText: string?
	})

	return Roact.createElement("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.X
	}, {
		TextBox = Roact.createElement("TextBox", {
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			AutomaticSize = true,
			Size = UDim2.fromScale(1, 1),
			PlaceholderText = props.placeHolderText or "",
			Text = props.defaultText or ""
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
		Position = UDim2.fromOffset(10,10),
		Size = UDim2.new(1, -140, 0, 20),
		placeHolderText = props.textBoxLabel,
		[Roact.Ref] = textRef
	})

	local button = Roact.createElement("TextButton", {
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1, -15, 0, 10),
		Size = UDim2.fromOffset(100, 20),
		TextSize = 15,
		Text = props.buttonText,
		[Roact.Event.Activated] = function()
			if props.callback then
				props.callback(textRef:getValue().Text)
			end
		end
	})

	return Roact.createElement(blankFrame, {
	}, {
		TextEntry = textEntry,
		Button = button
	})
end

local function menuButton(props)
	return Roact.createElement("ImageButton", {
		Image = props.Image,
		[Roact.Event.Activated] = props.OnActivated
	})
end

local ResultRow = {}
do
	ResultRow.__index = ResultRow
	
	local HIDDEN = "hidden"
	local SHOWN = "shown"
	local HEIGHT = 50
	
	function ResultRow.new(description: PackageDescription)

		local rootFrame = Instance.new("Frame")
		rootFrame.Size = UDim2.new(1, 0, 0, HEIGHT)
		--rootFrame.ZIndex = -1
		rootFrame.BackgroundTransparency = 1
		rootFrame.BorderSizePixel = 0

		local textButton = Instance.new("TextButton")
		textButton.Parent = rootFrame
		textButton.Size = UDim2.new(1, -25, 0, HEIGHT - 10)
		textButton.TextSize = 10
		textButton.ZIndex = 5
		textButton.AnchorPoint = Vector2.new(0.5,0.5)
		textButton.Position = UDim2.new(0.5, -8, 0, 0.5 * HEIGHT)
		textButton.TextXAlignment = Enum.TextXAlignment.Left
		textButton.Text = (
			" Scope: " .. description.scope .. "\n" ..
			" Name: " .. description.name --.. "\n" ..
			--"Versions: " .. HttpService:JSONEncode(description.versions)
		)
		
		StudioWidgets.GuiUtilities.syncGuiElementFontColor(textButton)
		StudioWidgets.GuiUtilities.syncGuiElementBackgroundColor(textButton)
		StudioWidgets.GuiUtilities.syncGuiElementBorderColor(textButton)
		
		local versionInfo = Instance.new("TextLabel")
		versionInfo.Parent = rootFrame
		versionInfo.Size = UDim2.new(1, -40, 1, -HEIGHT + 2)
		versionInfo.TextSize = 10
		versionInfo.Position = UDim2.new(0.5, 0, 1, 0)
		versionInfo.AnchorPoint = Vector2.new(0.5, 1)
		versionInfo.TextXAlignment = Enum.TextXAlignment.Left
		versionInfo.TextYAlignment = Enum.TextYAlignment.Top
		versionInfo.Text = " Loading ..."
		
		StudioWidgets.GuiUtilities.syncGuiElementFontColor(versionInfo)
		StudioWidgets.GuiUtilities.syncGuiElementBackgroundColor(versionInfo)
		StudioWidgets.GuiUtilities.syncGuiElementBorderColor(versionInfo)

		local self = {}
		setmetatable(self, ResultRow)
		self._button = textButton
		self._versionInfo = versionInfo
		self._detailsHeight = 10
		self.Frame = rootFrame
		self.Activated = textButton.Activated
		self.State = nil
		self.Description = description
		self.MetaData = nil
		self:HideDetails()
		
		self.Activated:Connect(function()
			self:_onActivated()
		end)
		
		return self
	end
	
	function ResultRow:ShowDetails()
		self.State = SHOWN
		
		self.Frame.Size = UDim2.new(1, 0, 0, HEIGHT + self._detailsHeight)
		self._versionInfo.Visible = true
	end
	
	function ResultRow:HideDetails()
		self.State = HIDDEN
		
		self._versionInfo.Visible = false
		self.Frame.Size = UDim2.new(1, 0, 0, HEIGHT)
	end
	
	function ResultRow:SetMetaData(newData: PackageMetaData)
		self.MetaData = newData
		
		local newText = " Versions:\n"
		
		local totalLines = 0
		for i, versionMetaData in newData.versions do
			local _version = versionMetaData.package.version
			
			newText ..= "  - " .. tostring(_version) .. "\n"
			totalLines = i
		end
		
		self._detailsHeight = (totalLines + 1) * 15
		
		self._versionInfo.Text = newText
		
		if self.State == SHOWN then
			self.Frame.Size = UDim2.new(1, 0, 0, HEIGHT + self._detailsHeight)
		end
	end
	
	function ResultRow:_onActivated()
		if self.State == SHOWN then
			return self:HideDetails()
		elseif self.State == HIDDEN then
			return self:ShowDetails()
		else
			error("unknown state: '" .. self.State .. "'")
		end
	end
	
end
export type ResultRow = typeof(ResultRow.new())

local SearchResults = {}
do
	SearchResults.__index = SearchResults

	local PADDING = 5

	function SearchResults.new()
	
		local rootFrame = Instance.new("ScrollingFrame")
		rootFrame.Size = UDim2.new(1,0,1,-40)
		rootFrame.AnchorPoint = Vector2.new(0.5, 1)
		rootFrame.Position = UDim2.fromScale(0.5, 1)
		rootFrame.BackgroundTransparency = 0.9
		rootFrame.BorderSizePixel = 1
		local shade = 40
		rootFrame.BorderColor3 = Color3.fromRGB(shade, shade, shade)
		rootFrame.CanvasSize = UDim2.fromOffset(0,0)
		rootFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

		local listLayout = Instance.new("UIListLayout")
		listLayout.Parent = rootFrame
		listLayout.Padding = UDim.new(0, PADDING)
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local self = {}
		setmetatable(self, SearchResults)
		self.Frame = rootFrame
		self.UILayout = listLayout

		return self
	end

end

local function downloadsMenu(props: {
		downloadCallback: ((url: string) -> nil)?,
		browseCallback: (() -> nil)?
	})

	local downloadEntry = Roact.createElement(searchEntry, {
		textBoxLabel = "<scope>/<name>@<version>",
		buttonText = "Download",
		callback = props.downloadCallback
	})

	local browseButton = Roact.createElement("TextButton", {
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

local function searchMenu(props: {
		searchCallback: (rawText: string) -> nil
	})

	local wallySearch = Roact.createElement(searchEntry, {
		textBoxLabel = "search...",
		buttonText = "Go",
		callback = props.searchCallback
	})
	--wallySearch.Parent = parentFrame

	local searchResults = SearchResults.new()
	searchResults.Frame.Parent = wallySearch

	GUI.SearchResults = searchResults

	return wallySearch
end

local function settingsMenu(props)

	local listLayout = Instance.new("UIListLayout")
	--listLayout.Parent = parentFrame

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.fromOffset(100, 20)
	versionLabel.BackgroundTransparency = 1
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Text = "Version: v" .. Version.Value
	versionLabel.LayoutOrder = 1
	--versionLabel.Parent = parentFrame
	GuiUtilities.syncGuiElementFontColor(versionLabel)

	local textFormat = "Packages Location: \"%s\""
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromOffset(100, 20)
	textLabel.Text = ""
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.LayoutOrder = 2

	--textLabel.Parent = parentFrame

	local serverTextFormat = "Server Packages Location: \"%s\""
	local serverTextLabel = Instance.new("TextLabel")
	serverTextLabel.Size = UDim2.fromOffset(100, 20)
	serverTextLabel.Text = ""
	serverTextLabel.BackgroundTransparency = 1
	serverTextLabel.TextXAlignment = Enum.TextXAlignment.Left
	serverTextLabel.LayoutOrder = 3

	--serverTextLabel.Parent = parentFrame

	local function update()
		local packageLocation = Config:GetPackageLocation()
		textLabel.Text = string.format(
			textFormat,
			packageLocation and Config:GetRawLocation(packageLocation)
			or " --- ")

		local serverLocation = Config:GetServerPackageLocation()
		serverTextLabel.Text = string.format(
			serverTextFormat,
			serverLocation and Config:GetRawLocation(serverLocation)
			or "---")
	end

	Config.Changed:Connect(update)
	update()

	GuiUtilities.syncGuiElementFontColor(textLabel)
	GuiUtilities.syncGuiElementFontColor(serverTextLabel)

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

			local newButton = Roact.createElement(menuButton, {
				LayoutOrder = menuProps.LayoutOrder,
				Image = menuProps.Image,
				OnActivated = function()
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
			BackgroundTransparency = 0
		}, {
			ActiveMenu = self.state.MenuElement
		})

		Logging:Debug(self.state.CurrentMenu)

		return Roact.createElement(blankFrame, {}, {
			TopPanel = topBar,
			BottomPanel = bottomFrame
		})
	end

end


function GUI:UpdateSearchResults(
	resultsData: {PackageDescription},
	rowCallback: (ResultRow) -> nil
	)
	
	if not self.SearchResults then
		return
	end
	
	local searchFrame = self.SearchResults.Frame
	
	for _, child in searchFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	for _, description in resultsData do
		local resultRow = ResultRow.new(description)
		resultRow.Frame.Parent = searchFrame
		resultRow.Activated:Connect(function()
			if rowCallback then
				rowCallback(resultRow)
			end
		end)
	end
	
end

function GUI:RegisterDownloadCallback(callback: (url: string) -> nil)
	downloadCallback = callback
end

function GUI:Init(props: {
		Plugin: any,
		OnDownload: (url: string) -> nil,
		OnBrowse: () -> nil,
		OnWallySearch: (rawText: string) -> nil
	})

	--selene: allow(unused_variable)
	local toolbar, widget = createToolbar(props.Plugin)

	local menu = Roact.createElement(MenuComponent, {
		Menus = {
			Download = {
				LayoutOrder = 2,
				Element = Roact.createElement(downloadsMenu, {
					downloadCallback = props.OnDownload,
					browseCallback = props.OnBrowse
				})
			},
			["Search Wally"] = {
				LayoutOrder = 3,
				Element = Roact.createElement(searchMenu, {
					searchCallback = props.OnWallySearch
				})
			},
			Settings = {
				LayoutOrder = 4,
				Element = Roact.createElement(settingsMenu)
			}
		},
		Default = DEFAULT_MENU
	})

	local app = Roact.createElement(blankFrame, nil, {
		Menu = menu
	})

	Roact.mount(app, widget)

end

return GUI
