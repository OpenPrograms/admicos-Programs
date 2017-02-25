--- Coolkit is a OC and CC compatible toolkit to make cross-platform programs.
-- @module coolkit
-- @author admicos
-- @copyright 2017+ admicos
-- @release 0.0.0-beta
-- @usage Add the following code at the top of your code:
--local ck=nil if require then ck=require("coolkit") else ck=dofile("coolkit.lua") end

local coolkit = {
    --- The current version of Coolkit
    VERSION = "0.0.0",

    --- Is Coolkit processing events? (Set false to stop the loop)
    -- @see coolkit.start
    isRunning = true,

    --- The events that coolkit can handle
    -- @field raw Fires when any event occurs. Allows you to register to events not handled by coolkit. Handling being cross-platform is up to you.
    -- @field click Fires when the mouse is clicked
    -- @field scroll Fires when the mouse is scrolled
    -- @field keypress Fires when any key is pressed
    -- @field keyrelease Fires when any key is released
    -- @table events
    -- @see coolkit.registerToEvent
    events = {
        --- Fires when any event occurs. Allows you to register to events not handled by coolkit. Handling being cross-platform is up to you.
        -- @table events.raw
        -- @tparam string name Event name
        -- @tparam any ... The event parameters.
        raw = {},

        --- Fires when the mouse is clicked
        -- @table events.click
        -- @tparam number btn The button clicked (1, 2 and 3 for left, right, and middle)
        -- @tparam number x The x position of the cursor
        -- @tparam number y The y position of the cursor
        click = {},

        --- Fires when the mouse is scrolled
        -- @table events.scroll
        -- @tparam number dir The scroll direction (1 and -1 for up and down)
        -- @tparam number x The x position of the cursor
        -- @tparam number y The y position of the cursor
        scroll = {},

        --- Fires when any key is pressed
        -- @table events.keypress
        -- @tparam number code The keycode
        keypress = {},

        --- Fires when any key is released
        -- @table events.keyrelease
        -- @tparam number code The keycode
        keyrelease = {},
    },

    fs = {};
    net = {};
    screen = {};

    _internal = {},
}

if require then
    --- The system Coolkit is running under. Can be "OC" or "CC"
    coolkit.SYSTEM = "OC"
    coolkit._internal.oc = {
        internet = require("component").internet,
        event = require("event"),
        term = require("term"),
        gpu = {}
    }
    coolkit._internal.oc.gpu = coolkit._internal.oc.term.gpu()

    --- Colors to use with functions needing colors, can also be used with the native system functions
    -- @see coolkit.screen.setBG
    -- @see coolkit.screen.setFG
    coolkit.screen.colors = {
        white = 0xF0F0F0,
        orange = 0xF2B233,
        magenta = 0xE57FD8,
        lightBlue = 0x99B2F2,
        yellow = 0xDEDE6C,
        lime = 0x7FCC19,
        pink = 0xF2B2CC,
        gray = 0x4C4C4C,
        lightGray = 0x999999,
        cyan = 0x4C99B2,
        purple = 0xB266E5,
        blue = 0x3366CC,
        brown = 0x7F664C,
        green = 0x57A64E,
        red = 0xCC4C4C,
        black = 0x191919,
    }

    function coolkit._internal.ocProcessEvent(pulled)
        coolkit._internal.callAll("raw", table.unpack(pulled))

        local eName = table.remove(pulled, 1);
        if (eName == "key_down") then
            coolkit._internal.callAll("keypress", pulled[3])
        elseif (eName == "key_up") then
            coolkit._internal.callAll("keyrelease", pulled[3])
        elseif (eName == "touch") then
            coolkit._internal.callAll("click", pulled[4] + 1, pulled[2], pulled[3])
        elseif (eName == "scroll") then
            coolkit._internal.callAll("scroll", pulled[4], pulled[2], pulled[3])
        end
    end

    function coolkit._internal.ocSendNet(url, postData, headers)
        if not coolkit._internal.oc.internet then error("ck: OC no internet card") end
        if not coolkit._internal.oc.internet.isHttpEnabled() then error("ck: OC internet is not enabled") end
    
        local h = coolkit._internal.oc.internet.request(url, postData, headers)
        local rc, _, _rh = h.response()
        local rm = ""
        while true do
            local data = h.read()
            if not data then break
            elseif #data > 0 then rm = rm .. data end
        end

        local rh = {}
        for k, v in pairs(_rh) do
            rh[k] = tostring(v[1])
        end

        local ret = {
            code = rc,
            headers = rh,
            message = rm,
        }
        
        h.close()

        return ret
    end

