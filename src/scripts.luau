-- Script sources: bytecode -> decompiler, cached by bytecode hash for the whole session
-- (scripts that share bytecode, and re-saves, cost one decompile).
--
-- `decompile()` is whatever is installed when the save starts: the executor's native
-- decompiler, or a loader's hook such as Oracle (an HTTP API). Hooks can return their
-- error text as if it were source, so every result is checked before it is saved or cached.
local Env = require("env")
local Log = require("log")
local Util = require("util")

local Scripts = {}

local HttpService = game:GetService("HttpService")

local genv = (getgenv and getgenv()) or _G
local CACHE = genv.__SaveInstance420Sources
if type(CACHE) ~= "table" then
	CACHE = {}
	genv.__SaveInstance420Sources = CACHE
end

local state

-- Provider identification ------------------------------------------------------------------
local KNOWN_PROVIDERS = { -- substring of a URL or name inside the hook -> label
	{ "oracle.mshq.dev", "Oracle" },
	{ "oracle", "Oracle" },
	{ "lua.expert", "lua.expert" },
	{ "konstant", "Konstant" },
	{ "medal", "Medal" },
}

local function currentDecompile()
	local installed = genv.decompile
	if type(installed) == "function" then
		return installed
	end
	return Env.decompile
end

local function isNative(f)
	if type(iscclosure) == "function" then
		local ok, result = pcall(iscclosure, f)
		if ok then
			return result == true
		end
	end
	return false
end

-- Strings a hook holds (constants and upvalues), lowercased, for provider detection.
local function hookStrings(f)
	local strings = {}
	local debugLib = debug
	for _, getter in { debugLib.getconstants, debugLib.getupvalues, getconstants, getupvalues } do
		if type(getter) == "function" then
			local ok, values = pcall(getter, f)
			if ok and type(values) == "table" then
				for _, value in values do
					if type(value) == "string" then
						table.insert(strings, string.lower(value))
					end
				end
			end
		end
	end
	return strings
end

-- Returns the label for the installed decompile() and whether it is a native C function.
local function identify(f, options)
	local native = isNative(f)
	if type(options.DecompilerName) == "string" and options.DecompilerName ~= "" then
		return options.DecompilerName, native
	end
	-- Registration convention kept from 1.x:
	-- getgenv().__SaveInstanceDecompiler = { Name = "Oracle", Function = getgenv().decompile }
	local registered = genv.__SaveInstanceDecompiler
	if type(registered) == "table" and registered.Function == f and type(registered.Name) == "string" then
		return registered.Name, native
	end
	if native then
		return (string.match(Env.executor, "^(%S+)") or "executor") .. " decompile()", true
	end
	for _, text in hookStrings(f) do
		for _, provider in KNOWN_PROVIDERS do
			if string.find(text, provider[1], 1, true) then
				return provider[2], false
			end
		end
	end
	return "decompile() hook", false
end

-- Result checking --------------------------------------------------------------------------
local KEY_TEXT = { "key has expired", "expired key", "not redeemed", "invalid key", "invalid api key", "unauthorized", "unauthorised" }
local QUOTA_TEXT = { "quota", "out of credits", "out of requests", "insufficient credits", "insufficient balance", "no credits left", "no requests left" }
local RATE_TEXT = { "rate limit", "rate-limit", "ratelimit", "too many requests", "too many concurrent", "slow down" }
local STUBS = { -- placeholder "sources" providers return instead of failing
	"-- decompilation failed",
	"-- update the decompiling script",
	"-- something went wrong when decompiling",
	"-- your executor does not have a decompiler",
	"-- failed to decompile",
	"-- decompiler error",
}

local function containsAny(text, list)
	for _, needle in list do
		if string.find(text, needle, 1, true) then
			return true
		end
	end
	return false
end

local function scrub(text) -- providers sometimes echo the request URL, key included
	text = string.gsub(tostring(text), "([?&]key=)[^&%s\"']+", "%1***")
	text = string.gsub(text, "[%c]", " ")
	return string.sub(text, 1, 160)
end

