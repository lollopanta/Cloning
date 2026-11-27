-- Copy the rebuilt saveinstance.luau into your executor workspace at ssi-dev/saveinstance.luau.
-- Run this file in Xeno. If Roblox closes, inspect ssi-dev/startup.log for the last stage.
getgenv().RSOPS_OFF = true
local history = ""
local function stage(message)
	history ..= message .. "\n"
	writefile("ssi-dev/startup.log", history)
end

stage("Reading local patched bundle")
local source = readfile("ssi-dev/saveinstance.luau")
stage("Compiling bundle (" .. #source .. " bytes)")
local loader, compileError = loadstring(source, "=saveinstance")
if not loader then
	stage("Compile failed: " .. tostring(compileError))
	error(compileError, 0)
end
stage("Initializing bundle")
local ok, result = pcall(function()
	local saveinstance = loader()
	stage("Starting save (options, thread identity, then UI)")
	return saveinstance({
		Mode = "optimized",
		NilInstances = true,
		RemovePlayerCharacters = true,
		IsolateLocalPlayer = false,
		Decompile = false,
		SetStreaming = false,
		StreamingAreaSize = 10000,
		FilePath = false,
		ShowStatus = true,
		NeutralizeLighting = false,
		SafeMode = false,
		Debug = true,
	})
end)
if not ok then
	stage("Lua error: " .. tostring(result))
	error(result, 0)
end
stage("Finished: ok=" .. tostring(result.ok) .. ", error=" .. tostring(result.error))
return result
