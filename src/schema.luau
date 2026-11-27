-- Which properties each class saves, and how to read them.
--
-- Two sources are merged per class:
--   1. ReflectionService on the running client: exact for this build, including members
--      newer than any published API dump.
--   2. The generated snapshot (schema_snapshot.luau): restores the serialized members that
--      ReflectionService hides from scripts (AttributesSerialize, Tags, union MeshData2 /
--      PhysicsData, Script.Source, Workspace streaming settings, ...), and is the whole
--      schema when reflection is unavailable.
-- A member is saved if either source says the engine serializes it.
local Snapshot = require("schema_snapshot")
local Quirks = require("quirks")
local Encode = require("encode")
local Env = require("env")
local Log = require("log")

local Schema = {}

local Reflection
do
	local ok, service = pcall(game.GetService, game, "ReflectionService")
	if ok and service then
		local probed, members = pcall(service.GetPropertiesOfClass, service, "Part")
		if probed and type(members) == "table" and #members > 0 then
			Reflection = service
		end
	end
end
Schema.usingReflection = Reflection ~= nil
Schema.snapshotVersion = Snapshot.version

local REFLECTION_TYPES = {
	Enum = "token",
	RefType = "Ref",
	CoordinateFrame = "CFrame",
	OptionalCoordinateFrame = "OptionalCFrame",
	Rect2D = "Rect",
	Vector3Int16 = "Vector3int16",
	Vector2Int16 = "Vector2int16",
}

-- Types whose nil value is meaningful (and must not be mistaken for a failed read).
local NILABLE = { Ref = true, OptionalCFrame = true, PhysicalProperties = true }

-- Snapshot access ------------------------------------------------------------------------
local parsedSnapshot = {}
local function snapshotClass(name)
	local entry = parsedSnapshot[name]
	if entry ~= nil then
		return entry or nil
	end
	local raw = Snapshot.classes[name]
	if not raw then
		parsedSnapshot[name] = false
		return nil
	end
	local super, flags, list = string.match(raw, "^([^|]*)|([^|]*)|(.*)$")
	entry = {
		super = super ~= "" and super or nil,
		notCreatable = string.find(flags, "N", 1, true) ~= nil,
		service = string.find(flags, "S", 1, true) ~= nil,
		props = {},
	}
	if list ~= "" then
		for _, item in string.split(list, ",") do
			local name, valueType, propFlags = string.match(item, "^([^:]+):([^:]+):?(.*)$")
			if name then
				table.insert(entry.props, {
					name = name,
					type = valueType,
					hidden = string.find(propFlags, "H", 1, true) ~= nil,
					preferred = string.match(propFlags, ">(.+)$"),
				})
			end
		end
	end
	parsedSnapshot[name] = entry
	return entry
end

local reflectedClasses = {}
local function reflectedClass(name)
	local entry = reflectedClasses[name]
	if entry == nil then
		entry = false
		if Reflection then
			local ok, class = pcall(Reflection.GetClass, Reflection, name)
			if ok and class then
				entry = class
			end
		end
		reflectedClasses[name] = entry
	end
	return entry or nil
end

local superclasses = {}
local function superclassOf(name)
	local super = superclasses[name]
	if super == nil then
		local snap = snapshotClass(name)
		if snap then
			super = snap.super
		else
			local class = reflectedClass(name)
			super = class and class.Superclass or nil
		end
		superclasses[name] = super or false
	end
	return super or nil
end
Schema.superclassOf = superclassOf

function Schema.isA(className, base)
	local current = className
	while current do
		if current == base then
			return true
		end
		current = superclassOf(current)
	end
	return false
end

local function quirkFor(map, className, propertyName)
	local current = className
	while current do
		local entries = map[current]
		local entry = entries and entries[propertyName]
		if entry ~= nil then
			return entry
		end
		current = superclassOf(current)
	end
	return nil
end

-- Class information ------------------------------------------------------------------------
local classInfos = {}