-- nil when `source` looks like decompiled code; otherwise kind, message where kind is
-- "fatal" (stop decompiling: key or quota), "rate" (back off and retry) or "failed".
local function classify(source)
	if type(source) ~= "string" or string.match(source, "^%s*$") then
		return "failed", "decompiler returned nothing"
	end
	local head = string.lower(string.sub(source, 1, 300))
	for _, stub in STUBS do
		if string.sub(head, 1, #stub) == stub then
			return containsAny(head, RATE_TEXT) and "rate" or "failed", scrub(string.match(source, "^[^\n]*"))
		end
	end
	if string.find(head, "^%s*<!doctype") or string.find(head, "^%s*<html") then
		return (containsAny(head, RATE_TEXT) or string.find(head, "1015", 1, true)) and "rate" or "failed",
			"the provider returned a web page instead of source"
	end
	-- Error bodies are one short line of prose or a small JSON object; code is not.
	if #source <= 300 and not string.find(source, "\n", 1, true)
		and not string.find(head, "^%s*return[%s%(]") and not string.find(head, "^%s*local%s") then
		if containsAny(head, KEY_TEXT) or containsAny(head, QUOTA_TEXT) then
			return "fatal", scrub(source)
		elseif containsAny(head, RATE_TEXT) then
			return "rate", scrub(source)
		elseif string.find(head, "^%s*{") and (string.find(head, "error", 1, true) or string.find(head, "message", 1, true)) then
			return "failed", scrub(source)
		end
	end
	return nil
end
Scripts.classify = classify

-- Calling the provider --------------------------------------------------------------------
-- Runs f in its own thread and waits up to `timeout` seconds. A thread that overruns is
-- abandoned, never cancelled: task.cancel on a thread inside a native decompiler crashes
-- Volt. A late result is simply ignored.
local function callWithTimeout(timeout, f, ...)
	local box = { done = false }
	task.spawn(function(...)
		box.result = table.pack(pcall(f, ...))
		box.done = true
	end, ...)
	if not box.done then
		local deadline = os.clock() + timeout
		while not box.done do
			if os.clock() > deadline then
				return false, string.format("timed out after %gs", timeout)
			end
			task.wait()
		end
	end
	return table.unpack(box.result, 1, box.result.n)
end

-- lua.expert free API. Requests are spaced by DecompilerApiGap seconds (it rejects bursts)
-- and `request` is called directly: some executors' request misbehaves in spawned threads.
local nextRequestAt = 0
local function apiDecompile(_, bytecode)
	local wait = nextRequestAt - os.clock()
	if wait > 0 then
		task.wait(wait)
	end
	nextRequestAt = os.clock() + state.options.DecompilerApiGap
	local response = Env.request({
		Url = state.options.DecompilerApiUrl,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ script = Env.base64encode(bytecode) }),
	})
	if type(response) == "table" and type(response.Body) == "string" then
		if response.StatusCode == 200 or response.StatusCode == 429 then
			return response.Body -- a 429 body is classified as a rate limit
		end
	end
	error(string.format("HTTP %s", tostring(type(response) == "table" and response.StatusCode or "no response")), 0)
end

function Scripts.begin(options)
	state = {
		options = options,
		results = {},
		byHash = {}, -- [bytecode hash] = { source, by, fresh } | { failure }
		keys = {}, -- [script] = bytecode hash, filled by prepare()
		stats = { total = 0, decompiled = 0, cached = 0, failed = 0, server = 0, unavailable = 0 },
	}
	local hook = currentDecompile()
	if not options.Decompile then
		state.label = "off (Decompile = false)"
	elseif hook then
		local label, native = identify(hook, options)
		state.backend = function(script)
			return hook(script)
		end
		state.spawn, state.native, state.label = true, native, label
		state.concurrency = math.clamp(math.floor(tonumber(options.DecompileConcurrency) or 16), 1, 64)
		-- Remote hooks wait on HTTP; give them as long as their own request timeout.
		state.timeout = tonumber(options.DecompileTimeout) or (native and 10 or 30)
	elseif options.DecompilerFallback and Env.request and Env.getscriptbytecode then
		state.backend, state.spawn, state.concurrency, state.label = apiDecompile, false, 1, "lua.expert API"
		state.timeout = tonumber(options.DecompileTimeout) or 30
	else
		state.label = "unavailable on this executor"
	end
	return state.label
end

function Scripts.stats()
	return state.stats
end

function Scripts.stoppedReason()
	return state and state.stopped
end

