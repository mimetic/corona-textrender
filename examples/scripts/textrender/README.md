corona-textrender
======================

## Synopsis

A pure-Lua text rendering module for Corona SDK which can handle basic HTML, fonts, font-styles, and even basic font metrics.


## Options
The function uses a table with options.

text : [string] The text to render. It can be HTML or unstyled text.

width : [number] width of the column of text in pixels

maxHeight : [number] Maximum height of the text block. Extra text is not rendered.

isHTML : [boolean] Set to true if the text is simplified HTML styled text. Default is true.

useHTMLSpacing : [boolean] Set to true to change all returns and tabs and double-spaces to a single space, as with HTML in a browser. Default is true.

testing = false, -- [boolean] True for testing, shows borders and colors.


### Font Defaults

font : [string] The iOS or Android font name, e.g. "AvenirNext-Regular". Don't use Postscript names, they won't work. See http://iosfonts.com for a list of built-in iOS fonts.

size : [number] The default font size. Changed by any style settings in the text.

lineHeight : [number] The default line height. Changed by any style settings in the text.

color : [table] The default font color. Changed by any style settings in the text. Use an RGBa table, like this: {0, 0, 0, 1} (black type)

opacity : [number] The default font opacity (or alpha). Changed by any style settings in the text. Use a number, e.g. 0.3 or a percentage in a string, e.g. "80%"

alignment : [number] Default text alignment, note the initial capital letter. "Left" | "Right" | "Center"

### Caching Settings
This module caches the text rendering so that the second time you show the text, it appears much faster. It uses some heuristics (i.e. guesses) for speed. You don't have to set any of this. You can just use the defaults.

minCharCount : [number] Minimum number of characters per line. Start low, like 5.

cacheToDB : [boolean] Default is true. Set to false for no caching. Uses sqlite3 caching (faster).

cacheDir : [string] If cacheToDB is false, then try this method for caching. If this value is set to the _full path_ to the cache directory to use for json file caching (slower). 


minWordLen : [number] 2, - Minimum length of a word shown at the end of a line, e.g. don't end lines with "a".

### Text Style Sheets

textstyles : [table] The styles table. Load the table using using funx.loadTextStyles

defaultStyle : [sring] The name of the the default style (from textstyles.txt) for text, default is "Normal".


### Hyperlinks

handler : [function] A function that will accept a 'tap' event on a hyperlink.

hyperlinkFillColor : [string] The fill of a box surrounding a hyperlink.An RGBa color in a string, like this: "200,120,255,100"

hyperlinkTextColor : [string] The color of text of hyperlink. An RGBa color in a string, like this: "200,120,255,100"


### Unused or In Development
Here are some options that I started work on but never finished or found no current use for.

~~targetDeviceScreenSize : [string] The screen dimensions as "width,height", e.g. "1024,768" This is the target screen size, used to resize text to be readable on different screens~~

~~letterspacing : [number] Letterspacing in pixels. (PLANNED, NOT IN USE)~~




## Code Example

```
-- Load the module
local funx = require("scripts.funx")
local textrender = require("scripts.textrender.textrender")
local textStyles = funx.loadTextStyles("scripts/textrender/textstyles.txt", system.ResourceDirectory)

------------
-- For TESTING, we clear text caches so we can see changes to our code and texts.
-- We clear the cache before begining, so first render creates a cache, second uses it.
textrender.clearAllCaches(cacheDir)

------------
-- Sample text
local mytext = [[
<p class="Left" >
	Hit events propagate until they are <b>handled.</b> This means that if you have <i>multiple objects overlaying</i> each other in the display hierarchy, and a hit event listener has been applied to each, the <i>hit event will propagate through all of these objects.</i> 
</p>
<p class="Left" >
	Hit events propagate until they are <b>handled.</b> This means that if you have <i>multiple objects overlaying</i> each other in the display hierarchy, and a hit event listener has been applied to each, the <i>hit event will propagate through all of these objects.</i> 
</p>
]]

local options = {
	text = mytext,
	font = "AvenirNext-Regular",
	size = "12",
	lineHeight = "16",
	color = {0, 0, 0, 255},
	opacity = "100%",
	width = w, -- width of the column of text
	alignment = "Left", -- default text alignment, note the initial capital letter
	minCharCount = 5,	-- 	Minimum number of characters per line. Start low.
	targetDeviceScreenSize = screenW..","..screenH,	-- Target screen size, may be different from current screen size
	letterspacing = 0,
	maxHeight = screenH - 50,
	minWordLen = 2, - Minimum length of a word shown at the end of a line, e.g. don't end lines with "a".
	textstyles = textStyles, -- styles table, loaded using funx.loadTextStyles
	defaultStyle = "Normal", -- default style (from textstyles.txt) for text
	cacheToDB = true, -- default is true, set to false for no caching, uses sqlite3 caching (faster)
	cacheDir = nil, -- Set to cache directory name to use json file caching (slow)
	handler = handler,  -- a function that will accept a 'tap' event
	hyperlinkFillColor = hyperlinkFillColor, -- an RGBa color in a string, like this: "200,120,255,100"
	hyperlinkTextColor = hyperlinkTextColor, -- an RGBa color in a string, like this: "200,120,255,100"
	isHTML = true, -- TRUE if the text is simplified HTML styled text
	useHTMLSpacing = true, -- if TRUE, then change all returns and tabs and double-spaces to a single space
	testing = false, -- [boolean] True for testing, shows borders and colors.
}
local textblock = textwrap.autoWrappedText( options )
```


