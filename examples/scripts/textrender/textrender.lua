-- textrender.lua
--
-- Version 3.1.1
--
-- Copyright (C) 2015 David I. Gross. All Rights Reserved.
--
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

--
--[[
	This version renders lines of text, then aligns them left/right/center. The previous version
	could not do this with sub-elements in a block, e.g. 
		<p>my text <span>is cool</span> but not hot.</p>
	would have failed.

--]]
--[[

	Create a block text, wrapped to fit a rectangular boundary.
	Formats text using basic HTML.
	@return 	textblock	A display group containing the wrapped text.



	Pass params in a table, e.g. options = { ... }
	Inside of the options table:
	@param	hyperlinkFillColor	An RGBa string, e.g. "150,200,120,50", of the color for a box around the hyperlinks.
	@param	hyperlinkTextColor	An RGBa string, e.g. "150,200,120,50", of the color for hyperlink text.


]]
--display.setDrawMode( "wireframe", false )
-- TESTING
-- Check the GLOBAL testing variable
local testing = _TESTING
local noCache = _NOCACHE


if (testing) then
	print ("**** WARNING: textrender: TESTING ON ****")
end

if (noCache) then
	print ("**** WARNING: textrender: CACHING TURNED OFF FOR TESTING!!!! ****")
end

-- Main var for this module
local T = {}

local pathToModule = "scripts/textrender/"
T.path = pathToModule

-- funx must be installed in scripts folder
local funx = require ("scripts.funx")

local html = require ("scripts.textrender.html")
local entities = require ("scripts.textrender.entities")
local fontMetricsLib = require("scripts.textrender.fontmetrics")

local sqlite3 = require ( "sqlite3" )
local json = require( "json" )
local crypto = require ( "crypto" )
local widget = require( "widget" )


-- functions
local abs = math.abs
local ceil = math.ceil
local find = string.find
local floor = math.floor
local gfind = string.gfind
local gmatch = string.gmatch
local gsub = string.gsub
local lower = string.lower
local max = math.max
local min = math.min
local strlen = string.len
local substring = string.sub
local upper = string.upper



-- shortcuts to my functions
local anchor = funx.anchor
local anchorZero = funx.anchorZero
local trim = funx.trim
local rtrim = funx.rtrim
local ltrim = funx.ltrim
local stringToColorTable = funx.stringToColorTable
local setFillColorFromString = funx.setFillColorFromString
local split = funx.split
local setCase = funx.setCase
local fixCapsForReferencePoint = funx.fixCapsForReferencePoint
local isPercent = funx.isPercent
local loadImageFile = funx.loadImageFile
local applyPercent = funx.applyPercent

-- Set the width/height of screen. Might have changed from when module loaded due to orientation change
local screenW, screenH = display.contentWidth, display.contentHeight


-- Useful constants
local OPAQUE = 255
local TRANSPARENT = 0

-- Be sure a caches dir is set up inside the system caches
local textWrapCacheDir = "textwrap"
--funx.mkdir (textWrapCacheDir, "",false, system.CachesDirectory)


-- testing function
local function showTestLine(group, y, isFirstTextInBlock, i)
	local q = display.newLine(group, 0,y,200,y)
	i = i or 1
	if (isFirstTextInBlock) then
		q:setStrokeColor(100,250,0)
	else
		q:setStrokeColor(80 * i,80 * i, 80)
	end
	q.strokeWidth = 2
end



-- Use "." at the beginning of a line to add spaces before it.
local usePeriodsForLineBeginnings = false

-------------------------------------------------
-- font metrics module, for knowing text heights and baselines
-- variations, for knowing the names of font variations, e.g. italic
-- Corona doesn't do this so we must.
-------------------------------------------------
local fontMetrics = fontMetricsLib.new()
local fontFaces = fontMetrics.metrics.variations or {}


-------------------------------------------------
-- HTML/XML tags that are inline tags, e.g. <b>
-- This table can be used to check if a tag is an inline tag:
-- if (inline[tag]) then...
-------------------------------------------------
--[[
local inline = {
	a = true,
	abbr = true,
	acronym = true,
	applet = true,
	b = true,
	basefont = true,
	bdo = true,
	big = true,
	br = true,
	button = true,
	cite = true,
	code = true,
	dfn = true,
	em = true,
	font = true,
	i = true,
	iframe = true,
	img = true,
	input = true,
	kbd = true,
	label = true,
	map = true,
	object = true,
	q = true,
	s = true,
	samp = true,
	select = true,
	small = true,
	span = true,
	strike = true,
	strong = true,
	sub = true,
	sup = true,
	textarea = true,
	tt = true,
	u = true,
	var = true,
}
--]]

local isBlockTag = {
	address = true,
	blockquote = true,
	center = true,
	dir = true, div = true, dl = true,
	fieldset = true, form = true,
	h1 = true, h2 = true, h3 = true, h4 = true, h5 = true, h6 = true, 
	hr = true,
	isindex = true,
	-- Note, we treat <li> as a block, which is not standard HTML
	li = true,
	menu = true,
	noframes = true,
	ol = true,
	p = true,
	pre = true,
	table = true,
	ul = true,
}

local isListTag = {
	ol = true,
	ul = true,
}

--------------------------------------------------------
-- Common functions redefined for speed
--------------------------------------------------------


--------------------------------------------------------
-- Convert CSS relational font sizings to percent
-- e.g. x-large = 150%
-- Return the new font size based on the one give
-- If no keyword found, then return current fontsize
-- Source: http://www.trishasdesignstudio.com/font-size-conversion-chart.asp
local function keywordFontsizeRatio (keyword)
	local sizes = {
		xxsmall	= 0.55,
		xsmall	= 0.625,
		small 	= 0.8,
		medium 	= 1,
		large	= 1.2,
		xlarge	= 1.5,
		xxlarge	= 2.55,
	}
	return (sizes[lower(keyword:gsub("%-",""))] or 1)
end


local function convertCSSFontsizeKeyword(keyword, fontsize)
	fontsize = fontsize or 14	-- default to 14px if something goes wrong
	return fontsize * keywordFontsizeRatio(keyword)
end

--------------------------------------------------------
-- Convert pt values to pixels, for font sizing.
-- We use the font height for 1em.
-- Basically, I think we should just use the pt sizing as
-- px sizing. Or, we could use the screen pixel sizing?
-- We could use funx.getDeviceMetrics()
-- Using 72 pixels per point:
-- 12pt => 72/72  * 12pt => 12px
-- 12pt => 132/72 * 12pt => 24px
-- @param t = [string] The new font size, including units or as text, e.g. 'small'
-- @param fontsize = [number] Fallback font-size, usually whatever it current is before we try to change it
--------------------------------------------------------
local function convertValuesToPixels (t, fontsizeFallback, deviceMetrics)
	if (t ~= nil) then
		t = trim(t)
		-- Get the numeric part of the size, e.g. 15pt -> 15
		local _, _, n = find(t, "^(%--%d+)")
		-- Get the units, e.g. pt or px, e.g. 15pt -> pt
		local _, _, u = find(t, "(%a%a)$")
		
		-- Handle textual fontsizing, e.g. "x-large"
--print ("A -----> ", t, fontsizeFallback)
		n = convertCSSFontsizeKeyword(t, n)
--print ("B -----> ", t, n)
		
		if (tonumber(n) == 0) then
			n = fontsizeFallback
		end
	
		if ((u == "pt" ) and deviceMetrics) then
			n = n * (deviceMetrics.ppi/72)
		elseif (u == "em" and deviceMetrics) then
			n = n * fontsize * (deviceMetrics.ppi/72)
		end
--print ("C Result:",n)
--print ("  ")
		return tonumber(n)
	end
end


--------------------------------------------------------
-- Trim based on alignment
--------------------------------------------------------
local function trimToAlignment(t,a)
	if (a == "Right") then
		t = rtrim(t)
	elseif (a == "Center") then
		t = trim(t)
	else
		t = ltrim(t)
	end
	return t
end

--------------------------------------------------------
-- Get tag formatting values
--------------------------------------------------------
local function getTagFormatting(fontFaces, tag, currentfont, variation, attr)
	local font, basename
			------------
			-- If the fontfaces list has our font transformation, use it,
			-- otherwise try to figure it out.
			------------
			local function getFontFace (basefont, variation)
				local newFont = ""

				if (fontFaces[basefont .. variation]) then
					newFont = fontFaces[basefont .. variation]
				else
					-- Some name transformations...
					-- -Roman becomes -Italic or -Bold or -BoldItalic
					newFont = basefont:gsub("-Roman","") .. variation
				end
				return newFont
			end
			------------

	if (type(currentfont) ~= "string") then
		return {}
	end
	
	local basefont = gsub(currentfont, "%-.*$","")
	--local _,_,variation = find(currentfont, "%-(.-)$")
	variation = variation or ""
	local format = {}
	if (tag == "em" or tag == "i") then
		if (variation == "Bold" or variation == "BoldItalic") then
			format.font = getFontFace (basefont, "-BoldItalic")
			format.fontvariation = "BoldItalic"
		else
			format.font = getFontFace (basefont, "-Italic")
			format.fontvariation = "Italic"
--print (basefont, format.font)
		end
	elseif (tag == "strong" or tag == "b") then
		if (variation == "Italic" or variation == "BoldItalic") then
			format.font = getFontFace (basefont, "-BoldItalic")
			format.fontvariation = "BoldItalic"
		else
			format.font = getFontFace (basefont, "-Bold")
			format.fontvariation = "Bold"
		end
	elseif (tag == "font" and attr) then
		format = attr
		format.font = attr.name
		--format.basename = attr.name
	elseif ( tag == "sup") then
		format.scale = "70%"
		format.yOffset = "50%"
	elseif ( tag == "sub") then
		format.scale = "70%"
		format.yOffset = "-10%"
	elseif (attr) then
		-- get style info
		local style = {}
		local p = split(attr.style, ";", true) or {}
		for i,j in pairs( p ) do
			local c = split(j,":",true)
			if (c[1] and c[2]) then
				style[c[1]] = c[2]
			end
		end
		format = funx.tableMerge(attr, style)
		--format.basename = attr.font
	end

	return format

end



--------------------------------------------------------
-- Break text into paragraphs using <p>
-- Any carriage returns inside any element is remove!
local function breakTextIntoParagraphs(text)

	-- remove CR inside of <p>
	local count = 1
	while (count > 0) do
		text, count = text:gsub("(%<.-)%s*[\r\n]%s*(.-<%/.->)","%1 %2")
	end

	text = text:gsub("%<p(.-)%>","<p%1>\r")
	text = text:gsub("%<%/p%>","</p>\r")
	return text

end


--------------------------------------------------------
-- Convert <h> tags into  paragraph tags but set the style to the header, e.g. h1
-- Hopefully, the style will exist!
-- @param tag, attr
-- @return tag, attr
local function convertHeaders(tag, attr)
	if ( tag and find(tag, "[hH]%d") ) then
		attr.class = lower(tostring(tag))
		tag = "p"
	end

	return tag, attr
end