-- "client" scripts carry bytecode on this client; "server" ones never do.
function Scripts.kind(script)
	if script:IsA("ModuleScript") or script:IsA("LocalScript") then
		return "client"
	elseif script:IsA("Script") then
		local ok, context = pcall(function()
			return script.RunContext
		end)
		return (ok and context == Enum.RunContext.Client) and "client" or "server"
	end
	return "client"
end

-- Calls the provider once. Returns kind, sourceOrMessage where kind is "ok", "fatal",
-- "rate" or "failed".
local function attempt(script, bytecode, timeout)
	local ok, source
	if state.spawn then
		ok, source = callWithTimeout(timeout, state.backend, script, bytecode)
	else
		ok, source = pcall(state.backend, script, bytecode)
	end
	if not ok then
		return "failed", scrub(source)
	end
	local kind, message = classify(source)
	if kind then
		return kind, message
	end
	return "ok", source
end

local function cachedEntry(key)
	local entry = state.byHash[key]
	if entry then
		return entry
	end
	if state.options.ScriptCache then
		entry = CACHE[key]
		if entry and classify(entry.source) then
			CACHE[key] = nil -- written by an older build that cached error text
			return nil
		end
	end
	return entry
end

local function remember(key, source)
	local entry = { source = source, by = state.label, fresh = true }
	state.byHash[key] = entry
	if state.options.ScriptCache then
		CACHE[key] = { source = source, by = state.label }
	end
end

local function stop(message)
	if not state.stopped then
		state.stopped = message
		Log.warn(string.format("%s stopped answering: %s. The remaining scripts are saved without source.", state.label, message))
	end
end

local function resolve(script)
	local result = state.results[script]
	if result then
		return result
	end
	local options = state.options
	local stats = state.stats
	stats.total += 1

	if Scripts.kind(script) == "server" then
		stats.server += 1
		result = { note = "server script: its source is never sent to the client" }
	elseif not state.backend and not options.DecompileJobless then
		stats.unavailable += 1
		result = { note = "not decompiled: decompiler " .. state.label }
	else
		local ok, bytecode = false, nil
		if Env.getscriptbytecode then
			ok, bytecode = pcall(Env.getscriptbytecode, script)
		end
		if not ok or type(bytecode) ~= "string" or bytecode == "" then
			stats.unavailable += 1
			result = { note = "no bytecode on this client" }
		else
			local key = state.keys[script] or Env.hash(bytecode)
			local known = cachedEntry(key)
			if known and known.failure then
				stats.failed += 1
				result = { note = "decompile failed: " .. known.failure }
			elseif known then
				if known.fresh then
					known.fresh = nil -- the first script with this bytecode counts as the decompile
					stats.decompiled += 1
					result = { source = known.source, note = "decompiled with " .. known.by }
				else
					stats.cached += 1
					result = { source = known.source, note = "decompiled with " .. known.by .. " (cached)" }
				end
			elseif options.DecompileJobless then
				stats.unavailable += 1
				result = { note = "not in the decompile cache (DecompileJobless)" }
			elseif state.stopped then
				stats.failed += 1
				result = { note = "not decompiled: " .. state.label .. " stopped (" .. state.stopped .. ")" }
			else
				local kind, value = attempt(script, bytecode, state.timeout)
				if kind == "ok" then
					remember(key, value)
					state.byHash[key].fresh = nil
					stats.decompiled += 1
					result = { source = value, note = "decompiled with " .. state.label }
				else
					if kind == "fatal" then
						stop(value)
					end
					stats.failed += 1
					result = { note = "decompile failed: " .. value }
				end
			end
			if options.SaveBytecode then
				result.bytecode = bytecode
			end
		end
	end
	state.results[script] = result
	return result
end

