
local StudioWidgets = require(script:WaitForChild("StudioWidgets"))
local WallyApi = require(script.Parent:WaitForChild("WallyApi"))
local Version = require(script.Parent:WaitForChild("Version"))
local Config = require(script.Parent:WaitForChild("Config"))

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

local function blankFrame()
	local rootFrame = Instance.new("Frame")
	rootFrame.BackgroundTransparency = 1
	rootFrame.BorderSizePixel = 0
	rootFrame.Size = UDim2.fromScale(1,1)
	rootFrame.Position = UDim2.fromScale(0,0)
	return rootFrame
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

local function createSearchEntry(
	textBoxLabel: string, 
	buttonText: string,
	callback: (text: string) -> nil)
	
	local rootFrame = blankFrame()
	
	local textEntry = StudioWidgets.ScrollingTextInput.new(textBoxLabel)
	local frame = textEntry:GetFrame()
	frame.Parent = rootFrame
	frame.Position = UDim2.fromOffset(10,10)
	frame.Size = UDim2.new(1, -140, 0, 20)
	
	local box = textEntry:GetTextBox()
	box.TextXAlignment = Enum.TextXAlignment.Left

	textEntry:GetTextBox().ClearTextOnFocus = false

	local textButton = StudioWidgets.CustomTextButton.new(
		"Search Button", 
		buttonText, 
		15
	)
	local button = textButton:GetButton()
	button.Parent = rootFrame
	button.AnchorPoint = Vector2.new(1,0)
	button.Position = UDim2.new(1, -15, 0, 10)
	button.Size = UDim2.fromOffset(100, 20)

	button.Activated:Connect(function()
		if callback then
			callback(textEntry:GetValue())
		end
	end)
	
	return rootFrame
end

local function onMenuButton(rootFrame, menuFrames, menuName)
	return function()
		local activeFrame = menuFrames[menuName]
		activeFrame.Parent = rootFrame

		for name, frame in pairs(menuFrames) do
			if name == menuName then continue end

			frame.Parent = nil
		end
	end
end

local function createMenuBar(buttonTexts: {string}, menuParentFrame: Frame)
	
	local rootFrame = blankFrame()
	rootFrame.AnchorPoint = Vector2.new(0.5,0.5)
	rootFrame.Position = UDim2.fromScale(0.5,0.5)
	rootFrame.Size = UDim2.new(1, -10, 1)

	local iconImage = Instance.new("ImageLabel")
	iconImage.Image = ICON_ID
	iconImage.Size = UDim2.new(0, 50, 1, -5)
	iconImage.BackgroundTransparency = 1
	iconImage.Parent = rootFrame

	local iconAspectRatio = Instance.new("UIAspectRatioConstraint")
	iconAspectRatio.AspectRatio = 1
	iconAspectRatio.AspectType = Enum.AspectType.ScaleWithParentSize
	iconAspectRatio.DominantAxis = Enum.DominantAxis.Height
	iconAspectRatio.Parent = iconImage
	
	local uiLayout = Instance.new("UIListLayout")
	uiLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	uiLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	uiLayout.Padding = UDim.new(0, 10)
	uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiLayout.FillDirection = Enum.FillDirection.Horizontal
	uiLayout.Parent = rootFrame

	local menuFrames = {}
	for order, buttonName in ipairs(buttonTexts) do
		local manualButton = StudioWidgets.CustomTextButton.new(
			"MenuButton" .. tostring(order + 1),
			buttonName,
			18
		)
		local button = manualButton:GetButton()
		button.Parent = rootFrame
		button.Size = UDim2.new(0, 100, 1, -10)
		button.LayoutOrder = order
		button.Activated:Connect(
			onMenuButton(
				menuParentFrame,
				menuFrames,
				buttonName
			)
		)

		menuFrames[buttonName] = blankFrame()
	end
	
	return rootFrame, menuFrames
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

local function mountDownloadsMenu(parentFrame: Frame)
	local downloadFrame = createSearchEntry(
		"<scope>/<name>@<version>",
		"Download",
		function(url)
			if downloadCallback then
				downloadCallback(url)
			end
		end
	)
	downloadFrame.Parent = parentFrame
end

local function mountSearchMenu(parentFrame: Frame)
	local wallySearch = createSearchEntry(
		"search...",
		"Go",
		function(text)
			if wallyCallback then
				wallyCallback(text)
			end
		end
	)
	wallySearch.Parent = parentFrame

	local searchResults = SearchResults.new()
	searchResults.Frame.Parent = wallySearch
	
	GUI.SearchResults = searchResults
end

local function mountSettingsMenu(parentFrame: Frame)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent = parentFrame

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.fromOffset(100, 20)
	versionLabel.BackgroundTransparency = 1
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Text = "Version: v" .. Version.Value
	versionLabel.LayoutOrder = 1
	versionLabel.Parent = parentFrame
	GuiUtilities.syncGuiElementFontColor(versionLabel)

	local textFormat = "Packages Location: %s"
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromOffset(100, 20)
	textLabel.Text = ""
	textLabel.BackgroundTransparency = 1
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.LayoutOrder = 2

	textLabel.Parent = parentFrame

	local function update()
		local packageLocation = Config:GetPackageLocation()
		textLabel.Text = string.format(
			textFormat,
			packageLocation and packageLocation:GetFullName()
			or " --- ")
	end

	Config.Changed:Connect(update)
	update()

	GuiUtilities.syncGuiElementFontColor(textLabel)

end

function GUI:RegisterWallySearch(callback)
	wallyCallback = callback
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

function GUI:Init(plugin)

	--selene: allow(unused_variable)
	local toolbar, widget = createToolbar(plugin)

	local topFrame = blankFrame()
	topFrame.Size = UDim2.new(1,0,0,40)
	topFrame.Position = UDim2.fromScale(0,0)
	
	topFrame.Parent = widget
	
	local bottomFrame = blankFrame()
	bottomFrame.Size = UDim2.new(1, -10, 1, -45)
	bottomFrame.AnchorPoint = Vector2.new(0.5,1)
	bottomFrame.Position = UDim2.new(0.5, 0, 1, -5)
	bottomFrame.BackgroundTransparency = 0
	
	StudioWidgets.GuiUtilities.syncGuiElementBackgroundColor(bottomFrame)
	
	bottomFrame.Parent = widget
	
	local menuFrame, menuFrames = createMenuBar(
		{
			"Download",
			"Search Wally",
			"Settings"
		},
		bottomFrame
	)
	menuFrame.Parent = topFrame

	mountDownloadsMenu(menuFrames["Download"])
	mountSearchMenu(menuFrames["Search Wally"])
	mountSettingsMenu(menuFrames["Settings"])

	local defaultFrame = menuFrames[DEFAULT_MENU]
	defaultFrame.Parent = bottomFrame
end

return GUI
