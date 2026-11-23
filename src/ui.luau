-- On-screen status panel. Lives in gethui()/CoreGui so it is never part of a save.
local Env = require("env")

local UI = {}

local LINKS = { "sirmemehub.com", "robloxscripts.com", "scriptdumper.com", "exploitstrap.com" }
local ACCENT = Color3.fromRGB(150, 220, 120)

local function label(parent, y, height, size, font, color)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(16, y)
	text.Size = UDim2.new(1, -32, 0, height)
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	text.Parent = parent
	return text
end

function UI.open(version)
	local ok, parts = pcall(function()
		local parent, unprotected = Env.guiParent()
		local gui = Instance.new("ScreenGui")
		gui.Name = game:GetService("HttpService"):GenerateGUID(false)
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 1000000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if unprotected and Env.protectgui then
			pcall(Env.protectgui, gui)
		end

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -48)
		panel.Size = UDim2.fromOffset(460, 100)
		panel.BackgroundColor3 = Color3.fromRGB(17, 19, 24)
		panel.BackgroundTransparency = 0.06
		panel.BorderSizePixel = 0
		panel.Parent = gui
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = ACCENT
		stroke.Transparency = 0.65
		stroke.Parent = panel

		local title = label(panel, 10, 18, 15, Enum.Font.GothamBold, ACCENT)
		title.Text = "SaveInstance 420 Edition " .. version
		local link = label(panel, 10, 18, 12, Enum.Font.Gotham, Color3.fromRGB(120, 125, 135))
		link.TextXAlignment = Enum.TextXAlignment.Right
		link.Text = LINKS[1]
		local phase = label(panel, 34, 18, 14, Enum.Font.GothamMedium, Color3.fromRGB(236, 237, 242))
		phase.Text = "Starting..."

		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(16, 60)
		track.Size = UDim2.new(1, -32, 0, 6)
		track.BackgroundColor3 = Color3.fromRGB(44, 48, 58)
		track.BorderSizePixel = 0
		track.Parent = panel
		Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		local detail = label(panel, 72, 16, 12, Enum.Font.Gotham, Color3.fromRGB(165, 170, 180))
		gui.Parent = parent
		return { gui = gui, phase = phase, fill = fill, detail = detail, link = link, title = title }
	end)
	if not ok then
		return nil
	end

	local ui = {}
	local lastUpdate = 0
	local linkIndex = 1
	local lastLink = os.clock()

	-- fraction: 0..1 or nil for an indeterminate phase
	function ui.set(phaseText, fraction, detailText, force)
		local now = os.clock()
		if not force and now - lastUpdate < 0.1 then
			return
		end
		lastUpdate = now
		pcall(function()
			parts.phase.Text = phaseText
			if fraction then
				parts.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			end
			parts.detail.Text = detailText or ""
			if now - lastLink > 4 then
				lastLink = now
				linkIndex = linkIndex % #LINKS + 1
				parts.link.Text = LINKS[linkIndex]
			end
		end)
	end

	function ui.finish(phaseText, detailText, success)
		pcall(function()
			parts.phase.Text = phaseText
			parts.detail.Text = detailText or ""
			parts.fill.Size = UDim2.fromScale(1, 1)
			parts.fill.BackgroundColor3 = success and ACCENT or Color3.fromRGB(230, 95, 95)
		end)
	end

	function ui.close(delay)
		task.delay(delay or 0, function()
			pcall(parts.gui.Destroy, parts.gui)
		end)
	end

	return ui
end

return UI
