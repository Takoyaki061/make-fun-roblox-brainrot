-- World.luau — builds the whole 3D world out of parts, in code.
-- One module, one job: spawn plaza, central conveyor machine, 8 player
-- shop-bases on a ring, the Grinder Pit hazard, a thief ring-walkway
-- linking the base gates, a golden statue landmark, and the decorations
-- that make the map read as a place. Returns the built pieces the server
-- loop needs (bases, conveyor path, sweeper bar, spawn).
-- House rules: no bare boxes — plinth + body + cap everywhere, 3-value
-- material rule per zone, neon edge strips, baked shadow slabs under
-- overhangs, and a proper Lighting setup for a bright cartoon look.

local Lighting = game:GetService("Lighting")

local World = {}

local BASE_COUNT = 8
local BASE_RADIUS = 130
local BASE_SIZE = 44
local CONVEYOR_LENGTH = 300
local CONVEYOR_WIDTH = 24

local function newPart(name, size, color, material, parent, position, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	if position then
		part.Position = position
	end
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		part.Shape = Enum.PartType.Wedge
	end
	part.Parent = parent
	return part
end

-- A thin dark slab tucked under an overhang: fake ambient occlusion, the
-- cheapest way to make a build look finished instead of flat.
local function shadowSlab(name, size, parent, position)
	local slab = newPart(name, size, Color3.fromRGB(35, 30, 35), Enum.Material.SmoothPlastic,
		parent, position)
	slab.Transparency = 0.45
	slab.CanCollide = false
	return slab
end

-- Bright cartoon lighting: warm sun, soft sky haze, a little bloom on the
-- neon and a saturation lift. Runs at server start; the loader sets the
-- same values in Edit mode so the place looks right there too.
local function buildLighting()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(130, 130, 145)
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 172, 190)
	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.15
	-- NOTE: Lighting.Technology is NOT set here: it cannot be written by a
	-- script (the Assistant sandbox and the server both refuse it). New
	-- places already default to Future; if this place ever shows flat
	-- lighting, flip it in Studio: Lighting properties > Technology > Future.

	local atmo = Lighting:FindFirstChild("BazaarAtmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Name = "BazaarAtmosphere"
		atmo.Parent = Lighting
	end
	atmo.Density = 0.3
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(199, 216, 255)
	atmo.Decay = Color3.fromRGB(106, 145, 190)
	atmo.Glare = 0

	local bloom = Lighting:FindFirstChild("BazaarBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "BazaarBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 1.2
	bloom.Size = 24
	bloom.Threshold = 0.9

	local cc = Lighting:FindFirstChild("BazaarColor")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BazaarColor"
		cc.Parent = Lighting
	end
	cc.Brightness = 0.05
	cc.Contrast = 0.15
	cc.Saturation = 0.35
	cc.TintColor = Color3.fromRGB(255, 250, 240)
end

-- Ground: layered grass, a tiled spawn plaza, spoke paths from the plaza
-- to every base gate, and planters with flowers along the plaza edge.
local function buildGround(folder)
	local ground = newPart("MapGround", Vector3.new(420, 2, 420),
		Color3.fromRGB(90, 160, 90), Enum.Material.Grass, folder, Vector3.new(0, 0, 0))
	ground.TopSurface = Enum.SurfaceType.Smooth

	-- Plaza: a warm slab with a checker of tiles, so spawn reads as a place.
	newPart("SpawnPlaza", Vector3.new(120, 2.4, 70),
		Color3.fromRGB(230, 200, 140), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 0.2, 195))
	for row = 0, 2 do
		for col = 0, 5 do
			if (row + col) % 2 == 0 then
				newPart("PlazaTile", Vector3.new(18, 0.3, 20),
					Color3.fromRGB(245, 220, 165), Enum.Material.SmoothPlastic,
					folder, Vector3.new(-50 + col * 20, 1.5, 168 + row * 22))
			end
		end
	end
	-- Plaza edge trim: a darker border strip around the slab.
	newPart("PlazaTrim", Vector3.new(124, 0.4, 4),
		Color3.fromRGB(180, 140, 80), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 1.5, 161))
	newPart("PlazaTrim", Vector3.new(124, 0.4, 4),
		Color3.fromRGB(180, 140, 80), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 1.5, 229))

	-- Spoke paths from the plaza to the ring walkway (north side only;
	-- the other bases are reached along the ring).
	for _, x in ipairs({ -40, 40 }) do
		newPart("SpokePath", Vector3.new(10, 0.4, 46),
			Color3.fromRGB(210, 190, 150), Enum.Material.SmoothPlastic,
			folder, Vector3.new(x, 1.2, 138))
	end

	-- Flower planters along the plaza's north edge.
	for i = 1, 6 do
		local x = -50 + (i - 1) * 20
		newPart("Planter", Vector3.new(6, 2, 6),
			Color3.fromRGB(120, 80, 50), Enum.Material.Wood,
			folder, Vector3.new(x, 2, 164))
		local flowerColor = Color3.fromHSV((i * 0.16) % 1, 0.7, 0.95)
		local flower = newPart("Flower", Vector3.new(1.6, 1.6, 1.6), flowerColor,
			Enum.Material.SmoothPlastic, folder, Vector3.new(x, 3.6, 164), "Ball")
		flower.CanCollide = false
	end
