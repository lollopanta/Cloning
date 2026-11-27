-- Console output, warnings, and the optional debug log file.
local Env = require("env")
local Log = {}

local PREFIX = "[SaveInstance] "
local MAX_WARNINGS = 200

local debugEnabled = false
local debugLines = {}
local warnedKeys = {}
local startClock = os.clock()

Log.warnings = {}

local function join(...)
	local count = select("#", ...)
	local parts = table.create(count)
	for i = 1, count do
		parts[i] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end

function Log.begin(debug)
	debugEnabled = debug == true
	table.clear(debugLines)
	table.clear(warnedKeys)
	table.clear(Log.warnings)
	startClock = os.clock()
end

function Log.setDebug(enabled)
	debugEnabled = enabled == true
end

-- Write before risky native calls: a process crash never reaches the final debug flush.
function Log.checkpoint(...)
	if not debugEnabled or not Env.writefile then
		return
	end
	local message = join(...)
	pcall(function()
		if Env.makefolder and Env.isfolder and not Env.isfolder("SaveInstance420") then
			Env.makefolder("SaveInstance420")
		end
		Env.writefile("SaveInstance420/last-operation.log", message)
	end)
end

function Log.debug(...)
	if debugEnabled then
		table.insert(debugLines, string.format("[%8.2f] %s", os.clock() - startClock, join(...)))
	end
end

function Log.info(...)
	local message = join(...)
	print(PREFIX .. message)
	Log.debug(message)
end

function Log.warn(...)
	local message = join(...)
	warn(PREFIX .. message)
	Log.debug("WARN " .. message)
	if #Log.warnings < MAX_WARNINGS then
		table.insert(Log.warnings, message)
	end
end

-- Warns once per key for the whole save (for per-property or per-class problems).
function Log.warnOnce(key, ...)
	if warnedKeys[key] then
		Log.debug(...)
		return
	end
	warnedKeys[key] = true
	Log.warn(...)
end

function Log.debugText()
	return table.concat(debugLines, "\n")
end

function Log.isDebug()
	return debugEnabled
end

return Log
