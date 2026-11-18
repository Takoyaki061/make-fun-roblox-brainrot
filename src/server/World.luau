-- World.luau
-- Builds the whole Brainrot Bazaar map out of Parts, in code.
--
-- House style: no bare boxes — every structure gets a plinth, a body
-- and a cap; at most three materials per zone; neon edge strips on the
-- important edges; a thin dark semi-transparent slab under overhangs
-- as a fake shadow. Lighting is bright and cartoonish.
--
-- Layout: a grass plaza with a 300-stud conveyor down the middle, 8
-- shop-like bases on a ring around it, a golden statue, a thief
-- ring-walkway, a lava Grinder Pit in the north-west corner, and
-- scenery around the rim. Y=0 is ground level; pad tops sit at y=2.

local World = {}

local BASE_COUNT = 8
local RING_RADIUS = 130
local CONVEYOR_HALF = 150

-- ---------------------------------------------------------------------------
-- Part helpers
-- ---------------------------------------------------------------------------

local function P(parent, name, size, pos, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A part oriented by lookAt: its Front face (-Z) points at the target.
local function PF(parent, name, size, pos, target, color, material)
	local part = P(parent, name, size, pos, color, material)
	part.CFrame = CFrame.lookAt(pos, target)
	return part
end

local function ball(parent, name, size, pos, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Position = pos
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function cyl(parent, name, diameter, height, pos, color, material, axis)
	-- axis "X" | "Y" | "Z": which way the cylinder's length runs.
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	if axis == "X" then
		part.Size = Vector3.new(height, diameter, diameter)
		part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		part.Size = Vector3.new(diameter, diameter, height)
		part.CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(90), 0, 0)
	else
		part.Size = Vector3.new(diameter, height, diameter)
		part.CFrame = CFrame.new(pos)
	end
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A thin dark slab that reads as a shadow under an overhang.
local function fakeShadow(parent, size, pos)
	local slab = P(parent, "FakeShadow", size, pos, Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic)
	slab.Transparency = 0.6
	slab.CanCollide = false
	return slab
end

-- Neon strip: a thin glowing bar along one edge. Used everywhere an
-- edge needs to pop in screenshots.
local function neonStrip(parent, name, size, pos, color)
	return P(parent, name, size, pos, color, Enum.Material.Neon)
end

-- ---------------------------------------------------------------------------
-- Lighting
-- ---------------------------------------------------------------------------

local function setupLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 14
	lighting.Brightness = 3
	lighting.Ambient = Color3.fromRGB(120, 100, 90)
	lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 190)
	lighting.GeographicLatitude = 20
	-- NOTE: Lighting.Technology cannot be written from a script; new
	-- places default to Future, which is what we want anyway.

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "BazaarHaze"
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(180, 200, 230)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.5
	atmosphere.Parent = lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "BazaarBloom"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 0.85
	bloom.Parent = lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "BazaarColor"
	correction.Saturation = 0.25
	correction.Contrast = 0.05
	correction.Brightness = 0.02
	correction.Parent = lighting
end

-- ---------------------------------------------------------------------------
-- Ground and spawn plaza
-- ---------------------------------------------------------------------------