else
    coolkit.SYSTEM = "CC"
    coolkit.screen.colors = _G.colors

    function coolkit._internal.ccProcessEvent(pulled)
        coolkit._internal.callAll("raw", table.unpack(pulled))

        local eName = table.remove(pulled, 1);
        if (eName == "key") then
            coolkit._internal.callAll("keypress", pulled[1])
        elseif (eName == "key_up") then
            coolkit._internal.callAll("keyrelease", pulled[1])
        elseif (eName == "mouse_click") then
            coolkit._internal.callAll("click", table.unpack(pulled))
        elseif (eName == "mouse_scroll") then
            coolkit._internal.callAll("scroll", -pulled[1], pulled[2], pulled[3])
        end
    end

    function coolkit._internal.ccSendGET(url, headers)
        if not http then error("ck: CC internet is not enabled") end
        if not http.checkURL(url) then error("ck: couldn't find url '" .. url .. "' in CC whitelist.") end

        local h = http.get(url, headers)
        local ret = {
            code = h.getResponseCode(),
            headers = {},
            message = h.readAll(),
        }
        h.close()

        return ret
    end

    function coolkit._internal.ccSendPOST(url, postData, headers)
        if not http then error("ck: CC internet is not enabled") end
        if not http.checkURL(url) then error("ck: couldn't find url '" .. url .. "' in CC whitelist.") end
    
        local h = http.post(url, postData, headers)
        local ret = {
            code = h.getResponseCode(),
            headers = {},
            message = h.readAll(),
        }
        h.close()
    
        return ret
    end
end

function coolkit._internal.callAll(eName, ...)
    for _, eFunc in ipairs(coolkit.events[eName]) do
        eFunc(table.unpack({ ... }))
    end
end

--------------------------------------------------------------------------------

--- Runs the function <code>func</code> when event <code>e</code> occurs. The function will receive the event arguments individually.
-- @tparam string event The event to register to.
-- @tparam function func The function to register.
-- @see coolkit.events
-- @see coolkit.start
-- @usage ck.registerToEvent("click", function(dir, x, y)
--    print("clicked " .. x .. "x" .. y)
--end)
-- ck.start()
function coolkit.registerToEvent(event, func)
    coolkit.events[event][#coolkit.events[event] + 1] = func
end

--- Sets the cursor position on screen.
-- @tparam number x The new x coordinate of the cursor
-- @tparam number y The new y coordinate of the cursor
-- @usage ck.screen.setPos(5, 5)
--print("hello, world!")
function coolkit.screen.setPos(x, y)
    if coolkit.SYSTEM == "OC" then
        coolkit._internal.oc.term.setCursor(x, y)
    else
        term.setCursorPos(x, y)
    end
end

--- Sets the foreground color of screen.
-- @tparam coolkit.screen.color color The new foreground color
-- @see coolkit.screen.setBG
-- @usage ck.screen.setFG(ck.screen.colors.red)
--print("hello, world!")
function coolkit.screen.setFG(color)
    if coolkit.SYSTEM == "OC" then
        coolkit._internal.oc.gpu.setForeground(color)
    else
        term.setTextColor(color)
    end
end

--- Sets the background color of screen.
-- @tparam coolkit.screen.color color The new background color
-- @see coolkit.screen.setFG
function coolkit.screen.setBG(color)
    if coolkit.SYSTEM == "OC" then
        coolkit._internal.oc.gpu.setBackground(color)
    else
        term.setBackgroundColor(color)
    end
end

--- Writes a string to the screen, without going to the new line.
-- @tparam string str String to write.
function coolkit.screen.write(str)
    if coolkit.SYSTEM == "OC" then
        coolkit._internal.oc.term.write(str)
    else
        write(str)
    end
end


--- Send a GET request to <code>url</code> with optional <code>headers</code>.
-- @tparam string url URL to send the request to
-- @tparam table headers [OPTIONAL] Headers to send with the request.
-- @see coolkit.net.sendPOST
-- @treturn table Response. Contains three keys: <code>code</code>, <code>headers</code> and <code>message</code><br>
--<ul><li><code>code</code>: Returned HTTP status code<br></li>
--<li><code>headers</code>: [EMPTY IN CC] Returned headers from the request.<br></li>
--<li><code>message</code>: Contents of the request.</li></ul>
function coolkit.net.sendGET(url, headers)
    if coolkit.SYSTEM == "OC" then
        return coolkit._internal.ocSendNet(url, nil, headers)
    else
        return coolkit._internal.ccSendGET(url, headers)
    end
end

--- Send a POST request to <code>url</code> with <code>data</code> and optional <code>headers</code>.
-- @tparam string url URL to send the request to
-- @tparam table form table of POST data to send with the request.
-- @tparam table headers [OPTIONAL] Table of headers to send with the request.
-- @see coolkit.net.sendGET
-- @treturn table Response. Contains three keys: <code>code</code>, <code>headers</code> and <code>message</code><br>
--<ul><li><code>code</code>: Returned HTTP status code<br></li>
--<li><code>headers</code>: [EMPTY IN CC] Returned headers from the request.<br></li>
--<li><code>message</code>: Contents of the request.</li></ul>
function coolkit.net.sendPOST(url, form, headers)
    if coolkit.SYSTEM == "OC" then
        return coolkit._internal.ocSendNet(url, form, headers)
    else
        local ret = ""
        for k, v in pairs(t) do
           ret = ret .. k .. "=" .. tostring(v) .. "&"
        end

        return coolkit._internal.ccSendPOST(url, ret:sub(1, #ret - 1), headers)
    end
end

--- Starts the main loop of your program. Run this after all event registering is done.
-- @see coolkit.registerToEvent
-- @see coolkit.isRunning
function coolkit.start()
    while coolkit.isRunning do
        if coolkit.SYSTEM == "OC" then
            coolkit._internal.ocProcessEvent{coolkit._internal.oc.event.pull()}
        else
            coolkit._internal.ccProcessEvent{os.pullEvent()}
        end
    end
end

return coolkit
