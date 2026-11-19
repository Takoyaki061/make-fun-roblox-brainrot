-- BrainrotFactory.luau — Brainrot Bazaar: turn a character definition and a
-- mutation into a chunky 3D Model made of plain parts (no meshes, no assets).
-- Every figure: legs with shoes, short arms angled out, a big ball head with
-- a face, a hat or headgear, and a signature 3D prop built from 2-5 parts so
-- each character reads from across the map. Pivot at the feet: shoes 0-0.5,
-- legs 0-1.4, torso centre ~2.8, head centre ~5.6, hat above ~7.1.

local Cast = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Cast"))

local Factory = {}

-- ---------------------------------------------------------------------------
-- Part helpers
-- ---------------------------------------------------------------------------

local function addPart(model, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = model:GetPivot().Position + offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- A part placed relative to a reference CFrame (so a whole figure can be
-- rotated as one by pivoting the model).
local function addAt(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(30, 30, 30)
local SKIN = Color3.fromRGB(255, 220, 180)

-- ---------------------------------------------------------------------------
-- Faces (five variants), drawn on the front of the ball head
-- ---------------------------------------------------------------------------

local function faceDefault(model, base)
	-- Gentle smile of three small blocks.
	addAt(model, "EyeL", Vector3.new(0.5, 0.6, 0.3), base * CFrame.new(-0.6, 0.3, 1.35), BLACK)
	addAt(model, "EyeR", Vector3.new(0.5, 0.6, 0.3), base * CFrame.new(0.6, 0.3, 1.35), BLACK)
	addAt(model, "Smile", Vector3.new(1.2, 0.3, 0.3), base * CFrame.new(0, -0.5, 1.4), BLACK)
	-- Chubby cheeks.
	addAt(model, "CheekL", Vector3.new(0.6, 0.5, 0.3), base * CFrame.new(-1.1, -0.2, 1.25), Color3.fromRGB(255, 150, 150))
	addAt(model, "CheekR", Vector3.new(0.6, 0.5, 0.3), base * CFrame.new(1.1, -0.2, 1.25), Color3.fromRGB(255, 150, 150))
end

local function faceDroopy(model, base)
	-- Lowered eyes, a glass tear, a downturned mouth — for the soggy crouton.
	addAt(model, "EyeL", Vector3.new(0.5, 0.4, 0.3), base * CFrame.new(-0.6, 0.0, 1.35), BLACK)
	addAt(model, "EyeR", Vector3.new(0.5, 0.4, 0.3), base * CFrame.new(0.6, 0.0, 1.35), BLACK)
	local tear = addAt(model, "Tear", Vector3.new(0.4, 0.9, 0.3), base * CFrame.new(1.0, -0.5, 1.3), Color3.fromRGB(120, 200, 255), Enum.Material.Glass, Enum.PartType.Ball)
	tear.Transparency = 0.3
	addAt(model, "Frown", Vector3.new(1.2, 0.3, 0.3), base * CFrame.new(0, -0.7, 1.4), BLACK)
end

local function faceToothy(model, base)
	-- Three teeth and a wide grin.
	addAt(model, "EyeL", Vector3.new(0.5, 0.6, 0.3), base * CFrame.new(-0.6, 0.4, 1.35), BLACK)
	addAt(model, "EyeR", Vector3.new(0.5, 0.6, 0.3), base * CFrame.new(0.6, 0.4, 1.35), BLACK)
	addAt(model, "Grin", Vector3.new(1.6, 0.6, 0.3), base * CFrame.new(0, -0.4, 1.4), BLACK)
	for i = 1, 3 do
		addAt(model, "Tooth" .. i, Vector3.new(0.4, 0.4, 0.2), base * CFrame.new(-0.5 + (i - 1) * 0.5, -0.35, 1.55), WHITE)
	end
end

local function faceShout(model, base)
	-- Wide eyes and an open mouth.
	addAt(model, "EyeL", Vector3.new(0.7, 0.8, 0.3), base * CFrame.new(-0.6, 0.4, 1.35), WHITE)
	addAt(model, "PupilL", Vector3.new(0.35, 0.4, 0.2), base * CFrame.new(-0.6, 0.4, 1.5), BLACK)
	addAt(model, "EyeR", Vector3.new(0.7, 0.8, 0.3), base * CFrame.new(0.6, 0.4, 1.35), WHITE)
	addAt(model, "PupilR", Vector3.new(0.35, 0.4, 0.2), base * CFrame.new(0.6, 0.4, 1.5), BLACK)
	addAt(model, "Mouth", Vector3.new(1.0, 1.0, 0.3), base * CFrame.new(0, -0.6, 1.4), BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local function faceGlasses(model, base)
	-- Spectacle frames of thin blocks, plus a smile.
	faceDefault(model, base)
	for _, sx in ipairs({ -1, 1 }) do
		addAt(model, "Lens" .. sx, Vector3.new(1.1, 1.1, 0.2), base * CFrame.new(sx * 0.65, 0.3, 1.45), BLACK)
	end
	addAt(model, "Bridge", Vector3.new(0.5, 0.2, 0.2), base * CFrame.new(0, 0.35, 1.45), BLACK)
	for _, sx in ipairs({ -1, 1 }) do
		addAt(model, "Arm" .. sx, Vector3.new(0.2, 0.2, 0.8), base * CFrame.new(sx * 1.25, 0.35, 1.1), BLACK)
	end
end

local FACES = {
	default = faceDefault,
	droopy = faceDroopy,
	toothy = faceToothy,
	shout = faceShout,
	glasses = faceGlasses,
}

-- ---------------------------------------------------------------------------
-- Hats (one kind per character), sitting above the head (~7.1)
-- ---------------------------------------------------------------------------

local function hatCrust(model, base, color)
	-- Dark cap on the crouton.
	addAt(model, "CrustCap", Vector3.new(3.2, 0.8, 3.2), base * CFrame.new(0, 1.6, 0), Color3.fromRGB(120, 70, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

local function hatHeadband(model, base, color)
	-- Gold band.
	addAt(model, "Headband", Vector3.new(3.1, 0.5, 3.1), base * CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
end

local function hatNozzle(model, base, color)
	-- Sprinkler nozzle with spray-hole nubs.
	addAt(model, "Nozzle", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 1.8, 0), Color3.fromRGB(120, 120, 130), Enum.Material.Metal, Enum.PartType.Cylinder)
	for i = 1, 4 do
		local angle = math.rad(90 * i)
		addAt(model, "SprayNub" .. i, Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(math.cos(angle) * 0.8, 2.3, math.sin(angle) * 0.8), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local function hatDoily(model, base, color)
	-- Flat white disc with a scalloped rim of balls.
	addAt(model, "Doily", Vector3.new(3.6, 0.3, 3.6), base * CFrame.new(0, 1.5, 0), Color3.fromRGB(250, 240, 220), Enum.Material.Fabric, Enum.PartType.Cylinder)
	for i = 1, 8 do
		local angle = math.rad(45 * i)
		addAt(model, "Scallop" .. i, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(math.cos(angle) * 1.7, 1.5, math.sin(angle) * 1.7), Color3.fromRGB(250, 240, 220), Enum.Material.Fabric, Enum.PartType.Ball)
	end
end

local function hatHalo(model, base, color)
	-- Neon gold ring.
	local halo = addAt(model, "Halo", Vector3.new(3.4, 0.4, 3.4), base * CFrame.new(0, 1.9, 0), Color3.fromRGB(255, 220, 80), Enum.Material.Neon, Enum.PartType.Cylinder)
	halo.Orientation = Vector3.new(0, 0, 0)
end

local function hatCap(model, base, color)
	-- Red cap with a brim.
	addAt(model, "CapTop", Vector3.new(3.0, 0.9, 3.0), base * CFrame.new(0, 1.6, 0), Color3.fromRGB(200, 40, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
	addAt(model, "CapBrim", Vector3.new(3.0, 0.3, 1.6), base * CFrame.new(0, 1.3, 1.6), Color3.fromRGB(200, 40, 40), Enum.Material.Fabric)
end

local function hatHelm(model, base, color)
	-- Great helm with a visor slit.
	addAt(model, "Helm", Vector3.new(3.2, 1.6, 3.2), base * CFrame.new(0, 1.6, 0), Color3.fromRGB(160, 160, 170), Enum.Material.Metal, Enum.PartType.Cylinder)
	addAt(model, "VisorSlit", Vector3.new(2.0, 0.4, 0.3), base * CFrame.new(0, 1.6, 1.55), BLACK)
end

local function hatStarhat(model, base, color)
	-- Gold disc with five wedge star points.
	addAt(model, "StarDisc", Vector3.new(3.0, 0.4, 3.0), base * CFrame.new(0, 1.7, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
	for i = 1, 5 do
		local angle = math.rad(72 * i)
		local point = addAt(model, "StarPoint" .. i, Vector3.new(1.0, 0.4, 0.6), base * CFrame.new(math.cos(angle) * 1.7, 1.7, math.sin(angle) * 1.7), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, Enum.PartType.Wedge)
		point.CFrame = base * CFrame.new(math.cos(angle) * 1.7, 1.7, math.sin(angle) * 1.7) * CFrame.Angles(0, -angle, 0)
	end
end

local function hatPanel(model, base, color)
	-- Washing-machine control panel with dials.
	addAt(model, "Panel", Vector3.new(2.6, 1.0, 0.6), base * CFrame.new(0, 1.6, 1.2), Color3.fromRGB(220, 220, 230), Enum.Material.Metal)
	for i = 1, 2 do
		addAt(model, "Dial" .. i, Vector3.new(0.5, 0.5, 0.3), base * CFrame.new(-0.6 + (i - 1) * 1.2, 1.6, 1.55), Color3.fromRGB(100, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
end

local function hatHeadphones(model, base, color)
	-- Cups and a band.
	addAt(model, "Band", Vector3.new(0.5, 1.6, 3.2), base * CFrame.new(0, 2.0, 0), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		addAt(model, "Cup" .. sx, Vector3.new(0.6, 1.4, 1.4), base * CFrame.new(sx * 1.6, 1.2, 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	end
end

local function hatAntenna(model, base, color)
	-- Rod with a neon red tip.
	addAt(model, "AntennaRod", Vector3.new(0.3, 2.4, 0.3), base * CFrame.new(0, 2.6, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	addAt(model, "AntennaTip", Vector3.new(0.8, 0.8, 0.8), base * CFrame.new(0, 3.9, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, Enum.PartType.Ball)
end

local function hatPepperoni(model, base, color)
	-- A crown of five red discs.
	for i = 1, 5 do
		local angle = math.rad(72 * i)
		addAt(model, "CrownDisc" .. i, Vector3.new(0.9, 0.3, 0.9), base * CFrame.new(math.cos(angle) * 1.4, 1.8, math.sin(angle) * 1.4), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

local HATS = {
	crust = hatCrust,
	headband = hatHeadband,
	nozzle = hatNozzle,
	doily = hatDoily,
	halo = hatHalo,
	cap = hatCap,
	helm = hatHelm,
	starhat = hatStarhat,
	panel = hatPanel,
	headphones = hatHeadphones,
	antenna = hatAntenna,
	pepperoni = hatPepperoni,
}

-- ---------------------------------------------------------------------------
-- Accessories (one per character), carried at the side or on the body
-- ---------------------------------------------------------------------------

local function accPuddle(model, base, color)
	-- A puddle with crumbs under the crouton.
	local puddle = addAt(model, "Puddle", Vector3.new(4.5, 0.3, 4.5), base * CFrame.new(0, -5.4, 0), Color3.fromRGB(140, 110, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	puddle.Transparency = 0.3
	for i = 1, 3 do
		addAt(model, "Crumb" .. i, Vector3.new(0.5, 0.4, 0.5), base * CFrame.new(-1 + i * 0.8, -5.2, 0.8), Color3.fromRGB(190, 150, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function accFlipflop(model, base, color)
	-- An oversized flip-flop held at the side.
	local flip = addAt(model, "BigFlipFlop", Vector3.new(1.2, 0.4, 3.2), base * CFrame.new(2.6, -1.5, 0.6), Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
	flip.CFrame = base * CFrame.new(2.6, -1.5, 0.6) * CFrame.Angles(0, 0, math.rad(25))
	addAt(model, "FlipStrap", Vector3.new(1.0, 0.3, 0.8), base * CFrame.new(2.6, -1.2, 1.2), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic)
end

local function accHose(model, base, color)
	-- A garden-hose coil with a brass nozzle.
	for i = 1, 3 do
		local ring = addAt(model, "HoseRing" .. i, Vector3.new(2.2 - i * 0.3, 0.5, 2.2 - i * 0.3), base * CFrame.new(-2.4, -1.8 + i * 0.5, 0), Color3.fromRGB(40, 120, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		ring.Orientation = Vector3.new(0, 0, 90)
	end
	addAt(model, "BrassNozzle", Vector3.new(0.8, 0.8, 1.4), base * CFrame.new(-2.4, -0.6, 0), Color3.fromRGB(220, 180, 80), Enum.Material.Metal)
end

local function accNeedles(model, base, color)
	-- Knitting needles and a yarn ball.
	for _, sx in ipairs({ -1, 1 }) do
		local needle = addAt(model, "Needle" .. sx, Vector3.new(0.25, 3.2, 0.25), base * CFrame.new(2.5 + sx * 0.3, -1.0, 0.4), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		needle.CFrame = base * CFrame.new(2.5 + sx * 0.3, -1.0, 0.4) * CFrame.Angles(0, 0, math.rad(sx * 15))
	end
	addAt(model, "YarnBall", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(2.5, -2.4, 0.4), Color3.fromRGB(255, 120, 170), Enum.Material.Fabric, Enum.PartType.Ball)
end

local function accWings(model, base, color)
	-- White wings on the back.
	for _, sx in ipairs({ -1, 1 }) do
		local wing = addAt(model, "Wing" .. sx, Vector3.new(0.4, 2.4, 1.6), base * CFrame.new(sx * 1.6, -1.0, -1.4), WHITE, Enum.Material.Fabric)
		wing.CFrame = base * CFrame.new(sx * 1.6, -1.0, -1.4) * CFrame.Angles(0, 0, math.rad(sx * -30))
	end
end

local function accCart(model, base, color)
	-- A little shopping cart pushed at the side.
	addAt(model, "CartBasket", Vector3.new(2.2, 1.4, 1.6), base * CFrame.new(2.8, -2.0, 0.8), Color3.fromRGB(180, 180, 180), Enum.Material.Metal)
	addAt(model, "CartHandle", Vector3.new(0.3, 0.3, 2.0), base * CFrame.new(2.8, -1.2, 1.8), Color3.fromRGB(120, 120, 120), Enum.Material.Metal)
	for _, dz in ipairs({ -0.6, 0.6 }) do
		addAt(model, "CartWheel" .. dz, Vector3.new(0.5, 0.5, 0.5), base * CFrame.new(2.8, -2.8, 0.8 + dz), BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function accLance(model, base, color)
	-- A long lance held upright.
	local lance = addAt(model, "Lance", Vector3.new(0.35, 6.5, 0.35), base * CFrame.new(2.6, 0.5, 0.6), Color3.fromRGB(255, 220, 60), Enum.Material.SmoothPlastic)
	lance.CFrame = base * CFrame.new(2.6, 0.5, 0.6) * CFrame.Angles(0, 0, math.rad(-12))
	addAt(model, "LanceTip", Vector3.new(0.8, 1.2, 0.8), base * CFrame.new(3.3, 3.8, 0.6), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
end

local function accShawl(model, base, color)
	-- A galaxy shawl with neon stars draped over the shoulders.
	addAt(model, "Shawl", Vector3.new(4.0, 1.2, 3.6), base * CFrame.new(0, -0.6, 0), Color3.fromRGB(200, 80, 255), Enum.Material.Neon)
	for i = 1, 4 do
		local angle = math.rad(90 * i)
		addAt(model, "Star" .. i, Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(math.cos(angle) * 1.6, -0.4, math.sin(angle) * 1.4), Color3.fromRGB(255, 255, 150), Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local function accPorthole(model, base, color)
	-- A porthole ring with glass on the chest.
	addAt(model, "PortholeRing", Vector3.new(2.2, 2.2, 0.4), base * CFrame.new(0, 0, 1.5), Color3.fromRGB(150, 150, 160), Enum.Material.Metal, Enum.PartType.Cylinder)
	local glass = addAt(model, "PortholeGlass", Vector3.new(1.7, 1.7, 0.3), base * CFrame.new(0, 0, 1.6), Color3.fromRGB(100, 200, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
	glass.Transparency = 0.3
end

local function accTurntables(model, base, color)
	-- Turntables strapped to the chest.
	addAt(model, "Deck", Vector3.new(3.0, 0.8, 1.8), base * CFrame.new(0, -0.8, 1.2), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		addAt(model, "Platter" .. sx, Vector3.new(1.0, 0.3, 1.0), base * CFrame.new(sx * 0.7, -0.3, 1.2), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

local function accModem(model, base, color)
	-- A dial-up modem box with neon lights.
	addAt(model, "ModemBox", Vector3.new(2.4, 1.2, 1.4), base * CFrame.new(-2.6, -2.0, 0.6), Color3.fromRGB(240, 240, 200), Enum.Material.SmoothPlastic)
	for i = 1, 3 do
		addAt(model, "ModemLight" .. i, Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(-3.4 + i * 0.6, -1.6, 1.35), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local function accPepperoni(model, base, color)
	-- Pepperoni discs on the body.
	for i = 1, 4 do
		local angle = math.rad(90 * i)
		addAt(model, "Pepperoni" .. i, Vector3.new(0.9, 0.3, 0.9), base * CFrame.new(math.cos(angle) * 0.9, -0.5 + (i % 2) * 0.8, 1.4), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

local ACCESSORIES = {
	puddle = accPuddle,
	flipflop = accFlipflop,
	hose = accHose,
	needles = accNeedles,
	wings = accWings,
	cart = accCart,
	lance = accLance,
	shawl = accShawl,
	porthole = accPorthole,
	turntables = accTurntables,
	modem = accModem,
	pepperoni = accPepperoni,
}

-- ---------------------------------------------------------------------------
-- Mutation treatment
-- ---------------------------------------------------------------------------

local function applyMutation(model, torso, head, mutationName)
	if mutationName == "Golden" then
		torso.Material = Enum.Material.Neon
		head.Material = Enum.Material.Neon
	elseif mutationName == "Rainbow" then
		torso.Color = Color3.fromRGB(120, 200, 255)
		torso.Material = Enum.Material.Neon
		local shell = addPart(model, "GlowShell", Vector3.new(3.6, 3.6, 3.6), Vector3.new(0, 5.6, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, Enum.PartType.Ball)
		shell.Transparency = 0.5
	elseif mutationName == "Diamond" then
		torso.Material = Enum.Material.Glass
		head.Material = Enum.Material.Glass
		local shell = addPart(model, "GlowShell", Vector3.new(3.6, 3.6, 3.6), Vector3.new(0, 5.6, 0), Color3.fromRGB(180, 240, 255), Enum.Material.Neon, Enum.PartType.Ball)
		shell.Transparency = 0.5
	end
end

-- ---------------------------------------------------------------------------
-- Label and prompts
-- ---------------------------------------------------------------------------

local function attachLabel(model, def, mutationName)
	local rate = Cast.baseRate(def, mutationName)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.new(0, 220, 0, 90)
	gui.StudsOffset = Vector3.new(0, 9.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = WHITE
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0, 26)
	rarityLabel.Position = UDim2.new(0, 0, 0, 30)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = def.rarity .. " • " .. mutationName
	rarityLabel.TextColor3 = Cast.rarityColor(def.rarity)
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = gui

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Size = UDim2.new(1, 0, 0, 26)
	rateLabel.Position = UDim2.new(0, 0, 0, 58)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = Cast.formatMoney(rate) .. "/sec"
	rateLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
	rateLabel.TextStrokeTransparency = 0
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = gui
end

--- BUY prompt for a conveyor brainrot: E, no hold, max distance 14.
function Factory.attachBuyPrompt(model, cost)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "BUY"
	prompt.ObjectText = "BUY " .. Cast.formatMoney(cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model
	return prompt
end

--- STEAL prompt for a based brainrot: E, hold 5 s.
function Factory.attachStealPrompt(model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "STEAL"
	prompt.ObjectText = "HOLD TO STEAL"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Cast.STEAL_HOLD_SECONDS
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model
	return prompt
end

-- ---------------------------------------------------------------------------
-- The build
-- ---------------------------------------------------------------------------

--- Build a brainrot Model from a character definition and a mutation name.
--- The caller places it; the model pivots at its feet.
function Factory.buildBrainrot(def, mutationName)
	local model = Instance.new("Model")
	model.Name = def.name .. " (" .. mutationName .. ")"

	-- A hidden root part to anchor the figure's CFrame math.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 0, 0)
	root.Parent = model
	model.PrimaryPart = root

	local base = CFrame.new(0, 0, 0) -- feet at the origin, facing -Z

	-- Legs with shoes (0-1.4).
	for _, sx in ipairs({ -1, 1 }) do
		addAt(model, "Shoe" .. sx, Vector3.new(1.2, 0.5, 2.0), base * CFrame.new(sx * 0.8, 0.25, 0.2), def.shoes)
		addAt(model, "Leg" .. sx, Vector3.new(1.0, 1.0, 1.0), base * CFrame.new(sx * 0.8, 0.9, 0), Color3.fromRGB(60, 60, 70))
	end

	-- Torso (centre ~2.8), shape and colour from the definition.
	local torso = addAt(model, "Torso", def.size, base * CFrame.new(0, 2.8, 0), def.color, Enum.Material.SmoothPlastic, Enum.PartType[def.shape])
	-- Short arms angled out.
	for _, sx in ipairs({ -1, 1 }) do
		local arm = addAt(model, "Arm" .. sx, Vector3.new(0.9, 2.2, 0.9), base * CFrame.new(sx * (def.size.X / 2 + 0.5), 2.8, 0), def.color)
		arm.CFrame = base * CFrame.new(sx * (def.size.X / 2 + 0.5), 2.8, 0) * CFrame.Angles(0, 0, math.rad(sx * -25))
	end

	-- Big ball head (centre ~5.6), same colour as the torso.
	local head = addAt(model, "Head", Vector3.new(3, 3, 3), base * CFrame.new(0, 5.6, 0), def.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	-- Face, hat, and signature prop.
	local faceFn = FACES[def.face] or faceDefault
	faceFn(model, base * CFrame.new(0, 5.6, 0))
	local hatFn = HATS[def.hat]
	if hatFn then
		hatFn(model, base * CFrame.new(0, 5.6, 0), def.color)
	end
	local accFn = ACCESSORIES[def.accessory]
	if accFn then
		accFn(model, base * CFrame.new(0, 5.6, 0), def.propColor)
	end

	-- Mutation treatment (gold neon, rainbow/diamond glow shells).
	applyMutation(model, torso, head, mutationName)

	-- Identity tag the server reads: "name|mutation".
	local tag = Instance.new("StringValue")
	tag.Name = "BrainrotDef"
	tag.Value = def.name .. "|" .. mutationName
	tag.Parent = model

	attachLabel(model, def, mutationName)

	-- Weld everything to the root so the model moves as one piece.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	return model
end

return Factory
