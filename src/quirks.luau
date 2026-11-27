-- Property and class exceptions that the API metadata alone gets wrong.
-- Every entry here exists because a save broke without it.
local Attributes = require("attributes")

local Quirks = {}

-- Never written. UniqueId/HistoryId duplicated across saves corrupt places (the classic
-- saveinstance bug); ScriptGuid is Studio-internal.
Quirks.blocked = {
	UniqueId = true,
	HistoryId = true,
	ScriptGuid = true,
}

-- Exceptions to Foo/FooId/FooID -> FooContent; the modern property is saved first.
Quirks.contentAliases = {
	AudioContent = { "SoundId", "Asset" },
	VideoContent = { "Asset" },
	TextureContent = { "Graphic" },
	SkyboxBackContent = { "SkyboxBk" },
	SkyboxDownContent = { "SkyboxDn" },
	SkyboxFrontContent = { "SkyboxFt" },
	SkyboxLeftContent = { "SkyboxLf" },
	SkyboxRightContent = { "SkyboxRt" },
	HSRContent = { "HSRAssetId" },
	TemporaryReferenceMeshContent = { "TemporaryReferenceId" },
}

-- Hidden serialized members with a scriptable twin that holds the same value. Reading the
-- twin is much faster than gethiddenproperty and works on every executor.
-- Keyed by the class that declares the member.
Quirks.aliases = {
	Instance = { DefinesCapabilities = "Sandboxed" },
	BasePart = { Color3uint8 = "Color", size = "Size", MaterialVariantSerialized = "MaterialVariant" },
	Part = { shape = "Shape" },
	TrussPart = { style = "Style" },
	FormFactorPart = { formFactorRaw = "FormFactor" },
	Fire = { heat_xml = "Heat", size_xml = "Size" },
	Smoke = { size_xml = "Size", opacity_xml = "Opacity", riseVelocity_xml = "RiseVelocity" },
	Sound = { xmlRead_MaxDistance_3 = "RollOffMaxDistance" },
	Humanoid = { Health_XML = "Health" },
	BallSocketConstraint = { MaxFrictionTorqueXml = "MaxFrictionTorque" },
	DoubleConstrainedValue = { value = "Value" },
	IntConstrainedValue = { value = "Value" },
	MaterialService = { Use2022MaterialsXml = "Use2022Materials" },
	WeldConstraint = { Part0Internal = "Part0", Part1Internal = "Part1" },
	MeshPart = { InitialSize = "MeshSize" },
	TriangleMeshPart = { FluidFidelityInternal = "FluidFidelity" },
	PackageLink = { PackageIdSerialize = "PackageId", VersionIdSerialize = "VersionNumber" },
	Players = { MaxPlayersInternal = "MaxPlayers", PreferredPlayersInternal = "PreferredPlayers" },
	StarterPlayer = { AvatarJointUpgrade_Serialized = "AvatarJointUpgrade" },
	Terrain = { AcquisitionMethod = "LastUsedModificationMethod" },
}

local TERRAIN_MATERIALS = { -- order fixed by the MaterialColors format
	"Grass", "Slate", "Concrete", "Brick", "Sand", "WoodPlanks", "Rock", "Glacier", "Snow", "Sandstone", "Mud",
	"Basalt", "Ground", "CrackedLava", "Asphalt", "Cobblestone", "Ice", "LeafyGrass", "Salt", "Limestone", "Pavement",
}

local function byte(channel)
	return math.clamp(math.floor(channel * 255 + 0.5), 0, 255)
end

-- Values rebuilt from public APIs. `first = true` means try this before gethiddenproperty
-- (cheaper, and it runs for every instance); otherwise it is a fallback.
Quirks.readers = {
	Instance = {
		AttributesSerialize = { first = true, read = Attributes.serialize },
		Tags = {
			first = true,
			read = function(instance)
				local tags = instance:GetTags()
				return #tags == 0 and "" or table.concat(tags, "\0")
			end,
		},
	},
	Model = {
		ScaleFactor = {
			first = true,
			read = function(model)
				return model:GetScale()
			end,
		},
		WorldPivotData = {
			read = function(model)
				return model.WorldPivot
			end,
		},
	},
	Terrain = {
		MaterialColors = {
			read = function(terrain)
				local parts = { string.rep("\0", 6) }
				for _, name in TERRAIN_MATERIALS do
					local color = terrain:GetMaterialColor(Enum.Material[name])
					table.insert(parts, string.char(byte(color.R), byte(color.G), byte(color.B)))
				end
				return table.concat(parts)
			end,
		},
	},
	Workspace = {
		CollisionGroupData = {
			read = function()
				local groups = game:GetService("PhysicsService"):GetRegisteredCollisionGroups()
				local parts = { string.pack("<BB", 1, #groups) }
				for index, group in groups do
					local mask = group.mask
					if mask >= 2147483648 then
						mask -= 4294967296 -- stored as a signed 32-bit integer
					end
					table.insert(parts, string.pack("<BBi4s1", index - 1, 4, mask, group.name))
				end
				return table.concat(parts)
			end,
		},
	},
	HumanoidDescription = {
		EmotesDataInternal = {
			read = function(description)
				local parts = {}
				for name, ids in description:GetEmotes() do
					table.insert(parts, name .. "^" .. table.concat(ids, "^") .. "^\\")
				end
				return table.concat(parts)
			end,
		},
		EquippedEmotesDataInternal = {
			read = function(description)
				local parts = {}
				for _, emote in description:GetEquippedEmotes() do
					table.insert(parts, emote.Slot .. "^" .. emote.Name .. "\\")
				end
				return table.concat(parts)
			end,
		},
	},
	LocalizationTable = {
		Contents = {
			read = function(localizationTable)
				return localizationTable:GetContents()
			end,
		},
	},
}

-- Classes that must never become <Item>s: Studio cannot create them, or they only make
-- sense at runtime. Used when ReflectionService cannot answer for a class.
Quirks.unsaveable = {
	Player = true,
	PlayerGui = true,
	PlayerScripts = true,
	PlayerMouse = true,
	Backpack = true,
	TouchTransmitter = true,
	AnimationTrack = true,
	StudioData = true,
	ScreenshotHud = true,
	TextSource = true,
	InputObject = true,
	Translator = true,
	CloudLocalizationTable = true,
}

-- Engine-injected copies of Roblox's default player scripts. Saving them (decompiled or
-- not) replaces Studio's working defaults with broken copies, so they are left out.
Quirks.defaultPlayerScripts = {
	PlayerModule = "ModuleScript",
	RbxCharacterSounds = "LocalScript",
	ChatScript = "LocalScript",
	BubbleChat = "LocalScript",
}

return Quirks
