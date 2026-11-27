-- Options: defaults, legacy aliases, and the call forms the original loader accepted.
local Log = require("log")

local Options = {}

-- { name, default } in display order. Names are matched case-insensitively.
local SPECS = {
	-- What to save
	{ "Mode", "optimized" }, -- "optimized" | "full" | "scripts"
	{ "Object", false }, -- Instance or { Instance } to save as a model (.rbxmx)
	{ "IsModel", "auto" },
	{ "ExtraInstances", {} },
	{ "IgnoreList", { "CoreGui", "CorePackages" } },
	{ "IgnoreProperties", {} },
	{ "IgnoreNotArchivable", true }, -- true = also save instances with Archivable = false
	{ "NilInstances", false },
	{ "RemovePlayerCharacters", true },
	{ "IsolateLocalPlayer", false },
	{ "IsolateLocalPlayerCharacter", false },
	{ "IsolatePlayers", false },
	{ "IsolateStarterPlayer", false },
	{ "SaveNotCreatable", false },

	-- Scripts
	{ "Decompile", true },
	{ "DecompileTimeout", false }, -- seconds per script; false = 10 for native decompilers, 30 for HTTP hooks
	{ "DecompileConcurrency", 16 }, -- decompiles in flight at once (native decompilers that yield)
	{ "DecompileIgnore", { "TextChatService" } },
	{ "DecompileJobless", false },
	{ "IgnoreDefaultPlayerScripts", true },
	{ "ScriptCache", true },
	{ "SaveBytecode", false },
	{ "DecompilerFallback", true }, -- use the lua.expert API when the executor has no decompile()
	{ "DecompilerApiUrl", "https://api.lua.expert/decompile" },
	{ "DecompilerApiGap", 0.12 },
	{ "DecompilerName", false },

	-- Properties
	{ "IgnoreDefaultProperties", true },
	{ "IgnoreSpecialProperties", false },
	{ "UseUGCValidationService", true },
	{ "IgnoreSharedStrings", false },
	{ "TreatUnionsAsParts", false },

	-- Output and behaviour
	{ "FilePath", false },
	{ "Callback", false },
	{ "ShowStatus", true },
	{ "ReadMe", true },
	{ "Debug", false },
	{ "SafeMode", false },
	{ "ShutdownWhenDone", false },
	{ "AntiIdle", true },
	{ "NeutralizeLighting", false },

	-- Streaming (StreamingEnabled games): request the map around the character before saving
	{ "SetStreaming", false },
	{ "StreamingAreaSize", 10000 }, -- side of the square swept around StreamingCenter, in studs
	{ "StreamingRadius", 512 }, -- grid spacing and settle radius, in studs
	{ "StreamingCenter", false }, -- Vector3; false = the character's position
	{ "StreamingSlices", 2 }, -- vertical layers per grid point
	{ "StreamingPasses", 1 },
	{ "StreamingPoints", false }, -- explicit { Vector3 } list instead of a grid
	{ "StreamingConcurrency", 4 },
	{ "StreamingTimeout", 20 }, -- seconds per request
	{ "StreamingChunkWait", 6 }, -- seconds to wait for a region to settle
	{ "StreamingSettleTime", 5 }, -- pause after the sweep for late arrivals
	{ "StreamingMaxTime", false }, -- overall limit in seconds; false = derived from the grid
	{ "YieldBudget", 8 }, -- milliseconds of work per frame
}

-- Legacy USSI / 420 names. { canonical, invert }
local ALIASES = {
	noscripts = { "Decompile", true },
	timeout = { "DecompileTimeout" },
	scriptcache = { "ScriptCache" },
	filename = { "FilePath" },
	ignoredefaultprops = { "IgnoreDefaultProperties" },
	savenoncreatable = { "SaveNotCreatable" },
	saveplayers = { "IsolatePlayers" },
	removeplayers = { "IsolatePlayers", true },
	ignorearchivable = { "IgnoreNotArchivable" },
	saveplayercharacters = { "RemovePlayerCharacters", true },
	__debug_mode = { "Debug" },
	streaming = { "SetStreaming" },
}

-- Accepted for compatibility; the rewrite no longer needs them.
local RETIRED = {
	decomptype = true,
	savecacheinterval = true,
	alternativewritefile = true,
	sharedstringoverwrite = true,
	ignorepropertiesofnotscriptsonscriptsmode = true,
	nilinstancesfixes = true,
	notcreatablefixes = true,
	anonymous = true,
}

local CANONICAL = {}
for _, spec in SPECS do
	CANONICAL[string.lower(spec[1])] = spec[1]
end

local function copy(value)
	if type(value) == "table" then
		return table.clone(value)
	end
	return value
end

local function isInstanceList(value)
	return type(value) == "table" and typeof(value[1]) == "Instance"
end

-- Accepts every call form of the original:
--   saveinstance()                  saveinstance(options)
--   saveinstance(instance)          saveinstance({ instance, ... })
--   saveinstance(instance, options) saveinstance({ instance, ... }, options)
function Options.resolve(first, second)
	local options = {}
	for _, spec in SPECS do
		options[spec[1]] = copy(spec[2])
	end

	local user, objects
	if typeof(first) == "Instance" or isInstanceList(first) then
		objects = first
		user = type(second) == "table" and second or {}
	elseif type(first) == "table" then
		user = first
	else
		user = {}
	end

	for key, value in user do
		if type(key) ~= "string" then
			continue
		end
		local lower = string.lower(key)
		local canonical = CANONICAL[lower]
		local alias = ALIASES[lower]
		if canonical then
			options[canonical] = value
		elseif alias then
			if alias[2] and type(value) == "boolean" then
				value = not value
			end
			options[alias[1]] = value
		elseif RETIRED[lower] then
			Log.debug("option", key, "is no longer needed and was ignored")
		elseif lower ~= "readme" then
			Log.warnOnce("option:" .. lower, "Unknown option '" .. key .. "' was ignored")
		end
	end

	if objects then
		options.Object = objects
	end
	if options.Object == game then
		options.Object = false
		options.Mode = "full"
	end
	if options.Object and options.IsModel == "auto" then
		options.IsModel = true
	elseif options.IsModel == "auto" then
		options.IsModel = false
	end

	options.Mode = string.lower(tostring(options.Mode))
	if options.Mode == "script" then
		options.Mode = "scripts"
	end
	local timeout = tonumber(options.DecompileTimeout)
	options.DecompileTimeout = timeout and (timeout <= 0 and math.huge or timeout) or false
	return options
end

return Options
