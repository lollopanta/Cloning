-- Run statistics for robloxscripts.com (Script Ops). What is sent and how to turn it off is
-- described at the top of the built saveinstance.luau (from src/prelude/telemetry.luau) and in
-- docs/privacy.md. Only counts are reported from here: no place content and no player names.
local Telemetry = {}

local ops

function Telemetry.attach(handle)
	ops = handle
end

local function call(method, ...)
	if ops ~= nil then
		pcall(function(...)
			ops[method](...)
		end, ...)
	end
end

-- Loaded successfully (ok = false with a short reason when it did not).
function Telemetry.ready(ok, reason)
	call("ready", ok, reason)
end

-- Counts one use of a feature. name: lowercase letters, digits and _; value: a short word.
function Telemetry.event(name, value)
	call("event", name, value)
end

function Telemetry.error(err, where)
	call("error", err, where)
end

return Telemetry
