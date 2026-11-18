-- World.luau — builds the whole 3D world out of parts, in code.
-- One module, one job: spawn plaza, central conveyor, 8 player bases on a
-- ring, the Grinder Pit hazard, a thief ring-walkway linking the base gates,
-- and the decorations that make the map read as a place. Returns the built
-- pieces the server loop needs (bases, conveyor path, sweeper bar, spawn).

local World = {}

local BASE_COUNT = 8
local BASE_RADIUS = 130
local BASE_SIZE = 44
local CONVEYOR_LENGTH = 300
local CONVEYOR_WIDTH = 24

local function newPart(name, size, color, material, parent, position)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Position = position
	part.Parent = parent
	return part
end

-- A flat coloured tile floor so the grey baseplate reads as a game map.
local function buildGround(folder)
	local ground = newPart("MapGround", Vector3.new(420, 2, 420),
		Color3.fromRGB(90, 160, 90), Enum.Material.Grass, folder, Vector3.new(0, 0, 0))
	ground.TopSurface = Enum.SurfaceType.Smooth
	-- A plaza of warm tiles around the spawn, for contrast.
	newPart("SpawnPlaza", Vector3.new(120, 2.4, 70),
		Color3.fromRGB(230, 200, 140), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 0.2, 195))
end

-- The central conveyor: a raised belt brainrots walk down, with side rails
-- and glowing chevrons so the eye follows it from spawn to the far arch.
local function buildConveyor(folder)
	local belt = newPart("ConveyorBelt", Vector3.new(CONVEYOR_WIDTH, 2, CONVEYOR_LENGTH),
		Color3.fromRGB(60, 60, 70), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 1, 0))
	belt.TopSurface = Enum.SurfaceType.Smooth
	for _, side in ipairs({ -1, 1 }) do
		newPart("ConveyorRail", Vector3.new(2, 3, CONVEYOR_LENGTH),
			Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
			folder, Vector3.new(side * (CONVEYOR_WIDTH / 2 + 1), 2.5, 0))
	end
	-- Chevron markers down the middle of the belt.
	for z = -135, 135, 30 do
		local chevron = newPart("Chevron", Vector3.new(10, 0.4, 6),
			Color3.fromRGB(255, 220, 80), Enum.Material.Neon,
			folder, Vector3.new(0, 2.1, z))
		chevron.CanCollide = false
	end
	-- The golden pedestal at the centre: rarest spawns are announced here.
	local pedestal = newPart("GoldPedestal", Vector3.new(10, 3, 10),
		Color3.fromRGB(255, 200, 40), Enum.Material.Neon,
		folder, Vector3.new(30, 1.5, 0))
	pedestal.CanCollide = false
	return belt
end

