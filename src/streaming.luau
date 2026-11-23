-- Streams in map content before saving (StreamingEnabled games).
-- The client only holds what has streamed to it, so the sweep asks the server for every
-- point of a grid around the character, waits for each region to settle, and keeps
-- streamed content resident until the save finishes. Completeness is never guaranteed:
-- the server decides what to send.
local Env = require("env")
local Log = require("log")
local Util = require("util")

local Streaming = {}

local Players = game:GetService("Players")

local function number(value, fallback, low, high)
	local n = tonumber(value)
	if not n or n ~= n or math.abs(n) == math.huge then
		n = fallback
	end
	return math.clamp(n, low, high)
end

local function validPoint(p)
	return typeof(p) == "Vector3" and p.X == p.X and p.Y == p.Y and p.Z == p.Z
		and math.abs(p.X) ~= math.huge and math.abs(p.Y) ~= math.huge and math.abs(p.Z) ~= math.huge
end

-- Grid of request points (serpentine rows so consecutive requests stay close).
function Streaming.plan(options, player)
	if type(options.StreamingPoints) == "table" then
		local points = {}
		for i, point in options.StreamingPoints do
			if not validPoint(point) then
				return nil, "StreamingPoints entry " .. i .. " is not a valid Vector3"
			end
			points[i] = point
		end
		if #points == 0 then
			return nil, "StreamingPoints is empty"
		end
		return { points = points, spacing = number(options.StreamingRadius, 512, 64, 4096) }
	end
	local spacing = number(options.StreamingRadius, 512, 64, 4096)
	local area = number(options.StreamingAreaSize, 10000, 0, 100000)
	local slices = math.floor(number(options.StreamingSlices, 2, 1, 8))
	local passes = math.floor(number(options.StreamingPasses, 1, 1, 3))
	local center = options.StreamingCenter
	if not validPoint(center) then
		center = Vector3.new(0, 50, 0)
		local character = player and player.Character
		if character then
			local ok, pivot = pcall(character.GetPivot, character)
			if ok then
				center = pivot.Position
			end
		end
	end
	local divisions = math.max(1, math.ceil(area / spacing))
	local width = area == 0 and 1 or divisions + 1
	local total = width * width * slices * passes
	if total > 10000 then
		return nil, "the sweep would need more than 10000 requests; lower StreamingAreaSize or raise StreamingRadius"
	end
	local points = table.create(total)
	for _ = 1, passes do
		for xi = 0, width - 1 do
			for zi = 0, width - 1 do
				local z = xi % 2 == 0 and zi or (width - 1 - zi)
				for yi = 0, slices - 1 do
					table.insert(points, center + Vector3.new(
						area == 0 and 0 or -area / 2 + xi * area / divisions,
						(yi - (slices - 1) / 2) * spacing * 0.8,
						area == 0 and 0 or -area / 2 + z * area / divisions
					))
				end
			end
		end
	end
	return { points = points, spacing = spacing, center = center }
end

-- Counts anchored parts near a point until the count stops changing.
local function waitForRegion(point, radius, maxWait)
	local function count()
		local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, point, radius)
		if not ok or not parts then
			return nil
		end
		local anchored = 0
		for _, part in parts do
			if part.Anchored then
				anchored += 1
			end
		end
		return anchored
	end
	local started = os.clock()
	local last, stableSince = count(), os.clock()
	if last == nil then
		return false
	end
	while os.clock() - started < maxWait do
		task.wait(0.5)
		local now = count()
		if now == nil then
			return false
		elseif now ~= last then
			last, stableSince = now, os.clock()
		end
		if os.clock() - started >= 1.5 and os.clock() - stableSince >= 1 then
			return true
		end
	end
	return false
end

-- Runs the sweep. Returns ok, summary, restore() (call restore after the save).
function Streaming.run(options, onProgress)
	local noop = function() end
	if not workspace.StreamingEnabled then
		return true, "StreamingEnabled is off; the whole map is already on the client", noop
	end
	local player = Players.LocalPlayer
	if not player then
		return false, "no LocalPlayer", noop
	end
	if options.SafeMode then
		return false, "streaming needs a connected client; turn SafeMode off", noop
	end
	local plan, reason = Streaming.plan(options, player)
	if not plan then
		return false, reason, noop
	end

	local points, spacing = plan.points, plan.spacing
	local total = #points
	local concurrency = math.floor(number(options.StreamingConcurrency, 4, 1, 8))
	local timeout = number(options.StreamingTimeout, 20, 1, 60)
	local chunkWait = number(options.StreamingChunkWait, 6, 1, 30)
	local maxTime = number(options.StreamingMaxTime, math.ceil(total / concurrency) * (math.min(timeout, 8) + chunkWait) * 1.25, 10, 3600)
	local started = os.clock()
	local deadline = started + maxTime

	-- Keep streamed content resident: Opportunistic stream-out evicts regions behind the sweep.
	local restore = noop
	if Env.gethiddenproperty and Env.sethiddenproperty then
		local ok, previous = pcall(Env.gethiddenproperty, workspace, "StreamOutBehavior")
		if ok and typeof(previous) == "EnumItem" and pcall(Env.sethiddenproperty, workspace, "StreamOutBehavior", Enum.StreamOutBehavior.LowMemory) then
			restore = function()
				pcall(Env.sethiddenproperty, workspace, "StreamOutBehavior", previous)
			end
		end
	end

	Log.info(string.format("streaming: %d requests around %s, %d at a time, up to %s", total,
		tostring(plan.center or "custom points"), concurrency, Util.formatDuration(maxTime)))

	local nextIndex, done, failed, unsettled, active = 0, 0, 0, 0, 0
	local function request(point)
		-- RequestStreamAroundAsync can hang past its own timeout on empty regions, so it runs
		-- on a side thread that is abandoned when the deadline passes.
		local box = { done = false }
		task.spawn(function()
			box.ok, box.err = pcall(player.RequestStreamAroundAsync, player, point, timeout)
			box.done = true
		end)
		local limit = os.clock() + timeout
		while not box.done and os.clock() < limit and os.clock() < deadline do
			task.wait(0.1)
		end
		return box.done and box.ok
	end
	local function worker()
		pcall(function()
			while os.clock() < deadline do
				nextIndex += 1
				local point = points[nextIndex]
				if not point then
					return
				end
				if not request(point) then
					failed += 1
				elseif not waitForRegion(point, spacing, math.min(chunkWait, math.max(0, deadline - os.clock()))) then
					unsettled += 1
				end
				done += 1
			end
		end)
		active -= 1
	end
	for _ = 1, math.min(concurrency, total) do
		active += 1
		task.spawn(worker)
	end
	while active > 0 and os.clock() < deadline do
		local elapsed = os.clock() - started
		onProgress(done, total, done > 0 and (total - done) * elapsed / done or nil)
		task.wait(0.25)
	end

	local settle = number(options.StreamingSettleTime, 5, 0, 60)
	if settle > 0 then
		onProgress(done, total, nil, "letting late regions arrive")
		task.wait(settle)
	end

	local complete = done == total and failed == 0 and unsettled == 0
	local summary = string.format("%d/%d regions requested, %d failed, %d still loading, %s", done, total, failed,
		unsettled, Util.formatDuration(os.clock() - started))
	if done < total then
		summary ..= " (time limit reached; raise StreamingMaxTime for a fuller save)"
	end
	return complete, summary, restore
end

return Streaming
