


--v2.0.1
--[[
Glider Debugger Library
Author: M.Y. Developers LLC
Copyright (C) 2013 M.Y. Developers LLC All Rights Reserved
Support: mydevelopergames@gmail.com
Website: http://www.mydevelopersgames.com/
License: Many hours of genuine hard work have gone into this project and we kindly ask you not to redistribute or illegally sell this package.
We are constantly developing this software to provide you with a better development experience and any suggestions are welcome. Thanks for you support.

-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.
--]]

local preFrameTimer,postFrameTimer,timeInFrame,frameTime,enterFrame,profilerRunning,profilerHook
local profilerPeriod = 1
local profilerTimer,reporter,systemTime,removeHook,debugloop,socketRecieveLoop,handleError
local socket = require "socket"
local tcpSocket,master,resolveName, tableToID, idToTable, lastKnownPC
local CiderRunMode = {};CiderRunMode.runmode = 'RUN';CiderRunMode.assertImage = true;CiderRunMode.userdir = "/Volumes/Macintosh HD/Users/dgross/Library/Application Support/luaglider2/dev";local SOCKET_PORT=52451;local GLIDER_MAIN_FOLDER= "/Volumes/Macintosh HD/Users/dgross/Corona Projects/corona-textrender/examples";local useNativePrint= false;local snapshotInterval= -1;local snapshotInterval= -1;local fileFilters= {"CiderDebugger.lua",};local startupMode= "require";local function shouldDebug()
    local env = system.getInfo( "environment" )
    if(env~="simulator") then
        native.showAlert(
        "Glider Debugger Warning!", "Glider debugger libraries are "
        .."still included on the device! You probably meant to click "
        .."build instead of debug/run. Please click the hammer icon when you "
        .."wish to deploy on the device. ", {"OK"} )        
        return false
    end    
    return true
end
local function gliderDebuggerErrorListener( event )
    handleError(2, event.errorMessage )
    return false
end
Runtime:addEventListener("unhandledError", gliderDebuggerErrorListener)

--in order for the profiler to work properly it must be synced to your the 
--frame timer of your sdk.
local function setEnterframeCallback(func)
    Runtime:addEventListener( "enterFrame" , func)
end

--this function will be called when an event is recieved from the IDE
local function ultimoteEventRecieved(evt)
    Runtime:dispatchEvent(evt)
end

local function initializeUltimote()
    local supportedEvents = {
        orientation = true,
        accelerometer = true,
        gyroscope = true,
        heading = true,
        collision = true,
        preCollision = true,
        postCollision = true,
    }
   system.hasEventSource = function(evt)
        return supportedEvents[evt]
    end
end

local function setEnterframeCallback(func)
    Runtime:addEventListener( "enterFrame" , func)
end


--DEBUG HEADERS HERE--

if(shouldDebug and not shouldDebug()) then
    return;