-- One player base: a pad, a back wall, a coloured banner post, and 6 slots
-- where bought brainrots stand and earn. Bases face the map centre.
local function buildBase(folder, index, angleDeg)
	local angle = math.rad(angleDeg)
	local cx = math.cos(angle) * BASE_RADIUS
	local cz = math.sin(angle) * BASE_RADIUS
	local base = Instance.new("Model")
	base.Name = "Base" .. tostring(index)

	local hue = (index - 1) / BASE_COUNT
	local padColor = Color3.fromHSV(hue, 0.55, 0.85)
	local pad = newPart("Pad", Vector3.new(BASE_SIZE, 2, BASE_SIZE),
		padColor, Enum.Material.SmoothPlastic, base, Vector3.new(cx, 1, cz))
	pad.TopSurface = Enum.SurfaceType.Smooth

	-- Back wall, on the far side from the centre. Its long axis (Z) runs
	-- tangent to the ring, so it reads as a wall across the back of the pad.
	local wallX = cx + math.cos(angle) * (BASE_SIZE / 2 + 1)
	local wallZ = cz + math.sin(angle) * (BASE_SIZE / 2 + 1)
	local wall = newPart("BackWall", Vector3.new(6, 16, BASE_SIZE),
		padColor, Enum.Material.SmoothPlastic, base, Vector3.new(wallX, 8, wallZ))
	wall.CFrame = CFrame.new(wallX, 8, wallZ) * CFrame.Angles(0, -angle, 0)

	-- Banner post with the base number, so players find their base fast.
	local post = newPart("BannerPost", Vector3.new(2, 22, 2),
		Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic,
		base, Vector3.new(cx - math.cos(angle) * (BASE_SIZE / 2 - 2), 11, cz - math.sin(angle) * (BASE_SIZE / 2 - 2)))
	post.CanCollide = false
	local flag = newPart("BannerFlag", Vector3.new(12, 7, 1),
		padColor, Enum.Material.Neon, base,
		Vector3.new(cx - math.cos(angle) * (BASE_SIZE / 2 - 8), 20, cz - math.sin(angle) * (BASE_SIZE / 2 - 8)))
	flag.CanCollide = false

	-- Six slots in two rows of three, facing the centre.
	local slots = {}
	for row = 0, 1 do
		for col = -1, 1 do
			local along = col * 12
			local across = -8 + row * 16
			local sx = cx + math.cos(angle) * across - math.sin(angle) * along
			local sz = cz + math.sin(angle) * across + math.cos(angle) * along
			local slot = newPart("Slot" .. tostring(#slots + 1), Vector3.new(8, 0.6, 8),
				Color3.fromRGB(255, 255, 255), Enum.Material.Neon,
				base, Vector3.new(sx, 2.3, sz))
			slot.CanCollide = false
			slot.Transparency = 0.5
			table.insert(slots, Vector3.new(sx, 2.6, sz))
		end
	end

	-- Owner name board above the gate. Its Front face must look toward the
	-- map centre, or nobody approaching the base can read it.
	local boardX = cx - math.cos(angle) * (BASE_SIZE / 2 + 1)
	local boardZ = cz - math.sin(angle) * (BASE_SIZE / 2 + 1)
	local board = newPart("OwnerBoard", Vector3.new(20, 8, 1),
		Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic,
		base, Vector3.new(boardX, 14, boardZ))
	board.CFrame = CFrame.new(boardX, 14, boardZ)
		* CFrame.Angles(0, -angle - math.pi / 2, 0)
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

-- The thief ring: a pale walkway octagon linking every base gate, so a
-- thief has one obvious route between bases and a victim can see them coming.
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
	end
end

-- The Grinder Pit: a sunken lava-coloured zone in the north-west with a
-- spinning sweeper bar that knocks careless players back to spawn.
local function buildHazard(folder)
	local pit = newPart("GrinderPit", Vector3.new(70, 2, 70),
		Color3.fromRGB(200, 60, 40), Enum.Material.Neon,
		folder, Vector3.new(-150, 0.5, -150))
	pit.TopSurface = Enum.SurfaceType.Smooth
	local hub = newPart("SweeperHub", Vector3.new(6, 8, 6),
		Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic,
		folder, Vector3.new(-150, 4, -150))
	hub.CanCollide = false
	local bar = newPart("SweeperBar", Vector3.new(60, 3, 4),
		Color3.fromRGB(255, 220, 40), Enum.Material.Neon,
		folder, Vector3.new(-150, 4, -150))
	bar.CanCollide = false
	-- A bridge across the pit, for players brave enough to cross.
	newPart("PitBridge", Vector3.new(10, 1, 70),
		Color3.fromRGB(180, 140, 90), Enum.Material.WoodPlanks,
		folder, Vector3.new(-150, 2.5, -150))
	return bar
end

-- Cheap scenery: blocky trees and a north arch, so the map has depth.
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
		local top = newPart("TreeTop", Vector3.new(10, 10, 10),
			Color3.fromRGB(40, 140, 60), Enum.Material.SmoothPlastic,
			folder, Vector3.new(x, 14, z))
		top.Shape = Enum.PartType.Ball
		top.CanCollide = false
	end
	-- North arch over the conveyor's far end: the brainrots' exit.
	for _, side in ipairs({ -1, 1 }) do
		newPart("ArchPillar", Vector3.new(4, 26, 4),
			Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic,
			folder, Vector3.new(side * 16, 13, -155))
	end
	newPart("ArchBeam", Vector3.new(36, 4, 4),
		Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic,
		folder, Vector3.new(0, 27, -155))
end

-- Build everything. Returns a table the server uses to run the game.
function World.buildWorld()
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = workspace

	buildGround(folder)
	buildConveyor(folder)
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