--------------------------------------------------------
-- CACHE of textwrap!!!
-- The closing of the database is done when the app quits.
--------------------------------------------------------
--- Fix single quotes for SQLite
-- Single quotes become double single-quotes, ' -> ''
local function fixQuotes(s)
	--s = string.gsub(s, "'", "''")
	s = s or ""
	s = string.gsub(s, [[']], [['']])
	return s
end

--- Implent the db:first_row command
-- @param db The database handle
-- @param cmd A text SQL command, e.g. "SELECT * FROM books"
local function first_row(db, cmd)
	local row = false
	local a
	for a in db:nrows(cmd) do
		return a
	end
	return row
end



----------------------------------------------------------
-- Made a text block a scrolling text block.
-- local scrollingblock = textblock:fitBlockToHeight ( options )
----------------------------------------------------------
local function fitBlockToHeight(textblock, options )

	local maxheight = options.maxVisibleHeight or screenH
	local scrollingFieldIndicatorActive = options.scrollingFieldIndicatorActive
	local parentTouchObject = options.parentTouchObject

	local h = funx.percentOfScreenHeight(maxheight)
	if (not h) then
		h = screenH
	end
	-- width and height must be a multiple of four
	h = ceil( h/4 ) * 4

	local w = funx.percentOfScreenWidth(textblock.width)
	if (not w) then
		w = screenW
	end
	-- width and height must be a multiple of four
	w = ceil( w/4 ) * 4

	-- Set a flag
	local textBlockIsScrolling = false
	
	-- This will be either the scrolling block, or just the textblock as it was
	local finalTextBlock

	if ( textblock.height > h ) then

		-- Listener function to listen to scrollView events
		-- However, this does NOT pass the touch event on even if we return false.
		-- Dammit.

		local prevPosX, prevPosY
		local startTime
		local minTapTime = 10
		local maxTapTime = 200
		local swipeDistance = 40
		local dragDistance, dragDistanceX, dragDistanceY
		--local swipeHorizontal, swipeVertical
		local dX, dY


		local function scrollViewListener( event )
			--print ("event.phase",event.phase)

		    local phase = event.phase
			if ( phase == "moved" ) then
				local dx = math.abs( ( event.x - event.xStart ) )
				-- If the touch on the object has moved more than 10 pixels,
				-- pass focus back to the parent object so it can continue doing its thing,
				-- usually scrolling
				if ( parentTouchObject and dx > 10 ) then
					parentTouchObject:takeFocus( event )
				end
			end
		    return true
		end


		-- Create a new ScrollView widget:

		-- The scrolling handle isn't visible unless we provide some extra space for it.
		-- We use a background but make it see-through, so that we can scroll from
		-- by swiping inside the rect of the scrollview
		
		--local correctForScrollHandle = 12
		
		
		-- customScrollBar.options = true/false
		local scrollBarOptions = nil

		--[[
		-- The custom scrollbar does not work in the current widgets!
		
		if options.customScrollBar then
			local scrollBarOpt = {
				width = 20,
				height = 20,
				numFrames = 3,
				sheetContentWidth = 20,
				sheetContentHeight = 60,
			}
			local scrollBarSheet = graphics.newImageSheet( pathToModule.."assets/widget-scrollbar.png", scrollBarOpt )
			
			scrollBarOptions = {
				sheet = scrollBarSheet,  --reference to the image sheet
				frameWidth = 20,
				frameHeight = 20,
				topFrame = 1,            --number of the "top" frame
				middleFrame = 2,         --number of the "middle" frame
				bottomFrame = 3          --number of the "bottom" frame
			}
			

		end
		--]]

		local maskFileName = funx.makeMask(w,h, "masks")
		
		local args = {
			width = w,--+correctForScrollHandle,
			height = h,
			scrollWidth = w,--+correctForScrollHandle,
			scrollHeight = h,
			hideScrollBar = false,
			maskFile = maskFileName,
			baseDir = system.CachesDirectory,
			listener = scrollViewListener,
			hideBackground = options.hideBackground,
			backgroundColor = options.backgroundColor or {1,1,1},
			topPadding = 0,
			bottomPadding = 0,
			horizontalScrollDisabled = true,
			
			scrollBarOptions = scrollBarOptions,
		}

		local scrollView = widget.newScrollView(args)

		-- Create an object and place it inside of ScrollView:
		scrollView:insert( textblock )
		finalTextBlock = scrollView

		-- Create an invisible rect so we can swipe anywhere in the text,
		-- instead of only on text itself.
		local objForSwipe = display.newRect(textblock, 0,0,textblock.contentWidth,textblock.contentHeight)
		funx.anchor(objForSwipe, "TopLeft")
		objForSwipe.x = 0
		objForSwipe.y = 0
		objForSwipe:setFillColor(250,0,0,0)
		objForSwipe:toBack()

		if (scrollingFieldIndicatorActive) then
			-- Add an icon to indicate this is a scrolling text field,
			-- Or add icons top/bottom, depending on settings
			-- The icon should disappear after usage(?)
			local scrollingFieldIndicator, scrollingFieldIndicatorUp, scrollingFieldIndicatorDown
			if (options.scrollingFieldIndicatorLocation == "over") then
				scrollingFieldIndicator = loadImageFile(options.scrollingFieldIndicatorIconOver)
				local s = min(w, h) - 10
				local r = s / min(scrollingFieldIndicator.width, scrollingFieldIndicator.height)

				funx.anchor(scrollingFieldIndicator, "TopCenter")
				scrollingFieldIndicator:scale(r,r)

				scrollView:insert( scrollingFieldIndicator )
				scrollView.Indicator = scrollingFieldIndicator
				scrollingFieldIndicator.x = w/2
				scrollingFieldIndicator.y = 0
			elseif (options.scrollingFieldIndicatorLocation == "bottom") then
				scrollingFieldIndicatorDown = loadImageFile(options.scrollingFieldIndicatorIconDown)
				scrollView:insert( scrollingFieldIndicatorDown )
				scrollView.downIndicator = scrollingFieldIndicatorDown
				funx.anchor(scrollingFieldIndicatorDown, "BottomCenter")

				scrollView.downIndicator.x = (scrollView.width /2)
				scrollView.downIndicator.y = (h - 10)
			else
				scrollingFieldIndicatorUp = loadImageFile(options.scrollingFieldIndicatorIconUp)
				scrollingFieldIndicatorDown = loadImageFile(options.scrollingFieldIndicatorIconDown)
				scrollView:insert( scrollingFieldIndicatorUp )
				scrollView:insert( scrollingFieldIndicatorDown )

				scrollView.upIndicator = scrollingFieldIndicatorUp
				scrollView.downIndicator = scrollingFieldIndicatorDown

				funx.anchor(scrollingFieldIndicatorUp, "TopCenter")
				funx.anchor(scrollingFieldIndicatorDown, "BottomCenter")

				scrollView.upIndicator.x = (scrollView.width /2)
				scrollView.downIndicator.x = (scrollView.width /2)
				scrollView.upIndicator.y = 10
				scrollView.downIndicator.y = (h - 10)
			end

					-- FADE AWAY scrollingFieldIndicator
					local function fadeOpeningItems( )
						
							-- Fade out
						local function fout(obj)
							funx.fadeOut(obj, nil, nil)
						end

						-- Wait...
						local function waitabit(obj)
							timer.performWithDelay( options.pageItemsPrefadeOnOpeningTime, function() fout(obj) end )
						end
						if (options.scrollingFieldIndicatorLocation == "over") then
							funx.fadeIn(scrollingFieldIndicator, function() waitabit(scrollingFieldIndicator) end, options.pageItemsFadeInOpeningTime)
						elseif (options.scrollingFieldIndicatorLocation == "bottom") then
							funx.fadeIn(scrollingFieldIndicatorDown, function() waitabit(scrollingFieldIndicatorDown) end, options.pageItemsFadeInOpeningTime)
						else
							funx.fadeIn(scrollingFieldIndicatorUp, function() waitabit(scrollingFieldIndicatorUp) end, options.pageItemsFadeInOpeningTime)
							funx.fadeIn(scrollingFieldIndicatorDown, function() waitabit(scrollingFieldIndicatorDown) end, options.pageItemsFadeInOpeningTime)
						end

					end

			-- Begin the fade away immediately
			fadeOpeningItems()

		end -- scroll view indicator icon

		textBlockIsScrolling = true
		-- must copy this over!
		finalTextBlock.anchorChildren = false
		finalTextBlock.yAdjustment = textblock.yAdjustment
		finalTextBlock.anchorChildren = true
		finalTextBlock.anchorX, finalTextBlock.anchorY = 0,0
		
	else
		finalTextBlock = textblock
	end
	
	return finalTextBlock
end



local function openCacheDB()
	-- Create the new DB
--print ("not T.db or not T.db:isopen()", not T.db or not T.db:isopen())
	if ( not T.db or not T.db:isopen() ) then
		local path = system.pathForFile( "textcache.db", system.CachesDirectory )
		local db = sqlite3.open( path )
		-- Be sure the table exists		
		local cmd = "CREATE TABLE IF NOT EXISTS caches (id TEXT PRIMARY KEY, cache TEXT, baseline TEXT );"
		db:exec( cmd )
		
		-- save in the module table
		T.db = db
		--print ("openCacheDB: Opened")
	end
	--T.cacheToDB = true
end

-- Install a closing function for the caching database into the applicationExit
local function closeDB( event )
	if event.type == "applicationExit" then
		if T.db and T.db:isopen() then
			T.db:close()
			--print ("closeDB: Close")
		end
	end
end



local function saveTextWrapToCache(id, cache, baselineCache, cacheDir)
--print ("saveTextWrapToCache: ID", id)
	if (T.cacheToDB) then
		if ( not T.db or not T.db:isopen() ) then
			openCacheDB()
		end

		local cmd = "INSERT INTO 'caches' (id,cache,baseline) VALUES ('" ..id .. "','" .. fixQuotes(json.encode(cache)) .. "','" .. fixQuotes(json.encode(baselineCache)) .. "');"
		T.db:exec( cmd )

	else
		if (cacheDir and cacheDir ~= "") then
			funx.mkdirTree (cacheDir .. "/" .. textWrapCacheDir, system.CachesDirectory)
			--funx.mkdir (cacheDir .. "/" .. textWrapCacheDir, "",false, system.CachesDirectory)
			-- Developing: delete the cache
		
			-- Add in the baseline cache
			local c = { wrapCache = cache, baselineCache = baselineCache, }
			if (true) then
				local fn =  cacheDir .. "/" .. textWrapCacheDir .. "/" ..  id .. ".json"
				funx.saveTable(c, fn , system.CachesDirectory)
			end
		end
	end
end

--------------------------------------------------------
local function loadTextWrapFromCache(id, cacheDir)
	if (T.cacheToDB) then
		if ( not T.db or not T.db:isopen() ) then
			openCacheDB()
		end

--print ("loadTextWrapFromCache: ID",id)

		local cmd = "SELECT * FROM caches WHERE id='" .. id .. "';"
		local row = first_row(T.db, cmd)
		if (row ) then
			local c = { wrapCache = json.decode(row.cache), baselineCache = json.decode(row.baseline), }
			return c
		else
--print ("*** NOT CACHED: ID",id)
			return false
		end
	else
		if (cacheDir) then
			local fn = cacheDir .. "/" .. textWrapCacheDir .. "/" ..  id .. ".json"

			if (funx.fileExists(fn, system.CachesDirectory)) then
				local c = funx.loadTable(fn, system.CachesDirectory)
	--print ("cacheTemplatizedPage: found page "..fn )
				return c
			end
		end
		return false
	end
end


--------------------------------------------------------
local function iteratorOverCacheText (t)
	local i = 0
	local n = table.getn(t)
	return function ()
		i = i + 1
		if i <= n then
			return t[i], ""
		end
	end
end

-- Create a cache chunk table from either an existing cache entry or for a chunk of XML for the cache table.
-- A chunk may have multiple lines.
-- Weird to use separate tables for each attribute? But this allows us to iterate over the words
-- instead of over the cache entry, allowing us to use the existing for-do structure.
local function newCacheChunk ( cachedChunk )
	
	cachedChunk = {
						text = {}, 
						item = {},
					}
	
	return cachedChunk
end


-- Get a chunk entry from the cache table
local function getCachedChunkItem(t, i)
	return t.item[i]
end

local function updateCachedChunk (t, args)
	local i = args.index or 1
	-- Write all in one entry
	t.item[i] = args
	-- Write text table for iteration
	t.text[i] = args.text
	return t
end


--------------------------------------------------------
-- CACHE: Clear all caches

local function clearAllCaches(cacheDir)
	if (cacheDir and cacheDir ~= "") then
		funx.rmDir (cacheDir .. "/" .. textWrapCacheDir, system.CachesDirectory, true) -- keep structure, delete contents
	end
	
	-- Remove DB file
	local path = system.pathForFile( "textcache.db", system.CachesDirectory )
	local results, reason = os.remove( path )
end



--------------------------------------------------------
-- Make a box that is the right size for touching.
-- Problem is, the font sizes are so big, they overlap lines.
-- This box will be a nicer size.
-- NOte, there is no stroke, so we don't x+1/y+1
local function touchableBox(g, referencePoint, x,y, width, height, fillColor)

	local touchme = display.newRect(0,0,width, height)
	setFillColorFromString(touchme, fillColor)

	g:insert(touchme)
	anchor(touchme, referencePoint)
	touchme.x = x
	touchme.y = y
	touchme:toBack()

	return touchme
end


--------------------------------------------------------
-- Add a tap handler to the object and pass it the tag attributes, e.g. href
-- @param obj A display object, probably text
-- @param id String: ID of the object?
-- @param attr table: the attributes of the tag, e.g. href or target, HTML stuff, !!! also the text tapped should be in "text" in attr
-- @param handler table A function to handle link values, like "goToPage". These should work with the button handler in slideView
local function attachLinkToObj(obj, attr, handler)

	local function comboListener( event )
		local object = event.target
		if not ( event.phase ) then
			local attr = event.target._attr
			--print( "Tap event on word!", attr.text)


			if (handler) then
				handler(event)
				--print( "Tap event on word!", attr.text)
				--print ("Tapped on ", attr.text)
			else
				print ("WARNING: textwrap:attachLinkToObj says no handler set for this event.")
			end
		end
		return true
	end

	obj.id = attr.id or (attr.id or "")
	obj._attr = attr
	obj:addEventListener( "tap", comboListener )
	obj:addEventListener( "touch", comboListener )
end




------------------------------------------------
-- Get the ascent of a font, which is how we position text.
-- Set InDesign to position from the box top using leading
------------------------------------------------
local function getFontAscent(baselineCache, font, size)
	
	local baseline, descent, ascent

	if (baselineCache[font] and baselineCache[font][size]) then
			baseline, descent, ascent = unpack(baselineCache[font][size])
	else

		local fontInfo = fontMetrics.getMetrics(font)

		-- Get the iOS bounding box size for this particular font!!!
		-- This must be done for each size and font, since it changes unpredictably
		local samplefont = display.newText("X", 0, 0, font, size)
		local boxHeight = samplefont.height
		samplefont:removeSelf()
		samplefont = nil

		-- Set the new baseline from the font metrics
		baseline = boxHeight + (size * fontInfo.descent)
		
		ascent = fontInfo.ascent * size
		
		-- This should adjust the font above/below the baseline to reflect differences in fonts,
		-- putting them all on the same line.
		-- This amount is above the bottom of the rendered font box
		descent = (size * fontInfo.descent)

		if (not baselineCache[font]) then
			baselineCache[font] = {}
		end
		baselineCache[font][size] = { baseline, descent, ascent }
		
	end
	return baseline, descent, ascent
end


-- ------------------------------------------------------
-- Finished lines, aligns them left/right/center
-- ------------------------------------------------------
local function alignRenderedLines(lines, stats)
	for i,_ in pairs(lines) do
		if (stats[i].textAlignment == "Right") then
			lines[i].anchorX = 1
			lines[i].x = stats[i].currentWidth + stats[i].leftIndent + stats[i].firstLineIndent
		elseif (stats[i].textAlignment == "Center") then
			lines[i].anchorX = 0.5
			-- currentWidth compensates for margins			
			--local c = stats[i].leftIndent + stats[i].firstLineIndent + (stats[i].currentWidth)/2
			--local c = stats[i].firstLineIndent + (stats[i].currentWidth)/2
			local c = stats[i].firstLineIndent + (stats[i].width)/2
			lines[i].x = c
		else
			lines[i].x = stats[i].leftIndent + stats[i].firstLineIndent
		end
	end
	return lines
end



--------------------------------------------------------
-- Wrap text to a width
-- Blank lines are ignored.
-- *** To show a blank line, put a space on it.
-- The minCharCount is the number of chars to assume are in the line, which means
-- fewer calculations to figure out first line's.
-- It starts at 25, about 5 words or so, which is probabaly fine in 99% of the cases.
-- You can raise lower this for very narrow columns.
-- opacity : 0.0-1.0
-- "minWordLen" is the shortest word a line can end with, usually 2, i.e, don't end with single letter words.
-- NOTE: the "floor" is crucial in the y-position of the lines. If they are not integer values, the text blurs!
--
-- Look for CR codes. Since clumsy XML, such as that from inDesign, cannot include line breaks,
-- we have to allow for a special code for line breaks: [[[cr]]]
--------------------------------------------------------

local function autoWrappedText(text, font, size, lineHeight, color, width, alignment, opacity, minCharCount, targetDeviceScreenSize, letterspacing, maxHeight, minWordLen, textstyles, defaultStyle, cacheDir)

	----------
	--if text == '' then return false end
	local renderedTextblock = display.newGroup()
	
	-- Add the scrollblock function to the result
	renderedTextblock.fitBlockToHeight = fitBlockToHeight

	local baseline = 0
	local descent = 0
	local ascent = 0
	
	if (testing) then
		print ("autoWrappedText: testing flag is true.")
		print ("----------")
		--print (text.text)
		--print ("----------")
	end

	-- table for useful settings. We need fewer upvalues, and this is a way to do that
	local settings = {}

	-- ====================
	-- FIXED VALUES
	-- These should probably be changeable somewhere!
	
	-- Fudge factor -- pixels to add after a change in font scale (not size!)
	-- which is how we handle superscript and subscript.
	settings.fontscaleChangeFudge = 1
	
	-- Indent value in OL and UL lists
	settings.listIndent = 10
	settings.listExtraSpaceAfterBullet = 2
	settings.listBulletToTextDistance = 30

	-- ====================
	
	-- Used to track x location while creating a line of text
	settings.currentXOffset = 0
	
	settings.deviceMetrics = funx.getDeviceMetrics( )

	settings.minWordLen = 2

	settings.isHTML = false
	settings.useHTMLSpacing = false

	-- handler for links
	settings.handler = {}

	-- Get from the funx textStyles variable.
	local textstyles = textstyles or {}

	local hyperlinkFillColor = "0,0,255,"..TRANSPARENT
	local hyperlinkTextColor = "0,0,255,"..OPAQUE
	
	T.cacheToDB = true

	-- If table passed, then extract values
	if (type(text) == "table") then
		font = text.font
		size = text.size
		lineHeight = text.lineHeight
		color = text.color
		width = text.width
		alignment = text.textAlignment
		opacity = text.opacity
		minCharCount = text.minCharCount
		targetDeviceScreenSize = text.targetDeviceScreenSize
		letterspacing = text.letterspacing
		maxHeight = text.maxHeight
		settings.minWordLen = text.minWordLen
		textstyles = text.textstyles or textstyles
		settings.isHTML = text.isHTML or false
		settings.useHTMLSpacing = text.useHTMLSpacing or false
		
		defaultStyle = text.defaultStyle or "body"
		cacheDir = text.cacheDir
		settings.handler = text.handler
		hyperlinkFillColor = text.hyperlinkFillColor or hyperlinkFillColor
		hyperlinkTextColor = text.hyperlinkTextColor or hyperlinkTextColor
		
		sourceDirectory = text.sourceDirectory or false
		sourcePath = text.sourcePath or false
		
		testing = testing or text.testing
		noCache = noCache or text.noCache
		
		-- Default is true, allow set to false here
		if (text.cacheToDB ~= nil) then
			T.cacheToDB = text.cacheToDB
		end
				
		-- restore text
		text = text.text
	end
	
	-- If no text, do nothing.
	if (not text) then
		return renderedTextblock
	end
	
	
	-- Be sure text isn't nil
	text = text or ""

	-- Caching values
	-- Name the cache with the width, too, so the same text isn't wrapped to the wrong
	-- width based on the cache.
	local textUID = 0
	local textwrapIsCached = false
	local cache = { { text = "", width = "", } }
	local cacheIndex = 1
		
	-- Cache of font baselines for different sizes, as drawing on screen
	local baselineCache = {}
	
	-- Interpret the width so we can get it right caching:
	width = funx.percentOfScreenWidth(width) or display.contentWidth
	
	-- TESTING
	if (noCache) then
		cacheDir = nil
		T.cacheToDB = false
		print ("WARNING: textrender: caching turned off for testing.")
	end
		
	-- Default is to cache using the sqlite3 database.
	-- If cacheToDB is FALSE, then we fall back on the text file cacheing
	-- if cacheDir is set.
	if ( T.cacheToDB or (cacheDir and cacheDir ~= "") ) then
		--textUID = "cache"..funx.checksum(text).."_"..tostring(width)
		textUID = crypto.digest( crypto.md4, tostring(width) .. text )
--print ( tostring(width) .. text )
		local c = loadTextWrapFromCache(textUID, cacheDir)
		if (c) then
			textwrapIsCached = true
			cache = c.wrapCache
			baselineCache = c.baselineCache
			--print ("***** CACHE LOADED")
			--funx.dump(cache)
		end
	end


	-- default
	settings.minWordLen = settings.minWordLen or 2
	text = text or ""
	if (text == "") then
		return renderedTextblock
	end

	-- alignment is the initial setting for the text block, but sub-elements may differ
	local textAlignment = fixCapsForReferencePoint(alignment) or "Left"

	-- Just in case
	text = tostring(text)

	--[[
	------------------------
	-- HANDLING LINE BREAKS:
	-- This is also a standard XML paragraph separator used by Unicode
	See:   http://www.fileformat.info/info/unicode/char/2028/index.htm

	Unicode introduced separator				<textblock>
					<text>
						Fish are ncie to me.
						I sure like them!
						They're great!
					</text>
				</textblock>


	In an attempt to simplify the several newline characters used in legacy text, UCS introduces its own newline characters to separate either lines or paragraphs: U+2028 line separator (HTML: &#8232; LSEP) and U+2029 paragraph separator (HTML: &#8233; PSEP). These characters are text formatting only, and not <control> characters.


	Unicode Decimal Code &#8233; 
	Symbol Name:	Paragraph Separator
	Html Entity:
	Hex Code:	&#x2029;
	Decimal Code:	&#8233;
	Unicode Group:	General Punctuation

	InDesign also uses &#8221; instead of double-quote marks when exporting quotes in XML. WTF?

	]]
	
	-- This is &#8221;
	--local doubleRtQuote

	-- Strip InDesign end-of-line values, since we now use a kind of HTML from
	-- InDesign.

	local lineSeparatorCode = "%E2%80%A8"
	local paragraphSeparatorCode = "%E2%80%A9"	-- This is ;&#8233;
	text = text:gsub(funx.unescape(lineSeparatorCode),"")
	text = text:gsub(funx.unescape(paragraphSeparatorCode),"")


	-- Convert entities in the text, .e.g. "&#8211;"
	if (not settings.isHTML) then
		text = entities.unescape(text)
	end


	--- THEN, TOO, THERE'S MY OWN FLAVOR OF LINE BREAK!
	-- Replace our special line break code one could use in the source text with an HTML return!
	text = text:gsub("%[%[%[br%]%]%]","<br>")

	------------------------

	maxHeight = tonumber(maxHeight) or 0

	-- Minimum number of characters per line. Start low.
	--local minLineCharCount = minCharCount or 5

	-- This will cause problems with Android
--	font = font or "Helvetica" --native.systemFont
--	size = tonumber(size) or 12
--	color = color or {0,0,0,0}
--	width = funx.percentOfScreenWidth(width) or display.contentWidth
--	opacity = funx.applyPercent(opacity, OPAQUE) or OPAQUE
--	targetDeviceScreenSize = targetDeviceScreenSize or screenW..","..screenH
	-- case can be ALL_CAPS or UPPERCASE or LOWERCASE or NORMAL
	--local case = "NORMAL";
	-- Space before/after paragraph
	--local spaceBefore = 0
	--local spaceAfter = 0
	--local firstLineIndent = 0
	--local currentFirstLineIndent = 0
	--local leftIndent = 0
	--local rightIndent = 0
	--local bullet = "&#9679;"

	-- Combine a bunch of local variables into a settings array because we have too many "upvalues"!!!
	settings.font = font or "Helvetica" --native.systemFont
	 -- used to restore from bold, bold-italic, etc. since some names aren't clear, e.g. FoozleSemiBold might be the only bold for a font
	settings.fontvariation = ""
	settings.size = tonumber(size) or 12
	settings.color = color or {0,0,0,255}
	settings.width = width
	settings.opacity = applyPercent(opacity, OPAQUE) or OPAQUE
	settings.targetDeviceScreenSize = targetDeviceScreenSize or screenW..","..screenH
	settings.case = "none"
	settings.decoration = "none"
	settings.spaceBefore = 0
	settings.spaceAfter = 0
	settings.firstLineIndent = 0
	settings.currentFirstLineIndent = 0
	settings.leftIndent =0
	settings.rightIndent = 0
	settings.bullet = "&#9679;"
	settings.minLineCharCount = minCharCount or 5
	settings.maxHeight = tonumber(maxHeight) or 0
	settings.yOffset = 0	-- used for ascenders/descenders, superscript, subscript
	
 	lineHeight = applyPercent(lineHeight, settings.size) or floor(settings.size * 1.3)

	-- Scaling for device
	-- Scale the text proportionally
	-- We don't need this if we set use the Corona Dynamic Content Scaling!
	-- Set in the config.lua
	-- Actually, we do, for the width, because that doesn't seem to be shrinking!
	-- WHAT TO DO? WIDTH DOES NOT ADJUST, AND WE DON'T KNOW THE
	-- ACTUAL SCREEN WIDTH. WHAT NOW?

	local scalingRatio = funx.scaleFactorForRetina()

	local currentLine = ''
	
	local lineCount = 0
	
	-- First line of text
	local lineY = 0

	-- x is start of line
	local x = 0

	local defaultSettings = {}

		---------------------------------------------------------------------------
		-- Style setting functions
		---------------------------------------------------------------------------

		-- get all style settings so we can save them in a table
		local function getAllStyleSettings ()
			local params = {}

			params.font = settings.font
			params.fontvariation = settings.fontvariation
			-- font size
			params.size = settings.size
			params.minLineCharCount = settings.minLineCharCount
			params.lineHeight = lineHeight
			params.color = settings.color
			params.width = settings.width
			params.opacity = settings.opacity
			-- case (uppercase/lowercase)
			params.case = settings.case
			if (params.case == "all_caps") then
				params.case = "uppercase"
			end

			-- space before paragraph
			params.spaceBefore = settings.spaceBefore or 0
			-- space after paragraph
			params.spaceAfter = settings.spaceAfter or 0
			-- First Line Indent
			params.firstLineIndent = settings.firstLineIndent
			-- Left Indent
			params.leftIndent = settings.leftIndent
			-- Right Indent
			params.rightIndent = settings.rightIndent
			params.textAlignment = textAlignment
			
			params.yOffset = settings.yOffset
			
			--NO
			-- params.currentXOffset = settings.currentXOffset



			return params
		end


		-- Set style settings which were saved using the function above.
		-- These are set using the values from internal variables, e.g. font or size,
		-- NOT from the style sheet parameters.
		local function setStyleSettings (params)
			if (params.font ) then settings.font = params.font end
			if (params.fontvariation) then settings.fontvariation = params.fontvariation end
				-- font size
			if (params.size ) then settings.size = params.size end
			if (params.minLineCharCount ) then settings.minLineCharCount = params.minLineCharCount end
			if (params.lineHeight ) then lineHeight = params.lineHeight end
			if (params.color ) then 
				settings.color = params.color 
			end
			if (params.width ) then settings.width = params.width end
			if (params.opacity ) then settings.opacity = params.opacity end
				-- case (upper/normal)
			if (params.case ) then settings.case = params.case end
				-- space before paragraph
			if (params.spaceBefore ) then settings.spaceBefore = tonumber(params.spaceBefore) end
				-- space after paragraph
			if (params.spaceAfter ) then settings.spaceAfter = tonumber(params.spaceAfter) end
				-- First Line Indent
			if (params.firstLineIndent ) then params.firstLineIndent = tonumber(settings.firstLineIndent) end
				-- Left Indent
			if (params.leftIndent ) then settings.leftIndent = tonumber(params.leftIndent) end
				-- Right Indent
			if (params.rightIndent ) then settings.rightIndent = tonumber(params.rightIndent) end
			if (params.textAlignment ) then textAlignment = params.textAlignment end

			if (params.yOffset ) then settings.yOffset = params.yOffset end

			--NO
			-- if (params.currentXOffset) then settings.currentXOffset = params.currentXOffset end
	--[[
			if (lower(textAlignment) == "right") then
				x = settings.width - settings.rightIndent
				settings.currentFirstLineIndent = 0
				settings.firstLineIndent = 0
			elseif (lower(textAlignment) == "left") then
				x = 0
			else
				local currentWidth = settings.width - settings.leftIndent - settings.rightIndent -- settings.firstLineIndent
				x = floor(currentWidth/2) --+ settings.firstLineIndent
			end
	]]
		end



		-- set style from params in a ### set, ... command line in the text
		-- This depends on the closure for variables, such as font, size, etc.
		local function setStyleFromCommandLine (params)
		
			if (not params) then
				return
			end

-- testing:
--local ss = funx.tableCopy(settings)

			-- font
			if (params[2] and params[2] ~= "") then settings.font = trim(params[2]) end
			-- font size
			if (params[3] and params[3] ~= "") then
				settings.size = tonumber(params[3])
				--size = scaleToScreenSize(tonumber(params[3]), scalingRatio)
				-- reset min char count in case we loaded a BIG font
				settings.minLineCharCount = minCharCount or 5
			end

			-- line height
			if (params[4] and params[4] ~= "") then
				lineHeight = tonumber(params[4])
				--lineHeight = scaleToScreenSize(tonumber(params[4]), scalingRatio)
			end
			-- color
			if ((params[5] and params[5] ~= "") and (params[6] and params[6] ~= "") and (params[7] and params[7] ~= "")) then
				-- Handle opacity as RGBa or HDRa, not by itself
				if (params[9] and params[9] ~= "") then
					settings.color = {tonumber(params[5]), tonumber(params[6]), tonumber(params[7]), applyPercent(params[9], OPAQUE) }
				else
					settings.color = {tonumber(params[5]), tonumber(params[6]), tonumber(params[7]), OPAQUE }
				end
			end
			-- width of the text block
			if (params[8] and params[8] ~= "") then
				if (params[8] == "reset" or params[8] == "r") then
					settings.width = defaultSettings.width
				else
					settings.width = tonumber(funx.percentOfScreenWidth(params[8]) or defaultSettings.width)
				end
				settings.minLineCharCount = minCharCount or 5
			end
			-- opacity (Now always 100%)
			settings.opacity = 1.0
			-- case (upper/normal)
			if (params[10] and params[10] ~= "") then settings.case = lower(trim(params[10])) end
			if (settings.case == "all_caps") then
				settings.case = "uppercase"
			end

			-- space before paragraph
			if (params[12] and params[12] ~= "") then settings.spaceBefore = tonumber(params[12]) end
			-- space after paragraph
			if (params[13] and params[13] ~= "") then settings.spaceAfter = tonumber(params[13]) end
			-- First Line Indent
			if (params[14] and params[14] ~= "") then settings.firstLineIndent = tonumber(params[14]) end
			-- Left Indent
			if (params[15] and params[15] ~= "") then settings.leftIndent = tonumber(params[15]) end
			-- Right Indent
			if (params[16] and params[16] ~= "") then settings.rightIndent = tonumber(params[16]) end

			-- alignment (note, set first line indent, etc., first!
			if (params[11] and params[11] ~= "") then
				textAlignment = fixCapsForReferencePoint(params[11])
				-- set the line starting point to match the alignment
				if (lower(textAlignment) == "right") then
					--x = settings.width - settings.rightIndent
					settings.currentFirstLineIndent = 0
					settings.firstLineIndent = 0
				elseif (lower(textAlignment) == "center") then
					--local currentWidth = settings.width - settings.leftIndent - settings.rightIndent -- settings.firstLineIndent
					--x = floor(currentWidth/2) --+ settings.firstLineIndent
				else
					x = 0
				end
				-- Alignment happens after a whole line is built.
				x = 0
			end


--print (" ------------------------------")
--for k,v in pairs (settings) do
--	if (ss[k] ~= settings[k]) then
--		print ("--> " .. k .. " has changed to ", settings[k])
--		if (type(settings[k]) == "table") then
--			funx.dump(settings[k])
--		end
--		
--	end
--end
--print (" ")
		end



		-- set style from the attributes of an XML tag, from the style attribute,
		-- e.g. <p style="font:Helvetica;"/>
		-- This depends on the closure for variables, such as font, size, etc.
		-- fontFaces, font are in the closure!
		local function setStyleFromTag (tag, attr)

			local format = getTagFormatting(fontFaces, tag, settings.font, settings.fontvariation, attr)
			if (not format or format == {}) then
				return 
			end

--			if (tag == "sup") then
--				settings.currentXOffset = settings.currentXOffset + 1
--			end
			
			-- font
			if (format.font) then
				settings.font = trim(format.font)
				settings.fontvariation = format.fontvariation
			end
			-- font with CSS:
			if (format['font-family']) then
				settings.font = trim(format['font-family'])
				settings.fontvariation = format.fontvariation
			end

			-- Scale the font
			-- If value is a percentage, apply it
			if (format['yOffset']) then
				settings.yOffset = settings.yOffset + applyPercent ( format.yOffset, settings.size, false)
			end

			if (format['scale']) then
				local prevSize = settings.size
				settings.size = applyPercent ( format.scale, settings.size, false)
				-- If we shrink the scale, then we should move the text over just a little
				-- to compensate, or it is too hard to read
				if ( settings.size < prevSize ) then
					--print ("REDUSED SCALE", prevSize, settings.size, (( prevSize - settings.size ) / prevSize ))
					--local fudge = (( prevSize - settings.size ) / prevSize ) * 5
					settings.currentXOffset = settings.currentXOffset + settings.fontscaleChangeFudge
				end
			end
			-- font size
			if (format['font-size'] or format['size']) then
				if (format['font-size']) then
					-- convert pt values to px
					settings.size = convertValuesToPixels(format['font-size'], settings.size, settings.deviceMetrics)
					-- Change lineheight to match a change in font size when using
					-- somethign like "x-large"
					-- If the fontsize is not something like x-large, this will have no effect
					lineHeight = lineHeight * keywordFontsizeRatio(format['font-size'])
				else
					settings.size = convertValuesToPixels(format['size'], settings.size, settings.deviceMetrics)
				end
				--size = scaleToScreenSize(tonumber(params[3]), scalingRatio)
				-- reset min char count in case we loaded a BIG font
				settings.minLineCharCount = minCharCount or 5
			end
			
			-- lineHeight (HTML property)
			if (format.lineHeight) then
				lineHeight = convertValuesToPixels (format.lineHeight, settings.size, settings.deviceMetrics)
			end

			-- lineHeight (CSS property)
			if (format['line-height']) then
				lineHeight = convertValuesToPixels (format['line-height'], settings.size, settings.deviceMetrics)
			end

			-- color
			-- We're using decimal, e.g. 12,24,55 not hex (#ffeeff)
			if (format.color) then
				local _, _, c = find(format.color, "%((.*)%)")
				local s = stringToColorTable(c)
				if (s) then
					settings.color = { s[1], s[2], s[3], s[4] }
				end
			end

			-- width of the text block
			if (format.width) then
				if (format.width == "reset" or format.width == "r") then
					settings.width = defaultSettings.width
				else
					-- Remove "px" from the width value if it is there.
					format.width = format.width:gsub("px$","")
					settings.width = tonumber(funx.percentOfScreenWidth(format.width) or defaultSettings.width)
				end
				settings.minLineCharCount = minCharCount or 5
			end

			-- opacity
			-- Now built into the color, e.g. RGBa color
			--if (format.opacity) then settings.opacity = applyPercent(format.opacity, OPAQUE) end

			-- case (upper/normal) using *legacy* coding ("case")
			if (format.case) then
				settings.case = lower(trim(format.case))
			end
			
			-- font-variant: none, uppercase, etc.
			-- case, using CSS, e.g. "text-transform:uppercase"
			if (format["text-transform"]) then settings.case = lower(trim(format["text-transform"])) end
			-- Fix legacy "normal" setting, which in CSS is "none"
			if settings.case == "normal" then settings.case = "none"; end

			if (format["text-decoration"]) then 
				settings.decoration = lower(trim(format["text-decoration"])) 
			end

			-- space before paragraph
			if (format['margin-top']) then settings.spaceBefore = convertValuesToPixels(format['margin-top'], settings.size, settings.deviceMetrics) end

			-- space after paragraph
			if (format['margin-bottom']) then settings.spaceAfter = convertValuesToPixels(format['margin-bottom'], settings.size, settings.deviceMetrics) end

			-- First Line Indent
			if (format['text-indent']) then settings.firstLineIndent = convertValuesToPixels(format['text-indent'], settings.size, settings.deviceMetrics) end

			-- Left Indent
			if (format['margin-left']) then 
				settings.leftIndent = convertValuesToPixels(format['margin-left'], settings.size, settings.deviceMetrics) 
			end

			-- Right Indent
			if (format['margin-right']) then settings.rightIndent = convertValuesToPixels(format['margin-right'], settings.size, settings.deviceMetrics) end

			-- alignment (note, set first line indent, etc., first!
			if (format['text-align']) then
				textAlignment = fixCapsForReferencePoint(format['text-align'])
				-- set the line starting point to match the alignment
				if (lower(textAlignment) == "right") then
					--x = settings.width - settings.rightIndent
					settings.currentFirstLineIndent = 0
					settings.firstLineIndent = 0
				elseif (lower(textAlignment) == "center") then
					-- Center
					--local currentWidth = settings.width - settings.leftIndent - settings.rightIndent -- settings.firstLineIndent
					--x = floor(currentWidth/2) --+ settings.firstLineIndent
				else
					x = 0
				end
				-- Alignment happens after a whole line is built.
				x = 0

			end

			-- List bullet
			-- Default to disc

			-- bullet set to nothing!
			if ( format['bullet'] == "" or format['bullet'] == "none") then
				settings.bullet = nil
			elseif ( format['bullet'] == nil ) then
			-- bullet not set, use default
				settings.bullet = "&#9679;"
			else
				settings.bullet = format['bullet']
			end

			
			
			------------------------------------------------
			-- Refigure font metrics if font has changed
			------------------------------------------------
			if (settings.font ~= prevFont or settings.size ~= prevSize) then

				baseline, descent, ascent = getFontAscent(baselineCache, settings.font, settings.size)
				prevFont = settings.font
				prevSize = settings.size
			end
			
			baseline, descent, ascent = getFontAscent(baselineCache, settings.font, settings.size)
			
		end



		---------------------------------------------------------------------------

	-- Load default style if it exists
	if (defaultStyle ~= "") then
		local params = textstyles[defaultStyle]
		if (params) then
			setStyleFromCommandLine (params)
		end
	end

	local defaultSettings = {
		font = settings.font,
		size = settings.size,
		lineHeight = lineHeight,
		color = settings.color,
		width = settings.width,
		opacity = settings.opacity,
	}



	-- Typesetting corrections
	-- InDesign uses tighter typesetting, so we'll try to correct a little
	-- with some fudge-factors.
	local widthCorrection = 1
	if (true) then
		widthCorrection = 1.02--0.999
	end


	-- This is ;&#8232;
	--local lineSeparatorCode = "%E2%80%A8"
	-- This is ;&#8233;
	--local paragraphSeparatorCode = "%E2%80%A9"
	-- Get lines with ending command, e.g. CR or LF
	--	for line in gmatch(text, "[^\n]+") do
	local linebreak = funx.unescape(lineSeparatorCode)
	local paragraphbreak = funx.unescape(paragraphSeparatorCode)
	local oneLinePattern = "[^\n^\r]+"
	local oneLinePattern = ".-[\n\r]"
	if (settings.isHTML) then
		--print ("Autowrap: line 500 : text is HTML!")
		text = text:gsub("[\n\r]+"," ")
		text = trim(text, false)
	end

	-- ----------------------
	-- Use HTML Spacing
	-- Replace all multiple-spaces, returns and tabs with single spaces, just like HTML
	-- ----------------------
	if (settings.useHTMLSpacing) then
		text = text:gsub("[\t ]+"," ")
		text = text:gsub(" +"," ")
	end


	-- Be sure the text block ends with a return, so the line chopper below finds the last line!
	if (substring(text,1,-1) ~= "\n") then
		text = text .. "\n"
	end

	local lineBreakType,prevLineBreakType,prevFont,prevSize

	-- Set the initial left side to 0
	-- (FYI, the var is defined far above here!)
	x = 0
	
	-- Flag for very first text in the entire XML block of text.
	settings.isFirstTextInBlock = true
	
	-- Flag for first line of text of a chunk of text that ends with a return, like a paragraph.
	settings.isFirstLine = true


	-- And adjustment to better position the text.
	-- Corona positions type incorrectly, at the descender line, not the baseline.
	local yAdjustment = 0

	-- The output x,y for any given chunk of text
	local cursorX, cursorY = 0,0

	-- Repeat for each block of text (ending with a carriage return)
	-- Usually, this will be a paragraph
	-- Text from InDesign should be one large block,
	-- which is right since it is escaped HTML.
	for line in gmatch(text, oneLinePattern) do
		local command, commandline

		local lineEnd = substring(line,-1,-1)
		local q = funx.escape(lineEnd)

		-- CR means end of paragraph, LF = soft-return
		prevLineBreakType = lineBreakType or "hard"
		if (lineEnd == "\r") then
			lineBreakType = "soft"
		else
			lineBreakType = "hard"
		end

		line = trim(line)

		-----------------------------------------
		-- COMMAND LINES:
		-- command line: reset, set, textalign
		-- set is followed by: font, size, red,green,blue, width, opacity
		-- Command line?
		if (currentLine == "" and substring(line,1,3) == "###") then
			currentLine = ''
			commandline = substring(line,4,-1)	-- get end of line
			local params = split(commandline, ",", true)
			command = trim(params[1])
			if (command == "reset") then
				settings.font = defaultSettings.font
				settings.size = defaultSettings.size
				lineHeight = defaultSettings.lineHeight
				settings.color = defaultSettings.color
				settings.width = defaultSettings.width
				settings.opacity = defaultSettings.opacity
				textAlignment = "Left"
				x = 0
				settings.currentFirstLineIndent = settings.firstLineIndent
				settings.leftIndent = 0
				settings.rightIndent = 0
				settings.bullet = "&#9679;"
			elseif (command == "style") then
				local styleName = params[2] or "MISSING"
				if (textstyles and textstyles[styleName] ) then
					params = textstyles[styleName]
					setStyleFromCommandLine (params)
				else
					print ("WARNING: funx.autoWrappedText tried to use a missing text style ("..styleName..")")
				end
			elseif (command == "set") then
				setStyleFromCommandLine (params)
			elseif (command == "textalign") then
				-- alignment
				if (params[2] and params[2] ~= "") then
					textAlignment = fixCapsForReferencePoint(params[2])
					-- set the line starting point to match the alignment
					if (lower(textAlignment) == "right") then
						--x = settings.width - settings.rightIndent
						settings.currentFirstLineIndent = 0
						settings.firstLineIndent = 0
					elseif  (lower(textAlignment) == "center") then
						--local currentWidth = settings.width - settings.leftIndent - settings.rightIndent -- settings.currentFirstLineIndent
						--x = floor(currentWidth/2) --+ settings.currentFirstLineIndent
					else
						--x = 0
					end
					x = 0
				end



			elseif (command == "blank") then
				local lh
				if (params[2]) then
					--lh = scaleToScreenSize(tonumber(params[2]), scalingRatio, true)
					lh = tonumber(params[2])
				else
					lh = lineHeight
				end
				lineCount = lineCount + 1
				lineY = lineY + lh

			elseif (command == "setline") then
				-- set the x of the line
				if (params[2]) then
					x = tonumber(params[2])
				end
				-- set the y of the line
				if (params[3]) then
				    lineY = tonumber(params[3])
				end
				-- set the y based on the line count, i.e. the line to write to
				if (params[4]) then
					lineCount = tonumber(params[4])
					lineY = floor(lineHeight * (lineCount - 1))
				end



			end
		else
			local restOLine = substring(line, strlen(currentLine)+1)


			------------------------------------------------------------
			------------------------------------------------------------
			-- Render parsed XML block
			-- stick this here cuz it needs the closure variables
			---------
			local function renderXML (xmlChunk)
			
				local renderXMLvars = {}
				local renderXMLresult = display.newGroup()
				-- Need this positioniong rect so lines can be right/center justified inside of the result group
				funx.addPosRect(renderXMLresult, testing, {0,250,0})

				if (not settings.width) then print ("WARNING: textwrap: renderXML: The width is not set! This shouldn't happen."); end


				settings.width = settings.width or 300

				-- Everything is left aligned, the alignment happens after a whole line is built.
				--textAlignment = "Left"
				renderXMLvars.textDisplayReferencePoint = "BottomLeft"


				renderXMLvars.shortword = ""

				-- Set paragraph wide stuff, indents and spacing
				settings.currentFirstLineIndent = settings.firstLineIndent
				settings.currentSpaceBefore = settings.spaceBefore
				settings.currentSpaceAfter = settings.spaceAfter

				if (lineBreakType == "hard") then
					settings.currentFirstLineIndent = settings.firstLineIndent
					settings.currentSpaceBefore = settings.spaceBefore
					settings.currentSpaceAfter = settings.spaceAfter
					settings.isFirstLine = true
				end

				if (lineBreakType == "soft") then
					settings.currentSpaceBefore = settings.spaceBefore
					settings.currentSpaceAfter = 0
				end

				-- If previous paragraph had a soft return, don't add space before, nor indent the 1st line
				if (prevLineBreakType == "soft") then
					settings.currentFirstLineIndent = 0
					settings.currentSpaceAfter = 0
					settings.currentSpaceBefore = 0
				end

				-- ALIGN TOP OF TEXT FRAME TO CAP HEIGHT!!!
				-- If this is the first line in the block of text, DON'T apply the space before settings
				-- Tell the function which called this to raise the entire block to the cap-height
				-- of the first line.

				renderXMLvars.fontInfo = fontMetrics.getMetrics(settings.font)
				local currentLineHeight = lineHeight

				baseline, descent, ascent = getFontAscent(baselineCache, settings.font, settings.size)


				-- Width of the text column (not including indents which are paragraph based)
				settings.currentWidth = settings.width
				--settings.currentWidth = width - settings.leftIndent - settings.rightIndent - settings.currentFirstLineIndent

				-- Get min characters to start with
				-- We now know the max char width in a font,
				-- so we can start with a minimum based on that.
				-- IF the metric was set!
				if (renderXMLvars.fontInfo.maxHorizontalAdvance) then
					settings.minLineCharCount = floor((settings.currentWidth * widthCorrection) / (settings.size * renderXMLvars.fontInfo.maxCharWidth) )
				end



				-- Remember the font we start with to handle bold/italic changes
				local basefont = settings.font

				local prevTextInLine = ""


				local prevFont = settings.font
				local prevSize = settings.size


				------------------------------------------------------------
				-- Parse the line of text (ending with CR) into a table, if it is XML
				-- or leave it as text if it is not.
				local parsedText = html.parsestr(xmlChunk)

				-- Start rendering this text at the margin
				local renderTextFromMargin = true

				-- If this is an inline element, then apply 1st line indent
				-- if needed. To begin, we are definitely on a first line.
				settings.elementOnFirstLine = true

				------------------------------------------------------------
				-- RENDERING
				-- Now broken up into functions so we can recurse.
				-- This function will render
				------------------------------------------------------------
				
				-- Array of rendered lines, so we can access them one by one for alignment
				renderXMLvars.renderedLines = {}
				renderXMLvars.renderedLinesStats = {}
				-- Index in array of lines rendered.
				renderXMLvars.currentRenderedLineIndex = 1
				
				
				
				local function addToCurrentRenderedLine(obj, x, lineY, textAlignment, settings, text)
					textAlignment = textAlignment or "Left"
						
					if (not renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex]) then
						renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex] = display.newGroup()
						renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex].anchorChildren = true
						
						funx.addPosRect(renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex], testing)
						
						renderXMLresult:insert(renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex])
						anchorZero(renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex], "BottomLeft")
						renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex] = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex] or { text = "", ascent = ascent, }
					end
					
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].ascent = max( renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].ascent, ascent)
					
					renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex]:insert(obj)
					
					obj.x = x + settings.currentXOffset

					-- Set the line at it's baseline, by using the Font's Ascent value
					-- The settings.yOffset is used for superscript/subscript
					obj.y = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].ascent - settings.yOffset

					renderXMLvars.renderedLines[renderXMLvars.currentRenderedLineIndex].y = lineY
					
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].text = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].text .. text

					-- Can't just save the settings table b/c Lua doesn't 'copy' tables by assigning to a new variable!
					-- Lines with sub-elements might have these values already set. Don't overwrite!
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].rightIndent = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].rightIndent or settings.rightIndent
					
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].leftIndent = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].leftIndent or settings.leftIndent

					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].firstLineIndent = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].firstLineIndent or settings.currentFirstLineIndent

					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].textAlignment = renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].textAlignment or textAlignment
					
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].currentWidth = settings.currentWidth
					
					renderXMLvars.renderedLinesStats[renderXMLvars.currentRenderedLineIndex].width = settings.width
					
					return obj.x, obj.y

				end
				
										

				local function renderParsedText(parsedText, tag, attr, parseDepth, stacks)
				
					local tempvar = {} -- to get around more than 60 upvalues?

					-- The rendered text with multiple lines in it
					local renderParsedTextResult = display.newGroup()
					
					parseDepth = parseDepth or 0
					parseDepth = parseDepth + 1
					
					-- Be sure the tag is lowercase for comparisons!
					tag = lower(tostring(tag))

					-- Init stacks
					stacks = stacks or { list = { ptr = 0 } }


					------------------------------------------------------------
					-- Function to render one parsed XML element, i.e a block of text
					-- An element would be, for example: <b>piece of text</b>
					------------------------------------------------------------
					local function renderParsedElement(elementNum, element, tag, attr, renderIfEmpty)

							local tempLineWidth, words
							local firstWord = true
							local words
							local nextChunk, nextChunkLen
							local cachedChunk
							local cachedChunkIndex = 1
							local tempDisplayLineTxt
							local renderParsedElementResult, resultPosRect
							local tempLine, allTextInLine
							local wordlen = 0
							

							-- =======================================================
							-- FUNCTIONS
							-- =======================================================
							
							-- =======================================================
							-- <A> tag box. If we make the text itself touchable, it is easy to miss it...your touch
							-- goes through the white spaces around letter strokes!
							-- This also should let us position text in a space, e.g. centered?
							local function createLinkingBox(newDisplayLineGroup, newDisplayLineText, alttext, testBkgdColor )
								
								if (testing) then

									testBkgdColor = testBkgdColor or {1,1,0.5,0.2}
									local firstLineColor =  {1,0,0, 0.2}
									local onFirstLineColor = firstLineColor or {0,1,0, 0.2}
									local otherLinesColor = {0, 0, 1, 0.2}

									-- when drawing the box, we compensate for the stroke, thus -2
									local r = display.newRect(newDisplayLineGroup, 0, 0, newDisplayLineText.width-2, newDisplayLineText.height-2)
									r.strokeWidth=1
									anchor(r, "BottomLeft")
									r.x = newDisplayLineText.x+1
									r.y = newDisplayLineText.y+1
									
									-- FALSE = show first line values, TRUE = show A or C render 
									if (false) then
										if (settings.elementOnFirstLine) then
											r:setStrokeColor( unpack (onFirstLineColor) )
											r:setFillColor(unpack(onFirstLineColor))
										elseif (settings.isFirstLine) then
											r:setStrokeColor( unpack (firstLineColor) )
											r:setFillColor(unpack(firstLineColor))
										else
											r:setStrokeColor( unpack (otherLinesColor) )
											r:setFillColor(unpack(otherLinesColor))
										end
									else
										r:setFillColor(unpack(testBkgdColor))
									end


									r.isVisible = testing
								end

								if (tag == "a") then
									local touchme = touchableBox(newDisplayLineGroup, "BottomLeft", 0, 0,  newDisplayLineText.width-2, renderXMLvars.fontInfo.capheight * settings.size, hyperlinkFillColor)

									attr.text = alttext
									attachLinkToObj(newDisplayLineGroup, attr, settings.handler)
								end
							end

							
							-- =======================================================
							-- =======================================================
							
							nextChunk = element or ""
							nextChunkLen = strlen(nextChunk)

							-- Apply the tag, e.g. bold or italic
							if (tag) then
								setStyleFromTag (tag, attr)
							end

							-- Do not render empty elements or an element that is just a space
							-- MUST return an empty table!
							if (not renderIfEmpty and ( not element or element == " " ) ) then
								return {}
							end
							
							baseline, descent, ascent = getFontAscent(baselineCache, settings.font, settings.size)

							-- If we're at the very first line of a text block, these
							-- start at the Ascent, following InDesign defaults.
							if (settings.isFirstTextInBlock) then
								lineY = ascent
								settings.isFirstTextInBlock = false
							end

							-- Set the current width of the column, factoring in indents
							-- Need the width to figure out how many words fit.
							settings.currentWidth = settings.width - settings.leftIndent - settings.rightIndent - settings.currentFirstLineIndent


							------------------------------------------------
							-- Refigure font metrics if font has changed
							------------------------------------------------
							if (settings.font ~= prevFont or settings.size ~= prevSize) then

								baseline, descent, ascent = getFontAscent(baselineCache, settings.font, settings.size)

								prevFont = settings.font
								prevSize = settings.size
							end
							------------------------------------------------

							----------------
							-- IF this is the first line of the text box, figure out the corrections
							-- to position the ENTIRE box properly (yAdjustment).
							-- The current line height is NOT the leading/lineheight as with other lines,
							-- since the box should start at the Cap Height (ascender).

							------
							-- Calc the adjustment so we position text at its baseline, not top-left corner
							-- For rendering using Reference Point TopLeft
							--descent = 0

							------------------------------------------------
							-- RENDER TEXT OBJECT
							------------------------------------------------
							--[[
							 Render a chunk of the text object.
							 Requires all the nice closure variables, so we can't move this very well...
							 This could be a paragraph <p>chunk</p> or a piece of text in a paragraph (<span>chunk</span>)
							 So, we don't know if this requires an end-of-line at the end!

							 A chunk to render is ALWAYS pure text. All HTML formatting is outside it.
							
							Lua REGEX:
							() captures
							[] defines a class, i.e. characters in this class
							^ negates the class, i.e. characters not in this class

							--]]



							renderParsedElementResult = display.newGroup()
							renderParsedElementResult.anchorX, renderParsedElementResult.anchorY = 0, 0

							renderXMLvars.textDisplayReferencePoint = "BottomLeft"
							
							local _, padding
							-- In the rare, rare case that our chunk of text is a single hyphen,
							-- which happens if you make some sort of mathematical formula,
							-- we have to capture it differently.
							local isSingleHyphen = string.match(nextChunk, '^%s-(%-)%s-')

							-- Preserve initial padding before first word
							-- This captures spaces and hyphens!
							if (not isSingleHyphen) then
								_, _, padding = find(nextChunk, "^([%s%-]*)")
							end

							padding = padding or ""

							-- Get chunks of text to iterate over to figure out line line wrap

							-- If the line wrapping is cached, get it
							if (textwrapIsCached) then
								cachedChunk = cache[cacheIndex]
								--words = gmatch(cachedChunk.text, "[^\r\n]+")
								cachedChunk = cachedChunk or { text = {}, item = {}, }
								words = iteratorOverCacheText(cachedChunk.text)
							else
								cachedChunk = newCacheChunk()
								
								-- So, ([^%s%-]+)([%s%-]*) ==> all non-space, non-hyphens followed by spaces or hyphens
								if (not isSingleHyphen) then
									words = gmatch(nextChunk, "([^%s%-]+)([%s%-]*)")
								else
									-- So, ([^%s]+)([%s]*) ==> all non-space followed by spaces
									words = gmatch(nextChunk, "([^%s]+)([%s]*)")
								end
							end
							

