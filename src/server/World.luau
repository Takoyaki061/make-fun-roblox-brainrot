-- World.luau — Brainrot Bazaar: the whole 3D map, built out of Parts in code.
-- House style: no bare boxes — plinth + body + cap everywhere; at most three
-- materials per zone; neon edge strips; a thin dark semi-transparent slab under
-- overhangs as a fake shadow. Bright cartoon lighting. Y=0 is the ground and
-- the pad tops sit at y=2.

local World = {}

local BASE_COUNT = 8
local RING_RADIUS = 130
local SLOT_COUNT = 6

-- ---------------------------------------------------------------------------
-- Small builders
-- ---------------------------------------------------------------------------

local function part(parent, name, size, pos, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- A neon strip: thin, glowing, anchored, non-colliding.
local function neon(parent, name, size, pos, color)
	local p = part(parent, name, size, pos, color, Enum.Material.Neon)
	p.CanCollide = false
	return p
end

-- A fake shadow: a thin dark slab, slightly transparent, under an overhang.
local function shadowSlab(parent, size, pos)
	local p = part(parent, "Shadow", size, pos, Color3.fromRGB(20, 20, 25), Enum.Material.SmoothPlastic)
	p.Transparency = 0.6
	p.CanCollide = false
	return p
end

-- A plinth + body + cap stack: the house style for anything that stands up.
local function stack(parent, name, centre, footSize, bodySize, capSize, footColor, bodyColor, capColor)
	local folder = Instance.new("Model")
	folder.Name = name
	folder.Parent = parent
	part(folder, "Plinth", footSize, centre + Vector3.new(0, footSize.Y / 2, 0), footColor)
	part(folder, "Body", bodySize, centre + Vector3.new(0, footSize.Y + bodySize.Y / 2, 0), bodyColor)
	part(folder, "Cap", capSize, centre + Vector3.new(0, footSize.Y + bodySize.Y + capSize.Y / 2, 0), capColor)
	return folder
end

-- ---------------------------------------------------------------------------
-- Lighting
-- ---------------------------------------------------------------------------

local function buildLighting(world)
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 14
	lighting.Brightness = 3
	lighting.Ambient = Color3.fromRGB(255, 240, 210)
	lighting.OutdoorAmbient = Color3.fromRGB(200, 220, 255)
	lighting.GeographicLatitude = 0

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.15
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(180, 220, 255)
	atmosphere.Decay = Color3.fromRGB(120, 160, 220)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5
	atmosphere.Parent = lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = 0.25
	correction.Contrast = 0.05
	correction.Brightness = 0.02
	correction.Parent = lighting
end

-- ---------------------------------------------------------------------------
-- Ground and spawn plaza
-- ---------------------------------------------------------------------------

local function buildGround(world)
	-- Grass slab, 420 x 420.
	part(world, "Ground", Vector3.new(420, 2, 420), Vector3.new(0, -1, 0), Color3.fromRGB(90, 190, 90), Enum.Material.Grass)

	-- Spawn plaza: warm slab 120 x 70 centred at (0, 195), checker tiles on top.
	local plaza = part(world, "SpawnPlaza", Vector3.new(120, 2, 70), Vector3.new(0, 1, 195), Color3.fromRGB(230, 200, 150), Enum.Material.SmoothPlastic)
	plaza.TopSurface = Enum.SurfaceType.Smooth
	-- Checker of tiles: 12 x 7, alternating warm tones.
	for ix = 1, 12 do
		for iz = 1, 7 do
			local warm = (ix + iz) % 2 == 0
			local tile = part(world, "PlazaTile", Vector3.new(9.6, 0.2, 9.6),
				Vector3.new(-55 + ix * 10, 2.1, 163 + iz * 10),
				warm and Color3.fromRGB(240, 215, 165) or Color3.fromRGB(215, 180, 130), Enum.Material.SmoothPlastic)
			tile.CanCollide = false
		end
	end
	-- Edge trim around the plaza.
	neon(world, "PlazaTrimNorth", Vector3.new(120, 0.4, 1), Vector3.new(0, 2.2, 160.5), Color3.fromRGB(255, 200, 60))
	neon(world, "PlazaTrimSouth", Vector3.new(120, 0.4, 1), Vector3.new(0, 2.2, 229.5), Color3.fromRGB(255, 200, 60))
	neon(world, "PlazaTrimWest", Vector3.new(1, 0.4, 70), Vector3.new(-59.5, 2.2, 195), Color3.fromRGB(255, 200, 60))
	neon(world, "PlazaTrimEast", Vector3.new(1, 0.4, 70), Vector3.new(59.5, 2.2, 195), Color3.fromRGB(255, 200, 60))

	-- Two spoke paths from the plaza to the ring.
	part(world, "SpokeWest", Vector3.new(10, 0.4, 60), Vector3.new(-45, 2.1, 150), Color3.fromRGB(220, 190, 140), Enum.Material.SmoothPlastic).CanCollide = false
	part(world, "SpokeEast", Vector3.new(10, 0.4, 60), Vector3.new(45, 2.1, 150), Color3.fromRGB(220, 190, 140), Enum.Material.SmoothPlastic).CanCollide = false

	-- Six flower planters along the plaza's north edge.
	for i = 1, 6 do
		local x = -50 + (i - 1) * 20
		local planter = stack(world, "Planter" .. i, Vector3.new(x, 2, 163), Vector3.new(6, 1, 4),
			Vector3.new(5, 2, 3), Vector3.new(6.5, 0.6, 4.5),
			Color3.fromRGB(150, 90, 50), Color3.fromRGB(120, 70, 40), Color3.fromRGB(180, 110, 60))
		for _, offset in ipairs({ Vector3.new(-1.4, 0, 0), Vector3.new(0, 0.4, 0), Vector3.new(1.4, 0, 0) }) do
			part(planter, "Flower", Vector3.new(1.6, 1.6, 1.6),
				Vector3.new(x, 5.6, 163) + offset,
				Color3.fromRGB(255, 120, 180), Enum.Material.Neon, Enum.PartType.Ball).CanCollide = false
		end
	end
end

-- ---------------------------------------------------------------------------
-- Conveyor: a real machine down the middle, 24 wide, 300 long
-- ---------------------------------------------------------------------------

local function buildConveyor(world)
	local folder = Instance.new("Model")
	folder.Name = "Conveyor"
	folder.Parent = world

	-- Dark metal deck on A-frame legs, belt top at y=2.
	part(folder, "Deck", Vector3.new(24, 2, 300), Vector3.new(0, 0, 0), Color3.fromRGB(50, 55, 65), Enum.Material.Metal)
	local belt = part(folder, "Belt", Vector3.new(20, 0.6, 298), Vector3.new(0, 1.8, 0), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
	belt.TopSurface = Enum.SurfaceType.Smooth
	for _, z in ipairs({ -140, -70, 0, 70, 140 }) do
		-- A-frame legs, two per station.
		for _, x in ipairs({ -8, 8 }) do
			local leg = part(folder, "Leg", Vector3.new(2, 4, 2), Vector3.new(x, -2, z), Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
			leg.Orientation = Vector3.new(0, 0, x < 0 and 12 or -12)
		end
	end
	-- Rollers across the belt every 16 studs.
	for z = -144, 144, 16 do
		local roller = part(folder, "Roller", Vector3.new(20, 1, 1.6), Vector3.new(0, 1.6, z), Color3.fromRGB(120, 125, 135), Enum.Material.Metal, Enum.PartType.Cylinder)
		roller.Orientation = Vector3.new(0, 0, 90)
		roller.CanCollide = false
	end
	-- Side frames with neon gold edge strips and bolt nubs.
	for _, x in ipairs({ -11.5, 11.5 }) do
		part(folder, "SideFrame", Vector3.new(1.5, 2.5, 300), Vector3.new(x, 2.5, 0), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
		neon(folder, "GoldStrip", Vector3.new(0.6, 0.5, 300), Vector3.new(x, 3.9, 0), Color3.fromRGB(255, 200, 40))
		for z = -140, 140, 20 do
			part(folder, "Bolt", Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, 3.2, z), Color3.fromRGB(255, 220, 80), Enum.Material.Neon, Enum.PartType.Ball).CanCollide = false
		end
	end
	-- Chevron markers down the belt centre.
	for z = -135, 135, 15 do
		local chevron = part(folder, "Chevron", Vector3.new(6, 0.3, 3), Vector3.new(0, 2.15, z), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
		chevron.Orientation = Vector3.new(0, 45, 0)
		chevron.CanCollide = false
	end
	-- Gearbox housing and cable tray on the east side near spawn.
	stack(folder, "Gearbox", Vector3.new(16, 2, 120), Vector3.new(8, 1.5, 10), Vector3.new(6, 5, 8), Vector3.new(8, 1, 10),
		Color3.fromRGB(60, 60, 70), Color3.fromRGB(90, 90, 100), Color3.fromRGB(255, 200, 40))
	part(folder, "CableTray", Vector3.new(1.5, 1, 60), Vector3.new(14, 2.5, 90), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
	-- Red neon stop-lamp at the north (discharge) end.
	local lampPost = part(folder, "StopLampPost", Vector3.new(1.5, 6, 1.5), Vector3.new(11, 5, -148), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	part(folder, "StopLamp", Vector3.new(3, 3, 3), Vector3.new(11, 8.5, -148), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- Golden statue at (36, 0)
-- ---------------------------------------------------------------------------

local function buildStatue(world)
	local folder = Instance.new("Model")
	folder.Name = "GoldenStatue"
	folder.Parent = world
	local base = Vector3.new(36, 0, 0)
	-- Tiered slate pedestal with neon risers.
	part(folder, "Pedestal1", Vector3.new(14, 2, 14), base + Vector3.new(0, 1, 0), Color3.fromRGB(90, 95, 110), Enum.Material.Slate)
	part(folder, "Pedestal2", Vector3.new(10, 2, 10), base + Vector3.new(0, 3, 0), Color3.fromRGB(110, 115, 130), Enum.Material.Slate)
	neon(folder, "PedestalRiser", Vector3.new(10.4, 0.5, 10.4), base + Vector3.new(0, 4.1, 0), Color3.fromRGB(255, 200, 40))
	part(folder, "Pedestal3", Vector3.new(7, 2, 7), base + Vector3.new(0, 5, 0), Color3.fromRGB(130, 135, 150), Enum.Material.Slate)
	-- Gold metallic head-and-shoulders figure.
	local gold = Color3.fromRGB(255, 200, 40)
	local shoulders = part(folder, "Shoulders", Vector3.new(6, 2.5, 3.5), base + Vector3.new(0, 7.2, 0), gold, Enum.Material.Metal)
	local head = part(folder, "Head", Vector3.new(3.6, 3.6, 3.6), base + Vector3.new(0, 10.2, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
	-- Eyes and smile.
	for _, dx in ipairs({ -0.8, 0.8 }) do
		part(folder, "Eye", Vector3.new(0.5, 0.7, 0.4), base + Vector3.new(dx, 10.6, 1.7), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic).CanCollide = false
	end
	part(folder, "Smile", Vector3.new(1.4, 0.35, 0.4), base + Vector3.new(0, 9.4, 1.7), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic).CanCollide = false
	-- Halo ring above the head.
	local halo = part(folder, "Halo", Vector3.new(4.5, 0.4, 4.5), base + Vector3.new(0, 12.6, 0), Color3.fromRGB(255, 220, 80), Enum.Material.Neon, Enum.PartType.Cylinder)
	halo.Orientation = Vector3.new(0, 0, 0)
	halo.CanCollide = false
	-- Uplights around the pedestal.
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local rad = math.rad(angle)
		local pos = base + Vector3.new(math.cos(rad) * 8, 2.3, math.sin(rad) * 8)
		part(folder, "Uplight", Vector3.new(1, 0.6, 1), pos, Color3.fromRGB(255, 220, 80), Enum.Material.Neon).CanCollide = false
	end
	shadowSlab(folder, Vector3.new(16, 0.2, 16), base + Vector3.new(0, 0.3, 0))
end

-- ---------------------------------------------------------------------------
-- Bases: 8 little shops on a ring of radius 130
-- ---------------------------------------------------------------------------

local function buildBase(world, index)
	local angle = math.rad(22.5 + 45 * (index - 1))
	local cx = math.sin(angle) * RING_RADIUS
	local cz = math.cos(angle) * RING_RADIUS
	local centre = Vector3.new(cx, 0, cz)
	-- Face the map centre: the gate looks inward.
	local lookAt = CFrame.lookAt(centre + Vector3.new(0, 2, 0), Vector3.new(0, 2, 0))
	local hue = (index - 1) / 8
	local padColor = Color3.fromHSV(hue, 0.65, 0.9)

	local folder = Instance.new("Model")
	folder.Name = "Base" .. index
	folder.Parent = world

	-- Concrete slab + coloured pad.
	local slab = part(folder, "Slab", Vector3.new(44, 2, 44), centre + Vector3.new(0, 1, 0), Color3.fromRGB(150, 150, 155), Enum.Material.Concrete)
	slab.CFrame = lookAt * CFrame.new(0, -1, 0)
	local pad = part(folder, "Pad", Vector3.new(40, 0.6, 40), centre + Vector3.new(0, 2.1, 0), padColor, Enum.Material.SmoothPlastic)
	pad.CFrame = lookAt * CFrame.new(0, 0.1, 0)
	pad.CanCollide = false
	neon(folder, "PadEdge", Vector3.new(40, 0.4, 1), centre, padColor).CFrame = lookAt * CFrame.new(0, 0.4, -19.5)

	-- 2-step stoop toward the centre.
	local stoop1 = part(folder, "Stoop1", Vector3.new(12, 1, 4), centre, Color3.fromRGB(170, 170, 175), Enum.Material.Concrete)
	stoop1.CFrame = lookAt * CFrame.new(0, 0.5, -22)
	local stoop2 = part(folder, "Stoop2", Vector3.new(12, 1, 4), centre, Color3.fromRGB(170, 170, 175), Enum.Material.Concrete)
	stoop2.CFrame = lookAt * CFrame.new(0, 1.5, -20)

	-- Back + side walls with a door cutout facing the centre. Walls are two
	-- side pillars and a top lintel, so the doorway stays open.
	local wallColor = Color3.fromRGB(235, 225, 210)
	for _, sx in ipairs({ -1, 1 }) do
		local pillar = part(folder, "WallPillar", Vector3.new(6, 10, 2), centre, wallColor, Enum.Material.SmoothPlastic)
		pillar.CFrame = lookAt * CFrame.new(sx * 12, 7, -21)
		local side = part(folder, "SideWall", Vector3.new(2, 10, 42), centre, wallColor, Enum.Material.SmoothPlastic)
		side.CFrame = lookAt * CFrame.new(sx * 21, 7, 0)
	end
	local lintel = part(folder, "Lintel", Vector3.new(30, 4, 2), centre, wallColor, Enum.Material.SmoothPlastic)
	lintel.CFrame = lookAt * CFrame.new(0, 10, -21)
	-- Flat roof with parapet.
	local roof = part(folder, "Roof", Vector3.new(46, 1.5, 46), centre, Color3.fromRGB(120, 110, 100), Enum.Material.Concrete)
	roof.CFrame = lookAt * CFrame.new(0, 12.7, 0)
	for _, sz in ipairs({ -1, 1 }) do
		local parapet = part(folder, "Parapet", Vector3.new(46, 1.5, 1.5), centre, Color3.fromRGB(100, 90, 80), Enum.Material.Concrete)
		parapet.CFrame = lookAt * CFrame.new(0, 14, sz * 22.5)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local parapet = part(folder, "ParapetSide", Vector3.new(1.5, 1.5, 46), centre, Color3.fromRGB(100, 90, 80), Enum.Material.Concrete)
		parapet.CFrame = lookAt * CFrame.new(sx * 22.5, 14, 0)
	end
	-- Neon fascia and wedge corners.
	local fascia = neon(folder, "Fascia", Vector3.new(44, 0.8, 1), centre, padColor)
	fascia.CFrame = lookAt * CFrame.new(0, 12, -22.5)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local wedge = part(folder, "CornerWedge", Vector3.new(3, 3, 3), centre, padColor, Enum.Material.Neon, Enum.PartType.Wedge)
			wedge.CFrame = lookAt * CFrame.new(sx * 21, 13.5, sz * 21) * CFrame.Angles(0, math.rad(sx * sz * 45), 0)
			wedge.CanCollide = false
		end
	end
	-- Striped awning over the door on two posts.
	for _, sx in ipairs({ -1, 1 }) do
		local post = part(folder, "AwningPost", Vector3.new(1, 6, 1), centre, Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
		post.CFrame = lookAt * CFrame.new(sx * 8, 5, -24)
	end
	for i = 1, 6 do
		local stripeColor = i % 2 == 0 and Color3.fromRGB(255, 255, 255) or padColor
		local stripe = part(folder, "AwningStripe", Vector3.new(3, 0.4, 6), centre, stripeColor, Enum.Material.Fabric)
		stripe.CFrame = lookAt * CFrame.new(-7.5 + (i - 0.5) * 3, 8.2, -24)
		stripe.CanCollide = false
	end
	shadowSlab(folder, Vector3.new(20, 0.2, 8), centre).CFrame = lookAt * CFrame.new(0, 2.4, -24)

	-- Flag pole on the roof.
	local pole = part(folder, "FlagPole", Vector3.new(0.8, 10, 0.8), centre, Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	pole.CFrame = lookAt * CFrame.new(18, 18, 18)
	local flag = part(folder, "Flag", Vector3.new(5, 3, 0.3), centre, padColor, Enum.Material.Fabric)
	flag.CFrame = lookAt * CFrame.new(20.5, 21.5, 18)
	flag.CanCollide = false

	-- Owner sign above the door: a SurfaceGui on the front face toward the centre.
	local sign = part(folder, "SignBoard", Vector3.new(16, 4, 0.6), centre, Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
	sign.CFrame = lookAt * CFrame.new(0, 13.5, -22.2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BASE " .. index
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	-- 6 display slots in two rows of three: dark trim plate + glowing pad.
	local slots = {}
	for row = 1, 2 do
		for col = 1, 3 do
			local slotIndex = (row - 1) * 3 + col
			local lx = -12 + (col - 1) * 12
			local lz = -6 + (row - 1) * 12
			local trim = part(folder, "SlotTrim" .. slotIndex, Vector3.new(9, 0.5, 9), centre, Color3.fromRGB(50, 50, 60), Enum.Material.SmoothPlastic)
			trim.CFrame = lookAt * CFrame.new(lx, 2.4, lz)
			trim.CanCollide = false
			local glow = part(folder, "SlotPad" .. slotIndex, Vector3.new(7, 0.4, 7), centre, padColor, Enum.Material.Neon)
			glow.CFrame = lookAt * CFrame.new(lx, 2.6, lz)
			glow.CanCollide = false
			-- Slot positions face the gate: a CFrame looking toward the centre.
			local slotCFrame = lookAt * CFrame.new(lx, 2.8, lz) * CFrame.Angles(0, math.rad(180), 0)
			table.insert(slots, slotCFrame)
		end
	end

	return {
		model = folder,
		centre = centre,
		slots = slots,
		label = label,
		pad = pad,
	}
end

-- ---------------------------------------------------------------------------
-- Thief ring-walkway: pale octagon of radius 100, lamps at each segment
-- ---------------------------------------------------------------------------

local function buildRingWalkway(world)
	local folder = Instance.new("Model")
	folder.Name = "RingWalkway"
	folder.Parent = world
	for i = 1, 8 do
		local angle = math.rad(22.5 + 45 * (i - 1))
		local cx = math.sin(angle) * 100
		local cz = math.cos(angle) * 100
		local segment = part(folder, "Segment" .. i, Vector3.new(10, 0.6, 78), Vector3.new(cx, 2.1, cz), Color3.fromRGB(220, 210, 190), Enum.Material.SmoothPlastic)
		segment.CFrame = CFrame.new(cx, 2.1, cz) * CFrame.Angles(0, angle, 0)
		segment.CanCollide = false
		-- Neon edge strip along the outer side.
		local edge = neon(folder, "Edge" .. i, Vector3.new(0.6, 0.4, 78), Vector3.new(cx, 2.4, cz), Color3.fromRGB(255, 200, 40))
		edge.CFrame = CFrame.new(cx, 2.4, cz) * CFrame.Angles(0, angle, 0) * CFrame.new(4.8, 0, 0)
		-- A lamp post at each segment.
		local lampAngle = math.rad(45 * (i - 1))
		local lx = math.sin(lampAngle) * 100
		local lz = math.cos(lampAngle) * 100
		part(folder, "LampPost" .. i, Vector3.new(1, 8, 1), Vector3.new(lx, 6, lz), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
		part(folder, "Lamp" .. i, Vector3.new(2.5, 2.5, 2.5), Vector3.new(lx, 10.5, lz), Color3.fromRGB(255, 230, 150), Enum.Material.Neon, Enum.PartType.Ball).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Grinder Pit at (-150, -150): lava, rocks, chevrons, sweeper, bridge
-- ---------------------------------------------------------------------------

local function buildGrinderPit(world)
	local folder = Instance.new("Model")
	folder.Name = "GrinderPit"
	folder.Parent = world
	local centre = Vector3.new(-150, 0, -150)

	-- 70 x 70 neon lava slab.
	local lava = part(folder, "Lava", Vector3.new(70, 1, 70), centre + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 90, 20), Enum.Material.Neon)
	lava.CanCollide = false
	part(folder, "PitRim", Vector3.new(74, 2, 74), centre + Vector3.new(0, 0, 0), Color3.fromRGB(60, 55, 50), Enum.Material.Slate)
	-- A ring of 8 dark rocks.
	for i = 1, 8 do
		local angle = math.rad(45 * (i - 1))
		local rx = centre.X + math.sin(angle) * 34
		local rz = centre.Z + math.cos(angle) * 34
		part(folder, "Rock" .. i, Vector3.new(5, 4 + (i % 3), 5), Vector3.new(rx, 2.5, rz), Color3.fromRGB(45, 45, 50), Enum.Material.Slate, Enum.PartType.Ball)
	end
	-- 12 alternating yellow/dark warning chevrons around the rim.
	for i = 1, 12 do
		local angle = math.rad(30 * (i - 1))
		local cx = centre.X + math.sin(angle) * 37
		local cz = centre.Z + math.cos(angle) * 37
		local color = i % 2 == 0 and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(40, 40, 40)
		local chevron = part(folder, "Warning" .. i, Vector3.new(4, 0.5, 2), Vector3.new(cx, 2.2, cz), color, Enum.Material.SmoothPlastic)
		chevron.CFrame = CFrame.new(cx, 2.2, cz) * CFrame.Angles(0, angle, 0)
		chevron.CanCollide = false
	end
	-- Central hub with a 60-stud neon sweeper bar.
	local hub = part(folder, "Hub", Vector3.new(6, 3, 6), centre + Vector3.new(0, 2.5, 0), Color3.fromRGB(50, 50, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	local sweeper = part(folder, "SweeperBar", Vector3.new(60, 1.5, 3), centre + Vector3.new(0, 4, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	sweeper.CanCollide = false
	-- A railed wooden bridge across the pit.
	for i = 1, 7 do
		local plank = part(folder, "BridgePlank" .. i, Vector3.new(8, 0.8, 4), centre + Vector3.new(-12 + (i - 1) * 4, 2.4, 0), Color3.fromRGB(160, 110, 60), Enum.Material.Wood)
		plank.CanCollide = false
	end
	for _, sz in ipairs({ -1, 1 }) do
		local rail = part(folder, "BridgeRail", Vector3.new(28, 1, 1), centre + Vector3.new(0, 4.5, sz * 4.5), Color3.fromRGB(120, 80, 40), Enum.Material.Wood)
		rail.CanCollide = false
	end

	return sweeper, centre
end

-- ---------------------------------------------------------------------------
-- Scenery: trees, bushes, clouds, arches, spawn
-- ---------------------------------------------------------------------------

local function buildScenery(world)
	local folder = Instance.new("Model")
	folder.Name = "Scenery"
	folder.Parent = world

	-- 14 trees around the rim, keeping the conveyor sightline clear.
	local treeSpots = {
		{ -180, 60 }, { -180, -60 }, { -120, 180 }, { 120, 180 }, { 180, 60 },
		{ 180, -60 }, { -60, -190 }, { 60, -190 }, { -190, 140 }, { 190, 140 },
		{ -190, -140 }, { 190, -140 }, { -90, 195 }, { 90, 195 },
	}
	for i, spot in ipairs(treeSpots) do
		local tree = Instance.new("Model")
		tree.Name = "Tree" .. i
		tree.Parent = folder
		local x, z = spot[1], spot[2]
		part(tree, "Trunk", Vector3.new(2, 8, 2), Vector3.new(x, 4, z), Color3.fromRGB(120, 80, 40), Enum.Material.Wood)
		part(tree, "Canopy1", Vector3.new(8, 7, 8), Vector3.new(x, 11, z), Color3.fromRGB(60, 160, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(tree, "Canopy2", Vector3.new(6, 5, 6), Vector3.new(x + 2, 15, z - 1), Color3.fromRGB(80, 190, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(tree, "Canopy3", Vector3.new(5, 4, 5), Vector3.new(x - 2, 14, z + 1), Color3.fromRGB(50, 140, 60), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end

	-- 10 bushes near the ring.
	for i = 1, 10 do
		local angle = math.rad(36 * i)
		local x = math.sin(angle) * 112
		local z = math.cos(angle) * 112
		part(folder, "Bush" .. i, Vector3.new(5, 4, 5), Vector3.new(x, 3, z), Color3.fromRGB(70, 170, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end

	-- 6 cloud clusters floating high up.
	for i = 1, 6 do
		local cloud = Instance.new("Model")
		cloud.Name = "Cloud" .. i
		cloud.Parent = folder
		local x = -150 + (i - 1) * 60
		local z = -120 + ((i * 37) % 160)
		for j, offset in ipairs({ Vector3.new(0, 0, 0), Vector3.new(5, 1, 1), Vector3.new(-5, 0.5, -1), Vector3.new(2, 2, -2) }) do
			local puff = part(cloud, "Puff" .. j, Vector3.new(12, 6, 8), Vector3.new(x, 60, z) + offset, Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			puff.Transparency = 0.25
			puff.CanCollide = false
		end
	end

	-- Tall pink arch over the conveyor's north end, with the sign facing spawn.
	local archN = Instance.new("Model")
	archN.Name = "ArchNorth"
	archN.Parent = folder
	for _, sx in ipairs({ -1, 1 }) do
		stack(archN, "ArchLeg", Vector3.new(sx * 16, 0, -150), Vector3.new(4, 1, 4), Vector3.new(3, 14, 3), Vector3.new(4, 1, 4),
			Color3.fromRGB(255, 120, 180), Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 200, 220))
	end
	part(archN, "ArchBeam", Vector3.new(36, 3, 4), Vector3.new(0, 16, -150), Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
	local signBoard = part(archN, "SignBoard", Vector3.new(30, 5, 1), Vector3.new(0, 12, -147.5), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back -- faces spawn (south)
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 12
	signGui.Parent = signBoard
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "BRAINROT BAZAAR"
	signLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Smaller gold arch over the south end.
	local archS = Instance.new("Model")
	archS.Name = "ArchSouth"
	archS.Parent = folder
	for _, sx in ipairs({ -1, 1 }) do
		part(archS, "Leg", Vector3.new(3, 10, 3), Vector3.new(sx * 14, 5, 150), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
	end
	part(archS, "Beam", Vector3.new(31, 2.5, 3), Vector3.new(0, 11, 150), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)

	-- Spawn: a SpawnLocation 40 x 12 at (0, 1, 205), neutral, gold neon.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(40, 2, 12)
	spawn.Position = Vector3.new(0, 1, 205)
	spawn.Color = Color3.fromRGB(255, 200, 40)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	return Vector3.new(0, 4, 205)
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

function World.buildWorld()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = game:GetService("Workspace")

	buildLighting(world)
	buildGround(world)
	buildConveyor(world)
	buildStatue(world)

	local bases = {}
	for i = 1, BASE_COUNT do
		bases[i] = buildBase(world, i)
	end

	buildRingWalkway(world)
	local sweeper, pitCentre = buildGrinderPit(world)
	local spawnPosition = buildScenery(world)

	return {
		world = world,
		bases = bases,
		sweeper = sweeper,
		spawnPosition = spawnPosition,
		conveyorStart = Vector3.new(0, 2, 150),
		conveyorEnd = Vector3.new(0, 2, -150),
		pitCentre = pitCentre,
	}
end

return World
