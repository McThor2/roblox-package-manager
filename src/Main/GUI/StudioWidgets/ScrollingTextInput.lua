
local TextService = game:GetService("TextService")

local GuiUtilities = require(script.Parent.GuiUtilities)

local ScrollingTextInput = {}
ScrollingTextInput.__index = ScrollingTextInput

function ScrollingTextInput.new(defaultText: string)
	
	local self = {}
	setmetatable(self, ScrollingTextInput)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(150, 20)
	frame.BackgroundTransparency = 1
	self._frame = frame

	local scrollingFrame = Instance.new("ScrollingFrame", frame)
	scrollingFrame.ScrollBarThickness = 0
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.X
	scrollingFrame.CanvasSize = UDim2.new(1,0,1,0)
	scrollingFrame.Size = UDim2.fromScale(1,1)
	
	GuiUtilities.syncGuiElementBackgroundColor(scrollingFrame)
	GuiUtilities.syncGuiElementBorderColor(scrollingFrame)
	
	self._scrollingFrame = scrollingFrame
	
	local textBox = Instance.new("TextBox", scrollingFrame)
	textBox.AnchorPoint = Vector2.new(0.5,0.5)
	textBox.Size = UDim2.new(1,-10,1,-5)
	textBox.Position = UDim2.fromScale(0.5,0.5)
	textBox.BackgroundTransparency = 1
	textBox.BorderSizePixel = 0
	textBox.PlaceholderText = defaultText
	textBox.Text = ""
	
	GuiUtilities.syncGuiElementInputFieldColor(textBox)
	GuiUtilities.syncGuiElementFontColor(textBox)
	
	self._textBox = textBox
	
	local textBoundsSignal = textBox:GetPropertyChangedSignal("TextBounds")
	local cursorPosSignal = textBox:GetPropertyChangedSignal("CursorPosition")
	local textChangedSignal = textBox:GetPropertyChangedSignal("Text")
	
	textBoundsSignal:Connect(function() self:_updateCanvasSize() end)
	textBoundsSignal:Connect(function() self:_updateCanvasPosition() end)
	cursorPosSignal:Connect(function() self:_updateCanvasPosition() end)
	textChangedSignal:Connect(function() self:_textUpdated() end)

	self:_updateCanvasSize()
	self:_updateCanvasPosition()
	
	return self
end

function ScrollingTextInput:_getTextSize(text: string)
	return TextService:GetTextSize(
		text, 
		self._textBox.TextSize, 
		self._textBox.Font, 
		Vector2.new(1_000, 200)
	)
end

function ScrollingTextInput:_updateCanvasSize()
	self._scrollingFrame.CanvasSize = UDim2.new(
		0,
		math.max(self._scrollingFrame.AbsoluteSize.X, self._textBox.TextBounds.X + 15),
		1,
		0
	)
end

function ScrollingTextInput:_updateCanvasPosition()

	local cursorPos = self._textBox.CursorPosition
	
	if cursorPos == -1 then
		return
	end
	
	local textBounds = self._textBox.TextBounds

	if self._textBox.TextBounds.X < self._scrollingFrame.AbsoluteSize.X then
		return
	end

	-- Check if cursor is within visible region

	local leftString = string.sub(self._textBox.Text, 1, cursorPos-1)
	local leftSize = self:_getTextSize(leftString)

	local xOffset = leftSize.X - self._scrollingFrame.CanvasPosition.X

	local isVisible = (
		0 < xOffset and
			xOffset < self._scrollingFrame.AbsoluteSize.X - 5
	)

	local delta = xOffset > 0 and xOffset - self._scrollingFrame.AbsoluteSize.X + 15  or xOffset

	if not isVisible then
		self._scrollingFrame.CanvasPosition = Vector2.new(
			self._scrollingFrame.CanvasPosition.X + delta, 
			0
		)
	end

end

function ScrollingTextInput:_textUpdated()
	if self._valueChangedFunction then
		self._valueChangedFunction(self._textBox.Text)
	end
end

function ScrollingTextInput:GetFrame()
	return self._frame
end

function ScrollingTextInput:GetTextBox()
	return self._textBox
end

function ScrollingTextInput:SetValueChangedFunction(callback)
	self._valueChangedFunction = callback
end

function ScrollingTextInput:GetValue()
	return self._textBox.Text
end

return ScrollingTextInput
