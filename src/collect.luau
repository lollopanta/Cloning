-- Decides what goes into the file: root services or model objects, ignore rules, player
-- characters, engine-injected scripts, nil instances and the extras folder.
local Schema = require("schema")
local Quirks = require("quirks")
local Env = require("env")
local Util = require("util")
local Log = require("log")

local Collect = {}

local Players = game:GetService("Players")

-- Services written for a place save, in file order. ServerStorage is written separately
-- by the serializer because it also carries the extras folder.
local PLACE_SERVICES = {
	"Workspace", "Players", "Lighting", "MaterialService", "ReplicatedFirst", "ReplicatedStorage",
	"StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService", "Chat", "TextChatService",
	"LocalizationService", "ProximityPromptService", "VoiceChatService", "ServerScriptService",
}

-- List entries (IgnoreList, DecompileIgnore):
--   instance | "ClassName" | ClassName = true | ClassName = { "Name", ... }  -> "tree"
--   [instance] = false                                                         -> "self"
local function matcher(list)
	local instances, classes, named = {}, {}, {}
	if type(list) == "table" then
		for key, value in list do
			if type(key) == "number" then
				if typeof(value) == "Instance" then
					instances[value] = "tree"
				elseif type(value) == "string" then
					classes[value] = true
				end
			elseif typeof(key) == "Instance" then
				instances[key] = value == false and "self" or "tree"
			elseif type(key) == "string" then
				if type(value) == "table" then
					local names = {}
					for _, name in value do
						names[name] = true
					end
					named[key] = names
				elseif value then
					classes[key] = true
				end
			end
		end
	end
	return function(instance, className)
		local hit = instances[instance]
		if hit then
			return hit
		elseif classes[className] then
			return "tree"
		end
		local names = named[className]
		if names and names[instance.Name] then
			return "tree"
		end
		return nil
	end
end