end

-- The central conveyor as a real machine: a dark deck on A-frame legs,
-- rollers down the belt, side frames with neon edge strips and bolt nubs,
-- a gearbox housing, a red stop-lamp at the discharge end, and the golden
-- statue beside the middle. Belt top stays at y=2, so walkers stand on it.
local function buildConveyor(folder)
	-- Deck + legs.
	newPart("ConveyorDeck", Vector3.new(CONVEYOR_WIDTH + 4, 1, CONVEYOR_LENGTH),
		Color3.fromRGB(50, 50, 60), Enum.Material.Metal,
		folder, Vector3.new(0, 0.5, 0))
	for z = -120, 120, 60 do
		for _, side in ipairs({ -1, 1 }) do
			local leg = newPart("ConveyorLeg", Vector3.new(1, 2, 1),
				Color3.fromRGB(70, 70, 80), Enum.Material.Metal,
				folder, Vector3.new(side * 11, 0, z))
			leg.CanCollide = false
			newPart("ConveyorFoot", Vector3.new(3, 0.4, 3),
				Color3.fromRGB(90, 90, 100), Enum.Material.Concrete,
				folder, Vector3.new(side * 11, 0.2, z))
		end
	end

	-- The belt itself.
	local belt = newPart("ConveyorBelt", Vector3.new(CONVEYOR_WIDTH, 2, CONVEYOR_LENGTH),
		Color3.fromRGB(60, 60, 70), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 1, 0))
	belt.TopSurface = Enum.SurfaceType.Smooth

	-- Rollers across the belt: cylinder axis is X by default, so a roller
	-- spanning the belt width needs no rotation. Tops sit flush with the
	-- belt top (y=2) so walkers glide over them.
	for z = -142, 142, 16 do
		local shade = (math.floor(z / 16) % 2 == 0)
			and Color3.fromRGB(140, 140, 150) or Color3.fromRGB(90, 90, 100)
		local roller = newPart("ConveyorRoller", Vector3.new(22, 0.6, 0.6), shade,
			Enum.Material.Metal, folder, Vector3.new(0, 1.7, z), "Cylinder")
		roller.CanCollide = false
	end

	-- Side frames with neon edge strips and bolt nubs.
	for _, side in ipairs({ -1, 1 }) do
		newPart("ConveyorRail", Vector3.new(1.5, 3, CONVEYOR_LENGTH),
			Color3.fromRGB(45, 45, 55), Enum.Material.Metal,
			folder, Vector3.new(side * (CONVEYOR_WIDTH / 2 + 1), 2.5, 0))
		local strip = newPart("ConveyorNeon", Vector3.new(0.5, 0.5, CONVEYOR_LENGTH),
			Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
			folder, Vector3.new(side * (CONVEYOR_WIDTH / 2 + 1), 4.2, 0))
		strip.CanCollide = false
		for z = -135, 135, 30 do
			local bolt = newPart("RailBolt", Vector3.new(0.6, 0.6, 0.6),
				Color3.fromRGB(200, 200, 210), Enum.Material.SmoothPlastic,
				folder, Vector3.new(side * (CONVEYOR_WIDTH / 2 + 1.8), 2.5, z), "Ball")
			bolt.CanCollide = false
		end
	end

	-- Chevron markers down the middle of the belt.
	for z = -135, 135, 30 do
		local chevron = newPart("Chevron", Vector3.new(10, 0.4, 6),
			Color3.fromRGB(255, 220, 80), Enum.Material.Neon,
			folder, Vector3.new(0, 2.1, z))
		chevron.CanCollide = false
	end

	-- Gearbox housing + cable tray on the east side, near spawn.
	newPart("Gearbox", Vector3.new(4, 5, 6),
		Color3.fromRGB(80, 80, 90), Enum.Material.Metal,
		folder, Vector3.new(15, 2.5, 120))
	newPart("CableTray", Vector3.new(1, 0.6, 60),
		Color3.fromRGB(60, 60, 70), Enum.Material.Metal,
		folder, Vector3.new(14.5, 1.2, 90))

	-- Red stop-lamp at the discharge (north) end.
	local lamp = newPart("StopLamp", Vector3.new(3, 3, 3),
		Color3.fromRGB(255, 40, 40), Enum.Material.Neon,
		folder, Vector3.new(0, 4, -152))
	lamp.CanCollide = false
	newPart("StopLampPost", Vector3.new(1, 3, 1),
		Color3.fromRGB(50, 50, 60), Enum.Material.Metal,
		folder, Vector3.new(0, 1.5, -152))

	return belt
