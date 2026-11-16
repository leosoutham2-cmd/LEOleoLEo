--[[
	Chip The Ice - Blocky Glacier Generator

	HOW TO USE
	1. In Roblox Studio, open the View tab and turn on "Command Bar".
	2. Paste this whole script into the Command Bar and press Enter.
	3. A model called "Glacier" appears in Workspace. Run it again to rebuild it
	   (the old one is deleted first). Change Seed for a different shape.

	STYLE
	- Chunky voxel blocks, flat SmoothPlastic, no textures, bright readable colours
	  (the look most top Roblox games use right now).
	- Colour bands: deep blue base, light ice middle, pale top, snow caps.
	- Lighting is NOT touched.

	PERFORMANCE (high player counts)
	- Each column is a few tall parts, not hundreds of 1x1 cubes.
	- Everything is Anchored, CanTouch off, no transparency, no textures.
]]

local CONFIG = {
	Seed = 7,                       -- change for a different glacier
	BlockSize = 4,                  -- studs per block
	Width = 26,                     -- blocks along X
	Depth = 20,                     -- blocks along Z
	MaxHeight = 14,                 -- tallest column, in blocks
	Origin = Vector3.new(0, 0, 0),  -- centre of the glacier's base
	SpikeChance = 0.07,             -- chance of an ice spike on high columns
}

local COLORS = {
	Deep  = Color3.fromRGB(56, 118, 196),
	Mid   = Color3.fromRGB(104, 178, 232),
	Light = Color3.fromRGB(170, 222, 250),
	Snow  = Color3.fromRGB(242, 250, 255),
	Spike = Color3.fromRGB(196, 236, 255),
}

local old = workspace:FindFirstChild("Glacier")
if old then old:Destroy() end

local model = Instance.new("Model")
model.Name = "Glacier"

local rng = Random.new(CONFIG.Seed)
local seed = CONFIG.Seed + 0.5 -- math.noise needs non-whole inputs
local s = CONFIG.BlockSize
local partCount = 0

local function block(gx, gz, y0, heightBlocks, color)
	if heightBlocks <= 0 then return end
	local p = Instance.new("Part")
	p.Name = "Ice"
	p.Anchored = true
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = Vector3.new(s, heightBlocks * s, s)
	p.Position = CONFIG.Origin + Vector3.new(
		(gx - CONFIG.Width / 2 + 0.5) * s,
		(y0 + heightBlocks / 2) * s,
		(gz - CONFIG.Depth / 2 + 0.5) * s
	)
	p.Parent = model
	partCount += 1
end

local band1 = math.floor(CONFIG.MaxHeight * 0.35)
local band2 = math.floor(CONFIG.MaxHeight * 0.7)

for gx = 0, CONFIG.Width - 1 do
	for gz = 0, CONFIG.Depth - 1 do
		-- distance from centre (oval), with a wobbly, uneven edge
		local nx = (gx + 0.5) / CONFIG.Width * 2 - 1
		local nz = (gz + 0.5) / CONFIG.Depth * 2 - 1
		local dist = math.sqrt(nx * nx + nz * nz)
		local wobble = math.noise(gx * 0.23 + 0.37, gz * 0.23 + 0.37, seed + 10) * 0.45
		local falloff = 1 - (dist + wobble)

		if falloff > 0 then
			-- big lumps + small bumps = uneven glacier top
			local n = math.noise(gx * 0.11 + 0.37, gz * 0.11 + 0.37, seed) * 0.9
				+ math.noise(gx * 0.31 + 0.37, gz * 0.31 + 0.37, seed + 20) * 0.35
			local t = math.clamp(falloff * 1.4 + n, 0, 1) ^ 0.85
			local h = math.floor(t * CONFIG.MaxHeight + 0.5)

			if h > 0 then
				local hasSnow = h > band1
				local iceTop = hasSnow and h - 1 or h

				-- stacked colour bands
				block(gx, gz, 0, math.min(iceTop, band1), COLORS.Deep)
				if iceTop > band1 then
					block(gx, gz, band1, math.min(iceTop, band2) - band1, COLORS.Mid)
				end
				if iceTop > band2 then
					block(gx, gz, band2, iceTop - band2, COLORS.Light)
				end
				if hasSnow then
					block(gx, gz, h - 1, 1, COLORS.Snow)
				end

				-- occasional jagged ice spike on the high parts
				if h >= band2 and rng:NextNumber() < CONFIG.SpikeChance then
					block(gx, gz, h, rng:NextInteger(2, 4), COLORS.Spike)
				end
			end
		end
	end
end

model.Parent = workspace
pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("Build Glacier")
end)
print(("Glacier built: %d parts"):format(partCount))