-- { known, saveable, creatable, service }
function Schema.classInfo(className)
	local info = classInfos[className]
	if info then
		return info
	end
	info = { name = className, known = false, saveable = false, creatable = false, service = false }
	local class = reflectedClass(className)
	local snap = snapshotClass(className)
	if class then
		local permits = class.Permits
		info.known = true
		info.saveable = class.Serialized == true
		info.creatable = type(permits) == "table" and permits.New ~= nil
		info.service = type(permits) == "table" and permits.GetService ~= nil
	elseif snap then
		info.known = true
		info.saveable = true
		info.creatable = not snap.notCreatable
		info.service = snap.service
	end
	if Quirks.unsaveable[className] then
		info.saveable = false
	end
	classInfos[className] = info
	return info
end

-- Read strategies ------------------------------------------------------------------------
local function index(instance, name)
	return instance[name]
end

local function directStrategy(name)
	return function(instance)
		return pcall(index, instance, name)
	end
end

local function hiddenStrategy(name)
	local gethiddenproperty = Env.gethiddenproperty
	return function(instance)
		Log.checkpoint("gethiddenproperty", instance.ClassName, name)
		local ok, value = pcall(gethiddenproperty, instance, name)
		return ok, value
	end
end

local function readerStrategy(reader)
	local read = reader.read
	return function(instance)
		return pcall(read, instance)
	end
end

local UGCValidationService
local function ugcStrategy(name)
	return function(instance)
		if not UGCValidationService then
			local ok, service = pcall(game.GetService, game, "UGCValidationService")
			if not ok or not service then
				return false
			end
			UGCValidationService = service
		end
		Log.checkpoint("UGCValidationService.GetPropertyValue", instance.ClassName, name)
		local ok, value = pcall(UGCValidationService.GetPropertyValue, UGCValidationService, instance, name)
		if ok and value ~= nil then -- this API returns nil for anything it cannot read
			return true, value
		end
		return false
	end
end

-- Plans --------------------------------------------------------------------------------------
local plans = {}
local settings = { hidden = true, ugc = true }
local defaultInstances = {}

function Schema.reset(options)
	table.clear(plans)
	settings.hidden = Env.gethiddenproperty ~= nil and not options.IgnoreSpecialProperties
	settings.ugc = options.UseUGCValidationService ~= false
	settings.sharedStrings = not options.IgnoreSharedStrings
end

local function buildStrategies(className, entry)
	local strategies = {}
	local alias = quirkFor(Quirks.aliases, className, entry.name)
	local reader = quirkFor(Quirks.readers, className, entry.name)
	if alias then
		table.insert(strategies, directStrategy(alias))
	end
	if reader and reader.first then
		table.insert(strategies, readerStrategy(reader))
	end
	if not entry.hidden then
		table.insert(strategies, directStrategy(entry.name))
	end
	if settings.hidden then
		table.insert(strategies, hiddenStrategy(entry.name))
	end
	if reader and not reader.first then
		table.insert(strategies, readerStrategy(reader))
	end
	if entry.preferred and entry.preferred ~= alias then
		table.insert(strategies, directStrategy(entry.preferred))
	end
	if entry.hidden then
		table.insert(strategies, directStrategy(entry.name)) -- some "hidden" members are readable at high identity
	end
	if settings.ugc then
		table.insert(strategies, ugcStrategy(entry.name))
	end
	return strategies
end