## Style Sheets
The module uses style sheets of predefined styles. It does render many HTML attributes, such as color and fontsize, so a great deal of HTML will work without change.

You load the style sheet before calling the textrender() function. This way, you only need to load it once, and that's faster.

A stylesheet is a simple format. Each style is a line, beginning with a name, like this:

    style = font, size, leading, R,G,B, width, opacity, NORMAL|ALL_CAPS, text alignment, spaceBefore, spaceAfter, firstLineIndent, leftIndent, rightIndent

Use a '#' to comment a line.

Here is an example (note the colors use the 2.0 version of Corona with values between 0 and 1):
```
# TEXT STYLES FOR CORONA GRAPHICS v2 (values between 0-1)

# style = font, size, leading, R,G,B, width, opacity, NORMAL|ALL_CAPS, text alignment, spaceBefore, spaceAfter, firstLineIndent, leftIndent, rightIndent

#generic styles
Normal = Avenir-Book,16,20,0,0,0,,100%
Heading = Avenir-Bold,16,20,0,0,0,,100%
Title=Avenir-Light,24,40,0.5,0.5,0.5,,100%,NORMAL,left,10,6,0,0,0
H1=,18,26,0,0,0,,100%,NORMAL,left,12,4,0,0,0
H2=Avenir-Book,18,26,0,0,0,,100%,NORMAL,left,12,4,0,0,0
H2 Light=Avenir-Book,18,26,220,220,220,,100%,NORMAL,left,12,4,0,0,0
H3=,16,26,0,0,0,,100%,NORMAL,left,8,0,0,0,0
H4=,16,26,0,0,0,,100%,NORMAL,left,8,0,0,0,0
H6=,16,26,0,0,0,,100%,NORMAL,left,8,0,0,0,0
H5=,16,26,0,0,0,,100%,NORMAL,left,8,0,0,0,0
Quote = Avenir-Light,20,28,200,255,20,,100%
```

## HTML Tags
The module recognizes the following HTML tags.
- p
``<p class="myclass">text</p>
- br
- ol, li
- b,i,em, strong
- font
- sup, sub
- a
- img


## Notes:

###Hyperlinking

<b>handler</b> : a function that will use a 'tap' event. Note that event.target._attr contains the HTML attributes of the hyperlink, e.g. href, style, class, whatever your throw in. 
In the example, the function will get 'makeSound' as the href, and it can do the appropriate action. 
You can pass any attribute you need, such as a page number or URL, of course.<br>
Example: &lt;a href="makeSound" style="font-size:24;"&gt;My Link&lt;/a&gt;

###Parts of the module
- textrender.lua : the module that renders a piece of text. The text can have basic HTML coding (p, br, i, em, b, li, ol), as well as my built-in paragraph formatting. It will also read the 'class' attribute of HTML to figure out the style, then apply the style from the textstyles.txt file!
- HTML support: entities.lua, html.lua : these are open source modules I found and modified to handle HTML
- fontmetrics.lua, fontmetrics.txt, fontvariations.txt : this module and files let the textwrap module position type correctly on the screen. Normally, you can't position with baseline, but these modules let us do that.
- funx.lua : a large collection of useful functions


## Motivation

Corona SDK does not offer styled text, and this code makes it easy to take existing HTML text and use it.
Also, Corona SDK does not position text using font metrics. Therefore it is very hard to write code that will show text as it appears in layout programs.

## Installation

In your main Corona app folder, create a folder named "scripts". From the "scripts" folder in this repo, copy these folders to your scripts folder.
* funx.lua
* textrender

Your app folder should now look something like this:
* main folder
	* main.lua (your main file)
	* scripts
		* funx.lua
		* textrender


## Tests

NA
## Contributors

This was created by me!

## License

The MIT License (MIT)

Copyright (c) 2015 David Gross

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
