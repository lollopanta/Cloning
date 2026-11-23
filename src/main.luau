-- Entry point: returns the saveinstance(options) function.

--[=[
	@class SaveInstance
	Saves the current place, or selected instances, to the executor's workspace as a
	Roblox XML file (.rbxlx for places, .rbxmx for models).

	Every option is described in the [Options reference](/docs/options).
]=]

--[=[
	@function saveinstance
	@within SaveInstance
	@param target table | Instance | { Instance } -- the options table, or what to save as a model
	@param options table? -- options, when the first argument is an instance or a list of instances
	@return table -- { ok, path, bytes, instances, scripts, decompiler, elapsed, warnings } or { ok = false, error, trace }

	```lua
	local saveinstance = loadstring(game:HttpGet(
		"https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
	))()

	saveinstance()                          -- the whole place
	saveinstance({ Decompile = false })     -- map only
	saveinstance(workspace.SomeModel)       -- one model
	```
]=]
local Options = require("options")
local Env = require("env")
local Log = require("log")
local Util = require("util")
local Schema = require("schema")
local Scripts = require("scripts")
local Collect = require("collect")
local Serialize = require("serialize")
local Writer = require("writer")
local Streaming = require("streaming")
local UI = require("ui")

local Players = game:GetService("Players")

local FOLDER = "SaveInstance420"

local function timestamp()
	return os.date("!%Y-%m-%d %H.%M.%S")
end