-- ============================================================
-- CACHED RENDER
-- ============================================================

							if (textwrapIsCached) then
								if (testing) then
									print ("********** Rendering from cache.")
								end
								for cachedChunkIndex, text in pairs(cachedChunk.text) do

									local cachedItem = getCachedChunkItem(cachedChunk, cachedChunkIndex)
									
									-- Cached values
									settings.isFirstLine = cachedItem.isFirstLine
									settings.elementOnFirstLine = cachedItem.elementOnFirstLine

									lineHeight = cachedItem.lineHeight
									renderXMLvars.currentRenderedLineIndex = cachedItem.currentRenderedLineIndex
									lineY = cachedItem.lineY
									x = cachedItem.x
									textAlignment = cachedItem.textAlignment
									renderTextFromMargin = cachedItem.renderTextFromMargin
									currentLineHeight = cachedItem.currentLineHeight

									settings.currentFirstLineIndent = cachedItem.currentFirstLineIndent
									settings.leftIndent = cachedItem.leftIndent
									settings.rightIndent = cachedItem.rightIndent
									-- We capture the x-position, so we don't need this which is used by addToCurrentRenderedLine
									settings.currentXOffset = 0
		
									renderXMLvars.textDisplayReferencePoint = "BottomLeft"
		
									local newDisplayLineGroup = display.newGroup()

									local newDisplayLineText = display.newText({
										parent = newDisplayLineGroup,
										text = text,
										x = 0, y = 0,
										font = cachedItem.font,
										fontSize = cachedItem.fontSize,
										align = "left",
									})

									newDisplayLineText:setFillColor(unpack(cachedItem.color))
									anchorZero(newDisplayLineText, "BottomLeft")

									addToCurrentRenderedLine(newDisplayLineGroup, x, lineY, textAlignment, settings, text)

									createLinkingBox(newDisplayLineGroup, newDisplayLineText, currentLine, {250,0,250,30} )
									
									-- Legacy for non-HTML formatted lines of text
									lineCount = lineCount + 1
		
									if (not yAdjustment or yAdjustment == 0) then
										yAdjustment = ( (settings.size / renderXMLvars.fontInfo.sampledFontSize ) * renderXMLvars.fontInfo.textHeight)- newDisplayLineGroup.height
									end


								end -- for
	
								cacheIndex = cacheIndex + 1
							else

