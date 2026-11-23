-- Writes the XML document (Roblox XML format, version 4).
local Schema = require("schema")
local Scripts = require("scripts")
local Encode = require("encode")
local Env = require("env")
local Util = require("util")

local Serialize = {}

local function readme(version)
	return table.concat({
		"--[[",
		"\tSaved with SaveInstance 420 Edition " .. version,
		"\tPlace " .. tostring(game.PlaceId) .. ", saved " .. os.date("!%Y-%m-%d %H:%M UTC") .. " with " .. Env.executor,
		"",
		"\tWhat a client can save:",
		"\t- Server scripts never reach the client, so they contain only a note, and",
		"\t  ServerScriptService / ServerStorage start empty.",
		"\t- LocalScripts and ModuleScripts are decompiled; decompiled code can need fixes.",
		"\t- Only content streamed in to this client is saved.",
		"\t- MeshParts that use private assets can show as grey boxes in Studio.",
		"",
		"\tTips:",
		"\t- Save the place as .rbxl from Studio right away (smaller, faster to open).",
		"\t- Camera stuck: workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed, or delete the Camera.",
		"\t- Character will not spawn: move the scripts out of StarterPlayer, then run",
		"\t  game:GetService(\"Players\").CharacterAutoLoads = true in the command bar.",
		"]]",
		"return nil",
		"",
	}, "\n")
end

-- job: { roots, extras, rules, isModel }; onProgress(instancesWritten, bytes)
function Serialize.run(job, writer, options, version, onProgress)
	local push = writer.push
	local rules = job.rules
	local text, cdata = Encode.text, Encode.cdata
	local read, isDefault, plan = Schema.read, Schema.isDefault, Schema.plan
	local skipDefaults = options.IgnoreDefaultProperties ~= false
	local saveNotCreatable = options.SaveNotCreatable
	local unionsAsParts = options.TreatUnionsAsParts

	local ignoredProperties = {}
	for key, value in options.IgnoreProperties do
		if type(key) == "number" and type(value) == "string" then
			ignoredProperties[value] = true
		elseif type(key) == "string" and value then
			ignoredProperties[key] = true
		end
	end

	-- Referents and shared strings --------------------------------------------------------
	local referents, referentCount = {}, 0
	local sharedKeys, sharedList = {}, {}
	local ctx = {}

	function ctx.ref(instance)
		local referent = referents[instance]
		if not referent then
			referentCount += 1
			referent = "RBX" .. referentCount
			referents[instance] = referent
		end
		return referent
	end

	local function newReferent()
		referentCount += 1
		return "RBX" .. referentCount
	end

	function ctx.shared(bytes)
		local key = sharedKeys[bytes]
		if not key then
			key = Env.sharedKey(bytes, #sharedList + 1)
			sharedKeys[bytes] = key
			table.insert(sharedList, { key, bytes })
		end
		return key
	end

	local stats = { instances = 0, skippedClasses = {} }
	local scriptClass = {}
	local function isScriptClass(className)
		local result = scriptClass[className]
		if result == nil then
			result = Schema.isA(className, "LuaSourceContainer")
			scriptClass[className] = result
		end
		return result
	end

	-- Instances --------------------------------------------------------------------------
	local function writeProperties(instance, className, isScript, decompileIgnored)
		local entries = plan(className)
		for i = 1, #entries do
			local entry = entries[i]
			local name = entry.name
			if entry.dead or ignoredProperties[name] then
				continue
			end
			if isScript and name == "Source" then
				push(entry.open .. cdata(Scripts.source(instance, decompileIgnored)) .. entry.close)
				continue
			end
			local ok, value = read(instance, entry)
			if not ok or (skipDefaults and isDefault(className, entry, value)) then
				continue
			end
			local xml = entry.encode(value, ctx)
			if xml ~= nil then
				push(entry.open .. xml .. entry.close)
			end
		end
	end

	local function folderItem(instance, name)
		push('<Item class="Folder" referent="' .. ctx.ref(instance) .. '"><Properties><string name="Name">' .. text(name)
			.. "</string></Properties>")
	end

	local function writeInstance(instance, folderize, ignoredDepth, isRoot)
		Util.step()
		local className = instance.ClassName
		local info = Schema.classInfo(className)
		if info.service and not isRoot then
			return -- services only exist at the top of a place
		end
		local mark = rules.decompileIgnored(instance, className)
		local decompileIgnored = ignoredDepth > 0 or mark ~= nil

		if job.isModel and info.service then
			folderItem(instance, instance.Name) -- a service cannot be inserted as a model
		elseif not info.saveable or not info.known then
			if not (folderize or saveNotCreatable) then
				stats.skippedClasses[className] = (stats.skippedClasses[className] or 0) + 1
				return
			end
			folderItem(instance, "[" .. className .. "] " .. instance.Name)
		else
			local itemClass = className
			if unionsAsParts and Schema.isA(className, "PartOperation") then
				itemClass = "Part"
			end
			push('<Item class="' .. itemClass .. '" referent="' .. ctx.ref(instance) .. '"><Properties>')
			writeProperties(instance, itemClass, isScriptClass(itemClass), decompileIgnored)
			push("</Properties>")
		end

		stats.instances += 1
		if stats.instances % 250 == 0 then
			onProgress(stats.instances, writer.size())
		end
		local childDepth = ignoredDepth + (mark == "tree" and 1 or 0)
		for _, child in rules.children(instance) do
			writeInstance(child, folderize, childDepth, false)
		end
		push("</Item>")
	end

	-- Document ---------------------------------------------------------------------------
	push('<roblox version="4">')
	if not job.isModel then
		push('<Meta name="ExplicitAutoJoints">true</Meta>')
	end

	for _, root in job.roots do
		writeInstance(root, false, 0, true)
	end

	if not job.isModel then
		-- ServerStorage never replicates, so it is always written here. Its contents neither
		-- run nor render in Studio, which makes it the safe home for the extras folder.
		push('<Item class="ServerStorage" referent="' .. newReferent()
			.. '"><Properties><string name="Name">ServerStorage</string></Properties>')
		if options.ReadMe or #job.extras > 0 then
			push('<Item class="Folder" referent="' .. newReferent()
				.. '"><Properties><string name="Name">SaveInstance420</string></Properties>')
			if options.ReadMe then
				push('<Item class="ModuleScript" referent="' .. newReferent()
					.. '"><Properties><string name="Name">README</string><ProtectedString name="Source">'
					.. cdata(readme(version)) .. "</ProtectedString></Properties></Item>")
			end
			for _, extra in job.extras do
				push('<Item class="Folder" referent="' .. newReferent() .. '"><Properties><string name="Name">'
					.. text(extra.name) .. "</string></Properties>")
				for _, instance in extra.contents do
					if typeof(instance) == "Instance" then
						writeInstance(instance, extra.folderize, 0, false)
					end
				end
				push("</Item>")
			end
			push("</Item>")
		end
		push("</Item>")
	end

	if #sharedList > 0 then
		push("<SharedStrings>")
		for _, item in sharedList do
			push('<SharedString md5="' .. item[1] .. '">' .. Env.base64encode(item[2]) .. "</SharedString>")
			Util.step()
		end
		push("</SharedStrings>")
	end
	push("</roblox>")

	onProgress(stats.instances, writer.size())
	stats.referents = referentCount
	stats.sharedStrings = #sharedList
	return stats
end

return Serialize