function Collect.rules(options)
	local ignore = matcher(options.IgnoreList)
	local decompileIgnore = matcher(options.DecompileIgnore)
	local saveNotArchivable = options.IgnoreNotArchivable ~= false

	local characters = {}
	if options.RemovePlayerCharacters then
		for _, player in Players:GetPlayers() do
			if player.Character then
				characters[player.Character] = true
			end
		end
	end

	local starterPlayerScripts
	if options.IgnoreDefaultPlayerScripts then
		pcall(function()
			starterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
		end)
	end

	local rules = { only = nil }

	-- True when the instance and everything under it stays out of the file.
	function rules.skip(instance, className)
		if characters[instance] or ignore(instance, className) == "tree" then
			return true
		end
		if not saveNotArchivable and not instance.Archivable then
			return true
		end
		if starterPlayerScripts and instance.Parent == starterPlayerScripts
			and Quirks.defaultPlayerScripts[instance.Name] == className then
			return true
		end
		return false
	end

	function rules.children(instance)
		if ignore(instance, instance.ClassName) == "self" then
			return {}
		end
		local children = instance:GetChildren()
		local kept = table.create(#children)
		local only = rules.only
		for _, child in children do
			if not rules.skip(child, child.ClassName) and (not only or only[child]) then
				table.insert(kept, child)
			end
		end
		return kept
	end

	-- "tree", "self" or nil
	function rules.decompileIgnored(instance, className)
		return decompileIgnore(instance, className)
	end

	return rules
end

local function filteredNilInstances(own, rules)
	local list = {}
	if not Env.getnilinstances then
		Log.warn("NilInstances: this executor has no getnilinstances()")
		return list
	end
	Log.checkpoint("Calling getnilinstances")
	local ok, instances = pcall(Env.getnilinstances)
	Log.checkpoint("getnilinstances returned", ok, type(instances))
	if not ok or type(instances) ~= "table" then
		Log.warn("NilInstances: getnilinstances() failed or returned a non-table")
		return list
	end
	local seen = {}
	for index, instance in instances do
		Util.step()
		Log.checkpoint("Filtering nil instance", index)
		if typeof(instance) == "Instance" and instance ~= game and not own[instance]
			and not seen[instance] and instance.Parent == nil then
			seen[instance] = true
			local info = Schema.classInfo(instance.ClassName)
			if info.saveable and not info.service and not rules.skip(instance, instance.ClassName) then
				table.insert(list, instance)
			end
		end
	end
	Log.checkpoint("Filtered nil instances", #list)
	return list
end

-- Builds the job: roots, extras, rules, the scripts to decompile and a size estimate.
function Collect.build(options)
	local rules = Collect.rules(options)
	local job = { roots = {}, extras = {}, scripts = {}, estimate = 0, isModel = options.IsModel == true, rules = rules }

	if options.Object then
		local objects = typeof(options.Object) == "Instance" and { options.Object } or options.Object
		for _, object in objects do
			if typeof(object) == "Instance" then
				table.insert(job.roots, object)
			end
		end
		if #job.roots == 0 then
			error("Object must be an Instance or a list of Instances", 0)
		end
	elseif options.Mode == "full" then
		for _, child in game:GetChildren() do
			local className = child.ClassName
			if className ~= "ServerStorage" and Schema.classInfo(className).saveable and not rules.skip(child, className) then
				table.insert(job.roots, child)
			end
		end
	else
		for _, name in PLACE_SERVICES do
			local service = game:FindService(name)
			if service and Schema.classInfo(service.ClassName).saveable and not rules.skip(service, service.ClassName) then
				table.insert(job.roots, service)
			end
		end
	end

	if not job.isModel then
		local localPlayer = Players.LocalPlayer
		if options.IsolateLocalPlayer and localPlayer then
			table.insert(job.extras, { name = "LocalPlayer", contents = localPlayer:GetChildren(), folderize = true })
		end
		if options.IsolateLocalPlayerCharacter and localPlayer and localPlayer.Character then
			table.insert(job.extras, { name = "LocalPlayer Character", contents = { localPlayer.Character }, folderize = true })
		end
		if options.IsolatePlayers then
			table.insert(job.extras, { name = "Players", contents = Players:GetPlayers(), folderize = true })
		end
		if options.IsolateStarterPlayer then
			table.insert(job.extras, { name = "StarterPlayer", contents = game:GetService("StarterPlayer"):GetChildren(), folderize = true })
		end
		if type(options.ExtraInstances) == "table" and #options.ExtraInstances > 0 then
			table.insert(job.extras, { name = "Extra Instances", contents = options.ExtraInstances, folderize = true })
		end
		if options.NilInstances then
			table.insert(job.extras, { name = "Nil Instances", contents = filteredNilInstances(Schema.ownInstances(), rules), folderize = false })
		end
	end

	-- One pass over everything that will be written: counts instances for the progress bar,
	-- lists the scripts to decompile, and (scripts mode) marks branches that hold scripts.
	local scriptsOnly = options.Mode == "scripts" and not options.Object
	local holdsScripts = scriptsOnly and {} or nil
	local folderizeAll = options.SaveNotCreatable
	local function walk(instance, ignoredDepth, folderize, isRoot)
		Util.step()
		local className = instance.ClassName
		-- Mirror the writer: anything it leaves out (and everything under it) is skipped here,
		-- so no time goes into decompiling scripts that never reach the file.
		local info = Schema.classInfo(className)
		if (info.service and not isRoot) or ((not info.saveable or not info.known) and not (folderize or folderizeAll)) then
			return false
		end
		job.estimate += 1
		local mark = rules.decompileIgnored(instance, className)
		local isScript = instance:IsA("LuaSourceContainer")
		if isScript and ignoredDepth == 0 and mark == nil then
			table.insert(job.scripts, instance)
		end
		local childDepth = ignoredDepth + (mark == "tree" and 1 or 0)
		local found = isScript
		for _, child in rules.children(instance) do
			if walk(child, childDepth, folderize, false) then
				found = true
			end
		end
		if found and holdsScripts then
			holdsScripts[instance] = true
		end
		return found
	end
	for _, root in job.roots do
		walk(root, 0, job.isModel, true)
	end
	for _, extra in job.extras do
		for _, instance in extra.contents do
			if typeof(instance) == "Instance" then
				Log.checkpoint("Collecting extra tree", extra.name, instance.ClassName)
				walk(instance, 0, extra.folderize, false)
			end
		end
	end
	rules.only = holdsScripts
	if holdsScripts then
		for i = #job.roots, 1, -1 do
			if not holdsScripts[job.roots[i]] then
				table.remove(job.roots, i)
			end
		end
		for _, extra in job.extras do
			local kept = {}
			for _, instance in extra.contents do
				if holdsScripts[instance] then
					table.insert(kept, instance)
				end
			end
			extra.contents = kept
		end
	end
	return job
end

return Collect