-- ============================================================
-- UNCACHED RENDER (writes to cache)
-- ============================================================


--								if (testing) then
--									print ("Rendering from XML, not cache.")
--									print ("")
--									print ("")
--								end

							---------------------------------------------
								--local word,spacer
								local word, spacer, longword
								for word, spacer in words do
									if (not textwrapIsCached) then
										if (firstWord) then
											word = padding .. word
											firstWord = false
										end

										tempLine = currentLine..renderXMLvars.shortword..word..spacer

									else
										spacer = ""
										tempLine = word
										--currentLine = word
									end
									allTextInLine = prevTextInLine .. tempLine
									tempLine = setCase(settings.case, tempLine)

									-- Grab the first words of the line, until "minLineCharCount" hit
									if (strlen(allTextInLine) > settings.minLineCharCount) then
										-- Allow for lines with beginning spaces, for positioning
										if (usePeriodsForLineBeginnings and substring(currentLine,1,1) == ".") then
											currentLine = substring(currentLine,2,-1)
										end

										-- If a word is less than the minimum word length, force it to be with the next word,so lines don't end with single letter words.
										-- What was this check for? It causes single-letter lines to be lost:
										-- if ((strlen(allTextInLine) < nextChunkLen) and strlen(word) < settings.minWordLen) then
										if (strlen(word) < settings.minWordLen) then
											renderXMLvars.shortword = renderXMLvars.shortword..word..spacer
										else

											-- ===================================
											-- TEST LINE: Render a test line of text
											-- ===================================
											local firstLineIndent, leftIndent, rightIndent

											if (settings.elementOnFirstLine) then
												firstLineIndent = settings.firstLineIndent
											end
										
											local tempLineTrimmed = tempLine
											if (renderTextFromMargin) then
												tempLineTrimmed = trimToAlignment(tempLine, textAlignment)
											end

											-- Draw the text as a line.								-- Trim based on alignment!
											tempDisplayLineTxt = display.newText({
												text = tempLineTrimmed,
												x=0,
												y=0,
												font = settings.font,
												fontSize = settings.size,
											})

											anchor(tempDisplayLineTxt, "TopLeft")										
											tempDisplayLineTxt.x = 0
											tempDisplayLineTxt.y = 0

											tempLineWidth = tempDisplayLineTxt.width

											-- Is this line of text too long? In which case we render the line
											-- as text, then move down a line on the screen and start again.
											if (renderTextFromMargin) then
												tempLineWidth = tempDisplayLineTxt.width

												if (settings.isFirstTextInBlock or settings.elementOnFirstLine) then
													settings.currentFirstLineIndent = settings.firstLineIndent
												else
													settings.currentFirstLineIndent = 0
												end
											else
												tempLineWidth = tempDisplayLineTxt.width + settings.currentXOffset
											end

											display.remove(tempDisplayLineTxt);
											tempDisplayLineTxt=nil;


											-- ===================================
																						
											-- This text may be an element inside a first line, so we must include the currentFirstLineIndent to calc the current line width.
											-- Since indents may change per line, we have to reset this each time.
											settings.currentWidth = settings.width - settings.leftIndent - settings.rightIndent - settings.currentFirstLineIndent
											if (tempLineWidth <= settings.currentWidth * widthCorrection)  then
												-- Do not render line, unless it is the last word,
												-- in which case render ("C" render)
												currentLine = tempLine
											else
										
												if ( settings.maxHeight==0 or (lineY <= settings.maxHeight - currentLineHeight)) then

													-- It is possible the first word is so long that it doesn't fit
													-- the margins (a 'B' line render, below), and in that case, the currentLine is empty.
													if (strlen(currentLine) > 0) then

		-- ============================================================
		-- A: Render text that fills the entire line, that will continue on a following line.
		-- This line always has text that continues on the next line.
		-- ============================================================



