--luapp by Admicos




        -- ^ escape everything just to be safe, TODO: figure out what actually
        -- needs to be escaped.

    local fs = require("filesystem")
    local shell = require("shell")


local getopt = {}

function getopt.help(name, desc, options)
	local helpStr = name .. " -- " .. desc .. "\n"
	.. "USAGE: " .. name .. " [options] [args]\n"

	for k, v in pairs(options) do
		helpStr = helpStr .. "\n--" .. k .. " (-" .. v[2] .. ")"
		if v[3] ~= nil then
			helpStr = helpStr .. " [" .. v[3] .. "]"
		end
		helpStr = helpStr .. ": " .. v[1]
	end

	print(helpStr)
end

-- table or nil getopt.init(string programDescription, table optionsTable, table args)
-- NOTE: In optionsTable, you can't have --help or -h because getopt creates them for you.
function getopt.init(name, desc, options, args)
	local _resTbl = {}
	local _isArg = false
	local _optCnt = 1

	for i, v in ipairs(args) do
		if v == "-h" or v == "--help" then
			_resTbl = {}
			getopt.help(name, desc, options)

			return nil
		end

		if v:sub(1, 1) == "-" then
			for j, x in pairs(options) do
				if v == "--" .. j or v == "-" .. x[2] then
					if x[3] ~= nil then
						_resTbl[j] = args[i + 1]
						_isArg = true
					else
						_resTbl[j] = true
					end
				end
			end
		elseif not _isArg then
			_resTbl["opt-" .. _optCnt] = v
			_optCnt = _optCnt + 1
		else
			_isArg = false
		end
	end

	return _resTbl
end

local incdir  = "/etc/luapp/include/"

local version = "1.3.0"
local outType = "normal"

local prefix = "--pp:"
local output = shell.resolve("a.out")

local oBuf = ""

local _defines = {}
local _ignblck = false

local function _print(verbose, ...) local arg = { ... }
    if outType == "silent" then return end
    if (outType ~= "verbose") and (outType ~= "verboser") and verbose then return end
    if outType ~= "verboser" and verbose == "v" then return end

    print(table.unpack({ ... }))
end

local function _err(err)
    error("ERROR: " .. err, math.huge)
end

function _trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function _split(str, splitter)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
		helper((str:gsub("(.-)" .. splitter, helper)))
	return t
end

local processFile = function(_) end;
local pprocop = {
include = function(file)
    local incfile = ""
    _print("v", "Including file " .. file)

    if fs.exists(shell.resolve(file)) then
        incfile = shell.resolve(file)
    elseif fs.exists(fs.concat(incdir, file)) then
        incfile = fs.concat(incdir, file)
    elseif fs.exists(file) then
        incfile = file
    else
        _err("Couldn't find a include for '" .. file .. "'")
    end

    processFile(incfile)
end;
define = function(thing, ...) local arg = { ... }
    _print("v", "Defining " .. thing)
    _defines[thing] = table.concat(arg, " ")
end;

undef = function(thing)
    _print("v", "Undefining " .. thing)
    _defines[thing] = nil
end;
ifdef = function(defined)
    if _defines[defined] == nil then
        _print("v", "Starting a ignore block")
        _ignblck = true
    end
end;

ifndef = function(defined)
    if _defines[defined] ~= nil then
        _print("v", "Starting a ignore block")
        _ignblck = true
    end
end;
["if"] = function(...) local arg = { ... }
    local lstr = table.concat(arg, " ")
    for def, val in pairs(_defines) do
        lstr = lstr:gsub(def, val)
    end

    if not load("return " .. lstr)() then
        _print("v", "Starting a ignore block")
        _ignblck = true
    end
end;

ifn = function(...) local arg = { ... }
    local lstr = table.concat(arg, " ")
    for def, val in pairs(_defines) do
        lstr = lstr:gsub(def, val)
    end

    if load("return " .. lstr)() then
        _print("v", "Starting a ignore block")
        _ignblck = true
    end
end;

["else"] = function()
    _ignblck = not _ignblck
end;
ignorestart = function()
    _print("v", "Starting a ignore block")
    _ignblck = true
end;

ignoreend = function()
    _print("v", "Ending a ignore block")
    _ignblck = false
end;
print = function(...) local arg = { ... }
    print(table.unpack(arg))
end;

error = function(...) local arg = { ... }
    _err(table.unpack(arg))
end;
luapp = function(ver)
    if version < ver then
        _err("This file requires a newer version of luapp")
    end
end
}

processFile = function(file)
    _defines["__FI" .. "LE__"] = "\"" .. file .. "\""
                --^ hacky hack to avoid this getting replaced.

    if not fs.exists(file) then error("File " .. file .. " doesn't exist") end
    _print(true, "@@ /" .. file .. " @@")

    local ls = {}
    local lIsPreprocessed = false;
    local cLine = 0
    for line in io.lines(file) do
        _defines["__LI" .. "NE__"] = cLine + 1 --see line 3
        lIsPreprocessed = false
        ls = _split(_trim(line), " ")
        if #ls >= 1 then
            for _, line in ipairs(ls) do
                if line:sub(1, #prefix) == prefix then
                    local proc = table.remove(ls, 1):sub(#prefix + 1)

                    if not pprocop[proc] then _err("'" .. proc .. "': not found") end

                    if _ignblck then
                        if (proc == "ignoreend") or (proc == "else") then
                            pprocop[proc](table.unpack(ls))
                        end
                    else
                        pprocop[proc](table.unpack(ls))
                    end

                    lIsPreprocessed = true
                end
            end
        end

        if (not lIsPreprocessed) and (not _ignblck) then
            for def, val in pairs(_defines) do
                line = line:gsub(def, val)
            end

            oBuf = oBuf .. line .. "\n"
        end

         cLine = cLine + 1
    end

    local f = io.open(output, "w")
        f:write(oBuf)
    f:close()
end

local function main(args)
    if args == nil then return end
    if args["opt-1"] == nil then print("'luapp -h' for help") return end

    if args["verbose"]  then outType = "verbose" end
    if args["verboser"] then outType = "verboser" end
    if args["silent"]   then outType = "silent" end

    if args["prefix"] then prefix = args["prefix"] end
    if args["output"] then output = shell.resolve(args["output"]) end

    local file = shell.resolve(args["opt-1"])

    _print(false, "luapp " .. version)
    _print(true, "Prefix set as: " .. prefix)

    _print(false, "")

    processFile(file)
    _print(false, "DONE: /" .. output)
end

main(getopt.init("luapp", "Lua Preprocessor", {
    ["prefix"] = {"Preprocessor Line Prefix", "p", "prefix"};
    ["output"] = {"Processed file out", "o", "output"};
    ["verbose"] = {"More output", "v", nil};
    ["verboser"] = {"Even more output", "vv", nil};
    ["silent"] = {"Less output", "s", nil};
}, { ... }))
