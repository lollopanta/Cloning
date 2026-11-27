-- Run from the repository root: lune run tools/test-content.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local modules = {
	env = { executor = "test" },
	log = { debug = function() end, checkpoint = function() end },
	util = { step = function() end },
	scripts = {},
}
local load
load = function(name)
	if modules[name] then return modules[name] end
	modules[name] = luau.load(fs.readFile("src/" .. name .. ".luau"), { environment = {
		require = load,
		game = { GetService = function() error("no reflection") end },
		Instance = { new = function() return { MeshContent = "", MeshId = 0 } end },
	} })()
	return modules[name]
end
local Schema, Serialize = load("schema"), load("serialize")
local function save(className, fields, ignored, defaults)
	Schema.reset({ UseUGCValidationService = false })
	fields.ClassName = className
	local chunks = {}
	local rules = { children = function() return {} end, decompileIgnored = function() end }
	Serialize.run({ roots = { fields }, rules = rules, isModel = true }, {
		push = function(text) table.insert(chunks, text) end,
		size = function() return 0 end,
	}, { IgnoreProperties = ignored or {}, IgnoreDefaultProperties = defaults or false }, "test", function() end)
	return table.concat(chunks)
end
local pairs = {
	{ "CharacterMesh", "MeshId", "MeshContent", 27111857 },
	{ "CharacterMesh", "BaseTextureId", "BaseTextureContent", 27111857 },
	{ "CharacterMesh", "OverlayTextureId", "OverlayTextureContent", 27111857 },
	{ "MeshPart", "MeshId", "MeshContent" },
	{ "MeshPart", "TextureID", "TextureContent" },
	{ "SpecialMesh", "TextureId", "TextureContent" },
	{ "Decal", "Texture", "TextureContent" },
	{ "SurfaceAppearance", "ColorMap", "ColorMapContent" },
	{ "Sound", "SoundId", "AudioContent" },
	{ "AudioPlayer", "Asset", "AudioContent" },
	{ "VideoFrame", "Video", "VideoContent" },
	{ "ShirtGraphic", "Graphic", "TextureContent" },
	{ "Sky", "SkyboxBk", "SkyboxBackContent" },
	{ "Sky", "SunTextureId", "SunTextureContent" },
}
local uri = "rbxassetid://27111857"
for _, pair in pairs do
	local className, legacy, modern = pair[1], pair[2], pair[3]
	local value = pair[4] or uri
	local xml = save(className, { [legacy] = value, [modern] = uri })
	assert(string.find(xml, 'name="' .. modern .. '"><uri>' .. uri, 1, true), className .. "." .. modern)
	assert(not string.find(xml, 'name="' .. legacy .. '"', 1, true), "do not write both representations")
	for _, modernValue in { false, {} } do
		local fallback = save(className, { [legacy] = value, [modern] = modernValue })
		assert(string.find(fallback, 'name="' .. legacy .. '"', 1, true), className .. "." .. legacy .. ": retain legacy if modern cannot encode: " .. fallback)
	end
	local ignored = save(className, { [legacy] = value, [modern] = uri }, { modern })
	assert(string.find(ignored, 'name="' .. legacy .. '"', 1, true), "retain legacy if modern ignored")
	local absent = save(className, { [legacy] = value })
	assert(string.find(absent, 'name="' .. legacy .. '"', 1, true), "retain legacy if modern unreadable")
end
local xml = save("CharacterMesh", { MeshId = 27111857, MeshContent = uri }, nil, true)
assert(string.find(xml, '<Content name="MeshContent">', 1, true))
assert(not string.find(xml, 'name="MeshId"', 1, true))
modules.schema_snapshot.classes.LegacyMesh = "Instance||MeshId:ContentId"
assert(string.find(save("LegacyMesh", { MeshId = uri }), 'name="MeshId"', 1, true))
luau.load(fs.readFile("saveinstance.luau"))
print("PASS: modern Content wins, legacy fallback, inheritance, default filtering, old schema, bundle syntax")
