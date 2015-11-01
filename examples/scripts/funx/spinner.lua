--
-- created with TexturePacker (http://www.codeandweb.com/texturepacker)
--
-- $TexturePacker:SmartUpdate:459fc7091d0a2612fe2f6ac2521fece9:796598a08e961b575f09566039a37861:7f3c883f0651180a344ed5c6ae525a42$
--
-- local sheetInfo = require("mysheet")
-- local myImageSheet = graphics.newImageSheet( "mysheet.png", sheetInfo:getSheet() )
-- local sprite = display.newSprite( myImageSheet , {frames={sheetInfo:getFrameIndex("sprite")}} )
--

local SheetInfo = {}

SheetInfo.sheet =
{
    frames = {
    
        {
            -- spinner-18
            x=2,
            y=2,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-17
            x=376,
            y=2,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-16
            x=750,
            y=2,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-15
            x=1124,
            y=2,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-14
            x=2,
            y=371,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-13
            x=376,
            y=371,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-12
            x=750,
            y=371,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-11
            x=1124,
            y=371,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-10
            x=2,
            y=740,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-9
            x=376,
            y=740,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-8
            x=750,
            y=740,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-7
            x=1124,
            y=740,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-6
            x=2,
            y=1109,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-5
            x=376,
            y=1109,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-4
            x=750,
            y=1109,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-3
            x=1124,
            y=1109,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-2
            x=2,
            y=1478,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
        {
            -- spinner-1
            x=376,
            y=1478,
            width=372,
            height=367,

            sourceX = 6,
            sourceY = 6,
            sourceWidth = 384,
            sourceHeight = 379
        },
    },
    
    sheetContentWidth = 1498,
    sheetContentHeight = 1847
}

SheetInfo.sequenceData =
{
	name = "spinner",
	start = 1,
	count = 18,
	time = 2000,
	
}

function SheetInfo:getSheet()
    return self.sheet;
end

return SheetInfo