end

-- The golden statue: a tiered pedestal with neon risers and an oversized
-- golden brainrot head-and-shoulders, halo ring and uplights. It stands
-- beside the conveyor mid, visible from spawn, clear of the belt.
local function buildStatue(folder)
	local px, pz = 36, 0
	local tiers = {
		{ 24, 1, 24, 0.5 }, { 18, 1, 18, 1.5 }, { 12, 1, 12, 2.5 }, { 8, 2, 8, 4 },
	}
	for _, t in ipairs(tiers) do
		newPart("StatueTier", Vector3.new(t[1], t[2], t[3]),
			Color3.fromRGB(120, 120, 130), Enum.Material.Slate,
			folder, Vector3.new(px, t[4], pz))
		local riser = newPart("StatueRiser", Vector3.new(t[1] + 0.4, 0.3, t[3] + 0.4),
			Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
			folder, Vector3.new(px, t[4] - t[2] / 2 + 0.15, pz))
		riser.CanCollide = false
	end
	-- Shoulders, head, eyes, smile, halo — all gold metallic.
	local shoulders = newPart("StatueBody", Vector3.new(9, 4, 6),
		Color3.fromRGB(255, 200, 40), Enum.Material.Metal,
		folder, Vector3.new(px, 7, pz))
	shoulders.CanCollide = false
	local head = newPart("StatueHead", Vector3.new(7, 7, 7),
		Color3.fromRGB(255, 210, 60), Enum.Material.Metal,
		folder, Vector3.new(px, 12, pz), "Ball")
	head.CanCollide = false
	for _, side in ipairs({ -1.8, 1.8 }) do
		local eye = newPart("StatueEye", Vector3.new(1.4, 1.6, 0.6),
			Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic,
			folder, Vector3.new(px + side, 13, pz + 3.4), "Ball")
		eye.CanCollide = false
		local pupil = newPart("StatuePupil", Vector3.new(0.6, 0.8, 0.3),
			Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic,
			folder, Vector3.new(px + side, 13, pz + 3.7), "Ball")
		pupil.CanCollide = false
	end
	local smile = newPart("StatueSmile", Vector3.new(3, 0.6, 0.4),
		Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic,
		folder, Vector3.new(px, 10.2, pz + 3.4))
	smile.CanCollide = false
	local halo = newPart("StatueHalo", Vector3.new(0.4, 6, 6),
		Color3.fromRGB(255, 220, 80), Enum.Material.Neon,
		folder, Vector3.new(px, 17, pz), "Cylinder")
	halo.CanCollide = false
	halo.CFrame = CFrame.new(px, 17, pz) * CFrame.Angles(0, 0, math.rad(90))
	for _, side in ipairs({ -1, 1 }) do
		local light = newPart("StatueUplight", Vector3.new(1.5, 0.6, 1.5),
			Color3.fromRGB(255, 220, 80), Enum.Material.Neon,
			folder, Vector3.new(px + side * 8, 1.3, pz + 8))
		light.CanCollide = false
	end
