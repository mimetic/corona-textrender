-- fontmetrics.lua
--
-- Version 0.3
--
-- Copyright (C) 2011 David I. Gross. All Rights Reserved.
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
-- ===================
-- FONT METRICS FUNCTIONS
-- ===================

--[[

Return font metrics that tell how to position a font correctly.

Font metrics for 72pt Baskerville "A" are:

characterWidth = 72
characterHeight = 72
ascender = 64
descender = -18
textWidth = 50.953125
textHeight = 81
maxHorizontalAdvance = 84
boundingBox = Array
originX = 49
originY = 0



The metrics file is a list of font names and values.

Format of the source file:
name =  characterWidth, characterHeight, ascender, descender, textWidth, textHeight, maxHorizontalAdvance, originX, originY


baseline : is the distance from the very top of the font to the baseline, as rendered by Corona, as a percentage of the requested font size. So, for a 300px font, if the baseline is 1.0, then the baseline of the font is at 300px from the top of the font (right where it should be)

capheight : the height of a capital "X", as a percentage of the size. So, for a 300px font, if the capheight is 0.65, then the "X" of the 300px font is 0.65 * 300 = 195px.

e.g.
CrimsonText-Roman=1.0, 0.65


This returns a metrics table, which has the baseline, capheight, ascent, and height

baseline: see above
capheight: see above
ascent: baseline - capheight
height: the percentage of the requested size, e.g. 300px, that the text really is. Ask for 300px of
	font X, and you might get something 400px high. Use : height * size = real size, e.g. if height
	of the font at 300px really is 400px, then the value will be 1.33, and 1.33 x 300 = 400px

]]

local FM = {}

local funx = require ("scripts.funx")

local function loadMetricsFromFile (metricsfile, fontfacesfile, path)
	local metricsPacked = {}
	local variations = {}

	metricsfile = metricsfile or "scripts/textrender/fontmetrics.txt"

	if (metricsfile) then
		path = path or system.SystemDirectory
		local filePath = system.pathForFile( metricsfile, path )
		metricsPacked = funx.loadTableFromFile(filePath, "\n")
	else
		return {}
	end


	if (not metricsPacked) then
		return false
	end

	local metrics = {}
	local x = 0
	for n,v in pairs(metricsPacked) do

		local vv = funx.split(v,",")

	--[[
	
	# fontname = sampledFontSize, characterWidth, characterHeight, ascender, descender, textWidth, textHeight, maxHorizontalAdvance, originX, originY, boundingBoxX1, boundingBoxY1, boundingBoxX2, boundingBoxY2

	The  26.6 fixed  float format  used to  define  fractional pixel     coordinates.  Here, 1 unit = 1/64 pixel.
	
	Bounding Box: xMin, yMin, xMax, yMax
	xMin	
	The horizontal minimum (left-most).

	yMin	
	The vertical minimum (bottom-most).

	xMax	
	The horizontal maximum (right-most).

	yMax	
	The vertical maximum (top-most).
	
	The bounding box is specified with the coordinates of the lower left and the upper right corner. In PostScript, those values are often called (llx,lly) and (urx,ury), respectively.

	If ‘yMin’ is negative, this value gives the glyph's descender. Otherwise, the glyph doesn't descend below the baseline. Similarly, if ‘ymax’ is positive, this value gives the glyph's ascender.

	‘xMin’ gives the horizontal distance from the glyph's origin to the left edge of the glyph's bounding box. If ‘xMin’ is negative, the glyph extends to the left of the origin.
	
	--]]
    
		-- table.remove takes from the end (i.e. "pop")
		local y2 = tonumber(table.remove(vv) )
		local x2 = tonumber(table.remove(vv) )
		local y1 = tonumber(table.remove(vv) )
		local x1 = tonumber(table.remove(vv) )

		local originY = tonumber(table.remove(vv) )
		local originX = tonumber(table.remove(vv) )
		local maxHorizontalAdvance = tonumber(table.remove(vv) )
		local textHeight = tonumber(table.remove(vv) )
		local textWidth = tonumber(table.remove(vv) )
		local descender = tonumber(table.remove(vv) )
		local ascender = tonumber(table.remove(vv) )
		local characterHeight = tonumber(table.remove(vv) )
		local characterWidth = tonumber(table.remove(vv) )
		local sampledFontSize = tonumber(table.remove(vv) )

		local baseline = descender/sampledFontSize
		local capheight = (y2-y1)/sampledFontSize

		metrics[n] = {
			capheight = capheight,
			baseline = baseline,
			ascent = ascender/sampledFontSize,
			textHeight = textHeight/sampledFontSize,
			descent = descender/sampledFontSize,
			maxCharWidth = maxHorizontalAdvance/sampledFontSize,

			originY = originY,
			originX = originX,
			maxHorizontalAdvance = maxHorizontalAdvance,
			textHeight = textHeight,
			textWidth = textWidth,
			descender = descender,
			ascender = ascender,
			characterHeight = characterHeight,
			characterWidth = characterWidth,
			sampledFontSize = sampledFontSize,

			x1 = x1,
			y1 = y1,
			x2 = x2,
			y2 = y2,

		}
	end
--funx.dump(metrics)


	------------
	-- Get font transformation names, e.g. myfont-italic
	fontfacesfile = fontfacesfile or "scripts/textrender/fontvariations.txt"

	if (fontfacesfile) then
		path = path or system.SystemDirectory
		local filePath = system.pathForFile( fontfacesfile, path )
		variations = funx.loadTableFromFile(filePath, "\n")
	end
	metrics.variations = variations


	return metrics
end


---------------
-- Return a font metrics object
function FM.new(metricsfile, fontfacesfile)
	local M = {}

	metricsfile = metricsfile or "scripts/textrender/fontmetrics.txt"
	fontfacesfile = fontfacesfile or "scripts/textrender/fontvariations.txt"
	local metrics = loadMetricsFromFile(metricsfile, fontfacesfile)

	M.metrics = metrics


	-- Get the metrics for a font.
	-- If we don't know, guess.
	function M.getMetrics(f)
		local fontInfo = {}
		fontInfo = metrics[f]
		if (not fontInfo) then
			print ("WARNING: fontmetrics doesn't have info about the font, '"..tostring(f).."', using Baskerville settings.")
			-- unknown font
			fontInfo =	{
				x1=-2.953125,
				x2=47.109375,
				y1=0.609375,
				y2=49,
				textHeight=81,
				characterWidth=72,
				descent=-0.25,
				originY=0,
				ascent=0.88888888888889,
				sampledFontSize=72,
				ascender=64,
				baseline=-0.25,
				originX=49,
				characterHeight=72,
				textWidth=50.953125,
				maxCharWidth=1.1666666666667,
				maxHorizontalAdvance=84,
				descender=-18,
				capheight=0.67209201388889,
			}
			if (type(f) ~= "string") then
				print ("WARNING: fontmetrics was sent a font value that was not a name, probably a .user value.")
			end
		end
		return fontInfo
	end
	----------

--funx.dump(metrics)


	return M
end -- new

return FM