-- Returns the ordered property list for a class. Each entry:
--   name, type, open/close (XML tags), encode, strategies, nilable
function Schema.plan(className)
	local plan = plans[className]
	if plan then
		return plan
	end
	plan = {}
	local seen = {}

	local function add(name, valueType, hidden, preferred)
		if seen[name] or Quirks.blocked[name] then
			return
		end
		seen[name] = true
		if not Encode.supports(valueType) then
			Log.debug("schema: no encoder for", valueType, className .. "." .. name)
			return
		end
		if valueType == "SharedString" and not settings.sharedStrings then
			return
		end
		table.insert(plan, { name = name, type = valueType, hidden = hidden, preferred = preferred })
	end

	if Reflection then
		local ok, members = pcall(Reflection.GetPropertiesOfClass, Reflection, className)
		if ok and type(members) == "table" then
			for _, member in members do
				if member.Serialized == true and type(member.Type) == "table" then
					local engineType = member.Type.EngineType
					local permits = member.Permits
					local readable = type(permits) == "table" and permits.Read ~= nil
					if engineType then
						add(member.Name, REFLECTION_TYPES[engineType] or engineType, not readable, nil)
					end
				end
			end
		end
	end

	local current = className
	while current do
		local snap = snapshotClass(current)
		if snap then
			for _, member in snap.props do
				add(member.name, member.type, member.hidden, member.preferred)
			end
		end
		current = superclassOf(current)
	end

	local byName = {}
	for _, entry in plan do
		byName[entry.name] = entry
	end
	for _, entry in plan do
		if entry.type == "Content" and string.sub(entry.name, -7) == "Content" then
			local stem = string.sub(entry.name, 1, -8)
			local names = { stem, stem .. "Id", stem .. "ID" }
			for _, name in Quirks.contentAliases[entry.name] or {} do
				table.insert(names, name)
			end
			for _, name in names do
				local legacy = byName[name]
				if legacy and (legacy.type == "ContentId" or legacy.type == "int64" or legacy.type == "string") then
					legacy.content = entry.name
				end
			end
		end
	end
	table.sort(plan, function(a, b)
		return a.type == "Content" and b.type ~= "Content"
	end)

	for _, entry in plan do
		entry.open, entry.close = Encode.tags(entry.type, entry.name)
		entry.encode = Encode.encoders[entry.type]
		entry.nilable = NILABLE[entry.type] == true
		entry.strategies = buildStrategies(className, entry)
		entry.failures = 0
	end
	plans[className] = plan
	return plan
end

-- Reads one property, trying the strategy that worked last time first.
-- Returns ok, value.
function Schema.read(instance, entry)
	local strategies = entry.strategies
	local best = entry.best
	if best then
		local ok, value = strategies[best](instance)
		if ok and (value ~= nil or entry.nilable) then
			return true, value
		end
	end
	for i, strategy in strategies do
		if i ~= best then
			local ok, value = strategy(instance)
			if ok and (value ~= nil or entry.nilable) then
				entry.best = i
				return true, value
			end
		end
	end
	if not best then
		entry.failures += 1
		if entry.failures >= 50 then
			entry.dead = true -- never readable on this client; stop paying for the attempts
			Log.debug("schema: giving up on", entry.name, "after 50 failed reads")
		end
	end
	return false
end

-- Default values (IgnoreDefaultProperties) -------------------------------------------------
local function defaultInstance(className)
	local instance = defaultInstances[className]
	if instance == nil then
		instance = false
		if Schema.classInfo(className).creatable then
			local ok, created = pcall(Instance.new, className)
			if ok and created then
				instance = created
			end
		end
		defaultInstances[className] = instance
	end
	return instance or nil
end

function Schema.isDefault(className, entry, value)
	local hasDefault = entry.hasDefault
	if hasDefault == nil then
		hasDefault = false
		local instance = defaultInstance(className)
		if instance then
			for _, strategy in entry.strategies do
				local ok, defaultValue = strategy(instance)
				if ok and (defaultValue ~= nil or entry.nilable) then
					entry.default = defaultValue
					hasDefault = true
					break
				end
			end
		end
		entry.hasDefault = hasDefault
	end
	return hasDefault and entry.default == value
end

-- Instances created for default values, so they can be excluded from nil-instance saves.
function Schema.ownInstances()
	local set = {}
	for _, instance in defaultInstances do
		if instance then
			set[instance] = true
		end
	end
	return set
end

function Schema.cleanup()
	for className, instance in defaultInstances do
		if instance then
			pcall(instance.Destroy, instance)
		end
		defaultInstances[className] = nil
	end
	table.clear(plans)
end

return Schema