--		if (testing) then
--			print ()
--			print ("----------------------------")
--			print ("A: Render line: ["..currentLine .. "]")
----			print ("renderXMLvars.currentRenderedLineIndex:", renderXMLvars.currentRenderedLineIndex)
----			print ("Font: [".. settings.font .. "]")
--			print ("settings.currentWidth",settings.currentWidth)
--			print ("settings.isFirstLine", settings.isFirstLine)
--			print ("settings.elementOnFirstLine", settings.elementOnFirstLine)
--			print ("settings.isFirstTextInBlock", settings.isFirstTextInBlock)
--			print ("renderTextFromMargin: ", renderTextFromMargin)
--			print ("lineY = ",lineY)
--			-- print ("   newDisplayLineGroup.y = ",lineY + descent .. " + " .. descent)
--		end

														if (settings.isFirstLine) then
															currentLineHeight = lineHeight
															settings.currentSpaceBefore = settings.spaceBefore
															settings.isFirstLine = false
															settings.currentFirstLineIndent = settings.firstLineIndent
														else
															currentLineHeight = lineHeight
															settings.currentSpaceBefore = 0
															settings.currentFirstLineIndent = 0
														end


														if (renderTextFromMargin) then
															if (textAlignment == "Left") then
																currentLine = ltrim(currentLine)
															end
															settings.currentLeftIndent = settings.leftIndent
															settings.currentXOffset = 0
														else
															settings.currentFirstLineIndent = 0
															settings.currentLeftIndent = 0
														end
													
														-- This line always goes to the right margin, so you
														-- can always trim it on the right.
														currentLine = rtrim(currentLine)
														currentLine = setCase(settings.case, currentLine)

														local newDisplayLineGroup = display.newGroup()

														local newDisplayLineText = display.newText({
															parent=newDisplayLineGroup,
															text=currentLine,
															x=0, y=0,
															font=settings.font,
															fontSize = settings.size,
															align = "left",
														})
														newDisplayLineText:setFillColor(unpack(settings.color))
														anchorZero(newDisplayLineText, "BottomLeft")

														if (renderTextFromMargin) then
															renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
														end

														addToCurrentRenderedLine(newDisplayLineGroup, x, lineY, textAlignment, settings, currentLine)
													
														-- CACHE this line
														if (not textwrapIsCached) then
															updateCachedChunk (cachedChunk, { 
																		text = currentLine,

																		index = cachedChunkIndex, 
																		width = settings.width,
																		x = newDisplayLineGroup.x,
																		y = newDisplayLineGroup.y,
																		font=settings.font,
																		fontSize = settings.size,
																		textAlignment = textAlignment,
																		color = settings.color,
																		lineHeight = lineHeight,
																		lineY = lineY,
																	
																		currentLineHeight = currentLineHeight,																	
																		currentSpaceBefore = settings.currentSpaceBefore,
																		currentLeftIndent = settings.currentLeftIndent,
																		currentFirstLineIndent = settings.currentFirstLineIndent,
																	
																		leftIndent = settings.leftIndent,
																		rightIndent = settings.rightIndent,

																	
																		currentXOffset = settings.currentXOffset,

																		renderTextFromMargin = renderTextFromMargin,
																		isFirstLine = settings.isFirstLine,
																		elementOnFirstLine = settings.elementOnFirstLine,

																		currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex,
																	})
														end

														renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1

														-- Update cache chunk index counter
														cachedChunkIndex = cachedChunkIndex + 1



														lineCount = lineCount + 1

														-- Use once, then set to zero.
														settings.currentFirstLineIndent = 0

														-- Use the current line to estimate how many chars
														-- we can use to make a line.
														if (not renderXMLvars.fontInfo.maxHorizontalAdvance) then
															settings.minLineCharCount = strlen(currentLine)
														end
														
														-- Carry over the shortword at the end of the line, e.g. "a"
														-- the next line by adding it to the current word.
														word = renderXMLvars.shortword..word

														-- We have wrapped, don't need text from previous chunks of this line.
														prevTextInLine = ""

														-- If next word is not too big to fit the text column, start the new line with it.
														-- Otherwise, make a whole new line from it. Not sure how that would help.
														wordlen = 0
														if (textwrapIsCached) then
															wordlen = cachedChunk.width[cachedChunkIndex]
														elseif ( word ~= nil ) then
															wordlen = strlen(word) * (settings.size * renderXMLvars.fontInfo.maxCharWidth)
														
															local tempWord = display.newText({
																 text=word,
																 x=0, y=0,
																 font=settings.font,
																 fontSize = settings.size,
															 })
															 wordlen = tempWord.width
															 tempWord:removeSelf()
															 tempWord =  nil
						
														else
															 wordlen = 0
														end

														-- <A> tag box. If we make the text itself touchable, it is easy to miss it...your touch
														-- goes through the white spaces around letter strokes!
														createLinkingBox(newDisplayLineGroup, newDisplayLineText, currentLine )

														-- This line has now wrapped around, and the next one should start at the margin.
														renderTextFromMargin = true
														settings.currentXOffset = 0

														-- And, we should now move our line cursor to the next row.
														-- We know nothing can continue on this line because we've filled it up.
														lineY = lineY + currentLineHeight
														settings.elementOnFirstLine = false

														-- Text lines can vary in height depending on whether there are upper case letters, etc.
														-- Not predictable! So, we capture the height of the first line, and that is the basis of
														-- our y adjustment for the entire block, to position it correctly.
														if (not yAdjustment or yAdjustment == 0) then
															--yAdjustment = (settings.size * renderXMLvars.fontInfo.ascent )- newDisplayLineGroup.height
															yAdjustment = ( (settings.size / renderXMLvars.fontInfo.sampledFontSize ) * renderXMLvars.fontInfo.textHeight)- newDisplayLineGroup.height
														end




													else
														--longword = true
														renderTextFromMargin = true
														settings.currentXOffset = 0
														lineY = lineY + currentLineHeight
														settings.elementOnFirstLine = false
													end


													-- --------
													-- END 'A' RENDER
													-- --------




													if (textwrapIsCached or (not longword and wordlen <= settings.currentWidth * widthCorrection) ) then

														if (textwrapIsCached) then
															currentLine = word
														else
															currentLine = word..spacer
														end
													else
														currentLineHeight = lineHeight

	-- ----------------------------------------------------
	-- ----------------------------------------------------
	-- B: The word at the end of a line is too long to fit the text column! Very rare.
	-- Example: <span>Cows are nice to <span><span>elep|hants.<span>
	-- Where | is the column end.
	-- ----------------------------------------------------
	-- ----------------------------------------------------

														word = word

														if (textwrapIsCached) then
															currentLine = word
	--													else
	--														cachedChunk.text[cachedChunkIndex] = word
	--														cachedChunk.width[cachedChunkIndex] = wordlen
														end
														--cachedChunkIndex = cachedChunkIndex + 1

	--print ("B")
