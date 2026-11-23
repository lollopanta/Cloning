-- XML value encoders, one per serialized value type.
-- Each returns the inner XML of a property element, or nil to leave the property out
-- (wrong value type, unsupported content). Formats follow Roblox's XML format as
-- implemented by rbx-dom (rbx_xml/src/types).
local Env = require("env")

local Encode = {}

local format, floor, find, gsub, typeof, tostring = string.format, math.floor, string.find, string.gsub, typeof, tostring
local HUGE = math.huge

local ContentSourceType
pcall(function()
	ContentSourceType = Enum.ContentSourceType
end)

-- Numbers --------------------------------------------------------------------------------
local function f32(x) -- float32 round-trips with 9 significant digits
	if x ~= x then
		return "NAN"
	elseif x == HUGE then
		return "INF"
	elseif x == -HUGE then
		return "-INF"
	elseif x == floor(x) and x > -1e9 and x < 1e9 then
		return format("%d", x)
	end
	return format("%.9g", x)
end

local function f64(x)
	if x ~= x then
		return "NAN"
	elseif x == HUGE then
		return "INF"
	elseif x == -HUGE then
		return "-INF"
	elseif x == floor(x) and x > -1e15 and x < 1e15 then
		return format("%d", x)
	end
	return format("%.17g", x)
end

local function int(x)
	if x ~= x or x == HUGE or x == -HUGE then
		return "0"
	end
	return format("%d", floor(x))
end

local function f32range(x) -- ranges and sequences reset to zero on NaN in Studio
	return x ~= x and "0" or f32(x)
end

Encode.f32, Encode.f64, Encode.int = f32, f64, int

-- Text -----------------------------------------------------------------------------------
-- Plain printable ASCII is written as-is; anything else goes into CDATA, which keeps
-- newlines, tabs and UTF-8 byte-exact. NUL cannot appear in XML at all and is dropped.
local function text(s)
	if s == "" then
		return ""
	end
	if not find(s, "[^%w%p ]") and not find(s, "[&<>]") and not find(s, "^ ") and not find(s, " $") then
		return s
	end
	if find(s, "\0", 1, true) then
		s = gsub(s, "\0", "")
	end
	if find(s, "]]>", 1, true) then
		s = gsub(s, "%]%]>", "]]]]><![CDATA[>")
	end
	return "<![CDATA[" .. s .. "]]>"
end

local function cdata(s)
	if find(s, "\0", 1, true) then
		s = gsub(s, "\0", "")
	end
	if find(s, "]]>", 1, true) then
		s = gsub(s, "%]%]>", "]]]]><![CDATA[>")
	end
	return "<![CDATA[" .. s .. "]]>"
end

local ATTRIBUTE_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
local function attribute(s)
	if find(s, '[&<>"]') then
		s = gsub(s, '[&<>"]', ATTRIBUTE_ESCAPES)
	end
	return s
end

Encode.text, Encode.cdata, Encode.attribute = text, cdata, attribute

-- Compound values -------------------------------------------------------------------------
local function vector3(v)
	return "<X>" .. f32(v.X) .. "</X><Y>" .. f32(v.Y) .. "</Y><Z>" .. f32(v.Z) .. "</Z>"
end

local function cframe(v)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
	return "<X>" .. f32(x) .. "</X><Y>" .. f32(y) .. "</Y><Z>" .. f32(z)
		.. "</Z><R00>" .. f32(r00) .. "</R00><R01>" .. f32(r01) .. "</R01><R02>" .. f32(r02)
		.. "</R02><R10>" .. f32(r10) .. "</R10><R11>" .. f32(r11) .. "</R11><R12>" .. f32(r12)
		.. "</R12><R20>" .. f32(r20) .. "</R20><R21>" .. f32(r21) .. "</R21><R22>" .. f32(r22) .. "</R22>"
end

local function colorByte(channel)
	local b = floor(channel * 255 + 0.5)
	return b < 0 and 0 or b > 255 and 255 or b
end

local function uriOf(v)
	if type(v) == "string" then
		return v
	end
	if typeof(v) == "Content" and ContentSourceType then
		local sourceType = v.SourceType
		if sourceType == ContentSourceType.None then
			return ""
		elseif sourceType == ContentSourceType.Uri then
			return v.Uri or ""
		end
	end
	return nil -- Object-backed content (EditableImage, ...) cannot be stored in a file
end

