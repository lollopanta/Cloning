-- Run from the repository root: lune run tools/test-collect.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Instance = require("@lune/roblox").Instance

local function instance(className, name, parent)
	local item = Instance.new(className)
	item.Name, item.Parent = name, parent
	return item
end

local workspace = instance("Folder", "Workspace")
local emptyService = instance("Folder", "Lighting")
local branch = instance("Folder", "Branch", workspace)
local script = instance("ModuleScript", "ClientCode", branch)
instance("Part", "UnrelatedMapPart", workspace)
local nilScript = instance("ModuleScript", "NilScript")
local nilPart = instance("Part", "NilPart")
local nilBranch = instance("Folder", "NilBranch")
instance("ModuleScript", "NestedNilScript", nilBranch)
instance("Part", "NestedNilPart", nilBranch)
local extra = { nilPart, nilScript }
local steps = 0
local modules = {
	log = { warn = function() end, checkpoint = function() end },
	quirks = { defaultPlayerScripts = {} },
	util = { step = function() steps += 1 end },
	env = { getnilinstances = function() return { nilPart, nilScript, nilBranch } end },
	schema = {
		classInfo = function() return { known = true, saveable = true, service = false } end,
		ownInstances = function() return {} end,
	},
}
local game = {
	GetService = function() return { GetPlayers = function() return {} end } end,
	FindService = function(_, name)
		return name == "Workspace" and workspace or name == "Lighting" and emptyService or nil
	end,
}
local function load(name)
	return luau.load(fs.readFile("src/" .. name .. ".luau"), {
		environment = { require = function(key) return assert(modules[key], key) end, game = game },
	})()
end
local Options, Collect = load("options"), load("collect")
local options = Options.resolve({
	Mode = "script", NilInstances = true, Decompile = false,
	RemovePlayerCharacters = true, IsolateLocalPlayer = false,
	SetStreaming = false, StreamingAreaSize = 10000, FilePath = false,
	ShowStatus = true, NeutralizeLighting = false, SafeMode = false, Debug = false,
})
assert(options.Mode == "scripts", "singular script must select scripts mode")
assert(Options.resolve({ Mode = "ScRiPtS" }).Mode == "scripts")
local job = Collect.build(options)
assert(#job.roots == 1 and job.roots[1] == workspace, "omit roots without scripts")
assert(#job.extras[1].contents == 2, "omit nil roots without scripts")
assert(#job.rules.children(workspace) == 1 and job.rules.children(workspace)[1] == branch)
assert(#job.rules.children(nilBranch) == 1, "filter descendants of nil roots")
assert(#job.scripts == 3, "collect scripts in live and nil trees")
assert(steps >= job.estimate + 3, "nil-instance enumeration must yield cooperatively")

options.ExtraInstances = extra
Collect.build(options)
assert(#extra == 2 and extra[1] == nilPart, "do not modify caller-owned ExtraInstances")
options.Mode = "optimized"
local full = Collect.build(options)
assert(#full.roots == 2 and #full.extras[2].contents == 3, "preserve normal-mode roots")
assert(#full.rules.children(workspace) == 2)
options.Mode, options.Object, options.IsModel = "scripts", nilPart, true
assert(Collect.build(options).roots[1] == nilPart, "explicit objects override scripts filtering")

options = Options.resolve({ NilInstances = true, IgnoreList = { nilPart } })
modules.env.getnilinstances = function() return { nilPart, nilScript, nilScript, script, "invalid" } end
local filtered = Collect.build(options).extras[1].contents
assert(#filtered == 1 and filtered[1] == nilScript, "filter ignored, duplicate, parented and invalid nil entries")
modules.schema.ownInstances = function() return { [nilScript] = true } end
assert(#Collect.build(options).extras[1].contents == 0, "exclude saver-owned nil instances")
modules.env.getnilinstances = function() error("native failure") end
assert(#Collect.build(options).extras[1].contents == 0, "handle getnilinstances Lua errors")
modules.env.getnilinstances = function() return false end
assert(#Collect.build(options).extras[1].contents == 0, "handle invalid getnilinstances results")

local writes, folder = {}, false
modules.env.isfolder = function() return folder end
modules.env.makefolder = function() folder = true end
modules.env.writefile = function(path, message) writes[path] = message end
local Log = load("log")
Log.begin(false)
Log.checkpoint("disabled")
assert(next(writes) == nil, "disabled debug must not write checkpoints")
Log.setDebug(true)
Log.checkpoint("Calling getnilinstances")
assert(folder and writes["SaveInstance420/last-operation.log"] == "Calling getnilinstances")
Log.checkpoint("getnilinstances returned", true, "table")
assert(writes["SaveInstance420/last-operation.log"] == "getnilinstances returned true table")
modules.env.writefile = function() error("disk unavailable") end
assert(pcall(Log.checkpoint, "failure"), "diagnostic writes must not break a save")

-- Also compile the generated bundle without running executor APIs.
luau.load(fs.readFile("saveinstance.luau"))
local diagnostic = fs.readFile("examples/diagnose-xeno.luau")
for _, failure in { "none", "compile", "initialize", "save" } do
	local log, globals = "", {}
	local run = luau.load(diagnostic, { environment = {
		getgenv = function() return globals end,
		print = function() end,
		readfile = function() return "mock bundle" end,
		writefile = function(path, text)
			assert(path == "ssi-dev/startup.log")
			log = text
		end,
		loadstring = function()
			if failure == "compile" then return nil, "compile error" end
			return function()
				if failure == "initialize" then error("initialize error") end
				return function(opts)
					assert(opts.Mode == "optimized" and opts.NilInstances and not opts.Decompile)
					if failure == "save" then error("save error") end
					return { ok = true }
				end
			end
		end,
	} })
	local ok = pcall(run)
	assert(globals.RSOPS_OFF == true)
	assert(ok == (failure == "none"))
	assert(string.find(log, failure == "none" and "Finished: ok=true" or failure .. " error", 1, true))
end
print("PASS: script alias, script-only roots and nil trees, yielding, caller data, object mode, bundle syntax")
print("PASS: diagnostic success, compile failure, initialization failure, save failure")
print("PASS: nil-instance validation and durable native-call checkpoints")