--	if (testing) then
--		print ()
--		print ("----------------------------")
--		print ("B: render a word: "..word)
--		print ("\nrenderTextFromMargin reset to TRUE.")
--		print ("settings.isFirstLine", settings.isFirstLine)
--		print ("   newDisplayLineGroup.y",lineY + descent, descent)
--		print ("leftIndent + currentFirstLineIndent", settings.leftIndent, settings.currentFirstLineIndent, settings.currentXOffset)
--	end

														if (settings.isFirstLine) then
															currentLineHeight = lineHeight
															settings.currentSpaceBefore = settings.spaceBefore
															settings.isFirstLine = false
															settings.currentFirstLineIndent = settings.firstLineIndent
														else
															currentLineHeight = lineHeight
															settings.currentSpaceBefore = 0
															settings.currentFirstLineIndent = 0
														end


														if (renderTextFromMargin) then
															if (textAlignment == "Left") then
																currentLine = ltrim(currentLine)
															end
															currentLine = trimToAlignment(currentLine, textAlignment)
															settings.currentLeftIndent = settings.leftIndent
															settings.currentXOffset = 0
														else
															settings.currentFirstLineIndent = 0
															settings.currentLeftIndent = 0
														end

														currentLine = rtrim(currentLine)
														currentLine = setCase(settings.case, currentLine)

														local newDisplayLineGroup = display.newGroup()
														--newDisplayLineGroup.anchorChildren = true
													
														local newDisplayLineText = display.newText({
															parent = newDisplayLineGroup,
															text = word,
															x = 0, y = 0,
															font = settings.font,
															fontSize = settings.size,
														})

														newDisplayLineText:setFillColor(unpack(settings.color))
														anchorZero(newDisplayLineText, renderXMLvars.textDisplayReferencePoint)
														--newDisplayLineText.x, newDisplayLineText.y = 0, 0
														--newDisplayLineText.alpha = settings.opacity

														if (renderTextFromMargin) then
															renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
														end

														addToCurrentRenderedLine(newDisplayLineGroup, x, lineY, textAlignment, settings, word)
													
														-- CACHE this line
														if (not textwrapIsCached) then
															updateCachedChunk (cachedChunk, { 
																		text = word,

																		index = cachedChunkIndex, 
																		width = settings.width,
																		x = newDisplayLineGroup.x,
																		y = newDisplayLineGroup.y,
																		font=settings.font,
																		fontSize = settings.size,
																		textAlignment = textAlignment,
																		color = settings.color,
																		lineHeight = lineHeight,
																		lineY = lineY,
																	
																		currentLineHeight = currentLineHeight,																	
																		currentSpaceBefore = settings.currentSpaceBefore,
																		currentLeftIndent = settings.currentLeftIndent,
																		currentFirstLineIndent = settings.currentFirstLineIndent,
																	
																		leftIndent = settings.leftIndent,
																		rightIndent = settings.rightIndent,

																	
																		currentXOffset = settings.currentXOffset,

																		renderTextFromMargin = renderTextFromMargin,
																		isFirstLine = settings.isFirstLine,
																		elementOnFirstLine = settings.elementOnFirstLine,

																		currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex,
																	})
														end
													
														renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
														lineCount = lineCount + 1
														currentLine = ''

														-- Use once, then set to zero.
														settings.currentFirstLineIndent = 0

														-- <A> tag box. If we make the text itself touchable, it is easy to miss it...your touch
														-- goes through the white spaces around letter strokes!
														createLinkingBox(newDisplayLineGroup, newDisplayLineText, currentLine, {250,0,250,30} )

														cachedChunkIndex = cachedChunkIndex + 1


														-- This is a line too long to fit,
														-- so the next line surely must be the beginning
														-- a new line. We know nothing can continue on this line because we've filled it up.
														lineY = lineY + currentLineHeight
														settings.elementOnFirstLine = false

														renderTextFromMargin = true
														settings.currentXOffset = 0

													end	-- end B




													-- Get min characters to start with
													-- We now know the max char width in a font,
													-- so we can start with a minimum based on that.
													-- IF the metric was set!
													if (not textwrapIsCached and not renderXMLvars.fontInfo.maxHorizontalAdvance) then
														-- Get stats for next line
														-- Set the new min char count to the current line length, minus a few for protection
														-- (20 is chosen from a few tests)
														settings.minLineCharCount = max(settings.minLineCharCount - 20,1)
													end

												end
											end
											renderXMLvars.shortword = ""
										end

									else
										currentLine = tempLine
									end
								end -- for

								---------------------------------------------
								-- end for
								---------------------------------------------

								currentLine = currentLine .. renderXMLvars.shortword
								renderXMLvars.shortword = ""

								-- Allow for lines with beginning spaces, for positioning
								if (usePeriodsForLineBeginnings and substring(currentLine,1,1) == ".") then
									currentLine = substring(currentLine,2,-1)
								end

	---------------------------------------------
	-- C: line render
	-- C: SHORT LINE or FINAL LINE OF PARAGRAPH
	-- Add final line that didn't need wrapping
	-- (note, we add a space to the text to deal with a weirdo bug that was deleting final words. ????)
	---------------------------------------------

								-- IF content remains, render it.
								-- It is possible get the tailing space of block
								if (strlen(currentLine) > 0) then