-- Decompiles everything in `list` before the save, so writing never stalls and progress
-- can be shown. Each distinct bytecode is decompiled once.
-- onProgress(done, total, label)
function Scripts.prepare(list, onProgress)
	local options = state.options
	if not state.backend or options.DecompileJobless then
		return
	end

	-- 1. Bytecode + hash for every client script (cheap), keeping one job per bytecode.
	local jobs, queued = {}, {}
	for i, script in list do
		if Scripts.kind(script) == "client" then
			local ok, bytecode = pcall(Env.getscriptbytecode, script)
			if ok and type(bytecode) == "string" and bytecode ~= "" then
				local key = Env.hash(bytecode)
				state.keys[script] = key
				if not queued[key] and not cachedEntry(key) then
					queued[key] = true
					table.insert(jobs, { key = key, script = script, bytecode = bytecode })
				end
			end
		end
		if i % 250 == 0 then
			onProgress(0, #list, "reading bytecode")
			Util.yield()
		end
	end

	-- 2. Worker pool. `limit` is how many may be in flight: it halves on a rate limit and
	-- creeps back up after a run of successes. A key or quota error stops everything.
	local total, done = #jobs, 0
	local queue, head, requeued = jobs, 1, {}
	local limit, inflight, cooldownUntil, backoff, streak = state.concurrency, 0, 0, 2, 0
	local timeout = state.timeout

	local function finish(job, kind, value)
		if kind == "ok" then
			remember(job.key, value)
		else
			state.byHash[job.key] = { failure = value }
			Log.debug("decompile failed:", Util.path(job.script), value)
		end
		done += 1
	end

	local function nextJob()
		local job = queue[head]
		if job then
			head += 1
			return job
		end
		return table.remove(requeued, 1)
	end

	local function handle(job)
		local kind, value = attempt(job.script, job.bytecode, timeout)
		if kind == "rate" then
			job.rateRetries = (job.rateRetries or 0) + 1
			streak = 0
			if job.rateRetries <= 6 then
				limit = math.max(1, limit // 2)
				cooldownUntil = math.max(cooldownUntil, os.clock() + backoff)
				Log.debug(string.format("rate limited (%s); %d in flight, waiting %gs", value, limit, backoff))
				backoff = math.min(backoff * 2, 30)
				table.insert(requeued, job)
				return
			end
		elseif kind == "fatal" then
			stop(value)
		elseif kind == "ok" then
			backoff = 2
			streak += 1
			if streak >= 40 and limit < state.concurrency then
				limit += 1
				streak = 0
			end
		end
		finish(job, kind, value)
	end

	local active = 0
	local function worker()
		while not state.stopped do
			while not state.stopped and (inflight >= limit or os.clock() < cooldownUntil) do
				task.wait(0.05)
			end
			if state.stopped then
				break
			end
			local job = nextJob()
			if not job then
				break
			end
			inflight += 1
			pcall(handle, job)
			inflight -= 1
			Util.step() -- a synchronous native decompiler must not hold the frame
		end
		active -= 1
	end

	if state.concurrency <= 1 then
		active = 1
		worker() -- API backends: one request at a time, on this thread
	else
		for _ = 1, math.min(state.concurrency, total) do
			active += 1
			task.spawn(worker)
		end
	end
	while active > 0 do
		onProgress(done, total, limit < state.concurrency and string.format("%s, slowed to %d at a time", state.label, limit) or state.label)
		task.wait()
	end

	-- 3. With many jobs queued inside a provider, a slow script can miss its deadline
	-- without being stuck. Give each plain failure one more try on its own, with more time.
	if not state.stopped and state.spawn and state.concurrency > 1 then
		local retry = {}
		for _, job in jobs do
			local entry = state.byHash[job.key]
			if entry and entry.failure then
				table.insert(retry, job)
			end
		end
		for i, job in retry do
			if state.stopped then
				break
			end
			onProgress(i, #retry, "retrying slow scripts")
			local kind, value = attempt(job.script, job.bytecode, timeout * 3)
			if kind == "ok" then
				remember(job.key, value)
			else
				if kind == "fatal" then
					stop(value)
				end
				state.byHash[job.key] = { failure = value }
			end
			Util.step()
		end
	end
	onProgress(total, total, state.label)

	local failed = 0
	for _, job in jobs do
		local entry = state.byHash[job.key]
		if not entry or entry.failure then
			failed += 1
		end
	end
	return { unique = total, failed = failed, stopped = state.stopped }
end

-- Final Source text for a script.
function Scripts.source(script, ignored)
	if ignored then
		return "-- SaveInstance 420 Edition: skipped by DecompileIgnore\n"
	end
	local result = resolve(script)
	local source = "-- SaveInstance 420 Edition: " .. result.note .. "\n"
	if result.source then
		source ..= result.source
	end
	if result.bytecode then
		source ..= "\n\n--[==[ bytecode (base64)\n" .. Env.base64encode(result.bytecode) .. "\n]==]\n"
	end
	return source
end

return Scripts