local CAPABILITY_BITS = {
	Plugin = 2 ^ 0, LocalUser = 2 ^ 1, WritePlayer = 2 ^ 2, RobloxScript = 2 ^ 3, RobloxEngine = 2 ^ 4,
	NotAccessible = 2 ^ 5, RunClientScript = 2 ^ 8, RunServerScript = 2 ^ 9, AccessOutsideWrite = 2 ^ 11,
	Unassigned = 2 ^ 15, AssetRequire = 2 ^ 16, LoadString = 2 ^ 17, ScriptGlobals = 2 ^ 18,
	CreateInstances = 2 ^ 19, Basic = 2 ^ 20, Audio = 2 ^ 21, DataStore = 2 ^ 22, Network = 2 ^ 23,
	Physics = 2 ^ 24, UI = 2 ^ 25, CSG = 2 ^ 26, Chat = 2 ^ 27, Animation = 2 ^ 28, Avatar = 2 ^ 29,
	Input = 2 ^ 30, Environment = 2 ^ 31, RemoteEvent = 2 ^ 32, LegacySound = 2 ^ 33, Players = 2 ^ 34,
	CapabilityControl = 2 ^ 35, InternalTest = 2 ^ 60, PluginOrOpenCloud = 2 ^ 61, Assistant = 2 ^ 62,
}

-- Encoders --------------------------------------------------------------------------------
local E = {}

function E.bool(v)
	if type(v) == "boolean" then
		return v and "true" or "false"
	end
end

function E.int(v)
	if type(v) == "number" then
		return int(v)
	end
end
E.int64 = E.int

function E.float(v)
	if type(v) == "number" then
		return f32(v)
	end
end

function E.double(v)
	if type(v) == "number" then
		return f64(v)
	end
end

function E.string(v)
	if type(v) == "string" then
		return text(v)
	end
end

function E.ProtectedString(v)
	if type(v) == "string" then
		return cdata(v)
	end
end

function E.BinaryString(v)
	if type(v) == "string" then
		return v == "" and "" or Env.base64encode(v)
	end
end

function E.SharedString(v, ctx)
	if type(v) == "string" then
		return ctx.shared(v)
	end
end
E.NetAssetRef = E.SharedString

function E.ContentId(v)
	local uri = uriOf(v)
	if uri then
		return uri == "" and "<null></null>" or "<url>" .. text(uri) .. "</url>"
	end
end

function E.Content(v)
	local uri = uriOf(v)
	if uri then
		return uri == "" and "<null></null>" or "<uri>" .. text(uri) .. "</uri>"
	end
end

function E.token(v)
	if typeof(v) == "EnumItem" then
		return tostring(v.Value)
	elseif type(v) == "number" then
		return int(v)
	end
end

function E.Ref(v, ctx)
	if v == nil then
		return "null"
	elseif typeof(v) == "Instance" then
		return ctx.ref(v)
	end
end

function E.Vector2(v)
	if typeof(v) == "Vector2" then
		return "<X>" .. f32(v.X) .. "</X><Y>" .. f32(v.Y) .. "</Y>"
	end
end

function E.Vector2int16(v)
	if typeof(v) == "Vector2int16" then
		return "<X>" .. int(v.X) .. "</X><Y>" .. int(v.Y) .. "</Y>"
	end
end

function E.Vector3(v)
	if typeof(v) == "Vector3" then
		return vector3(v)
	end
end

function E.Vector3int16(v)
	if typeof(v) == "Vector3int16" then
		return "<X>" .. int(v.X) .. "</X><Y>" .. int(v.Y) .. "</Y><Z>" .. int(v.Z) .. "</Z>"
	end
end

function E.CFrame(v)
	if typeof(v) == "CFrame" then
		return cframe(v)
	end
end

function E.OptionalCFrame(v) -- nil means "not set": the property is left out
	if typeof(v) == "CFrame" then
		return "<CFrame>" .. cframe(v) .. "</CFrame>"
	end
end

function E.Color3(v)
	if typeof(v) == "Color3" then
		return "<R>" .. f32(v.R) .. "</R><G>" .. f32(v.G) .. "</G><B>" .. f32(v.B) .. "</B>"
	end
end

function E.Color3uint8(v)
	if typeof(v) == "Color3" then
		return format("%.0f", 4278190080 + colorByte(v.R) * 65536 + colorByte(v.G) * 256 + colorByte(v.B))
	end
end

function E.BrickColor(v)
	if typeof(v) == "BrickColor" then
		return tostring(v.Number)
	elseif type(v) == "number" then
		return int(v)
	end
end

function E.UDim(v)
	if typeof(v) == "UDim" then
		return "<S>" .. f32(v.Scale) .. "</S><O>" .. int(v.Offset) .. "</O>"
	end
end

function E.UDim2(v)
	if typeof(v) == "UDim2" then
		local x, y = v.X, v.Y
		return "<XS>" .. f32(x.Scale) .. "</XS><XO>" .. int(x.Offset) .. "</XO><YS>" .. f32(y.Scale) .. "</YS><YO>"
			.. int(y.Offset) .. "</YO>"
	end
end

function E.Rect(v)
	if typeof(v) == "Rect" then
		local min, max = v.Min, v.Max
		return "<min><X>" .. f32(min.X) .. "</X><Y>" .. f32(min.Y) .. "</Y></min><max><X>" .. f32(max.X) .. "</X><Y>"
			.. f32(max.Y) .. "</Y></max>"
	end