--if (testing) then
--	print ()
--	print ("----------------------------")
--	print ("C: Final line: ["..currentLine.."]", "length=" .. strlen(currentLine))
----										print ("Font: [".. settings.font .. "]")
----										print ("renderXMLvars.currentRenderedLineIndex:", renderXMLvars.currentRenderedLineIndex)
--	print ("lineY = ",lineY)
--	print ("settings.isFirstLine", settings.isFirstLine)
--	print ("settings.isFirstTextInBlock", settings.isFirstTextInBlock)
--	print ("renderTextFromMargin: ", renderTextFromMargin)
--	print ("Width,", settings.width)
--	print ("settings.currentWidth", settings.currentWidth)
----										print ("textAlignment: ", textAlignment)
----										print ("lineHeight: ", lineHeight)
--
--end

								
									if (settings.isFirstLine) then
										currentLineHeight = lineHeight
										settings.currentSpaceBefore = settings.spaceBefore
										settings.currentFirstLineIndent = settings.firstLineIndent
									else
										currentLineHeight = lineHeight
										settings.currentSpaceBefore = 0
										if (not settings.elementOnFirstLine) then
											settings.currentFirstLineIndent = 0
										end
									end

									if (renderTextFromMargin) then
										currentLine = ltrim(currentLine)
										settings.currentXOffset = 0
										settings.currentLeftIndent = settings.leftIndent
									elseif (not settings.elementOnFirstLine ) then
										settings.currentFirstLineIndent = 0
										settings.currentLeftIndent = 0
									end


									local newDisplayLineGroup = display.newGroup()
								
									currentLine = setCase(settings.case, currentLine)
--if (testing) then
--	print ("renderParsedElement: (C) : Substitutions in current line with 'settings' table values.")
--	currentLine = funx.substitutions (currentLine, settings)
--end
									
									local newDisplayLineText = display.newText({
										parent = newDisplayLineGroup,
										text = currentLine,
										x = 0, y = 0,
										font = settings.font,
										fontSize = settings.size,
										align = "left",
									})

									newDisplayLineText:setFillColor(unpack(settings.color))
									anchorZero(newDisplayLineText, "BottomLeft")

									if (renderTextFromMargin and not settings.isFirstLine) then
										renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
									end

									addToCurrentRenderedLine(newDisplayLineGroup, x, lineY, textAlignment, settings, currentLine)

									-- CACHE this line
									if (not textwrapIsCached) then
										updateCachedChunk (cachedChunk, { 
													text = currentLine,
							
													index = cachedChunkIndex, 
													width = settings.width,
													x = newDisplayLineGroup.x,
													y = newDisplayLineGroup.y,
													font=settings.font,
													fontSize = settings.size,
													textAlignment = textAlignment,
													color = settings.color,
													lineHeight = lineHeight,
													lineY = lineY,
												
													currentLineHeight = currentLineHeight,																	
													currentSpaceBefore = settings.currentSpaceBefore,
													currentLeftIndent = settings.currentLeftIndent,
													currentFirstLineIndent = settings.currentFirstLineIndent,
												
													leftIndent = settings.leftIndent,
													rightIndent = settings.rightIndent,

												
													currentXOffset = settings.currentXOffset,

													renderTextFromMargin = renderTextFromMargin,
													isFirstLine = settings.isFirstLine,
													elementOnFirstLine = settings.elementOnFirstLine,


													currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex,
												})
									end

									-- Corona is adding extra width, I think, so we remove 1.5 pixel around!!!
									settings.currentXOffset = settings.currentXOffset + newDisplayLineText.width - 3
									
									cachedChunkIndex = cachedChunkIndex + 1




									-- Save the current line if we started at the margin
									-- So the next line, if it has to, can start where this one ends.
									prevTextInLine = prevTextInLine .. currentLine

									-- Since line heights are not predictable, we capture the yAdjustment based on
									-- the actual height the first rendered line of text
									if (not yAdjustment or yAdjustment == 0) then
										--yAdjustment = (settings.size * renderXMLvars.fontInfo.ascent )- newDisplayLineGroup.height
										yAdjustment = ( (settings.size / renderXMLvars.fontInfo.sampledFontSize ) * renderXMLvars.fontInfo.textHeight)- newDisplayLineGroup.height
									end

									createLinkingBox(newDisplayLineGroup, newDisplayLineText, currentLine, {1,0,0,0.3})

--print ("2702 settings.isFirstLine, settings.elementOnFirstLine, lineY: ", settings.isFirstLine, settings.elementOnFirstLine, lineY, "C: Final line: ["..currentLine.."]")

									settings.isFirstLine = false
									renderTextFromMargin = false

									-- Clear the current line
									currentLine = ""

								end
							
								if (not textwrapIsCached) then
									cache[cacheIndex] = cachedChunk
								end
								cacheIndex = cacheIndex + 1							
						end -- cached/not cached if

						return renderParsedElementResult


					end -- renderParsedElement()
					
					-- ================================================
					-- END renderParsedElement()
					-- ================================================

					-- save the style settings as they are before
					-- anything modifies them inside this tag.

					local styleSettings = getAllStyleSettings()
					
					-- Convert h1, h2, etc. into <p class="h1">, etc.
					--tag, attr = convertHeaders(tag, attr)
					
					-- Be sure the tag isn't null
					tag = tag or ""
					
					------------------------------------------------------------
					-- Handle formatting tags: p, div, br
					-- This is the opening tag, so we add space before and stuff like that.
					------------------------------------------------------------



							-- New line, Carriage Return
							-- @param tag Name of the current tag, for testing display
							-- @param pos Add current spacing before or after this CR
							local function CRLF( pos, tag)
								
								pos = pos or "After"
								lineY = lineY + lineHeight + settings["space"..pos]
								--print (tag.." : CRLF ("..pos..") before/after, lineheight",settings["spaceBefore"], settings["spaceAfter"], lineHeight)
							end
							
							local function renderHR()
								-- Set style to HR
								setStyleFromCommandLine (textstyles.hr or textstyles.body)

								tempvar.hrLineSize = attr.size or (convertValuesToPixels(attr.height) or 1)
								tempvar.width = applyPercent(attr.width, width) or width
								tempvar.width = tempvar.width

								local hrg = display.newGroup()
								funx.addPosRect(hrg, testing)

								local hr = display.newRect(hrg, 0, 0, tempvar.width, tempvar.hrLineSize)
								funx.anchor(hr, "BottomLeft")
								hr:setFillColor(0,0,0,1)
								
								addToCurrentRenderedLine(hrg, x, lineY, "Center", settings, "---")
							end

					
					-- ================================================
					-- NON-HTML : Move down a line using current lineheight.
					-- ================================================
					if (not settings.isHTML) then
						CRLF( "Before" )

						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.isFirstLine = true
						settings.currentLeftIndent = 0
						settings.currentFirstLineIndent = 0
						x = 0
					end
					
					
					-- ================================================
					-- Tags reset margins
					-- ================================================
					-- Note, we treat <li> as a block, which is not standard HTML!

					if ( isBlockTag[tag] ) then 

						-- Reset margins, cursor, etc. to defaults
						settings.elementOnFirstLine = true
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.currentLeftIndent = 0
						settings.currentFirstLineIndent = 0
						settings.leftIndent = 0
						settings.rightIndent = 0
						x = 0
						
						-- Apply style based on tag, e.g. <ol> or <p>
						if (textstyles and textstyles[tag] ) then
							local params = textstyles[tag]
							setStyleFromCommandLine (params)
						end
						
						-- Next, apply style settings
						local styleName = "body"
						if (attr.class) then
							styleName = lower(attr.class)
							if (textstyles and textstyles[styleName] ) then
								setStyleFromCommandLine ( textstyles[styleName] )
							else
								print ("WARNING: funx.autoWrappedText tried to use a missing text style ("..styleName..")")
							end
						end
						setStyleFromTag (tag, attr)

						settings.currentSpaceBefore = settings.spaceBefore
						settings.currentSpaceAfter = settings.spaceAfter

						if (tag == "ol" or tag == "ul" ) then
						-- ================================================
						-- LISTS: OL/UL
						-- ================================================
							-- Nested lists require left indentation
							-- Left indent starting at 2nd level

							stacks.list.ptr =  stacks.list.ptr + 1
							local b = ""
							if (tag == "ul") then
								if (attr.bullet == "disc") then
									b = "&#9679;"
								elseif (attr.b == "square") then
									b = "&#9632;"
								elseif (attr.bullet == "circle") then
									b = "&#9675;"
								elseif (attr.bullet == "triangle") then
									b = "&#9658;"
								elseif (attr.bullet == "dash") then
									b = "&#8211;"
								elseif (attr.bullet == "mdash") then
									b = "&#8212;"
								elseif (attr.bullet == "none") then
									b = ""
								elseif (attr.bullet == nil) then
									b = "&#9679;"
								elseif (attr.bullet ~= "") then
									b = attr.bullet
								end
								b = entities.convert(b)
							end
							stacks.list[stacks.list.ptr] = { tag = tag, 
										line = 1,
										counter = 0,
										bullet = b, 
										indent = settings.listIndent * (stacks.list.ptr - 1),
										leftIndent = settings.leftIndent or 0, 
										rightIndent = settings.rightIndent or 0,
										padding = convertValuesToPixels(attr.padding),
										}
						elseif  (tag == "li") then
						-- ================================================
						-- LI tag
						-- LIST ITEMS: add a bullet or number
						-- Note, we treat the LI like a block, which is always standard.
						-- ================================================

							-- ----------
							-- Create the LI block

							stacks.list[stacks.list.ptr].counter = stacks.list[stacks.list.ptr].counter + 1

							-- Apply a 'value' attribute <li value="10" ...
							if (attr.value) then
								stacks.list[stacks.list.ptr].line = tonumber(attr.value)
							end

							stacks.list[stacks.list.ptr] = stacks.list[stacks.list.ptr] or {}
							-- default for list is a disk.
							tempvar.bulletText = ""
							-- If number, use the number instead
							if (stacks.list[stacks.list.ptr].tag == "ol" ) then
								tempvar.bulletText = stacks.list[stacks.list.ptr].line .. ". " or ""
								stacks.list[stacks.list.ptr].line = stacks.list[stacks.list.ptr].line + 1
							else
								tempvar.bulletText = stacks.list[stacks.list.ptr].bullet or ""
							end
						
							if ( stacks.list[stacks.list.ptr].indent > 0 ) then
								settings.leftIndent = settings.leftIndent  + stacks.list[stacks.list.ptr].indent
							end
							
							if (tempvar.bulletText) then
								-- get x ptr before adding the bullet
								local xptr = settings.currentXOffset
								tempvar.bullet = renderParsedElement(1, tempvar.bulletText, "", "")
								local bw = settings.currentXOffset - xptr

								-- Use 'padding' to set space after bullet. Crude but close to HTML
								local spaceAfterBullet
								if (attr.padding) then
									spaceAfterBullet = convertValuesToPixels(attr.padding)
								elseif (stacks.list[stacks.list.ptr].padding) then
									spaceAfterBullet = tonumber(stacks.list[stacks.list.ptr].padding)
								else
									-- note: settings.listExtraSpaceAfterBullet is a constant, set at beginning
									spaceAfterBullet = max(settings.size * 3 - (settings.currentXOffset - xptr), settings.listExtraSpaceAfterBullet,0)
								end

								-- Create space after the bullet on the first line of text
								settings.currentXOffset = settings.currentXOffset  + spaceAfterBullet
								settings.leftIndent = spaceAfterBullet + bw
							end

						elseif (tag == "hr") then
						-- ================================================
						-- HR tag
						-- ================================================
						--CRLF( "Before", tag )

						end

					elseif (tag == "br") then
					-- ================================================
					-- BR tag
					-- BR is NOT a block tag!
					-- ================================================
