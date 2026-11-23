-- Executor capability detection.
-- Functions are looked up by their known names only. Nothing is downloaded and nothing is
-- fuzzy-matched; the old method finder came from a repository that no longer exists.
local Env = {}

local function first(...)
	for i = 1, select("#", ...) do
		local candidate = select(i, ...)
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function field(container, key)
	if type(container) ~= "table" and type(container) ~= "userdata" then
		return nil
	end
	local ok, value = pcall(function()
		return container[key]
	end)
	return ok and value or nil
end

Env.gethiddenproperty = first(gethiddenproperty)
Env.sethiddenproperty = first(sethiddenproperty)
Env.getscriptbytecode = first(getscriptbytecode, get_script_bytecode)
Env.decompile = first(decompile)
Env.getnilinstances = first(getnilinstances, get_nil_instances)
Env.writefile = first(writefile)
Env.appendfile = first(appendfile)
Env.readfile = first(readfile)
Env.isfile = first(isfile)
Env.isfolder = first(isfolder)
Env.makefolder = first(makefolder)
Env.delfile = first(delfile)
Env.request = first(request, http_request, field(syn, "request"), field(http, "request"), field(fluxus, "request"))
Env.gethui = first(gethui, get_hidden_gui)
Env.protectgui = first(protectgui, field(syn, "protect_gui"))
Env.setthreadidentity = first(setthreadidentity, set_thread_identity, setidentity, field(syn, "set_thread_identity"))
Env.getthreadidentity = first(getthreadidentity, get_thread_identity, getidentity, field(syn, "get_thread_identity"))
Env.getconnections = first(getconnections, get_signal_cons)
Env.setclipboard = first(setclipboard, toclipboard, set_clipboard)

do
	local identify = first(identifyexecutor, getexecutorname, whatexecutor)
	local name = "Unknown executor"
	if identify then
		local ok, executor, version = pcall(identify)
		if ok and executor then
			name = tostring(executor) .. (version and (" " .. tostring(version)) or "")
		end
	end
	Env.executor = name
end

local EncodingService
pcall(function()
	EncodingService = game:GetService("EncodingService")
end)
Env.EncodingService = EncodingService

-- Base64 ----------------------------------------------------------------------------
-- Preference: the engine's EncodingService (native, identical on every executor), then
-- the executor's own encoder, then a pure-Luau encoder. Every candidate must reproduce a
-- known vector before it is trusted: some executors' helpers have returned odd output.
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ALPHABET_BYTES = buffer.fromstring(ALPHABET)

local function pureBase64(input)
	local length = #input
	if length == 0 then
		return ""
	end
	local source = buffer.fromstring(input)
	local out = buffer.create(math.ceil(length / 3) * 4)
	local readu8, writeu8 = buffer.readu8, buffer.writeu8
	local i, o = 0, 0
	while i + 2 < length do
		local n = readu8(source, i) * 65536 + readu8(source, i + 1) * 256 + readu8(source, i + 2)
		writeu8(out, o, readu8(ALPHABET_BYTES, n // 262144))
		writeu8(out, o + 1, readu8(ALPHABET_BYTES, (n // 4096) % 64))
		writeu8(out, o + 2, readu8(ALPHABET_BYTES, (n // 64) % 64))
		writeu8(out, o + 3, readu8(ALPHABET_BYTES, n % 64))
		i += 3
		o += 4
	end
	local rest = length - i
	if rest > 0 then
		local n = readu8(source, i) * 65536 + (rest == 2 and readu8(source, i + 1) * 256 or 0)
		writeu8(out, o, readu8(ALPHABET_BYTES, n // 262144))
		writeu8(out, o + 1, readu8(ALPHABET_BYTES, (n // 4096) % 64))
		writeu8(out, o + 2, rest == 2 and readu8(ALPHABET_BYTES, (n // 64) % 64) or 61)
		writeu8(out, o + 3, 61)
	end
	return buffer.tostring(out)
end

do
	local VECTOR_IN, VECTOR_OUT = "\0\1\2\255abc", "AAEC/2FiYw=="
	local candidates = {}
	if EncodingService then
		table.insert(candidates, {
			"EncodingService",
			function(input)
				return buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(input)))
			end,
		})
	end
	local crypt = crypt
	for _, entry in
		{
			{ "crypt.base64encode", field(crypt, "base64encode") },
			{ "crypt.base64.encode", field(field(crypt, "base64"), "encode") },
			{ "base64encode", base64encode },
			{ "base64_encode", base64_encode },
			{ "base64.encode", field(base64, "encode") },
		}
	do
		if type(entry[2]) == "function" then
			table.insert(candidates, entry)
		end
	end
	table.insert(candidates, { "pure Luau", pureBase64 })

	for _, candidate in candidates do
		local ok, output = pcall(candidate[2], VECTOR_IN)
		if ok and output == VECTOR_OUT then
			Env.base64encode = candidate[2]
			Env.base64source = candidate[1]
			break
		end
	end
end

-- Hashing (cache keys for decompiled sources) ---------------------------------------
do
	local algorithm
	pcall(function()
		algorithm = Enum.HashAlgorithm.Blake3
	end)
	local native = EncodingService
		and algorithm
		and pcall(EncodingService.ComputeStringHash, EncodingService, "probe", algorithm)
		and function(input)
			return EncodingService:ComputeStringHash(input, algorithm)
		end

	-- FNV-1a over the whole string plus its length: only used if the engine hash is gone.
	local function fallback(input)
		local h1, h2 = 2166136261, 5381
		local data = buffer.fromstring(input)
		for i = 0, #input - 1 do
			local byte = buffer.readu8(data, i)
			h1 = bit32.bxor(h1, byte)
			h1 = (h1 * 16777619) % 4294967296
			h2 = (h2 * 33 + byte) % 4294967296
		end
		return string.format("%d:%08x%08x", #input, h1, h2)
	end

	Env.hash = native or fallback
	Env.hashSource = native and "EncodingService Blake3" or "FNV-1a"
end

-- SharedString keys: Roblox uses a 16-byte hash (historically MD5) encoded as base64.
-- Any unique 16-byte key loads, so a counter is the fallback.
do
	local md5
	pcall(function()
		md5 = Enum.HashAlgorithm.Md5
	end)
	if EncodingService and md5 and pcall(EncodingService.ComputeStringHash, EncodingService, "probe", md5) then
		function Env.sharedKey(bytes)
			return Env.base64encode(EncodingService:ComputeStringHash(bytes, md5))
		end
	else
		function Env.sharedKey(_, index)
			return Env.base64encode(string.pack("<I8I8", index, 0x53534934))
		end
	end
end

-- Thread identity: run our own threads at the executor's highest level so reflection,
-- hidden properties and services are readable. Returns the previous level, if known.
function Env.elevate()
	local previous
	if Env.getthreadidentity then
		local ok, level = pcall(Env.getthreadidentity)
		previous = ok and level or nil
	end
	if Env.setthreadidentity then
		pcall(Env.setthreadidentity, 8)
	end
	return previous
end

function Env.guiParent()
	if Env.gethui then
		local ok, gui = pcall(Env.gethui)
		if ok and typeof(gui) == "Instance" then
			return gui, false
		end
	end
	local ok, coreGui = pcall(game.GetService, game, "CoreGui")
	if ok and coreGui then
		return coreGui, true
	end
	local player = game:GetService("Players").LocalPlayer
	return player and player:FindFirstChildOfClass("PlayerGui"), true
end

return Env