end

-- One player base, now a little shop: a slab with a curb and a 2-step
-- stoop, back + side walls with a door cutout facing the centre, a flat
-- roof with a parapet and wedge corners, a striped awning over the door,
-- a sign board above the awning, a flag pole on the roof, and 6 display
-- slots with trim plates where bought brainrots stand and earn.
-- Bases face the map centre. Slot positions are unchanged in layout so
-- the server's buy/steal math keeps working.
local function buildBase(folder, index, angleDeg)
	local angle = math.rad(angleDeg)
	local cx = math.cos(angle) * BASE_RADIUS
	local cz = math.sin(angle) * BASE_RADIUS
	local base = Instance.new("Model")
	base.Name = "Base" .. tostring(index)

	local hue = (index - 1) / BASE_COUNT
	local padColor = Color3.fromHSV(hue, 0.55, 0.85)
	local darkColor = Color3.fromHSV(hue, 0.6, 0.55)
	local trimColor = Color3.fromHSV(hue, 0.4, 0.95)

	-- Slab + curb + stoop. The pad is the play surface (top y=2).
	newPart("Slab", Vector3.new(BASE_SIZE + 4, 1, BASE_SIZE + 4),
		darkColor, Enum.Material.Concrete, base, Vector3.new(cx, 0.5, cz))
	local pad = newPart("Pad", Vector3.new(BASE_SIZE, 2, BASE_SIZE),
		padColor, Enum.Material.SmoothPlastic, base, Vector3.new(cx, 1, cz))
	pad.TopSurface = Enum.SurfaceType.Smooth
	-- Stoop: two steps down toward the centre, at the door. The 12-length
	-- runs tangentially (rotation -angle + 90deg puts X on the tangent).
	local stepDirX, stepDirZ = -math.cos(angle), -math.sin(angle)
	for i, s in ipairs({ 1, 2 }) do
		local stoop = newPart("Stoop", Vector3.new(12, 0.6, 4),
			Color3.fromRGB(210, 190, 150), Enum.Material.Concrete,
			base, Vector3.new(
				cx + stepDirX * (BASE_SIZE / 2 + 2 + s * 2),
				1.4 - s * 0.5,
				cz + stepDirZ * (BASE_SIZE / 2 + 2 + s * 2)))
		stoop.CFrame = CFrame.new(
			cx + stepDirX * (BASE_SIZE / 2 + 2 + s * 2),
			1.4 - s * 0.5,
			cz + stepDirZ * (BASE_SIZE / 2 + 2 + s * 2))
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
	end

	-- Back wall (far side from the centre) and two side walls. Front stays
	-- open as the door, flanked by short wall stubs.
	-- Rotation math: R_y(-angle) maps the Z axis onto the tangent, so a
	-- wall whose length runs along Z is tangent with rotation -angle and
	-- radial with rotation -angle + 90deg.
	local wallX = cx + math.cos(angle) * (BASE_SIZE / 2 + 0.5)
	local wallZ = cz + math.sin(angle) * (BASE_SIZE / 2 + 0.5)
	local back = newPart("BackWall", Vector3.new(1.5, 10, BASE_SIZE),
		padColor, Enum.Material.SmoothPlastic, base, Vector3.new(wallX, 6, wallZ))
	back.CFrame = CFrame.new(wallX, 6, wallZ) * CFrame.Angles(0, -angle, 0)
	for _, side in ipairs({ -1, 1 }) do
		local sx = cx - math.sin(angle) * side * (BASE_SIZE / 2 - 0.75)
		local sz = cz + math.cos(angle) * side * (BASE_SIZE / 2 - 0.75)
		local wall = newPart("SideWall", Vector3.new(1.5, 10, BASE_SIZE - 8),
			trimColor, Enum.Material.SmoothPlastic, base, Vector3.new(sx, 6, sz))
		wall.CFrame = CFrame.new(sx, 6, sz) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		-- Door-side stubs: short wall segments flanking a 12-wide door.
		local fx = cx - math.cos(angle) * (BASE_SIZE / 2 - 0.75) - math.sin(angle) * side * 14
		local fz = cz - math.sin(angle) * (BASE_SIZE / 2 - 0.75) + math.cos(angle) * side * 14
		local stub = newPart("DoorStub", Vector3.new(1.5, 8, 16),
			padColor, Enum.Material.SmoothPlastic, base, Vector3.new(fx, 5, fz))
		stub.CFrame = CFrame.new(fx, 5, fz) * CFrame.Angles(0, -angle, 0)
	end

	-- Roof: flat slab + parapet rim + wedge corners + neon fascia strip.
	local roof = newPart("Roof", Vector3.new(BASE_SIZE + 2, 1, BASE_SIZE + 2),
		darkColor, Enum.Material.SmoothPlastic, base, Vector3.new(cx, 11, cz))
	roof.TopSurface = Enum.SurfaceType.Smooth
	-- Parapet rim: one slab per side, no duplicates.
	for _, sz in ipairs({ -1, 1 }) do
		newPart("Parapet", Vector3.new(BASE_SIZE + 2, 1.5, 1.5),
			trimColor, Enum.Material.SmoothPlastic,
			base, Vector3.new(cx, 12.2, cz + sz * (BASE_SIZE / 2 + 0.25)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		newPart("Parapet", Vector3.new(1.5, 1.5, BASE_SIZE + 2),
			trimColor, Enum.Material.SmoothPlastic,
			base, Vector3.new(cx + sx * (BASE_SIZE / 2 + 0.25), 12.2, cz))
	end
	local fascia = newPart("RoofFascia", Vector3.new(BASE_SIZE + 2.4, 0.5, BASE_SIZE + 2.4),
		trimColor, Enum.Material.Neon, base, Vector3.new(cx, 10.4, cz))
	fascia.CanCollide = false
	shadowSlab("RoofShadow", Vector3.new(BASE_SIZE, 0.2, BASE_SIZE), base, Vector3.new(cx, 10.4, cz))
	-- Wedge corners on the roof, angled inward like a little pavilion.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local wedge = newPart("RoofWedge", Vector3.new(10, 3, 10),
				trimColor, Enum.Material.SmoothPlastic,
				base, Vector3.new(cx + sx * 14, 13, cz + sz * 14), "Wedge")
			wedge.CanCollide = false
			wedge.CFrame = CFrame.new(cx + sx * 14, 13, cz + sz * 14)
				* CFrame.Angles(0, math.rad(45 * sx * sz), 0)
		end
	end

	-- Striped awning over the door, on two thin posts.
	local awnX = cx - math.cos(angle) * (BASE_SIZE / 2 + 2)
	local awnZ = cz - math.sin(angle) * (BASE_SIZE / 2 + 2)
	for i = 1, 3 do
		local stripeColor = (i % 2 == 1) and trimColor or Color3.fromRGB(255, 255, 255)
		local stripe = newPart("Awning", Vector3.new(4, 0.3, 12),
			stripeColor, Enum.Material.SmoothPlastic,
			base, Vector3.new(awnX - math.sin(angle) * (i - 2) * 4, 7.6, awnZ + math.cos(angle) * (i - 2) * 4))
		stripe.CFrame = CFrame.new(
			awnX - math.sin(angle) * (i - 2) * 4, 7.6, awnZ + math.cos(angle) * (i - 2) * 4)
			* CFrame.Angles(0, -angle, math.rad(15))
	end
	for _, side in ipairs({ -1, 1 }) do
		local post = newPart("AwningPost", Vector3.new(0.5, 6.5, 0.5),
			Color3.fromRGB(40, 40, 40), Enum.Material.Metal,
			base, Vector3.new(
				awnX - math.cos(angle) * 2 - math.sin(angle) * side * 5.5,
				4.2,
				awnZ - math.sin(angle) * 2 + math.cos(angle) * side * 5.5))
		post.CanCollide = false
	end

	-- Flag pole on the roof, at the back corner, with the base colour flag.
	local flagX = cx + math.cos(angle) * (BASE_SIZE / 2 - 3)
	local flagZ = cz + math.sin(angle) * (BASE_SIZE / 2 - 3)
	local pole = newPart("BannerPost", Vector3.new(1, 12, 1),
		Color3.fromRGB(40, 40, 40), Enum.Material.Metal,
		base, Vector3.new(flagX, 17, flagZ))
	pole.CanCollide = false
	local flag = newPart("BannerFlag", Vector3.new(9, 5, 0.5),
		padColor, Enum.Material.Neon, base,
		Vector3.new(flagX - math.cos(angle) * 5, 20, flagZ - math.sin(angle) * 5))
	flag.CFrame = CFrame.new(flagX - math.cos(angle) * 5, 20, flagZ - math.sin(angle) * 5)
		* CFrame.Angles(0, -angle - math.pi / 2, 0)
	flag.CanCollide = false

	-- Six display slots in two rows of three, facing the centre. Each gets
	-- a dark trim plate under the glowing pad.
	local slots = {}
	for row = 0, 1 do
		for col = -1, 1 do
			local along = col * 12
			local across = -8 + row * 16
			local sx = cx + math.cos(angle) * across - math.sin(angle) * along
			local sz = cz + math.sin(angle) * across + math.cos(angle) * along
			local trim = newPart("SlotTrim", Vector3.new(9, 0.4, 9),
				Color3.fromRGB(35, 35, 45), Enum.Material.SmoothPlastic,
				base, Vector3.new(sx, 2.1, sz))
			trim.CanCollide = false
			local slot = newPart("Slot" .. tostring(#slots + 1), Vector3.new(8, 0.6, 8),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon,
				base, Vector3.new(sx, 2.3, sz))
			slot.CanCollide = false
			slot.Transparency = 0.5
			table.insert(slots, Vector3.new(sx, 2.6, sz))
		end
	end

	-- Owner sign board on the front fascia, under the roof edge. Its Front
	-- face must look toward the map centre, or nobody approaching the base
	-- can read it.
	local boardX = cx - math.cos(angle) * (BASE_SIZE / 2 + 0.5)
	local boardZ = cz - math.sin(angle) * (BASE_SIZE / 2 + 0.5)
	local board = newPart("OwnerBoard", Vector3.new(20, 4, 1),
		Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic,
		base, Vector3.new(boardX, 9, boardZ))
	board.CFrame = CFrame.new(boardX, 9, boardZ)
		* CFrame.Angles(0, -angle - math.pi / 2, 0)
	-- Neon border frame around the sign.
	local border = newPart("SignBorder", Vector3.new(20.6, 4.6, 0.4),
		trimColor, Enum.Material.Neon, base, Vector3.new(boardX, 9, boardZ))
	border.CFrame = CFrame.new(boardX, 9, boardZ)
		* CFrame.Angles(0, -angle - math.pi / 2, 0)
	border.CanCollide = false
	-- The border is bigger than the board, so it reads as a frame only if
	-- it sits behind it; pull it 0.3 studs back from the board face.
	border.CFrame = board.CFrame * CFrame.new(0, 0, 0.35)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerGui"
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BASE " .. tostring(index)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	base.Parent = folder
	return {
		model = base,
		center = Vector3.new(cx, 2, cz),
		slots = slots,
		ownerLabel = label,
		pad = pad,
	}
end

-- The thief ring: a pale walkway octagon linking every base gate, with a
-- neon edge strip and a lamp at each segment, so a thief has one obvious
-- route between bases and a victim can see them coming.
local function buildWalkway(folder)
	local ringRadius = 100
	local chord = 2 * ringRadius * math.sin(math.rad(45 / 2))
	for i = 1, BASE_COUNT do
		local midDeg = 45 + (i - 1) * 45
		local mid = math.rad(midDeg)
		local x = math.cos(mid) * ringRadius
		local z = math.sin(mid) * ringRadius
		local segment = newPart("ThiefRing", Vector3.new(12, 1, chord),
			Color3.fromRGB(220, 200, 160), Enum.Material.SmoothPlastic,
			folder, Vector3.new(x, 1.1, z))
		segment.CFrame = CFrame.new(x, 1.1, z) * CFrame.Angles(0, -mid, 0)
		segment.TopSurface = Enum.SurfaceType.Smooth
		-- Neon edge strip on the outer edge of the segment.
		local strip = newPart("RingNeon", Vector3.new(0.4, 0.3, chord),
			Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
			folder, Vector3.new(x, 1.7, z))
		strip.CFrame = CFrame.new(
			math.cos(mid) * (ringRadius + 6), 1.7, math.sin(mid) * (ringRadius + 6))
			* CFrame.Angles(0, -mid, 0)
		strip.CanCollide = false
		-- Lamp post at the segment midpoint, on the outer edge.
		local lx = math.cos(mid) * (ringRadius + 9)
		local lz = math.sin(mid) * (ringRadius + 9)
		local post = newPart("LampPost", Vector3.new(0.5, 9, 0.5),
			Color3.fromRGB(40, 40, 40), Enum.Material.Metal,
			folder, Vector3.new(lx, 5.5, lz))
		post.CanCollide = false
		local lampHead = newPart("LampHead", Vector3.new(2, 2, 2),
			Color3.fromRGB(255, 240, 180), Enum.Material.Neon,
			folder, Vector3.new(lx, 10.5, lz), "Ball")
		lampHead.CanCollide = false
	end
end

-- The Grinder Pit: a sunken lava zone in the north-west with a spinning
-- sweeper bar that knocks careless players back to spawn. Rock ring and
-- warning chevrons around the edge, and a railed bridge across it.
local function buildHazard(folder)
	local pit = newPart("GrinderPit", Vector3.new(70, 2, 70),
		Color3.fromRGB(200, 60, 40), Enum.Material.Neon,
		folder, Vector3.new(-150, 0.5, -150))
	pit.TopSurface = Enum.SurfaceType.Smooth
	-- Dark rock ring around the pit edge.
	for i = 1, 8 do
		local a = math.rad(i * 45)
		local rock = newPart("PitRock", Vector3.new(8, 6, 8),
			Color3.fromRGB(70, 70, 80), Enum.Material.Slate,
			folder, Vector3.new(-150 + math.cos(a) * 38, 2, -150 + math.sin(a) * 38), "Ball")
		rock.CanCollide = false
	end
	-- Warning chevrons: alternating yellow/dark strips on the pit rim.
	for i = 1, 12 do
		local a = math.rad(i * 30)
		local c = (i % 2 == 1) and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(30, 30, 30)
		local chev = newPart("PitWarning", Vector3.new(6, 0.4, 2), c, Enum.Material.SmoothPlastic,
			folder, Vector3.new(-150 + math.cos(a) * 34, 1.6, -150 + math.sin(a) * 34))
		chev.CFrame = CFrame.new(-150 + math.cos(a) * 34, 1.6, -150 + math.sin(a) * 34)
			* CFrame.Angles(0, -a, 0)
		chev.CanCollide = false
	end
	local hub = newPart("SweeperHub", Vector3.new(6, 8, 6),
		Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic,
		folder, Vector3.new(-150, 4, -150))
	hub.CanCollide = false
	local bar = newPart("SweeperBar", Vector3.new(60, 3, 4),
		Color3.fromRGB(255, 220, 40), Enum.Material.Neon,
		folder, Vector3.new(-150, 4, -150))
	bar.CanCollide = false
	-- A bridge across the pit, with rails, for players brave enough.
	newPart("PitBridge", Vector3.new(10, 1, 70),
		Color3.fromRGB(180, 140, 90), Enum.Material.WoodPlanks,
		folder, Vector3.new(-150, 2.5, -150))
	for _, side in ipairs({ -1, 1 }) do
		newPart("BridgeRail", Vector3.new(0.6, 2, 70),
			Color3.fromRGB(120, 90, 50), Enum.Material.Wood,
			folder, Vector3.new(-150 + side * 5, 3.5, -150))
	end
	return bar
end

-- Scenery: layered-canopy trees, bushes, and drifting-look cloud clusters.
local function buildScenery(folder)
	for i = 1, 14 do
		local angle = math.rad(i * 25.7)
		local r = 185 + (i % 3) * 12
		local x = math.cos(angle) * r
		local z = math.sin(angle) * r
		if math.abs(x) < 30 and math.abs(z) < 190 then
			continue -- keep the conveyor sightline clear
		end
		local trunk = newPart("TreeTrunk", Vector3.new(3, 10, 3),
			Color3.fromRGB(120, 80, 40), Enum.Material.Wood,
			folder, Vector3.new(x, 5, z))
		trunk.CanCollide = false
		local top = newPart("TreeTop", Vector3.new(11, 9, 11),
			Color3.fromRGB(40, 140, 60), Enum.Material.SmoothPlastic,
			folder, Vector3.new(x, 14, z), "Ball")
		top.CanCollide = false
		local top2 = newPart("TreeTop2", Vector3.new(7, 6, 7),
			Color3.fromRGB(60, 170, 80), Enum.Material.SmoothPlastic,
			folder, Vector3.new(x + 3, 18, z + 2), "Ball")
		top2.CanCollide = false
	end
	-- Bushes near the ring path.
	for i = 1, 10 do
		local a = math.rad(i * 36 + 18)
		local bush = newPart("Bush", Vector3.new(4, 3, 4),
			Color3.fromRGB(50, 150, 70), Enum.Material.SmoothPlastic,
			folder, Vector3.new(math.cos(a) * 88, 2, math.sin(a) * 88), "Ball")
		bush.CanCollide = false
	end
	-- Clouds: clusters of white spheres floating high up.
	for i = 1, 6 do
		local a = math.rad(i * 60 + 15)
		local cx = math.cos(a) * 160
		local cz = math.sin(a) * 160
		local cy = 65 + (i % 3) * 12
		for j, off in ipairs({ { 0, 0, 0 }, { 8, 2, 3 }, { -8, 1, -2 }, { 3, 4, -5 }, { -4, 3, 5 } }) do
			local cloud = newPart("Cloud", Vector3.new(12, 7, 10),
				Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic,
				folder, Vector3.new(cx + off[1], cy + off[2], cz + off[3]), "Ball")
			cloud.CanCollide = false
			cloud.Transparency = 0.15
		end
	end
	-- North arch over the conveyor's far end: the brainrots' exit, with a
	-- big BRAINROT BAZAAR sign facing spawn (+Z is the Back face here).
	for _, side in ipairs({ -1, 1 }) do
		newPart("ArchPillar", Vector3.new(4, 26, 4),
			Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic,
			folder, Vector3.new(side * 16, 13, -155))
		local cap = newPart("ArchCap", Vector3.new(6, 2, 6),
			Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
			folder, Vector3.new(side * 16, 27, -155))
		cap.CanCollide = false
	end
	local beam = newPart("ArchBeam", Vector3.new(36, 4, 4),
		Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 27, -155))
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "ArchSign"
	signGui.Face = Enum.NormalId.Back
	signGui.Parent = beam
	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "ArchText"
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "BRAINROT BAZAAR"
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui
	-- South arch over the spawn end, smaller, framing the view down the belt.
	for _, side in ipairs({ -1, 1 }) do
		newPart("SouthArchPillar", Vector3.new(3, 18, 3),
			Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic,
			folder, Vector3.new(side * 16, 9, 152))
	end
	newPart("SouthArchBeam", Vector3.new(35, 3, 3),
		Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 19, 152))
end

-- Build everything. Returns a table the server uses to run the game.
function World.buildWorld()
	buildLighting()

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = workspace

	buildGround(folder)
	buildConveyor(folder)
	buildStatue(folder)
	buildWalkway(folder)
	local sweeperBar = buildHazard(folder)
	buildScenery(folder)

	-- Spawn point on the plaza, facing the conveyor.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BrainrotSpawn"
	spawn.Size = Vector3.new(40, 2, 12)
	spawn.Color = Color3.fromRGB(255, 220, 80)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Position = Vector3.new(0, 1, 205)
	spawn.Neutral = true
	spawn.Parent = folder

	-- 8 bases on a ring turned 22.5 degrees, so none sits on the conveyor.
	local bases = {}
	for i = 1, BASE_COUNT do
		local angleDeg = 22.5 + (i - 1) * 45
		bases[i] = buildBase(folder, i, angleDeg)
	end

	return {
		folder = folder,
		bases = bases,
		sweeperBar = sweeperBar,
		spawnPosition = Vector3.new(0, 4, 205),
		conveyorStart = Vector3.new(0, 2, 150),
		conveyorEnd = Vector3.new(0, 2, -150),
		pitCenter = Vector3.new(-150, 4, -150),
	}
end

return World