local function buildGround(folder)
	-- Grass slab, top at y=0.
	P(folder, "Grass", Vector3.new(420, 2, 420), Vector3.new(0, -1, 0),
		Color3.fromRGB(110, 200, 90), Enum.Material.Grass)

	-- Spawn plaza: warm slab centred south, with a checker of tiles.
	local plaza = P(folder, "SpawnPlaza", Vector3.new(120, 1, 70), Vector3.new(0, 0.5, 195),
		Color3.fromRGB(240, 210, 140), Enum.Material.SmoothPlastic)
	plaza.CanCollide = true
	-- Checker tiles across the plaza top.
	for row = 0, 6 do
		for col = 0, 11 do
			if (row + col) % 2 == 0 then
				P(folder, "PlazaTile", Vector3.new(9.5, 0.2, 9.5),
					Vector3.new(-55 + col * 10, 1.1, 165 + row * 10),
					Color3.fromRGB(255, 230, 170), Enum.Material.SmoothPlastic).CanCollide = false
			end
		end
	end
	-- Edge trim around the plaza.
	neonStrip(folder, "PlazaTrimN", Vector3.new(120, 0.4, 1), Vector3.new(0, 1.2, 160.5), Color3.fromRGB(255, 200, 60))
	neonStrip(folder, "PlazaTrimS", Vector3.new(120, 0.4, 1), Vector3.new(0, 1.2, 229.5), Color3.fromRGB(255, 200, 60))
	neonStrip(folder, "PlazaTrimW", Vector3.new(1, 0.4, 70), Vector3.new(-59.5, 1.2, 195), Color3.fromRGB(255, 200, 60))
	neonStrip(folder, "PlazaTrimE", Vector3.new(1, 0.4, 70), Vector3.new(59.5, 1.2, 195), Color3.fromRGB(255, 200, 60))

	-- Two spoke paths from the plaza to the ring walkway.
	P(folder, "SpokeWest", Vector3.new(10, 0.4, 60), Vector3.new(-80, 0.2, 165),
		Color3.fromRGB(230, 200, 150), Enum.Material.SmoothPlastic).CanCollide = false
	P(folder, "SpokeEast", Vector3.new(10, 0.4, 60), Vector3.new(80, 0.2, 165),
		Color3.fromRGB(230, 200, 150), Enum.Material.SmoothPlastic).CanCollide = false

	-- Six flower planters along the plaza's north edge.
	for i = 1, 6 do
		local x = -50 + (i - 1) * 20
		P(folder, "Planter", Vector3.new(8, 2, 4), Vector3.new(x, 1, 162),
			Color3.fromRGB(150, 90, 50), Enum.Material.Wood)
		ball(folder, "PlanterFlower", 3, Vector3.new(x, 3, 162),
			Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
	end
end

-- ---------------------------------------------------------------------------
-- Conveyor: a real machine down the middle
-- ---------------------------------------------------------------------------

local function buildConveyor(folder)
	local deck = P(folder, "ConveyorDeck", Vector3.new(24, 2, 300), Vector3.new(0, 1, 0),
		Color3.fromRGB(50, 55, 65), Enum.Material.Metal)
	deck.CanCollide = true
	-- Belt: dark rubber top, its surface at y=2.
	local belt = P(folder, "ConveyorBelt", Vector3.new(20, 0.4, 298), Vector3.new(0, 1.9, 0),
		Color3.fromRGB(35, 35, 40), Enum.Material.SmoothPlastic)
	belt.CanCollide = false

	-- A-frame legs every 30 studs.
	for z = -135, 135, 30 do
		for _, x in ipairs({ -9, 9 }) do
			local leg = P(folder, "ConveyorLeg", Vector3.new(1.5, 2, 1.5), Vector3.new(x, 0, z),
				Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
			leg.CanCollide = false
		end
	end

	-- Rollers across the belt every 16 studs.
	for z = -144, 144, 16 do
		cyl(folder, "Roller", 1.6, 20, Vector3.new(0, 1.8, z),
			Color3.fromRGB(120, 125, 135), Enum.Material.Metal, "X").CanCollide = false
	end

	-- Side frames with neon gold edge strips and bolt nubs.
	for _, x in ipairs({ -11.5, 11.5 }) do
		P(folder, "ConveyorFrame", Vector3.new(1, 2.5, 300), Vector3.new(x, 1.5, 0),
			Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
		neonStrip(folder, "FrameGlow", Vector3.new(0.6, 0.6, 300), Vector3.new(x, 3, 0),
			Color3.fromRGB(255, 200, 60))
		for z = -140, 140, 20 do
			ball(folder, "FrameBolt", 0.8, Vector3.new(x, 2.4, z),
				Color3.fromRGB(200, 200, 210), Enum.Material.Metal).CanCollide = false
		end
	end

	-- Chevron markers down the belt centre, pointing north.
	for z = -140, 140, 20 do
		local chevron = Instance.new("Part")
		chevron.Name = "BeltChevron"
		chevron.Shape = Enum.PartType.Wedge
		chevron.Size = Vector3.new(6, 0.4, 5)
		chevron.CFrame = CFrame.new(0, 2.1, z) * CFrame.Angles(0, math.rad(180), 0)
		chevron.Color = Color3.fromRGB(255, 200, 60)
		chevron.Material = Enum.Material.Neon
		chevron.Anchored = true
		chevron.CanCollide = false
		chevron.TopSurface = Enum.SurfaceType.Smooth
		chevron.BottomSurface = Enum.SurfaceType.Smooth
		chevron.Parent = folder
	end

	-- Gearbox housing and cable tray on the east side near spawn.
	P(folder, "Gearbox", Vector3.new(6, 6, 10), Vector3.new(15, 3, 130),
		Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	P(folder, "GearboxCap", Vector3.new(7, 1, 11), Vector3.new(15, 6.5, 130),
		Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	P(folder, "CableTray", Vector3.new(2, 1, 60), Vector3.new(14, 1, 100),
		Color3.fromRGB(60, 60, 70), Enum.Material.Metal)

	-- Red neon stop-lamp at the north (discharge) end.
	local lampPost = cyl(folder, "StopLampPost", 1, 8, Vector3.new(13, 4, -148),
		Color3.fromRGB(70, 70, 80), Enum.Material.Metal, "Y")
	lampPost.CanCollide = false
	ball(folder, "StopLamp", 3, Vector3.new(13, 8.5, -148),
		Color3.fromRGB(255, 40, 40), Enum.Material.Neon).CanCollide = false
end

-- ---------------------------------------------------------------------------
-- Golden statue beside the conveyor
-- ---------------------------------------------------------------------------

local function buildStatue(folder)
	local base = Vector3.new(36, 0, 0)
	-- Tiered slate pedestal with neon risers.
	P(folder, "StatuePlinth", Vector3.new(14, 1, 14), base + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(60, 60, 70), Enum.Material.Slate)
	P(folder, "StatueRiser", Vector3.new(12, 0.5, 12), base + Vector3.new(0, 1.25, 0),
		Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	P(folder, "StatueTier2", Vector3.new(10, 2, 10), base + Vector3.new(0, 2.5, 0),
		Color3.fromRGB(80, 80, 90), Enum.Material.Slate)
	P(folder, "StatueRiser2", Vector3.new(10.5, 0.5, 10.5), base + Vector3.new(0, 3.75, 0),
		Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	-- Gold head-and-shoulders figure.
	local gold = Color3.fromRGB(255, 200, 60)
	ball(folder, "StatueHead", 6, base + Vector3.new(0, 9, 0), gold, Enum.Material.Metal)
	P(folder, "StatueShoulders", Vector3.new(10, 3, 5), base + Vector3.new(0, 5, 0),
		gold, Enum.Material.Metal)
	-- Eyes and a smile on the statue's south face.
	ball(folder, "StatueEyeL", 1, base + Vector3.new(-1.5, 10, 3), Color3.fromRGB(30, 30, 30)).CanCollide = false
	ball(folder, "StatueEyeR", 1, base + Vector3.new(1.5, 10, 3), Color3.fromRGB(30, 30, 30)).CanCollide = false
	P(folder, "StatueSmile", Vector3.new(2.5, 0.6, 0.6), base + Vector3.new(0, 8, 3),
		Color3.fromRGB(30, 30, 30)).CanCollide = false
	-- Halo ring floating above the head.
	local halo = cyl(folder, "StatueHalo", 7, 0.6, base + Vector3.new(0, 13, 0),
		Color3.fromRGB(255, 220, 100), Enum.Material.Neon, "Y")
	halo.CanCollide = false
	-- Uplights at the pedestal corners.
	for _, dx in ipairs({ -5, 5 }) do
		for _, dz in ipairs({ -5, 5 }) do
			ball(folder, "StatueUplight", 1.2, base + Vector3.new(dx, 1.6, dz),
				Color3.fromRGB(255, 220, 100), Enum.Material.Neon).CanCollide = false
		end
	end
end

-- ---------------------------------------------------------------------------
-- Player bases: little shops on a ring
-- ---------------------------------------------------------------------------

local function baseAngle(i)
	return math.rad(22.5 + 45 * (i - 1))
end

local function baseCentre(i)
	local a = baseAngle(i)
	return Vector3.new(math.cos(a) * RING_RADIUS, 0, math.sin(a) * RING_RADIUS)
end

-- One base. Returns the record the server loop needs: model, centre,
-- six slot CFrames (facing the gate, i.e. the map centre), the owner
-- sign's TextLabel, and the coloured pad.
local function buildBase(folder, i)
	local centre = baseCentre(i)
	local hue = Color3.fromHSV((i - 1) / 8, 0.7, 0.9)
	local model = Instance.new("Model")
	model.Name = "Base" .. i
	model.Parent = folder

	-- Concrete slab + coloured pad (pad top at y=2).
	P(model, "Slab", Vector3.new(46, 1.6, 46), centre + Vector3.new(0, 0.8, 0),
		Color3.fromRGB(180, 180, 185), Enum.Material.Concrete)
	P(model, "Pad", Vector3.new(40, 0.4, 40), centre + Vector3.new(0, 1.8, 0),
		hue, Enum.Material.SmoothPlastic)

	-- Direction from the base to the map centre, and the yaw that
	-- makes a part's Front face the centre.
	local toCentre = Vector3.new(-centre.X, 0, -centre.Z).Unit
	local gateTarget = centre + toCentre * 10
	local function facing(size, offset, color, material, name)
		local pos = centre + Vector3.new(offset.X, offset.Y, offset.Z)
		return PF(model, name or "Wall", size, pos, pos + toCentre * 10, color, material)
	end

	-- Two-step stoop toward the centre.
	local stepDir = toCentre
	P(model, "Stoop1", Vector3.new(14, 0.6, 4), centre + stepDir * 24 + Vector3.new(0, 0.3, 0),
		Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)
	P(model, "Stoop2", Vector3.new(14, 0.6, 4), centre + stepDir * 21 + Vector3.new(0, 0.9, 0),
		Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)

	-- Back wall, side walls, and a door cutout on the centre side:
	-- two door posts and a lintel instead of a full front wall.
	local back = centre - toCentre * 21
	local side = Vector3.new(-toCentre.Z, 0, toCentre.X) -- 90 degrees around Y
	facing(Vector3.new(44, 12, 2), Vector3.new(back.X - centre.X, 8, back.Z - centre.Z),
		Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, "BackWall")
	facing(Vector3.new(2, 12, 42), Vector3.new(side.X * 21, 8, side.Z * 21),
		Color3.fromRGB(230, 230, 235), Enum.Material.SmoothPlastic, "SideWallL")
	facing(Vector3.new(2, 12, 42), Vector3.new(-side.X * 21, 8, -side.Z * 21),
		Color3.fromRGB(230, 230, 235), Enum.Material.SmoothPlastic, "SideWallR")
	-- Door posts and lintel on the centre side.
	facing(Vector3.new(3, 10, 2), Vector3.new(toCentre.X * 21 + side.X * 7, 7, toCentre.Z * 21 + side.Z * 7),
		Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, "DoorPostL")
	facing(Vector3.new(3, 10, 2), Vector3.new(toCentre.X * 21 - side.X * 7, 7, toCentre.Z * 21 - side.Z * 7),
		Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, "DoorPostR")
	facing(Vector3.new(17, 2, 2), Vector3.new(toCentre.X * 21, 13, toCentre.Z * 21),
		Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic, "Lintel")

	-- Flat roof with parapet and neon fascia, plus wedge corners.
	facing(Vector3.new(46, 1, 46), Vector3.new(0, 14.5, 0),
		Color3.fromRGB(90, 90, 100), Enum.Material.SmoothPlastic, "Roof")
	facing(Vector3.new(46, 1.5, 1.5), Vector3.new(toCentre.X * 22, 15.5, toCentre.Z * 22),
		hue, Enum.Material.Neon, "FasciaFront")
	facing(Vector3.new(46, 1.5, 1.5), Vector3.new(-toCentre.X * 22, 15.5, -toCentre.Z * 22),
		hue, Enum.Material.Neon, "FasciaBack")
	fakeShadow(model, Vector3.new(44, 0.2, 44), centre + Vector3.new(0, 14, 0))

	-- Striped awning over the door on two posts.
	local awningPos = centre + toCentre * 24 + Vector3.new(0, 11, 0)
	local awning = PF(model, "Awning", Vector3.new(18, 0.6, 8), awningPos, gateTarget,
		Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	awning.CanCollide = false
	for stripe = -2, 2 do
		if stripe % 2 == 0 then
			local stripePart = PF(model, "AwningStripe", Vector3.new(3.4, 0.7, 8),
				awningPos + side * (stripe * 3.6), gateTarget, hue, Enum.Material.SmoothPlastic)
			stripePart.CanCollide = false
		end
	end
	for _, s in ipairs({ -7, 7 }) do
		local post = cyl(model, "AwningPost", 0.8, 9, centre + toCentre * 27 + side * s + Vector3.new(0, 6.5, 0),
			Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "Y")
		post.CanCollide = false
	end

	-- Flag pole on the roof with a waving flag.
	local polePos = centre - toCentre * 18 + side * 16 + Vector3.new(0, 19, 0)
	cyl(model, "FlagPole", 0.7, 9, polePos, Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "Y").CanCollide = false
	local flag = PF(model, "Flag", Vector3.new(0.4, 4, 7), polePos + Vector3.new(0, 2, 0) + side * 3.5,
		polePos + side * 10, hue, Enum.Material.SmoothPlastic)
	flag.CanCollide = false

	-- Six display slots in two rows of three: dark trim + glowing pad.
	local slots = {}
	for row = 0, 1 do
		for col = -1, 1 do
			local localPos = side * (col * 12) + toCentre * (4 - row * 10)
			local slotPos = centre + localPos + Vector3.new(0, 2, 0)
			P(model, "SlotTrim", Vector3.new(7, 0.4, 7), slotPos + Vector3.new(0, -0.1, 0),
				Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic).CanCollide = false
			local pad = P(model, "SlotPad", Vector3.new(6, 0.3, 6), slotPos + Vector3.new(0, 0.1, 0),
				hue, Enum.Material.Neon)
			pad.CanCollide = false
			table.insert(slots, CFrame.lookAt(slotPos + Vector3.new(0, 0.2, 0), slotPos + toCentre * 10))
		end
	end

	-- Owner sign board above the door, facing the centre.
	local signPos = centre + toCentre * 22.5 + Vector3.new(0, 16.5, 0)
	local board = PF(model, "OwnerSign", Vector3.new(16, 5, 1), signPos, gateTarget,
		Color3.fromRGB(40, 40, 55), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerSignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BASE " .. i
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return {
		model = model,
		centre = centre,
		slots = slots,
		ownerLabel = label,
		pad = hue,
	}
end

-- ---------------------------------------------------------------------------
-- Thief ring-walkway linking the base gates
-- ---------------------------------------------------------------------------

local function buildRing(folder, bases)
	-- Gate point of a base: its centre moved 24 studs toward the map centre.
	local function gatePoint(i)
		local c = bases[i].centre
		local dir = Vector3.new(-c.X, 0, -c.Z).Unit
		return c + dir * 24
	end
	for i = 1, BASE_COUNT do
		local a = gatePoint(i)
		local b = gatePoint(i % BASE_COUNT + 1)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		-- Pale octagon segment.
		local seg = PF(folder, "RingSegment", Vector3.new(8, 0.6, len), mid + Vector3.new(0, 0.3, 0),
			b, Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic)
		seg.CanCollide = false
		-- Neon edge strip down its middle.
		local strip = PF(folder, "RingGlow", Vector3.new(1, 0.7, len), mid + Vector3.new(0, 0.4, 0),
			b, Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
		strip.CanCollide = false
		-- A lamp post at the segment's midpoint, offset outward.
		local out = Vector3.new(mid.X, 0, mid.Z).Unit
		local lampBase = mid + out * 6
		cyl(folder, "RingLampPost", 0.8, 7, lampBase + Vector3.new(0, 3.5, 0),
			Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "Y").CanCollide = false
		ball(folder, "RingLamp", 2, lampBase + Vector3.new(0, 7.5, 0),
			Color3.fromRGB(255, 230, 150), Enum.Material.Neon).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Grinder Pit in the north-west corner
-- ---------------------------------------------------------------------------

local function buildPit(folder)
	local centre = Vector3.new(-150, 0, -150)
	-- Neon lava slab.
	P(folder, "Lava", Vector3.new(70, 1, 70), centre + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(255, 80, 20), Enum.Material.Neon)
	-- Ring of 8 dark rocks around the rim.
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local pos = centre + Vector3.new(math.cos(a) * 38, 1.5, math.sin(a) * 38)
		ball(folder, "PitRock", 5, pos, Color3.fromRGB(50, 50, 60), Enum.Material.Slate)
	end
	-- Twelve alternating yellow/dark warning chevrons on the rim.
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local pos = centre + Vector3.new(math.cos(a) * 34, 1.1, math.sin(a) * 34)
		local color = (i % 2 == 0) and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(40, 40, 50)
		local chevron = P(folder, "PitChevron", Vector3.new(5, 0.4, 3), pos, color, Enum.Material.SmoothPlastic)
		chevron.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, 0)
		chevron.CanCollide = false
	end
	-- Central hub and the spinning sweeper bar.
	local hub = cyl(folder, "PitHub", 8, 3, centre + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(60, 60, 70), Enum.Material.Metal, "Y")
	hub.CanCollide = false
	local sweeper = P(folder, "SweeperBar", Vector3.new(60, 1.5, 2), centre + Vector3.new(0, 3, 0),
		Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	sweeper.CanCollide = false
	-- Railed wooden bridge across the pit.
	for i = 0, 9 do
		local t = -30 + i * 6.7
		P(folder, "BridgePlank", Vector3.new(8, 0.5, 6), centre + Vector3.new(t, 1.2, 0),
			Color3.fromRGB(160, 110, 60), Enum.Material.Wood)
	end
	for _, z in ipairs({ -4, 4 }) do
		P(folder, "BridgeRail", Vector3.new(68, 0.5, 0.5), centre + Vector3.new(0, 3.5, z),
			Color3.fromRGB(120, 80, 40), Enum.Material.Wood).CanCollide = false
		for i = 0, 6 do
			P(folder, "BridgePost", Vector3.new(0.6, 3, 0.6), centre + Vector3.new(-30 + i * 10, 2, z),
				Color3.fromRGB(120, 80, 40), Enum.Material.Wood).CanCollide = false
		end
	end
	return sweeper
end

-- ---------------------------------------------------------------------------
-- Scenery: trees, bushes, clouds, arches
-- ---------------------------------------------------------------------------

local function buildScenery(folder)
	-- Fourteen trees around the rim, keeping the conveyor sightline
	-- (|x| < 40) and the spawn plaza clear.
	local treeSpots = {
		{ -180, -60 }, { -180, 60 }, { -170, 140 }, { -120, 185 },
		{ 120, 185 }, { 170, 140 }, { 180, 60 }, { 180, -60 },
		{ 170, -140 }, { 120, -185 }, { 60, -190 }, { -60, -190 },
		{ -120, -185 }, { -170, -140 },
	}
	for _, spot in ipairs(treeSpots) do
		local x, z = spot[1], spot[2]
		cyl(folder, "TreeTrunk", 2, 10, Vector3.new(x, 5, z),
			Color3.fromRGB(140, 90, 50), Enum.Material.Wood, "Y")
		ball(folder, "TreeCanopy", 9, Vector3.new(x, 13, z),
			Color3.fromRGB(60, 180, 70), Enum.Material.SmoothPlastic)
		ball(folder, "TreeCanopy2", 6, Vector3.new(x + 3, 17, z + 2),
			Color3.fromRGB(80, 200, 90), Enum.Material.SmoothPlastic)
		ball(folder, "TreeCanopy3", 5, Vector3.new(x - 3, 16, z - 2),
			Color3.fromRGB(50, 160, 60), Enum.Material.SmoothPlastic)
	end

	-- Ten bushes near the ring.
	local bushSpots = {
		{ -100, 40 }, { -40, 100 }, { 40, 100 }, { 100, 40 },
		{ 100, -40 }, { 40, -100 }, { -40, -100 }, { -100, -40 },
		{ -70, 70 }, { 70, 70 },
	}
	for _, spot in ipairs(bushSpots) do
		ball(folder, "Bush", 5, Vector3.new(spot[1], 2, spot[2]),
			Color3.fromRGB(70, 190, 80), Enum.Material.SmoothPlastic)
	end

	-- Six cloud clusters floating high up.
	local cloudSpots = {
		{ -120, -80, 90 }, { 0, -120, 100 }, { 130, -60, 85 },
		{ -140, 80, 95 }, { 110, 110, 90 }, { 40, 140, 100 },
	}
	for _, spot in ipairs(cloudSpots) do
		local cx, cz, cy = spot[1], spot[2], spot[3]
		for _, puff in ipairs({ { 0, 0, 0, 10 }, { 7, 1, 2, 7 }, { -7, 0, -2, 8 }, { 3, 3, -3, 6 } }) do
			local cloud = ball(folder, "Cloud", puff[4],
				Vector3.new(cx + puff[1], cy + puff[2], cz + puff[3]),
				Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
			cloud.Transparency = 0.3
			cloud.CanCollide = false
		end
	end

	-- Tall pink arch over the conveyor's north end, sign facing spawn.
	local archZ = -150
	for _, x in ipairs({ -14, 14 }) do
		P(folder, "NorthArchPost", Vector3.new(3, 24, 3), Vector3.new(x, 12, archZ),
			Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
	end
	P(folder, "NorthArchBeam", Vector3.new(31, 3, 3), Vector3.new(0, 25, archZ),
		Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
	local signPos = Vector3.new(0, 20, archZ + 2)
	local sign = PF(folder, "ArchSign", Vector3.new(24, 6, 1), signPos, Vector3.new(0, 20, 200),
		Color3.fromRGB(40, 40, 55), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ArchSignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BRAINROT BAZAAR"
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	-- Smaller gold arch over the conveyor's south end.
	for _, x in ipairs({ -14, 14 }) do
		P(folder, "SouthArchPost", Vector3.new(3, 16, 3), Vector3.new(x, 8, 150),
			Color3.fromRGB(255, 200, 60), Enum.Material.SmoothPlastic)
	end
	P(folder, "SouthArchBeam", Vector3.new(31, 3, 3), Vector3.new(0, 17, 150),
		Color3.fromRGB(255, 200, 60), Enum.Material.SmoothPlastic)
end

-- ---------------------------------------------------------------------------
-- Spawn
-- ---------------------------------------------------------------------------

local function buildSpawn(folder)
	local pad = Instance.new("SpawnLocation")
	pad.Name = "SpawnLocation"
	pad.Size = Vector3.new(40, 1, 12)
	pad.Position = Vector3.new(0, 1, 205)
	pad.Color = Color3.fromRGB(255, 220, 100)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Anchored = true
	pad.Neutral = true
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = folder
	-- Gold neon trim around the spawn pad.
	neonStrip(folder, "SpawnTrimN", Vector3.new(40, 0.4, 1), Vector3.new(0, 1.6, 199.5), Color3.fromRGB(255, 200, 60))
	neonStrip(folder, "SpawnTrimS", Vector3.new(40, 0.4, 1), Vector3.new(0, 1.6, 210.5), Color3.fromRGB(255, 200, 60))
	return Vector3.new(0, 4, 205)
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

function World.buildWorld()
	setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = workspace

	buildGround(folder)
	buildConveyor(folder)
	buildStatue(folder)

	local bases = {}
	for i = 1, BASE_COUNT do
		bases[i] = buildBase(folder, i)
	end
	buildRing(folder, bases)

	local sweeper = buildPit(folder)
	buildScenery(folder)
	local spawnPosition = buildSpawn(folder)

	return {
		folder = folder,
		bases = bases,
		sweeper = sweeper,
		spawnPosition = spawnPosition,
		conveyorStart = Vector3.new(0, 2, 150),
		conveyorEnd = Vector3.new(0, 2, -150),
		pitCentre = Vector3.new(-150, 2, -150),
	}
end

return World
