-- Small shared helpers: cooperative yielding and formatting.
local Util = {}

local budget = 0.008
local lastYield = os.clock()

-- How much work (in milliseconds) runs per frame before yielding.
function Util.setYieldBudget(ms)
	budget = math.clamp(tonumber(ms) or 8, 1, 100) / 1000
end

-- Call from every long loop. Yields one frame once this frame's budget is spent, so the
-- client keeps rendering and big games never white-screen during a save.
function Util.step()
	if os.clock() - lastYield >= budget then
		task.wait()
		lastYield = os.clock()
		return true
	end
	return false
end

function Util.yield()
	task.wait()
	lastYield = os.clock()
end

function Util.formatBytes(n)
	if n >= 1073741824 then
		return string.format("%.2f GB", n / 1073741824)
	elseif n >= 1048576 then
		return string.format("%.1f MB", n / 1048576)
	elseif n >= 1024 then
		return string.format("%.1f KB", n / 1024)
	end
	return string.format("%d B", n)
end

function Util.formatDuration(seconds)
	if seconds < 60 then
		return string.format("%.1fs", seconds)
	end
	return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds % 60))
end

function Util.path(instance)
	local ok, name = pcall(instance.GetFullName, instance)
	return ok and name or tostring(instance)
end

-- Makes a name safe to use as a Windows file name.
function Util.fileSafe(name)
	name = string.gsub(tostring(name), '[%c<>:"/\\|%?%*]', "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "[%s%.]+$", "")
	if #name > 120 then
		local cut = utf8.offset(name, 121)
		name = string.sub(name, 1, (cut or 121) - 1)
	end
	return name ~= "" and name or "Place"
end

return Util