end
io.stdout:setvbuf("no")
local json = {}
local function loadJson()
    
    local string = string
    local math = math
    local table = table
    local error = error
    local tonumber = tonumber
    local tostring = tostring
    local type = type
    local setmetatable = setmetatable
    local pairs = pairs
    local ipairs = ipairs
    local assert = assert
    local Chipmunk = Chipmunk
    
    local function Null()
	return Null
    end
    local StringBuilder = {
	buffer = {}
    }
    
    function StringBuilder:New()
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.buffer = {}
	return o
    end
    
    function StringBuilder:Append(s)
	self.buffer[#self.buffer+1] = s
    end
    
    function StringBuilder:ToString()
	return table.concat(self.buffer)
    end
    
    local JsonWriter = {
	backslashes = {
            ['\b'] = "\\b",
            ['\t'] = "\\t",	
            ['\n'] = "\\n", 
            ['\f'] = "\\f",
            ['\r'] = "\\r", 
            ['"']  = "\\\"", 
            ['\\'] = "\\\\", 
            ['/']  = "\\/"
	}
    }
    
    function JsonWriter:New()
	local o = {}
	o.writer = StringBuilder:New()
	setmetatable(o, self)
	self.__index = self
	return o
    end
    
    function JsonWriter:Append(s)
	self.writer:Append(s)
    end
    
    function JsonWriter:ToString()
	return self.writer:ToString()
    end
    
    function JsonWriter:Write(o)
	local t = type(o)
	if t == "nil" then
            self:WriteNil()
	elseif t == "boolean" then
            self:WriteString(o)
	elseif t == "number" then
            self:WriteString(o)
	elseif t == "string" then
            self:ParseString(o)
	elseif t == "table" then
            self:WriteTable(o)
	elseif t == "function" then
            self:WriteFunction(o)
	elseif t == "thread" then
            self:WriteTable{}
	elseif t == "userdata" then
            self:WriteTable{}
	end
    end
    
    function JsonWriter:WriteNil()
	self:Append("null")
    end
    
    function JsonWriter:WriteString(o)
	self:Append(tostring(o))
    end
    
    function JsonWriter:ParseString(s)
	self:Append('"')
	self:Append(string.gsub(s, "[%z%c\\\"/]", function(n)
            local c = self.backslashes[n]
            if c then return c end
            return string.format("\\u%.4X", string.byte(n))
	end))
	self:Append('"')
    end
    
    function JsonWriter:IsArray(t)
	local count = 0
	local isindex = function(k) 
            if type(k) == "number" and k > 0 then
                if math.floor(k) == k then
                    return true
                end
            end
            return false
	end
	for k,v in pairs(t) do
            if not isindex(k) then
                return false, '{', '}'
            else
                count = math.max(count, k)
            end
	end
	return true, '[', ']', count
    end
    
    function JsonWriter:WriteTable(t)
	local ba, st, et, n = self:IsArray(t)
	self:Append(st)	
	if ba then		
            for i = 1, n do
                self:Write(t[i])
                if i < n then
                    self:Append(',')
                end
            end
	else
            local first = true;
            for k, v in pairs(t) do
                if not first then
                    self:Append(',')
                end
                first = false;			
                self:ParseString(k)
                self:Append(':')
                self:Write(v)			
            end
	end
	self:Append(et)
    end
    
    function JsonWriter:WriteError(o)
	error(string.format(
        "Encoding of %s unsupported", 
        tostring(o)))
    end
    
    function JsonWriter:WriteFunction(o)
	if o == Null then 
            self:WriteNil()
	else
            self:WriteTable{}
	end
    end
    
    local StringReader = {
	s = "",
	i = 0
    }
    
    function StringReader:New(s)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.s = s or o.s
	return o	
    end
    
    function StringReader:Peek()
	local i = self.i + 1
	if i <= #self.s then
            return string.sub(self.s, i, i)
	end
	return nil
    end
    
    function StringReader:Next()
	self.i = self.i+1
	if self.i <= #self.s then
            return string.sub(self.s, self.i, self.i)
	end
	return nil
    end
    
    function StringReader:All()
	return self.s
    end
    
    local JsonReader = {
	escapes = {
            ['t'] = '\t',
            ['n'] = '\n',
            ['f'] = '\f',
            ['r'] = '\r',
            ['b'] = '\b',
	}
    }
    
    function JsonReader:New(s)
	local o = {}
	o.reader = StringReader:New(s)
	setmetatable(o, self)
	self.__index = self
	return o;
    end
    
    function JsonReader:Read()
	self:SkipWhiteSpace()
	local peek = self:Peek()
	if peek == nil then
            error(string.format(
            "Nil string: '%s'", 
            self:All()))
	elseif peek == '{' then
            return self:ReadObject()
	elseif peek == '[' then
            return self:ReadArray()
	elseif peek == '"' then
            return self:ReadString()
	elseif string.find(peek, "[%+%-%d]") then
            return self:ReadNumber()
	elseif peek == 't' then
            return self:ReadTrue()
	elseif peek == 'f' then
            return self:ReadFalse()
	elseif peek == 'n' then
            return self:ReadNull()
	elseif peek == '/' then
            self:ReadComment()
            return self:Read()
	else
            error(string.format(
            "Invalid input: '%s'", 
            self:All()))
	end
    end
    
    function JsonReader:ReadTrue()
	self:TestReservedWord{'t','r','u','e'}
	return true
    end
    
    function JsonReader:ReadFalse()
	self:TestReservedWord{'f','a','l','s','e'}
	return false
    end
    
    function JsonReader:ReadNull()
	self:TestReservedWord{'n','u','l','l'}
	return nil
    end
    
    function JsonReader:TestReservedWord(t)
	for i, v in ipairs(t) do
            if self:Next() ~= v then
                error(string.format(
                "Error reading '%s': %s", 
                table.concat(t), 
                self:All()))
            end
	end
    end
    
    function JsonReader:ReadNumber()
        local result = self:Next()
        local peek = self:Peek()
        while peek ~= nil and string.find(
            peek, 
            "[%+%-%d%.eE]") do
            result = result .. self:Next()
            peek = self:Peek()
	end
	result = tonumber(result)
	if result == nil then
            error(string.format(
            "Invalid number: '%s'", 
            result))
	else
            return result
	end
    end
    
    function JsonReader:ReadString()
	local result = ""
	assert(self:Next() == '"')
        while self:Peek() ~= '"' do
            local ch = self:Next()
            if ch == '\\' then
                ch = self:Next()
                if self.escapes[ch] then
                    ch = self.escapes[ch]
                end
            end
            result = result .. ch
	end
        assert(self:Next() == '"')
	local fromunicode = function(m)
            return string.char(tonumber(m, 16))
	end
	return string.gsub(
        result, 
        "u%x%x(%x%x)", 
        fromunicode)
    end
    
    function JsonReader:ReadComment()
        assert(self:Next() == '/')
        local second = self:Next()
        if second == '/' then
            self:ReadSingleLineComment()
        elseif second == '*' then
            self:ReadBlockComment()
        else
            error(string.format(
            "Invalid comment: %s", 
            self:All()))
	end
    end
    
    function JsonReader:ReadBlockComment()
	local done = false
	while not done do
            local ch = self:Next()		
            if ch == '*' and self:Peek() == '/' then
                done = true
            end
            if not done and 
                ch == '/' and 
                self:Peek() == "*" then
                error(string.format(
                "Invalid comment: %s, '/*' illegal.",  
                self:All()))
            end
	end
	self:Next()
    end
    
    function JsonReader:ReadSingleLineComment()
	local ch = self:Next()
	while ch ~= '\r' and ch ~= '\n' do
            ch = self:Next()
	end
    end
    
    function JsonReader:ReadArray()
	local result = {}
	assert(self:Next() == '[')
	local done = false
	if self:Peek() == ']' then
            done = true;
	end
	while not done do
            local item = self:Read()
            result[#result+1] = item
            self:SkipWhiteSpace()
            if self:Peek() == ']' then
                done = true
            end
            if not done then
                local ch = self:Next()
                if ch ~= ',' then
                    error(string.format(
                    "Invalid array: '%s' due to: '%s'", 
                    self:All(), ch))
                end
            end
	end
	assert(']' == self:Next())
	return result
    end
    
    function JsonReader:ReadObject()
	local result = {}
	assert(self:Next() == '{')
	local done = false
	if self:Peek() == '}' then
            done = true
	end
	while not done do
            local key = self:Read()
            if type(key) ~= "string" then
                error(string.format(
                "Invalid non-string object key: %s", 
                key))
            end
            self:SkipWhiteSpace()
            local ch = self:Next()
            if ch ~= ':' then
                error(string.format(
                "Invalid object: '%s' due to: '%s'", 
                self:All(), 
                ch))
            end
            self:SkipWhiteSpace()
            local val = self:Read()
            result[key] = val
            self:SkipWhiteSpace()
            if self:Peek() == '}' then
                done = true
            end
            if not done then
                ch = self:Next()
                if ch ~= ',' then
                    error(string.format(
                    "Invalid array: '%s' near: '%s'", 
                    self:All(), 
                    ch))
                end
            end
	end
	assert(self:Next() == "}")
	return result
    end
    
    function JsonReader:SkipWhiteSpace()
	local p = self:Peek()
	while p ~= nil and string.find(p, "[%s/]") do
            if p == '/' then
                self:ReadComment()
            else
                self:Next()
            end
            p = self:Peek()
	end
    end
    
    function JsonReader:Peek()
	return self.reader:Peek()
    end
    
    function JsonReader:Next()
	return self.reader:Next()
    end
    
    function JsonReader:All()
	return self.reader:All()
    end
    
    function json.encode(o)
	local writer = JsonWriter:New()
	writer:Write(o)
	return writer:ToString()
    end
    
    function json.decode(s)
	local reader = JsonReader:New(s)
	return reader:Read()
    end
    
    
    
    
end



local function sendObject(msg)
    tcpSocket:settimeout(5)
    tcpSocket:send(json.encode(msg)..'\n') ;
    tcpSocket:settimeout(0)
end


--local json = require "json"
loadJson()

local jsonNull = "nil"
if(type(json.null)=="function") then
    jsonNull = json.null()
elseif (json.Null) then
    jsonNull = json.Null
end 
local statusMessage
local previousLine, previousFile
local Root = {} --this is for variable dumps
local globalsBlacklist = {}
local breakpoints = {}
local breakpointLines = {}
local runToCursorKey = nil
local runToCursorKeyLine = nil
local snapshotCounter = 0
local lineBlacklist = {}
local workingEnterframe = false
local getinfo = debug.getinfo
local sethook =  debug.sethook
local tostring = tostring
--override display methods so warnings are thrown
if(CiderRunMode==nil) then
    CiderRunMode = {};
end
local function isAbsolute(path)
    return path:match("^/.*$") or path:match("^%a:/.*$")
end
local function standardizePath( input, changecase )    
    if changecase then
        input = string.lower( input )
    end
    input = string.gsub( input, "\\", "/" )
	if(not isAbsolute(input)) then
		input = GLIDER_MAIN_FOLDER..'/'..input
	end
    return input
end


------------------------------COROUTINE--------------------------------------
local coroutineCache = setmetatable({}, {__mode="k"})
local isMainThreadAdded = false;
local function shouldAddHook(co)
    if(co==nil) then
        if(isMainThreadAdded)then
            return false
        else 
            isMainThreadAdded = true
            return true
        end
    end
    if(coroutineCache[co]) then
        return false;
    else 
        coroutineCache[co] = true;
        return true;
    end
end

local function addHook(...)
    local co = coroutine.running()
    if(shouldAddHook(co)) then
        sethook(...)
    end    
end
local function removeHook(...)
    local co = coroutine.running()
    if(co) then
        coroutineCache[co]=nil;
    else
        isMainThreadAdded = false;
    end
    sethook(...)
end
local cocreate = coroutine.create 
------------------------------------------------------------------------------

------------------------------FRAME TIMER-------------------------------------
local cpuFraction,memoryUsed,runningSumCPU,runningSumMemory=0,0,0,0;--used for averaging
local runningFrames = 1;
function enterFrame()
    workingEnterframe = true
    socketRecieveLoop()   
    local currentTime =  socket.gettime();
    
    if(preFrameTimer) then
        frameTime = currentTime-preFrameTimer;
        if(postFrameTimer) then
            timeInFrame = currentTime-postFrameTimer            
            runningSumCPU = (frameTime-timeInFrame)/frameTime + runningSumCPU      
            runningSumMemory = collectgarbage("count")+runningSumMemory            
            runningFrames = runningFrames+1
            
        end        
    end
    preFrameTimer = currentTime
    reporter()
end
------------------------------------------------------------------------------
if(CiderRunMode.assertImage) then
    if(CiderRunMode.sdk=="CORONA") then
        local ov = {"newImage", "newImageRect",}
        local displayFunc = {}
        for i,v in pairs(ov) do
            local nativeF = display[v];
            display[v] = function(...)       
                return assert(nativeF(...), "display."..v.." assertion failed, check filename")        
            end               
        end
    end
end


for i,v in pairs(_G) do
    globalsBlacklist[v] = true 
end



local nativePrint = print
local nativeError = error
local function cat(...)
    local n = select("#", ...)
    local str = ""
    for i=1,n do
        str = str..tostring(select(i, ...)).."\t"
    end    
    return str
end
local function sendConsoleMessage(...)
    local message = {}
    message.type = "pr"
    local str = cat(...)
    message.str = str    
    sendObject(message)      
end
local function sendConsoleError(...)
    local message = {}
    message.type = "pe"
    local str = cat(...)
    message.str = str    
    sendObject(message)      
end
local function debugPrint(...)	
    sendConsoleMessage(...)    
    nativePrint(...)
end

local function debugError(...)
    sendConsoleError(...)    
    nativeError(...)    
end

--error = debugError
--this will block the program initially and wait for netbeans connection

local varRefTable = {} --holds ref to all discovered vars, must remove or leak.
local function globalsDump()
    
    local globalsVars = {}
    for i,globalv in pairs(_G) do
        
        if(globalsBlacklist[globalv]==nil) then
            globalsVars[i] = globalv
        end
    end		
    --return serializeDump(globalsVars)
    return globalsVars
end
local tostring = tostring
local serializeQueue = {}
local luaIDs
local queueIndex = 1;
local maxqueueIndex = 100;
local function serializeDump(tab, tables)--mirrors table and removes functions, userdata, and tries to identify type\
    luaIDs = {}
    if(tables == nil) then
        tables = {}
    end
    luaIDs[tostring(tab)] = {[".CIDERPath"] = "root"}    
    while(tab) do
        local tabKey = tostring(tab)
        varRefTable[tabKey] = tab
        if(tab == _G) then
            --dealing with global so filter the blacklist and proxy this but leave refernces to global
            tab = globalsDump()
        end
        --tab must be type table
        
        
        if(tables[tabKey] == nil) then
            local newTab = {}
            newTab[".myRef"] = tabKey
            if(tab._class and tab.x and tab.y and tab.rotation and tab.alpha) then            
                --in a displayGroup
                newTab[".isDisplayObject"] = true
                newTab.x, newTab.y, newTab.rotation, newTab.alpha, newTab.width, newTab.height, newTab.isVisible, newTab.xReference, newTab.yReference, newTab.xScale, newTab.yScale=
                tab.x,tab.y,tab.rotation,tab.alpha,tab.width,tab.height,tab.isVisible, tab.xReference, tab.yReference, tab.xScale, tab.yScale
                --also add the custom data
                if(tab.numChildren) then
                    --in a display object
                    newTab.numChildren = tab.numChildren;	
                    newTab[".isDisplayGroup"] = true
                else
                    
                end					
            end
            
            
            tables[tabKey] = newTab            
            local ciderPath = luaIDs[tabKey][".CIDERPath"] or "root";
            --traverse through table and add values
            for i,v in pairs(tab) do		
                local typev = type(v)
                if(type(i)=="table") then
                    i = tostring(i)
                end
                if(type(i)=="userdata") then
                    i = tostring(i)
                end              
                if(typev=="string" or type(v)=="boolean" or type(v)=="number" ) then
                    if(v == -math.huge or v == math.huge) then
                        newTab[i] = tostring(v)	
                    else
                        newTab[i] = v
                    end
                elseif(typev=="table" ) then			
                    --local tabKey = tostring(v)
                    newTab[i] = {}
                    newTab[i][".isCiderRef"] = tostring(v);--save the reference of v
                    
                    if(tables[tostring(v)]==nil) then		--check if we have serialized this table or not			
                        --check if this is a display object (see if there is a _class key)								
                        --add it to the queue instead
                        if(maxqueueIndex ~= queueIndex) then
                            serializeQueue[queueIndex] = v;
                            queueIndex = queueIndex+1;
                        end
                        
                        tabKey = tostring(v)
                        if(luaIDs[tabKey]==nil) then
                            luaIDs[tabKey]={}
                        end
                        local luaID = luaIDs[tabKey];
                        luaID[".CIDERPath"] = ciderPath..i
                        luaID[".luaID"] = i; --the table itself knows its ID
                        --serializeDump(v, tables)
                    end	
                    
                elseif(v==nil) then
                    newTab[i] = jsonNull;
                elseif(typev=="function") then
                    newTab[i]  = {}
                    newTab[i].isCoronaBridgeFunction = true
                    newTab[i].id = i
                elseif(typev=="userdata") then
                    newTab[i] = ".userdata"
                end
            end		
        end
        queueIndex = queueIndex-1
        tab = serializeQueue[queueIndex]
    end
    for i,v in pairs(luaIDs) do
        if(tables[i]) then
            tables[i][".CIDERPath"] = v[".CIDERPath"]
            tables[i][".luaID"] = v[".luaID"]
        end
    end
    
    return tables	
end
local function localsDump(stackLevel, vars) --puts all locals into table
    
    if(vars==nil) then
        vars = {}
    end
    
    local db = debug.getinfo(stackLevel, "fS")
    local func = db.func
    local i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if(value==nil) then
            vars[name] = jsonNull
        else
            vars[name] = value
        end
        
        i = i + 1
    end
    i = 1
    while true do
        local name, value = debug.getlocal(stackLevel, i)
        if not name then break end
        if(name:sub(1,1)~="(") then
            if(value==nil) then
                vars[name] = jsonNull
            else
                vars[name] = value
            end
            
            
            
        end
        i = i + 1
    end
    --setmetatable(vars, { __index = getfenv(func), __newindex = getfenv(func) })
    --	local dump = serializeDump(   vars	)
    return vars
end
local function searchLocals(localName,newValue,stackLevel) --puts all locals into table
    local db = debug.getinfo(stackLevel, "fS")
    local func = db.func
    local i = 1
    
    while true do        
        local name, value = debug.getlocal(stackLevel, i)    
        if not name then break end
        if(name == localName) then debug.setlocal(stackLevel, i, newValue); return; end
        i = i + 1
    end
    
    i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if(name == localName) then debug.setupvalue(func, i, newValue); return; end
        i = i + 1
    end  
end
function resolveName(nameToFind,stackLevel) --puts all locals into table
    local db = debug.getinfo(stackLevel, "fS")
    if(not db) then
        return  nil
    end
    local func = db.func
    local i = 1
    
    while true do        
        local name, value = debug.getlocal(stackLevel, i)    
        if not name then break end
        if(name == nameToFind) then  return value,"local" ; end
        i = i + 1
    end
    
    i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if(name == nameToFind) then  return value,"upvalue"; end
        i = i + 1
    end  
    
    return _G[nameToFind],"global"
end

local function stackDump(stackLevel)
    
    local stackDump = {};
    local stackIndex = stackLevel or 5
    local index = 0;
    local info 
    local filename;
    local info = debug.getinfo(stackIndex,"Sl")  
    while(info) do
        
        
        filename = info.source
        if( filename:find("CiderDebugger.lua") ) then
            break;
        end
        
        if( filename:find( "@" ) ) then
            filename = filename:sub( 2 )
        end    
        
        filename = standardizePath(filename)
        stackDump[index] = {filename,info.linedefined,info.currentline}
        
        
        index = index+1
        stackIndex = stackIndex+1
        info = debug.getinfo(stackIndex,"Sl")  
    end
    
    return stackDump
    
end


local function writeStackDump(stackLevel) --write the var dump to file
    local stackString = json.encode(stackDump(stackLevel));
    sendObject({["type"]="st",["data"]=stackString})    
end
local tableIDCounter = 0;
idToTable = setmetatable({}, {__mode="v"})  
tableToID = setmetatable({}, {__mode="k"})  
local function getTableIDFor(var) 
    local id = tableToID[var] 
    if not id then
        tableIDCounter = tableIDCounter+1;
        id = tostring(tableIDCounter)
        idToTable[id] = var
        tableToID[var] = id
    end
    return id
end
local maxDepth = 0
local extraSymbols
local function convertVarToResult(var, name, depth) 
    depth = depth or 0    
    depth = depth+1    
    local result = {}
    local tableID = getTableIDFor(var)
    result["name"] = name
    result["type"] = type(var)
    result["tableID"] = tableID
    local isTable = type(var)=="table" 
    local hasChildren = (isTable and next(var) ~=nil )
    result["hasChildren"] = hasChildren
    result["value"] = tostring(var)
    local children = {}
    if maxDepth >= depth and isTable and var then        
        for name,child in pairs(var) do                  
            local result = convertVarToResult(child, name, depth)
            table.insert(children, result)
        end
        if extraSymbols then
            for _,name in pairs(extraSymbols) do
                local resolved = var[name];
                if not resolved then
                    break
                end
                local result = convertVarToResult(resolved, name, depth)
                table.insert(children, result)           
            end
        end
    end
    result["children"] = children
    return result
end


local function dumpVariableList(varToDump, guessed)
    local list = {}    
    local results = {}
    for name,var in pairs(varToDump) do
        local result = convertVarToResult(var, name)
        table.insert(results, result)        
    end
    if guessed then
        for _,name in pairs(guessed) do
            local guessedVar = varToDump[name]
            if guessedVar then
                local result = convertVarToResult(guessedVar, name)
                table.insert(results, result)                   
            end            
        end
    end
    return results
end

local function tableIDtoVar(id) 
    local var = idToTable[id]
    return var
end


local function writeVariableDump(stackLevel, messageType) --write the var dump to file
    stackLevel = stackLevel or 5 
    local dumped = localsDump(stackLevel)
    dumped["_G"] =  _G
    local results = dumpVariableList(dumped)    
    local message = {}
    message.type = messageType or "hgl"
    local filename, line = lastKnownPC()
    message.file = filename
    message.line = line    
    message.value = results
    sendObject( message)        
end

GLIDER_MAIN_FOLDER = standardizePath(GLIDER_MAIN_FOLDER);

local steppingInto
local steppingOver
local pauseOnReturn
local stepOut
local firstLine = false
local callDepth = 0
local processFunctions = {}

function lastKnownPC()
    previousFile = standardizePath(previousFile)
    if(previousFile:find("@")) then
        previousFile = previousFile:sub(2)
    end     

    if(previousLine==nil) then
        previousLine = 0;
    end     
    return previousFile, previousLine
end
processFunctions.gpc = function()
    --now send the program counter position to netbeans
    local message = {}
    local filename, line = lastKnownPC()
    message.type = "gpc"
    message.value = {["file"] = filename,["line"] = line}    
    sendObject(message)
end
processFunctions.gl = function( )
    --gets the global and local variable state
    writeVariableDump( )
end
processFunctions.p = function( stackLevel )
    if(type(stackLevel)~="number") then
        stackLevel = 5
    end
    stackLevel = stackLevel or 5 
    local inPause = true
    --pause execution until resume is recieved, process other commands as they are received
    statusMessage = "paused"
    processFunctions.gpc( )
    
    writeStackDump( stackLevel )
    writeVariableDump( stackLevel )
    
    ---@class string
    local line = tcpSocket:receive( );
    local keepWaiting = true;
    while( keepWaiting ) do
        if( line and line:len()>3 ) then
            line = json.decode( line )
            if( line.type~="p" ) then
                pcall(processFunctions[line.type], line )
            end
            if( line.type == "k" or line.type == "r" or line.type == "si" or line.type == "sov" or line.type == "sou" or line.type == "rtc" ) then --if run or step
                return;
            end
            if( line.type == "sv" ) then
                
                writeVariableDump( );
            end			
        end
        tcpSocket:settimeout(0)
        line = tcpSocket:receive( )
        socket.sleep( 0.1 )
    end
    varRefTable = {}; --must clear reference or else we will have leaks.
end
processFunctions.r = function( )
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.s = function( )
    
end


processFunctions.sb = function( input )    
	
    --sets a breakpoint
    --	file = system.pathForFile( input.path )
    if( breakpointLines[input.line]==nil ) then
        breakpointLines[input.line] = 1 
    else
        breakpointLines[input.line] = breakpointLines[input.line]+1
    end
    
    breakpoints[ standardizePath( input.path, true )..input.line] = true;
end




processFunctions.rb = function( input )
    if( breakpointLines[input.line]==0 ) then
        breakpointLines[input.line] = nil
    else
        breakpointLines[input.line] = breakpointLines[input.line]-1
    end
    
    breakpoints[ standardizePath( input.path, true )..input.line] = nil;
end

processFunctions.rtc = function( input )
    --removes a breakpoint
    --	file = system.pathForFile( input.path )
    runToCursorKeyLine = input.line
    runToCursorKey = standardizePath( input.path, true )..input.line;
end

processFunctions.si = function( )
    
    steppingInto = true
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sov = function( )
    
    callDepth = 0;
    steppingOver= true
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sou = function( )
    
    callDepth = 1;
    pauseOnReturn = true
    steppingInto = false
    steppingOver= false
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sv = function( input )
    --print( "setting var", input.parent, input.key, input.value, _G )
    
    if( not input.parent ) then--now we must search for it        
        searchLocals( input.key,input.value, 5 );
        return;			
    elseif( input.parent == "GLOBAL" ) then--now we must search for it
        _G[input.key] = input.value
        return;		
    end	
    local mytab = tableIDtoVar(input.parent)
    if( mytab ) then
        --try to guess the content of the input
        if( input.value == "true" ) then
            mytab[input.key] = true
        elseif( input.value == "false" ) then
            mytab[input.key] = false
        elseif( input.value == "nil" ) then
            mytab[input.key] = nil			
        else
            mytab[input.key] = input.value;
        end
    end
    writeVariableDump( )
end

_G["@GliderLiveCode"] = {};
processFunctions.lcv = function( input )
    --print( "setting livecode var", input.key, input.value, _G )
    local mytab = {}
    if(input.filekey) then
        mytab = _G["@GliderLiveCode"][input.filekey];
    else 
        mytab = _G
    end    
    if( mytab ) then
        
        --try to guess the content of the input
        if( input.value == "true" ) then
            mytab[input.key] = true
        elseif( input.value == "false" ) then
            mytab[input.key] = false
        elseif( input.value == "nil" ) then
            mytab[input.key] = nil			
        else
            mytab[input.key] = input.value;
        end
    end
end
processFunctions.lcf = function( input )
    --print( "setting livecode function", input.filekey, input.key, input.value, _G ,mytab )  
    local mytab = {}
    if(input.filekey) then
        mytab = _G["@GliderLiveCode"][input.filekey];
    else 
        mytab = _G
    end 
    
    if( mytab ) then
        if(input.addself) then
            pcall(mytab[input.key], mytab, unpack(input.value));
        else
            pcall(mytab[input.key], unpack(input.value));
        end
        
        
    end
end
processFunctions.cb = function( evt )
    evt = evt.value
    for i,line in pairs(evt) do
        processFunctions[line.type]( line )
    end
end
processFunctions.e = function( evt )
    evt = evt.value
    if(ultimoteEventRecieved) then
        ultimoteEventRecieved(evt)
    end
end
processFunctions.k = function( evt )
    --just remove all the breakpoints    
    breakpoints = {}
    steppingInto = false
    steppingOver= false
    pauseOnReturn = false
    runToCursorKey = nil
end

local function prettyPrinter(tab)
    if(type(tab) == "table") then
        local str = ""
        for i,v in pairs(tab) do
            str = str.." "..tostring(i).." = "..tostring(v).."\n"
        end
        return str
    end
    return tostring(tab)
end

local function asyncPrototpye(evt, type)
    return {["requestID"] = evt.requestID,["type"]=type}
end
--
processFunctions.qv = function( evt )
    local result = asyncPrototpye(evt,"qv")
    if(not evt.value or not evt.value[1]) then
        result.resolved = false;
        sendObject(result)
        return;
    end
    local resolved = resolveName(evt.value[1], 7)        
    for i =2, table.getn(evt.value) do
        if(not resolved) then
            result.resolved = false;
            sendObject(result)
            return
        else
            resolved = resolved[evt.value[i]]
        end        
    end
    local printed=prettyPrinter(resolved)
    result.resolved = true;
    result.value = printed;
    sendObject(result)
end
local nameResolver = function(tab,key) 
    return resolveName(key, 11)   
end
local function eval(str)
    local func = loadstring(str)
    if not func then
        return nil;      
    end    
    setfenv(func,{})
    setmetatable(getfenv(func), {__index=nameResolver})
    local success, msg = pcall(func)
    return success, msg 
end
processFunctions.ev = function( evt )
    local result = asyncPrototpye(evt,"ev")
    if(not evt.value ) then
        result.resolved = false
        result.type = "no expression given"        
        result.value = result.type       
        sendObject(result)
        return;
    end
    local success, msg  = eval("return "..evt.value)
    if not success then
        result.resolved = false
        result.type = "error"  
        result.value = msg          
        sendObject(result)
    else
        result.resolved = true
        result.value = msg
        result.type = type(msg)
        sendObject(result)        
    end    
end
processFunctions.tq = function( evt )
    local result = asyncPrototpye(evt,"tq")
    local var = tableIDtoVar(evt.value)
    result.value = dumpVariableList(var,evt.guessed)
    sendObject(result) 
end
local function runloop( phase, lineKey, err )
    removeHook ( )	    
    if( phase == "error" ) then
        handleError(2, err);
    end   
    addHook ( runloop, "r",0 ) --errors occur during returns
end

function socketRecieveLoop()   
    tcpSocket:settimeout(0)
    local line = tcpSocket:receive( )
    while( line and line:len()>3) do
        --Process Line Here
        
        line = json.decode( line )
        if(processFunctions[line.type]) then
            pcall(processFunctions[line.type], line )
        end
        if( line.type=="sv" )then
            processFunctions.gl( ) --send the locals.
        end  
        tcpSocket:settimeout(0)
        line = tcpSocket:receive( )				
    end
    
end

function handleError(stackLevel,err)
    sendConsoleError(err.."\n"..(debug.traceback("message",stackLevel+1)) .."\n")
    processFunctions.p( stackLevel+3 ) 	
end

local function takeSnapshot()
    if  snapshotCounter%15==0 then
        writeVariableDump(5, "glsl")  
    end
    snapshotCounter = snapshotCounter+1;
end
local function debugloop( phase,lineKey,err)
    removeHook ( )
    if(not workingEnterframe) then
        --compatability mode, breaking inside userfunctions called from socketloop
        --(ie ultimote event) will not break.
        socketRecieveLoop()        
    end
    ---@class string
    local fileKey = getinfo( 2,"S" ).source 
    
    if( phase == "error" ) then
	handleError(2,err)
    end
    
    
    if( fileKey:sub(2,2) == ".") then        
        fileKey = GLIDER_MAIN_FOLDER..fileKey:sub(3);
    end
    if( fileKey:len() < 200 ) then
		--print(standardizePath(fileKey), lineKey)
	end
    if( fileKey~="=?" and fileKey~="=[C]" ) then
        if( fileKey:sub(1,1)=="@" ) then
            fileKey = fileKey:sub( 2 )
        end      
        
        if( lineBlacklist[fileKey]==nil ) then
            --check all the filters
            
            local filter
            for i=1, #fileFilters do
                
                filter = fileFilters[i]
                if(filter:len()>0) then
                    lineBlacklist[fileKey] = lineBlacklist[fileKey] or ( string.find( fileKey,filter,1,true ) or false )
                end				
            end                
        end
        
        
        
        if( lineBlacklist[fileKey] ) then
            
            if( phase ~= "line" ) then
                addHook ( debugloop, "l",0 )
            else
                addHook ( debugloop, "r",0 ) --future option
            end                        
            return;
        end        
        
        if( lineKey ) then
            previousLine, previousFile =  lineKey ,fileKey
        end    
        
        if( phase == "call" ) then
            
            callDepth = callDepth+1;
            --iterate through file filters
            if( steppingOver ) then
                pauseOnReturn = true;
                steppingOver = false;
            end
        elseif( phase == "return" or  phase == "tail return" ) then            
            callDepth = callDepth-1;
            if( steppingOver ) then
                steppingOver =  false
                steppingInto = true
            end				
            if( pauseOnReturn and callDepth==0) then
                pauseOnReturn = false;
                steppingInto = true;--pause after stepping one more
            end
        elseif( phase == "line" ) then
            --takeSnapshot()
            postFrameTimer = socket.gettime()
            if( steppingInto or steppingOver or firstLine ) then
                firstLine = false;
                steppingInto = false;
                steppingOver = false;
                processFunctions.p( 5 ) --pause after stepping one line					
            else
                --check if we are at a breakpoint or if we are at run to cursor 
                
                if( breakpointLines[lineKey] or lineKey==runToCursorKeyLine ) then
                    fileKey = standardizePath( previousFile, true )
                    
                    local key = fileKey..lineKey     
                    if( breakpoints[key] or runToCursorKey==key ) then
                        --we are at breakpoint
                        
                        if( runToCursorKey==key ) then
                            runToCursorKey = nil
                            runToCursorKeyLine = nil
                        end
                        processFunctions.p( ) 	
                    end
                end
            end
            
        end
    end
    
    addHook ( debugloop, "crl",0 )
end
function coroutine.create (...) 
    local ret = {cocreate(...)} 
    
    if(shouldAddHook(ret[1])) then
        sethook(ret[1], debugloop, "crl",0 )
    end       
    return unpack(ret) 
end 
-----------------------------------------------------------------------------



function reporter()
    if(profilerRunning) then
        if(runningSumCPU and runningSumMemory and runningFrames>0) then
            if(runningFrames%profilerPeriod == 0) then                
                local message = {}
                message.type = "p"
                message.m = runningSumMemory/runningFrames
                message.c = runningSumCPU/runningFrames
                message.f = frameTime
                sendObject(message)	
                
                runningSumCPU = 0;
                runningSumMemory= 0;
                runningFrames = 0        
            end
        end
    end
end

processFunctions.pr = function( evt )
    --update the profiler
    if(evt.gc) then
        print("garbage collecting now...")
        collectgarbage("collect")
    end
    
    if(evt.p) then
        if(evt.p~=-1) then
            profilerPeriod = evt.p            
            profilerRunning = true;      
        else
            profilerRunning = false;            
        end
        
    end
end
-------------------------------------------------------------------------------


local function initBlock( )
    if(initializeDebugger) then
        initializeDebugger()
    end
    if(initializeUltimote) then
        initializeUltimote()
    end
    if( initializeProfiler) then
        initializeProfiler()
    end
    if(setEnterframeCallback) then
        setEnterframeCallback(enterFrame)
    end
    for i,v in pairs(fileFilters) do
        fileFilters[i] = (string.gsub(v, "^%s*(.-)%s*$", "%1"))    
    end
    print("binding to port ",SOCKET_PORT)
    local master,mgs = socket.bind('*', SOCKET_PORT)
    print("listening on port ",SOCKET_PORT)
    if(master) then
        tcpSocket = master:accept()
    end
    if  not tcpSocket then
        print("debug init failed",mgs)  
        return false
    end
    print("connected")
    if(tcpSocket) then
        local  numTries = 0
        local maxTries = 10
        while(numTries<maxTries) do
            tcpSocket:settimeout(0)
            local line = tcpSocket:receive()
            while(line) do  
                if(line and line:len()>3) then                  
                    line = json.decode(line)
                    if(line.type=="s") then
                        print = debugPrint    
                        error = debugError
                        --now we have the first line with the start command, we can give back control of the program
                        nativePrint("program started")	
                        return true
                    end
                    if(line.type=="sb") then
                        processFunctions[line.type](line);--proccess current then the rest		
                    end
                end 
                line = tcpSocket:receive()
            end
            numTries = numTries+1
            socket.sleep(0.1)      
        end
    end
end



------------------------- profiler.lua -----------------------------------------
local unique_id = tostring(os.time(os.date( '*t' )))
local udp_socket
local UDP_PORT = 62874
local previous_function_id
local just_returned = false
local timers = {}
local SEND_PACKET_INTERVAL = 10000
local LAST_PACKET_SENT_ID = "last_packet_sent"
local PROFILER_OVERHEAD_ID = "profiler_overhead"
local send_packet_countdown = SEND_PACKET_INTERVAL
local send_packet_now = false
local line_keys_to_id = {}
local line_hit_counts = {}
local function_times = {}
local function_call_edges = {}
local current_file_line_id = 0

local timer_function = socket.gettime

local start_time = timer_function()

local function clear_table(tab)
    for k,v in pairs(tab) do tab[k]=nil end    
end

local function clear_model()        
    clear_table(line_hit_counts)
    clear_table(function_times)
    clear_table(function_call_edges)        
end

local function line_to_id(filename, line)
    local key = filename..":"..line
    local id = line_keys_to_id[key]
    if not id then
        current_file_line_id = current_file_line_id+1
        id = tostring(current_file_line_id)
        line_keys_to_id[key] = id
    end
    return id
end


local function start_timer_for(id, timer_capture)
    timers[id] = timer_capture or timer_function()   
end

local function increment_in_table(tab, key, amount)    
    local val = tab[key]
    if not val then
        val = 0
    end
    tab[key] = val + amount
end

local function stop_timer_for(id, timer_capture)
    local old_time = timers[id]
    if not old_time then
        --print("warning, tried to stop timer without starting", id)
    else
        local current_time =  timer_capture or timer_function()        
        increment_in_table(function_times, id, current_time-timers[id])
        timers[id] = nil
    end    
end

local function get_debug_info_ids()
    local info = debug.getinfo(3,"Sln")
    local file_key = info.source    
	if( file_key:find( "@" ) ) then
            file_key = file_key:sub( 2 )
    end      
    file_key = standardizePath(file_key)
	if(not isAbsolute(file_key)) then
		file_key = GLIDER_MAIN_FOLDER..'/'..file_key
	end
    return line_to_id(file_key, info.currentline) , line_to_id(file_key, info.linedefined)
end

local function increment_hit_count(id)
    increment_in_table(line_hit_counts, id, 1)
end

local function increment_edge_count(caller_id, callee_id)
    increment_in_table(function_call_edges, caller_id..":"..callee_id, 1)
end

local function serialize_packet()
    local packet = {}
    packet.profiler_overhead_time = function_times[PROFILER_OVERHEAD_ID] or 0
    packet.last_packet_time = function_times[LAST_PACKET_SENT_ID] or timer_function()-start_time
    function_times[PROFILER_OVERHEAD_ID] = nil
    function_times[LAST_PACKET_SENT_ID] = nil
    packet.line_keys_to_id = line_keys_to_id
    packet.line_hit_counts = line_hit_counts
    packet.function_times = function_times
    packet.function_call_edges = function_call_edges 
    packet.memory_used = collectgarbage("count")
    packet.unique_id = unique_id
    packet.type = "prof"
    return packet
end

local function send_packet()
    stop_timer_for(LAST_PACKET_SENT_ID)
    local data = serialize_packet()
    sendObject(data)
    clear_model()    
    start_timer_for(LAST_PACKET_SENT_ID)    
end

local function should_send_packet()

    send_packet_countdown = send_packet_countdown-1
    if send_packet_countdown == 0 or send_packet_now then
        send_packet_countdown = SEND_PACKET_INTERVAL
        send_packet_now = false
        return true
    end 

end
function profilerHook(phase)   
    local timer_capture = timer_function()
    start_timer_for(PROFILER_OVERHEAD_ID)
    local line_id, func_id = get_debug_info_ids()      
    if just_returned then
        --restart the function timer
        start_timer_for(func_id)
        just_returned = false
    end      
    if phase == "line" then        
        increment_hit_count(line_id)    
        if should_send_packet() then
           stop_timer_for(func_id,timer_capture)
           send_packet()            
           start_timer_for(func_id)
        end
    elseif phase == "call" then        
        increment_edge_count(previous_function_id, func_id)
    --    print("called ", func_id)    
        --stop the timer of the last function
        stop_timer_for(previous_function_id,timer_capture)        
        --start the timer for the current function
        start_timer_for(func_id)        
        
    elseif phase == "return" or  phase == "tail return" then
       -- print("returned ", func_id)    
        --stop the time for the current function
        stop_timer_for(func_id,timer_capture)
        just_returned = true
    end
    previous_function_id = func_id
    stop_timer_for(PROFILER_OVERHEAD_ID)    
end
local function connect()
    if setEnterframeCallback then
        local frame_counter = 0
        local send_every_frames = 30
        setEnterframeCallback(function()  
            if frame_counter == 0 then
                send_packet_now = true 
                frame_counter = send_every_frames
            end
            frame_counter = frame_counter -1
        end)
    end

    udp_socket = socket.udp()
    udp_socket:setpeername("localhost", UDP_PORT)   
end
connect()

----------------------- bootstrapper -----------------
if(initBlock()) then
    if(CiderRunMode.runmode == "RUN") then        
        
        addHook (runloop, "r",0 )
    elseif(CiderRunMode.runmode == "DEBUG") then       
        
        if(startupMode=="require") then
            addHook (debugloop, "crl",0 );			       
        elseif(startupMode=="noRequire") then
            timer.performWithDelay(1,function() addHook (debugloop, "crl",0 ); end)
        elseif(startupMode=="delay") then
            timer.performWithDelay(1000,function() addHook (debugloop, "crl",0 ); end)
        end   
    elseif(CiderRunMode.runmode == "PROFILE") then      
        addHook (profilerHook, "crl",0 );
    end
end
Debugger = {}
function Debugger.BreakNow()
    processFunctions.p()
end


