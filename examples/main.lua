-- TextRender example
--
-- Shows use of the textrender widget
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2015 David Gross. 
-- Copyright (C) 2014 David McCuskey. 
--====================================================================--
--[[
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in the
Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
--]]




--[[
	Demonstration of textrender.lua, a module for rendering styled text.


	textrender parameters:

	text = text to render
	font = font name, e.g. "AvenirNext-DemiBoldItalic"
	size = font size in pixels
	lineHeight = line height in pixels
	color = text color in an RGBa color table, e.g. {250, 0, 0, 255}
	width = Width of the text column,
	alignment = text alignment: "Left", "Right", "Center"
	opacity = text opacity (between 0 and 1, or as a percent, e.g. "50%" or 0.5
	minCharCount = Minimum number of characters per line. Estimate low, e.g. 5
	targetDeviceScreenSize = String of target screen size, in the form, "width,height", e.g. e.g. "1024,768".  May be different from current screen size.
	letterspacing = (unused)
	maxHeight = Maximum height of the text column. Extra text will be hidden.
	minWordLen = Minimum length of a word shown at the end of a line. In good typesetting, we don't end our lines with single letter words like "a", so normally this value is 2.
	textstyles = A table of text styles, loaded using funx.loadTextStyles()
	defaultStyle = The name of the default text style for the text block
	cacheDir = the name of the cache folder to use inside system.CachesDirectory, e.g. "text_render_cache"
--]]


-- Run test for cache speed by drawing/redrawing
local testCacheSpeed = false

-- My useful function collection
local funx = require("scripts.funx")

local textrender = require("scripts.textrender.textrender")

-- Make a local copy of the application settings global
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -	 display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
local midscreenX = screenW*(0.5)
local midscreenY = screenH*(0.5)

local textStyles = funx.loadTextStyles("assets/textstyles.txt", system.ResourceDirectory)

local mytext = funx.readFile("assets/text-render-sample.html")

-- To cache using files, set the cache directory
-- Not recommended, as it is slower than using SQLite
local cacheDir = "textrender_cache"
funx.mkdir (cacheDir, "",false, system.CachesDirectory)

local navbarHeight = 50

--===================================================================--
-- Page background
--===================================================================--
local bkgd = display.newRect(0,0,screenW, screenH)
bkgd:setFillColor(.9,.9,.9)
funx.anchor(bkgd,"TopLeftReferencePoint")
bkgd.x = 0
bkgd.y = 0
bkgd.strokeWidth = 0
bkgd:setStrokeColor(.2, .2, .2, 1)


--===================================================================--
-- Build a scrolling text field.
--===================================================================--

local width, height = display.contentWidth * .8, (display.contentHeight * .8) - 40
local x,y = 20, (display.contentHeight - height)/2

--===================================================================--
-- Background Rectangle
local strokeWidth = 1
local padding = 0
local textblockBkgd = display.newRect(x - strokeWidth - padding , y - strokeWidth - padding, width + strokeWidth + 2*padding, height + strokeWidth + 2*padding)
textblockBkgd:setFillColor( 1,1,1 )
funx.anchor(textblockBkgd,"TopLeftReferencePoint")
textblockBkgd.x = x - padding
textblockBkgd.y = y - padding
textblockBkgd.strokeWidth = strokeWidth
textblockBkgd:setStrokeColor( 0,0,0,0.3)

--===================================================================--
textrender.clearAllCaches(cacheDir)


local msgblock = display.newGroup()
msgblock.x = x - padding
msgblock.y = y - 40

local function removeMsgBlock()
	if (msgblock) then
		msgblock:removeSelf()
		msgblock = nil
	end
end

local function hyperlinkdemo( e )

	local mytext = "<p style='font:Avenir;size:18px;'><i>A <u>hyperlink</u> was tapped! The text is <i><b>“" .. e.target._attr.text .. "”</b></p>"

	local params = {
		text =  mytext,	--loaded above
		width = width,
		maxHeight = 0,	-- Set to zero, otherwise rendering STOPS after this amount!
		isHTML = true,
		}

	-- Clear existing message block
	removeMsgBlock()
	-- Create the message
	msgblock = textrender.autoWrappedText(params)
	msgblock.x = x - padding
	msgblock.y = y - 40
	
	timer.performWithDelay( 3000, removeMsgBlock )
end

--===================================================================--
-- Text Field
local params = {
	text =  mytext,	--loaded above
	
	width = width,
	maxHeight = 0,	-- Set to zero, otherwise rendering STOPS after this amount!

	isHTML = true,
	useHTMLSpacing = true,
	
	textstyles = textStyles,

	-- Not needed, but defaults
	font = "AvenirNext-Regular",
	size = "12",
	lineHeight = "16",
	color = {0, 0, 0, 255},
	alignment = "Left",
	opacity = "100%",
	letterspacing = 0,
	defaultStyle = "Normal",

	-- The higher these are, the faster a row is wrapped
	minCharCount = 10,	-- 	Minimum number of characters per line. Start low. Default is 5
	minWordLen = 2,
	
	-- not necessary, might not even work
	targetDeviceScreenSize = screenW..","..screenH,	-- Target screen size, may be different from current screen size
	
	-- The handler is the function executed when a hyperlink is tapped.
	-- It will get the HREF from the <a> tag.
	handler = hyperlinkdemo,
	
	-- cacheDir is empty so we do not use caching with files, instead we use the SQLite database
	-- which is faster.
	cacheDir = nil,
	cacheToDB = true,	-- true is default, for fast caches using sql database
}

local textblock = textrender.autoWrappedText(params)



--===================================================================--
-- Make the textblock a scrolling text block
local options = {
	maxVisibleHeight = height,
	parentTouchObject = nil,
	
	hideBackground = true,
	backgroundColor = {1,1,1},	-- hidden by the above line
	
	-- Show an icon over scrolling fields: values are "over", "bottom", anything else otherwise defaults to top+bottom
	scrollingFieldIndicatorActive = true,
	-- "over", "bottom", else top and bottom
	scrollingFieldIndicatorLocation = "",
	-- image files
	scrollingFieldIndicatorIconOver = "scripts/textrender/assets/scrolling-indicator-1024.png",
	scrollingFieldIndicatorIconDown = "scripts/textrender/assets/scrollingfieldindicatoricon-down.png",
	scrollingFieldIndicatorIconUp = "scripts/textrender/assets/scrollingfieldindicatoricon-up.png",
	pageItemsFadeOutOpeningTime = 300,
	pageItemsFadeInOpeningTime = 500,
	pageItemsPrefadeOnOpeningTime = 500,

}

local textblock = textblock:fitBlockToHeight( options )
local yAdjustment = textblock.yAdjustment
textblock.x = x
textblock.y = y

if (testCacheSpeed) then
	-- Remove for testing below, but now it is cached
	textblock:removeSelf()

	local startTime = system.getTimer()
	local doCache = true
	local n = 10
	print ("Repeat textrender for "..n.." times.")
	if (doCache) then
		print ("( using Caching )")
	end

	for i = 1, n do

		print ("textrender #"..i )

		-- Build
		params.cacheToDB = doCache
		textblock = textrender.autoWrappedText(params)

		local textblock = textblock:fitBlockToHeight( options )
		local yAdjustment = textblock.yAdjustment
		textblock.x = x
		textblock.y = y

		-- Remove
		textblock:removeSelf()
	
		if (not doCache) then
			print ("Clear caches.")
			textrender.clearAllCaches(cacheDir)
		end

	end
	local totalTime = math.floor((system.getTimer() - startTime) * 100) / 100
	print ("Time for "..n.." repetitions: ".. totalTime  .. " milliseconds, average speed is " .. totalTime/n .. " milliseconds")


	textblock = textrender.autoWrappedText(params)

	local textblock = textblock:fitBlockToHeight( options )
	local yAdjustment = textblock.yAdjustment
	textblock.x = x
	textblock.y = y
end -- test cache speed

--===================================================================--
-- Testing buttons

local buttonX = screenW - 120
local buttonY = 60


local wf = false
local function toggleWireframe()
	wf = not wf
	display.setDrawMode( "wireframe", wf )
	if (not wf) then
		display.setDrawMode( "forceRender" )
	end
	print ("WF = ",wf)
end

local widget = require ("widget")
local wfb = widget.newButton{
			label = "Wireframe",
			labelColor = { default={ 0,0,0 }, over={ 1, 0, 0, 0.5 } },
			fontSize = 20,
			x =buttonX,
			y=buttonY,
			shape = "roundedRect",
			fillColor = { default={ .7,.7,.7 }, over={ .2, .2, .2 } },
			onRelease = toggleWireframe,
		}
wfb:toFront()
