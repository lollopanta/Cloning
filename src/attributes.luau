-- Builds Instance.AttributesSerialize from GetAttributes().
-- Format: u32 count, then per attribute (sorted by name): string name, u8 type id, value.
-- Strings are u32-length-prefixed. Spec: github.com/RobloxAPI/spec (AttributesSerialize).
local Attributes = {}

local pack = string.pack

-- Exact axis-aligned rotation matrices get a one-byte id instead of nine floats.
-- Keys are the nine rotation components packed as little-endian float32 (R00..R22).
local ROTATION_IDS = {
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x02,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x03,
	["\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x05,
	["\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x06,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x07,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x09,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x0a,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x0c,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0d,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x0e,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\63\0\0\0\0\0\0\0\0"] = 0x10,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\128"] = 0x11,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x14,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128"] = 0x15,
	["\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x17,
	["\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128"] = 0x18,
	["\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63"] = 0x19,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0"] = 0x1b,
	["\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128\0\0\0\0\0\0\0\0\0\0\128\191"] = 0x1c,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0"] = 0x1e,
	["\0\0\0\0\0\0\128\63\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\191\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x1f,
	["\0\0\0\0\0\0\0\0\0\0\128\63\0\0\0\0\0\0\128\63\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x20,
	["\0\0\0\0\0\0\128\191\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128\63\0\0\128\191\0\0\0\0\0\0\0\0"] = 0x22,
	["\0\0\0\0\0\0\0\0\0\0\128\191\0\0\0\0\0\0\128\191\0\0\0\128\0\0\128\191\0\0\0\0\0\0\0\128"] = 0x23,
}

local function font(value)
	local okWeight, weight = pcall(function()
		return value.Weight.Value
	end)
	local okStyle, style = pcall(function()
		return value.Style.Value
	end)
	return pack("<I2B", okWeight and weight or 400, okStyle and style or 0) .. pack("<s4s4", value.Family, "")
end

-- typeof(value) -> function returning (type id, encoded value)
local WRITERS = {
	string = function(v)
		return 0x02, pack("<s4", v)
	end,
	boolean = function(v)
		return 0x03, pack("<B", v and 1 or 0)
	end,
	number = function(v)
		return 0x06, pack("<d", v)
	end,
	UDim = function(v)
		return 0x09, pack("<fi4", v.Scale, v.Offset)
	end,
	UDim2 = function(v)
		return 0x0A, pack("<fi4fi4", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	end,
	BrickColor = function(v)
		return 0x0E, pack("<I4", v.Number)
	end,
	Color3 = function(v)
		return 0x0F, pack("<fff", v.R, v.G, v.B)
	end,
	Vector2 = function(v)
		return 0x10, pack("<ff", v.X, v.Y)
	end,
	Vector3 = function(v)
		return 0x11, pack("<fff", v.X, v.Y, v.Z)
	end,
	CFrame = function(v)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
		local rotation = pack("<fffffffff", r00, r01, r02, r10, r11, r12, r20, r21, r22)
		local id = ROTATION_IDS[rotation]
		if id then
			return 0x14, pack("<fffB", x, y, z, id)
		end
		return 0x14, pack("<fffB", x, y, z, 0) .. rotation
	end,
	EnumItem = function(v)
		return 0x15, pack("<s4I4", tostring(v.EnumType), v.Value)
	end,
	NumberSequence = function(v)
		local keypoints = v.Keypoints
		local parts = { pack("<I4", #keypoints) }
		for _, keypoint in keypoints do
			table.insert(parts, pack("<fff", keypoint.Envelope, keypoint.Time, keypoint.Value))
		end
		return 0x17, table.concat(parts)
	end,
	ColorSequence = function(v)
		local keypoints = v.Keypoints
		local parts = { pack("<I4", #keypoints) }
		for _, keypoint in keypoints do
			local color = keypoint.Value
			table.insert(parts, pack("<fffff", 0, keypoint.Time, color.R, color.G, color.B))
		end
		return 0x19, table.concat(parts)
	end,
	NumberRange = function(v)
		return 0x1B, pack("<ff", v.Min, v.Max)
	end,
	Rect = function(v)
		return 0x1C, pack("<ffff", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
	end,
	Font = function(v)
		return 0x21, font(v)
	end,
}

-- Returns the serialized blob ("" when the instance has no attributes).
function Attributes.serialize(instance)
	local attributes = instance:GetAttributes()
	if next(attributes) == nil then
		return ""
	end
	local names = {}
	for name in attributes do
		table.insert(names, name)
	end
	table.sort(names)

	local parts = { "" }
	local count = 0
	for _, name in names do
		local value = attributes[name]
		local writer = WRITERS[typeof(value)]
		if writer then
			local ok, id, encoded = pcall(writer, value)
			if ok then
				count += 1
				table.insert(parts, pack("<s4B", name, id) .. encoded)
			end
		end
	end
	parts[1] = pack("<I4", count)
	return table.concat(parts)
end

return Attributes