local function placeName()
	local name
	pcall(function()
		name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	return Util.fileSafe(name or game.Name)
end

local function outputPath(options, job)
	local base = options.FilePath
	if type(base) ~= "string" or base == "" then
		local subject = job.isModel and Util.fileSafe(job.roots[1] and job.roots[1].Name or "Model") or placeName()
		base = subject .. " - " .. tostring(game.PlaceId) .. " - " .. timestamp()
	end
	return base .. (job.isModel and ".rbxmx" or ".rbxlx")
end

local function neutralizeLighting()
	local Lighting = game:GetService("Lighting")
	pcall(function()
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.ExposureCompensation = 0
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = true
		Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end)
	local function soften(effect)
		if effect:IsA("PostEffect") then
			pcall(function()
				effect.Enabled = false
			end)
		elseif effect:IsA("Atmosphere") then
			pcall(function()
				effect.Density, effect.Haze, effect.Glare = 0, 0, 0
			end)
		end
	end
	for _, effect in Lighting:GetDescendants() do
		soften(effect)
	end
	if workspace.CurrentCamera then
		for _, effect in workspace.CurrentCamera:GetChildren() do
			soften(effect)
		end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		pcall(function()
			clouds.Enabled = false
		end)
	end
end

local function startAntiIdle()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local VirtualUser = game:GetService("VirtualUser")
	return player.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end

return function(version)
	local genv = (getgenv and getgenv()) or _G

	if genv.__SaveInstance420Dev then
		-- Development only: lets tools/live.mjs tests reach individual modules.
		genv.__SaveInstance420Internals = {
			Scripts = Scripts,
			Schema = Schema,
			Encode = require("encode"),
			Env = Env,
			Options = Options,
		}
	end

	local function run(options, ui, status, cleanups)
		local started = os.clock()
		Util.setYieldBudget(options.YieldBudget)
		Schema.reset(options)

		local function report(phase, done, total, detail)
			status.phase, status.done, status.total = phase, done or 0, total or 0
			status.elapsed = os.clock() - started
			if ui then
				ui.set(phase .. (total and total > 0 and string.format(" %d / %d", done, total) or ""),
					total and total > 0 and done / total or nil,
					(detail or "") .. "  ·  " .. Util.formatDuration(status.elapsed))
			end
		end

		Log.info(string.format("SaveInstance 420 Edition %s on %s", version, Env.executor))
		Log.info(string.format("schema: %s (snapshot %s) | base64: %s | hidden properties: %s",
			Schema.usingReflection and "ReflectionService + snapshot" or "snapshot only",
			Schema.snapshotVersion, Env.base64source or "none",
			Env.gethiddenproperty and (options.IgnoreSpecialProperties and "off (IgnoreSpecialProperties)" or "gethiddenproperty")
				or "unavailable (unions and some properties will be incomplete)"))
		if not Env.base64encode then
			error("no working base64 encoder", 0)
		end
		local decompiler = Scripts.begin(options)
		Log.info("decompiler: " .. decompiler)

		local antiIdle = options.AntiIdle and startAntiIdle() or nil
		if antiIdle then
			table.insert(cleanups, function()
				antiIdle:Disconnect()
			end)
		end
		if options.NeutralizeLighting then
			neutralizeLighting()
		end

		if options.SetStreaming then
			report("Streaming the map in")
			local complete, summary, restore = Streaming.run(options, function(done, total, eta, note)
				report("Streaming map", done, total, note or (eta and ("about " .. Util.formatDuration(eta) .. " left")))
			end)
			table.insert(cleanups, restore)
			if complete then
				Log.info("streaming: " .. summary)
			else
				Log.warn("streaming incomplete: " .. summary)
			end
		end

		report("Collecting instances")
		local job = Collect.build(options)
		Log.info(string.format("collected ~%d instances, %d scripts in %s", job.estimate, #job.scripts,
			Util.formatDuration(os.clock() - started)))

		if options.Decompile and #job.scripts > 0 then
			local decompileStarted = os.clock()
			local prepared = Scripts.prepare(job.scripts, function(done, total, label)
				report("Decompiling scripts", done, total, label)
			end)
			if prepared then
				Log.info(string.format("decompiled %d unique scripts (%d failed) in %s", prepared.unique, prepared.failed,
					Util.formatDuration(os.clock() - decompileStarted)))
			end
		end

		if options.SafeMode and Players.LocalPlayer then
			pcall(Players.LocalPlayer.Kick, Players.LocalPlayer, "\nSaveInstance 420: saving this place, please wait...")
			pcall(function()
				game:GetService("RunService"):Set3dRenderingEnabled(false)
			end)
			table.insert(cleanups, function()
				game:GetService("RunService"):Set3dRenderingEnabled(true)
			end)
		end

		local path = outputPath(options, job)
		status.path = path
		report("Saving instances", 0, job.estimate)
		local writer = Writer.open(path, options.Callback)
		local saveStarted = os.clock()
		local ok, statsOrError = pcall(Serialize.run, job, writer, options, version, function(done, bytes)
			status.bytes = bytes
			report("Saving instances", math.min(done, job.estimate), job.estimate, Util.formatBytes(bytes))
		end)
		if not ok then
			writer.abort()
			error(statsOrError, 0)
		end
		local bytes = writer.finish()

		local stats = statsOrError
		local skipped = {}
		for className, count in stats.skippedClasses do
			table.insert(skipped, className .. " x" .. count)
		end
		if #skipped > 0 then
			table.sort(skipped)
			Log.debug("left out (not saveable): " .. table.concat(skipped, ", "))
		end

		local elapsed = os.clock() - started
		local s = Scripts.stats()
		if s.total > 0 then
			Log.info(string.format("scripts: %d decompiled, %d reused, %d failed, %d server-only, %d without source",
				s.decompiled, s.cached, s.failed, s.server, s.unavailable))
		end
		Log.info(string.format("saved %s: %d instances, %s in %s (writing took %s)", path, stats.instances,
			Util.formatBytes(bytes), Util.formatDuration(elapsed), Util.formatDuration(os.clock() - saveStarted)))
		return {
			ok = true,
			path = path,
			bytes = bytes,
			instances = stats.instances,
			sharedStrings = stats.sharedStrings,
			scripts = Scripts.stats(),
			decompiler = decompiler,
			decompilerStopped = Scripts.stoppedReason(),
			elapsed = elapsed,
			warnings = Log.warnings,
		}
	end

	local function saveinstance(first, second)
		if genv.__SaveInstance420Busy then
			warn("[SaveInstance] A save is already running")
			return { ok = false, error = "a save is already running" }
		end
		genv.__SaveInstance420Busy = true
		Log.begin(false)
		local previousIdentity = Env.elevate()

		local resolved, options = pcall(Options.resolve, first, second)
		if not resolved then
			genv.__SaveInstance420Busy = nil
			error(options, 2)
		end
		Log.setDebug(options.Debug)

		local status = { version = version, phase = "starting", done = 0, total = 0, bytes = 0, elapsed = 0 }
		genv.SaveInstance420Status = status
		local ui = options.ShowStatus and UI.open(version) or nil

		local cleanups = {}
		local ok, result = xpcall(run, function(message)
			return { message = tostring(message), trace = debug.traceback(nil, 2) }
		end, options, ui, status, cleanups)

		for _, cleanup in cleanups do
			pcall(cleanup)
		end
		Schema.cleanup()
		genv.__SaveInstance420Busy = nil
		if previousIdentity and Env.setthreadidentity then
			pcall(Env.setthreadidentity, previousIdentity)
		end

		if not ok then
			Log.warn("save failed: " .. result.message)
			Log.debug(result.trace)
			result = { ok = false, error = result.message, trace = result.trace, warnings = Log.warnings }
			if ui then
				ui.finish("Save failed", result.error, false)
				ui.close(8)
			end
		elseif ui then
			ui.finish("Saved " .. result.path, string.format("%d instances  ·  %s  ·  %s", result.instances,
				Util.formatBytes(result.bytes), Util.formatDuration(result.elapsed)), true)
			ui.close(6)
		end
		status.phase = ok and "done" or "failed"
		status.result = result

		if Log.isDebug() and Env.writefile then
			pcall(function()
				if Env.isfolder and Env.makefolder and not Env.isfolder(FOLDER) then
					Env.makefolder(FOLDER)
				end
				Env.writefile(FOLDER .. "/debug " .. timestamp() .. ".log", Log.debugText())
			end)
		end
		if ok and options.ShutdownWhenDone then
			game:Shutdown()
		end
		return result
	end

	return saveinstance
end