end

function E.NumberRange(v)
	if typeof(v) == "NumberRange" then
		return f32range(v.Min) .. " " .. f32range(v.Max)
	end
end

function E.NumberSequence(v)
	if typeof(v) == "NumberSequence" then
		local parts = {}
		for i, keypoint in v.Keypoints do
			parts[i] = f32range(keypoint.Time) .. " " .. f32range(keypoint.Value) .. " " .. f32range(keypoint.Envelope) .. " "
		end
		return table.concat(parts)
	end
end

function E.ColorSequence(v)
	if typeof(v) == "ColorSequence" then
		local parts = {}
		for i, keypoint in v.Keypoints do
			local color = keypoint.Value
			parts[i] = f32range(keypoint.Time) .. " " .. f32range(color.R) .. " " .. f32range(color.G) .. " "
				.. f32range(color.B) .. " 0 "
		end
		return table.concat(parts)
	end
end

function E.PhysicalProperties(v)
	if v == nil then
		return "<CustomPhysics>false</CustomPhysics>"
	elseif typeof(v) == "PhysicalProperties" then
		local xml = "<CustomPhysics>true</CustomPhysics><Density>" .. f32(v.Density) .. "</Density><Friction>"
			.. f32(v.Friction) .. "</Friction><Elasticity>" .. f32(v.Elasticity) .. "</Elasticity><FrictionWeight>"
			.. f32(v.FrictionWeight) .. "</FrictionWeight><ElasticityWeight>" .. f32(v.ElasticityWeight)
			.. "</ElasticityWeight>"
		local ok, absorption = pcall(function()
			return v.AcousticAbsorption
		end)
		if ok and type(absorption) == "number" then
			xml ..= "<AcousticAbsorption>" .. f32(absorption) .. "</AcousticAbsorption>"
		end
		return xml
	end
end

function E.Ray(v)
	if typeof(v) == "Ray" then
		return "<origin>" .. vector3(v.Origin) .. "</origin><direction>" .. vector3(v.Direction) .. "</direction>"
	end
end

function E.Faces(v)
	if typeof(v) == "Faces" then
		local bits = (v.Right and 1 or 0) + (v.Top and 2 or 0) + (v.Back and 4 or 0) + (v.Left and 8 or 0)
			+ (v.Bottom and 16 or 0) + (v.Front and 32 or 0)
		return "<faces>" .. bits .. "</faces>"
	end
end

function E.Axes(v)
	if typeof(v) == "Axes" then
		return "<axes>" .. ((v.X and 1 or 0) + (v.Y and 2 or 0) + (v.Z and 4 or 0)) .. "</axes>"
	end
end

function E.Font(v)
	if typeof(v) == "Font" then
		local okWeight, weight = pcall(function()
			return v.Weight.Value
		end)
		local okStyle, style = pcall(function()
			return v.Style.Name
		end)
		local family = v.Family
		return "<Family>" .. (family == "" and "<null></null>" or "<url>" .. text(family) .. "</url>")
			.. "</Family><Weight>" .. (okWeight and weight or 400) .. "</Weight><Style>"
			.. (okStyle and style or "Normal") .. "</Style>"
	end
end

function E.SecurityCapabilities(v)
	if typeof(v) == "SecurityCapabilities" then
		local total = 0
		for _, flag in string.split(tostring(v), " | ") do
			total += CAPABILITY_BITS[flag] or 0
		end
		return format("%.0f", total)
	end
end

-- XML element name per value type.
local TAGS = {
	bool = "bool", int = "int", int64 = "int64", float = "float", double = "double", string = "string",
	ProtectedString = "ProtectedString", BinaryString = "BinaryString", SharedString = "SharedString",
	NetAssetRef = "NetAssetRef", Content = "Content", ContentId = "ContentId", token = "token", Ref = "Ref",
	Vector2 = "Vector2", Vector2int16 = "Vector2int16", Vector3 = "Vector3", Vector3int16 = "Vector3int16",
	CFrame = "CoordinateFrame", OptionalCFrame = "OptionalCoordinateFrame", Color3 = "Color3",
	Color3uint8 = "Color3uint8", BrickColor = "BrickColor", UDim = "UDim", UDim2 = "UDim2", Rect = "Rect2D",
	NumberRange = "NumberRange", NumberSequence = "NumberSequence", ColorSequence = "ColorSequence",
	PhysicalProperties = "PhysicalProperties", Ray = "Ray", Faces = "Faces", Axes = "Axes", Font = "Font",
	SecurityCapabilities = "SecurityCapabilities",
}

Encode.encoders = E

function Encode.supports(valueType)
	return E[valueType] ~= nil
end

function Encode.tags(valueType, name)
	local tag = TAGS[valueType]
	return "<" .. tag .. ' name="' .. attribute(name) .. '">', "</" .. tag .. ">"
end

return Encode