--						renderTextFromMargin = true
--						settings.currentXOffset = 0
--						settings.currentLeftIndent = 0
--						settings.currentFirstLineIndent = 0
--						x = 0


					-- ================================================
					-- Tags that do not reset margins
					-- ================================================
 					elseif (tag == "a") then
						-- Always use hyperlinkTextColor for the hyperlink text
						-- NO. InDesign doesn't let us use a <span> to color the text, but it does let us surround the <a>
						-- with a <span>. I mean, that's how the conversion comes in.
						-- So, let's require that we color links by hand (or by InDesign)
						-- Unless we pass the hyperlinkTextColor!

						-- Apply style based on textstyles "a" value, if it exists.
						if ( textstyles[tag] ) then
							setStyleFromCommandLine ( textstyles[tag] )
						elseif (hyperlinkTextColor) then 
							-- parens are parsed by setStyleFromTag()
							attr.color = "(" .. hyperlinkTextColor .. ")"	
						end

					-- Ignore <style> and <script> blocks.
					elseif (tag == "style" or tag == "script" or tag=="head" ) then
						parsedText = {}

					elseif (tag == "img") then
						renderTextFromMargin = true
						settings.currentXOffset = 0
						lineY = lineY + settings.currentSpaceAfter
						x = 0
						if (attr.src ) then
							attr.directory = attr.directory or "ResourceDirectory"
							-- replace "*" wildcard with location of the book, if provided
							if (sourcePath) then
								attr.src = funx.replaceWildcard(attr.src, sourcePath)
							end
							if (funx.fileExists( attr.src,  system[attr.directory] )) then
								local image = funx.loadImageFile( attr.src, nil, system[attr.directory] )
								anchor(image, "TopLeft")
								if ( attr.width or attr.height) then
									funx.ScaleObjToSize (image, applyPercent(attr.width, width), attr.height)
								end
								lineY = lineY + image.contentHeight - lineHeight
								addToCurrentRenderedLine(image, x, lineY, textAlignment, settings, attr.src)
							else
								local e = renderParsedElement(1, "Missing picture: "..attr.src, "", "")
								-- renderParsedElement does this already:
								--addToCurrentRenderedLine(e, x, lineY, textAlignment, settings, attr.src)
							end
						end
					end
					


					-- -------------------------------------------------------
					-- Block-level elements start on a new line (HTML spec's)
					-- If we treat <li> as a block, then we can't treat a nested <ul> or <ol> as a block,
					-- too, or we get extra spaces.
					-- Don't add space before the first element, either.
					-- List Tags -> ul, ol
					-- Add space before a ul/ol if it is not embedded in another list
					-- Add space before li if not the first one in a list.
					
					if ( isBlockTag[tag] ) then
--print ("BLOCK TAG",tag, stacks.list.ptr)
						if (isListTag[tag]) then 
							-- Don't add space before sub-lists.
							if ( not (stacks.list.ptr > 1 ) ) then	
								-- List Tags (ol/ul)
								if (isListTag[tag]) then
--	print ("A YES",tag,"counter=",stacks.list[stacks.list.ptr].counter)
									CRLF( "Before", tag )
								
								-- other block tags
								elseif ( stacks.list[stacks.list.ptr] and stacks.list[stacks.list.ptr].counter > 1) then
--print ("B YES",tag,"counter=",stacks.list[stacks.list.ptr].counter)
									CRLF( "Before", tag )
								end
							end
						elseif tag == 'li' then
							if ( stacks.list[stacks.list.ptr] and stacks.list[stacks.list.ptr].counter > 1) then
--print ("C YES",tag,"counter=",stacks.list[stacks.list.ptr].counter)
									CRLF( "Before", tag )
							end
						else
						-- Not list tag
--print ("Not a sublist:",tag, stacks.list.ptr)
							CRLF( "Before", tag )
--print ("D YES",tag )
						end
--print ("D NO",tag, isListTag[tag], stacks.list.ptr, (not isListTag[tag]) and (stacks.list.ptr <= 1))
--print (not isListTag[tag], stacks.list.ptr <= 1)

					end
					
					
					
					-- -------------------------------------------------------
					-- Handle the HR line here, AFTER adding the space before it
					if (tag == "hr") then
						renderHR()
					end

					-- -------------------------------------------------------
					-- Render XML into lines of text
					for n, element in ipairs(parsedText) do
						if (type(element) == "table") then
						
							-- This tag is the PARENT tag of the current element!!!
							-- The current element tag is in element._tag!!!

--print("----------------------------")
--print ("A) Parent Tag; current tag; in block?",tag, element._tag)
--print ("lineY", lineY)					

							-- Apply a font formatting tag, e.g. bold or italic
							-- These settings cascade to nested elements
							local saveStyleSettings = getAllStyleSettings()
-- I AM NOT SURE THESE TAGS EVER GET HERE!?!?
							if (tag == "span" or tag == "a" or tag == "b" or tag == "i" or tag == "em" or tag == "strong" or tag == "font" or tag == "sup" or tag == "sub" ) then
								-- Now, apply any settings in the tag itself
								setStyleFromTag (tag, attr)
							end

							local e = renderParsedText(element, element._tag, element._attr, parseDepth, stacks)
							e.anchorX, e.anchorY = 0, 0

							-- Restore settings of parent element, saved above.
							setStyleSettings(saveStyleSettings)

						else
							if (not element) then
								print ("***** WARNING, EMPTY ELEMENT**** ")
							end
--print ("B) Tag, element : ",tag, ":",  element)
--print ("lineY", lineY)
							local saveStyleSettings = getAllStyleSettings()
							local e = renderParsedElement(n, element, tag, attr)
							e.anchorX, e.anchorY = 0, 0
							setStyleSettings(saveStyleSettings)
						end

					end -- end for
					-- -------------------------------------------------------
					

--print ("END OF LOOP", tag)

					-- Close tags
					-- AFTER rendering (so add afterspacing!)
					if ( isBlockTag[tag] ) then
--print ("Got a block tag:", tag)
						lineY = lineY + settings.currentSpaceAfter
						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						setStyleFromTag (tag, attr)
						renderTextFromMargin = true
						settings.isFirstLine = true
						
						settings.currentXOffset = 0
						settings.isFirstLine = true
					end


					if (tag == "br" or tag == "img" ) then
--print ("NEW LINE: br/img")
						CRLF( "After", tag )
						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.isFirstLine = true
						settings.currentLeftIndent = 0
						settings.currentFirstLineIndent = 0
						x = 0
						
					elseif (tag == "ul") then
						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						setStyleFromTag (tag, attr)
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.isFirstLine = true
						stacks.list[stacks.list.ptr] = nil
						stacks.list.ptr = stacks.list.ptr - 1
						
					elseif (tag == "ol") then
						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						setStyleFromTag (tag, attr)
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.isFirstLine = true
						stacks.list[stacks.list.ptr] = nil
						stacks.list.ptr = stacks.list.ptr - 1
					elseif (tag == "#document") then
						-- lines from non-HTML text will be tagged #document
						-- and this will handle them.
						renderTextFromMargin = true
						settings.isFirstLine = true
						--renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						settings.currentXOffset = 0
						setStyleFromTag (tag, attr)
						--lineY = lineY + settings.currentSpaceAfter
					end

					if (not settings.isHTML) then
						lineY = lineY + settings["spaceAfter"]
						
						renderXMLvars.currentRenderedLineIndex = renderXMLvars.currentRenderedLineIndex + 1
						renderTextFromMargin = true
						settings.currentXOffset = 0
						settings.isFirstLine = true
						settings.currentLeftIndent = 0
						settings.currentFirstLineIndent = 0
						x = 0
					end

					-- Now, overwrite Normal by restoring the style settings to what they were before
					-- entering the tag

					setStyleSettings(styleSettings)
					return renderParsedTextResult
				end -- end function renderParsedText

				------------------------------------------------------------
				-- Render one block of text (or an XML chunk of some sort)
				-- This could be the opening to a paragraph, e.g. <p class="myclass">
				-- or some text, or another XML chunk, e.g. <font name="Times">my text</font>
				------------------------------------------------------------
				
				-- Set default style to 'body'
				setStyleFromCommandLine ( textstyles.body )
				
				local e = renderParsedText(parsedText, parsedText._tag, parsedText._attr)
				renderXMLresult:insert(e)
				e.anchorX, e.anchorY = 0, 0

				-- This keeps centered/right aligned objects in the right place
				-- The line is built inside a rect of the correct width
				--e:setReferencePoint(display["Center" .. textAlignment .. "ReferencePoint"])
				--e.x = 0
				--e.y = 0
				
				renderXMLvars.renderedLines = alignRenderedLines(renderXMLvars.renderedLines, renderXMLvars.renderedLinesStats)

				return renderXMLresult

			end -- end renderXML


			-- Render this chunk of XML
			local oneXMLBlock = renderXML(restOLine)
			renderedTextblock:insert(oneXMLBlock)
			oneXMLBlock.anchorX, oneXMLBlock.anchorY = 0, 0
		end -- html elements for one paragraph

	end

	-----------------------------
	-- Finished rendering all blocks of text (all paragraphs).
	-- Anchor the text block TOP-LEFT by default
	-----------------------------
	renderedTextblock.anchorChildren = false
	renderedTextblock.yAdjustment = renderedTextblock.contentBounds.yMin
	renderedTextblock.anchorChildren = true
	renderedTextblock.anchorX, renderedTextblock.anchorY = 0,0
	
	
	-- Cache the render if it wasn't cached already.
	if ( not textwrapIsCached and (T.cacheToDB or (cacheDir and cacheDir ~= ""))) then
		--print ("NOT CACHED, WRITE")
		saveTextWrapToCache(textUID, cache, baselineCache, cacheDir)
	end



--	if T.db and T.db:isopen() then
--		T.db:close()
--		print ("TESTING: Close DB")
--	end

	return renderedTextblock
end

T.autoWrappedText = autoWrappedText
-- Allow new name for autowrapped text
T.textrender = autoWrappedText
T.clearAllCaches = clearAllCaches
T.fitBlockToHeight = fitBlockToHeight

-- OPEN CACHE DATABASE
openCacheDB()

if (not T.addedCloseDatabaseFunction) then
	Runtime:addEventListener( "system", closeDB )
	T.addedCloseDatabaseFunction = true
	--print ("textwrap: Added closing function!")
end




return T