-- BrainrotFactory.luau
-- Turns a character definition + mutation into a chunky 3D Model made
-- of plain parts (no meshes, no assets). Every figure reads from
-- across the map: legs with shoes, short arms angled out, a big ball
-- head with a face, a hat, and a signature 3D prop.
--
-- Figure layout (local Y, pivot at the feet): shoes 0-0.5, legs
-- 0-1.4, torso centre ~2.8, head centre ~5.6, hat above ~7.1.
-- Faces sit on the figure's -Z side, so CFrame.lookAt (which points
-- -Z at its target) always turns the face toward the viewer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cast = require(ReplicatedStorage.Shared.Cast)

local Factory = {}

local DARK = Color3.fromRGB(30, 30, 30)
local WHITE = Color3.fromRGB(255, 255, 255)
local CHEEK = Color3.fromRGB(255, 150, 170)

-- ---------------------------------------------------------------------------
-- Part helpers (all parts are anchored; figures never simulate physics)
-- ---------------------------------------------------------------------------

local function part(parent, name, size, pos, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent, name, diameter, pos, color, material)
	return part(parent, name, Vector3.new(diameter, diameter, diameter), pos, color, material, Enum.PartType.Ball)
end

local function wedge(parent, name, size, pos, color)
	local p = part(parent, name, size, pos, color, Enum.Material.SmoothPlastic, Enum.PartType.Wedge)
	return p
end

local function cylY(parent, name, diameter, height, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(diameter, height, diameter)
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------------------
-- Faces (five variants, all on the -Z side of the head)
-- ---------------------------------------------------------------------------

local function eyes(parent, head, spread, height, size, droopy)
	-- Two googly eyes with pupils, at the given height over the head centre.
	for _, side in ipairs({ -1, 1 }) do
		local eye = ball(parent, "Eye", size, head + Vector3.new(side * spread, height, -1.15), WHITE)
		eye.CanCollide = false
		local pupil = ball(parent, "Pupil", size * 0.5, head + Vector3.new(side * spread, height - (droopy and 0.25 or 0), -1.45), DARK)
		pupil.CanCollide = false
	end
end

local function smile(parent, head, width, y)
	-- A gentle smile from three small blocks.
	part(parent, "SmileL", Vector3.new(0.5, 0.4, 0.3), head + Vector3.new(-width, y, -1.4), DARK).CanCollide = false
	part(parent, "SmileC", Vector3.new(0.7, 0.4, 0.3), head + Vector3.new(0, y - 0.15, -1.45), DARK).CanCollide = false
	part(parent, "SmileR", Vector3.new(0.5, 0.4, 0.3), head + Vector3.new(width, y, -1.4), DARK).CanCollide = false
end

local function cheeks(parent, head)
	for _, side in ipairs({ -1, 1 }) do
		ball(parent, "Cheek", 0.7, head + Vector3.new(side * 1.15, -0.35, -1.05), CHEEK).CanCollide = false
	end
end

local function buildFace(parent, kind, head, headColor)
	-- head is the head centre (Vector3); the head is a 3-stud ball.
	if kind == "droopy" then
		eyes(parent, head, 0.7, 0.35, 0.9, true)
		-- A glass tear under the left eye.
		local tear = ball(parent, "Tear", 0.5, head + Vector3.new(-0.7, -0.5, -1.3), Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
		tear.CanCollide = false
		-- Downturned mouth: two blocks angled down toward the middle.
		part(parent, "FrownL", Vector3.new(0.6, 0.35, 0.3), head + Vector3.new(-0.5, -0.7, -1.4), DARK).CanCollide = false
		part(parent, "FrownR", Vector3.new(0.6, 0.35, 0.3), head + Vector3.new(0.5, -0.7, -1.4), DARK).CanCollide = false
		cheeks(parent, head)
	elseif kind == "toothy" then
		eyes(parent, head, 0.7, 0.4, 1.0, false)
		-- Wide grin with three teeth.
		part(parent, "Grin", Vector3.new(2.2, 0.8, 0.3), head + Vector3.new(0, -0.7, -1.4), DARK).CanCollide = false
		for i = -1, 1 do
			part(parent, "Tooth", Vector3.new(0.5, 0.5, 0.35), head + Vector3.new(i * 0.7, -0.55, -1.45), WHITE).CanCollide = false
		end
		cheeks(parent, head)
	elseif kind == "shout" then
		eyes(parent, head, 0.7, 0.45, 1.0, false)
		-- Open shouting mouth: dark oval with a tongue.
		ball(parent, "ShoutMouth", 1.1, head + Vector3.new(0, -0.7, -1.3), DARK).CanCollide = false
		part(parent, "Tongue", Vector3.new(0.7, 0.4, 0.3), head + Vector3.new(0, -1.0, -1.45), Color3.fromRGB(255, 120, 140)).CanCollide = false
		cheeks(parent, head)
	elseif kind == "glasses" then
		eyes(parent, head, 0.7, 0.4, 0.9, false)
		-- Spectacle frames of thin blocks, joined over the nose.
		for _, side in ipairs({ -1, 1 }) do
			part(parent, "GlassesFrame", Vector3.new(1.3, 1.3, 0.2), head + Vector3.new(side * 0.7, 0.4, -1.5), DARK).CanCollide = false
		end
		part(parent, "GlassesBridge", Vector3.new(0.5, 0.25, 0.2), head + Vector3.new(0, 0.45, -1.5), DARK).CanCollide = false
		smile(parent, head, 0.55, -0.6)
		cheeks(parent, head)
	else -- "default": gentle smile
		eyes(parent, head, 0.7, 0.4, 0.9, false)
		smile(parent, head, 0.55, -0.6)
		cheeks(parent, head)
	end
end

-- ---------------------------------------------------------------------------
-- Hats (one kind per character)
-- ---------------------------------------------------------------------------

local HATS = {}

-- Dark cap on the crouton.
HATS.crust = function(model, head, _color)
	local cap = ball(model, "HatCrust", 3.2, head + Vector3.new(0, 1.6, 0), Color3.fromRGB(120, 70, 30))
	cap.CanCollide = false
	part(model, "HatCrustBrim", Vector3.new(3.6, 0.4, 2.2), head + Vector3.new(0, 1.1, -1.2), Color3.fromRGB(90, 50, 20)).CanCollide = false
end

-- Gold headband.
HATS.headband = function(model, head, _color)
	local band = cylY(model, "HatBand", 3.2, 0.7, head + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	band.CanCollide = false
end

-- Sprinkler nozzle with spray-hole nubs.
HATS.nozzle = function(model, head, _color)
	cylY(model, "HatNozzle", 1.6, 1.6, head + Vector3.new(0, 2.0, 0), Color3.fromRGB(160, 160, 170), Enum.Material.Metal).CanCollide = false
	for i = 1, 4 do
		local a = math.rad(i * 90)
		ball(model, "NozzleNub", 0.5, head + Vector3.new(math.cos(a) * 0.7, 2.8, math.sin(a) * 0.7), Color3.fromRGB(80, 200, 255)).CanCollide = false
	end
end

-- Flat white doily disc with scalloped rim balls.
HATS.doily = function(model, head, _color)
	cylY(model, "HatDoily", 4.2, 0.4, head + Vector3.new(0, 1.7, 0), Color3.fromRGB(250, 240, 220)).CanCollide = false
	for i = 1, 8 do
		local a = math.rad(i * 45)
		ball(model, "DoilyScallop", 0.7, head + Vector3.new(math.cos(a) * 2.1, 1.7, math.sin(a) * 2.1), Color3.fromRGB(250, 240, 220)).CanCollide = false
	end
end

-- Neon gold halo ring.
HATS.halo = function(model, head, _color)
	local halo = cylY(model, "HatHalo", 4.4, 0.5, head + Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 220, 100), Enum.Material.Neon)
	halo.CanCollide = false
end

-- Red cap with a brim.
HATS.cap = function(model, head, _color)
	local cap = ball(model, "HatCap", 3.1, head + Vector3.new(0, 1.7, 0), Color3.fromRGB(220, 40, 40))
	cap.CanCollide = false
	part(model, "HatCapBrim", Vector3.new(3.4, 0.4, 2.0), head + Vector3.new(0, 1.2, -1.4), Color3.fromRGB(180, 30, 30)).CanCollide = false
end

-- Great helm with a visor slit.
HATS.helm = function(model, head, _color)
	part(model, "HatHelm", Vector3.new(3.4, 2.2, 3.4), head + Vector3.new(0, 1.9, 0), Color3.fromRGB(180, 180, 195), Enum.Material.Metal).CanCollide = false
	part(model, "HelmSlit", Vector3.new(2.4, 0.4, 0.3), head + Vector3.new(0, 1.9, -1.7), DARK).CanCollide = false
	part(model, "HelmPlume", Vector3.new(0.5, 1.6, 2.4), head + Vector3.new(0, 3.4, 0), Color3.fromRGB(255, 60, 90)).CanCollide = false
end

-- Gold disc with five wedge star points.
HATS.starhat = function(model, head, _color)
	cylY(model, "HatStarDisc", 3.6, 0.5, head + Vector3.new(0, 1.8, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Neon).CanCollide = false
	for i = 1, 5 do
		local a = math.rad(i * 72)
		local point = wedge(model, "StarPoint", Vector3.new(1.2, 0.4, 1.6), head + Vector3.new(math.cos(a) * 1.9, 1.8, math.sin(a) * 1.9), Color3.fromRGB(255, 220, 100))
		point.CFrame = CFrame.new(head + Vector3.new(math.cos(a) * 1.9, 1.8, math.sin(a) * 1.9)) * CFrame.Angles(0, -a, 0)
		point.CanCollide = false
	end
end

-- Washing-machine control panel with dials.
HATS.panel = function(model, head, _color)
	part(model, "HatPanel", Vector3.new(3.6, 1.4, 1.0), head + Vector3.new(0, 2.0, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Metal).CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		cylY(model, "PanelDial", 0.9, 0.4, head + Vector3.new(side * 1.0, 2.0, -0.6), Color3.fromRGB(100, 200, 255), Enum.Material.Neon).CanCollide = false
	end
	part(model, "PanelLight", Vector3.new(0.8, 0.4, 0.3), head + Vector3.new(0, 2.2, -0.6), Color3.fromRGB(255, 80, 80), Enum.Material.Neon).CanCollide = false
end

-- Headphones: two cups and a band.
HATS.headphones = function(model, head, _color)
	for _, side in ipairs({ -1, 1 }) do
		cylY(model, "HeadphoneCup", 1.4, 1.0, head + Vector3.new(side * 1.7, 0.3, 0), Color3.fromRGB(40, 40, 40)).CanCollide = false
	end
	local band = part(model, "HeadphoneBand", Vector3.new(3.6, 0.5, 1.0), head + Vector3.new(0, 1.7, 0), Color3.fromRGB(40, 40, 40))
	band.CanCollide = false
end

-- Antenna rod with a neon red tip.
HATS.antenna = function(model, head, _color)
	cylY(model, "HatAntenna", 0.3, 2.4, head + Vector3.new(0, 2.6, 0), Color3.fromRGB(160, 160, 170), Enum.Material.Metal).CanCollide = false
	ball(model, "AntennaTip", 0.9, head + Vector3.new(0, 3.9, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon).CanCollide = false
end

-- Crown of five red pepperoni discs.
HATS.pepperoni = function(model, head, _color)
	for i = 1, 5 do
		local a = math.rad(i * 72)
		cylY(model, "PepperoniCrown", 1.1, 0.4, head + Vector3.new(math.cos(a) * 1.3, 1.9, math.sin(a) * 1.3), Color3.fromRGB(200, 40, 40)).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Accessories (one per character, carried at the side or on the body)
-- ---------------------------------------------------------------------------

local ACCESSORIES = {}

-- A puddle with crumbs, under the crouton.
ACCESSORIES.puddle = function(model, torso, _head, propColor)
	local puddle = cylY(model, "Puddle", 4.5, 0.3, Vector3.new(2.6, 0.2, 0.6), Color3.fromRGB(150, 110, 60))
	puddle.CanCollide = false
	for i = 1, 3 do
		ball(model, "Crumb", 0.5, Vector3.new(2.0 + i * 0.6, 0.4, 0.2 + i * 0.3), Color3.fromRGB(120, 80, 40)).CanCollide = false
	end
end

-- An oversized flip-flop held at the side.
ACCESSORIES.flipflop = function(model, torso, _head, propColor)
	local sole = part(model, "FlipFlop", Vector3.new(1.6, 0.4, 3.6), torso + Vector3.new(2.6, -0.5, 0), propColor)
	sole.CanCollide = false
	part(model, "FlipFlopStrap", Vector3.new(1.4, 0.3, 0.4), torso + Vector3.new(2.6, -0.2, -0.8), Color3.fromRGB(255, 255, 255)).CanCollide = false
end

-- A garden-hose coil with a brass nozzle.
ACCESSORIES.hose = function(model, torso, _head, propColor)
	for i = 1, 3 do
		local ring = cylY(model, "HoseCoil", 3.0 - i * 0.4, 0.5, torso + Vector3.new(-2.8, -0.8 + i * 0.5, 0), propColor)
		ring.CanCollide = false
	end
	cylY(model, "HoseNozzle", 0.7, 1.4, torso + Vector3.new(-2.8, 1.2, 0), Color3.fromRGB(220, 180, 60), Enum.Material.Metal).CanCollide = false
end

-- Knitting needles and a yarn ball.
ACCESSORIES.needles = function(model, torso, _head, propColor)
	for _, side in ipairs({ -1, 1 }) do
		local needle = cylY(model, "KnittingNeedle", 0.25, 3.0, torso + Vector3.new(2.6, 0.5, side * 0.5), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		needle.CanCollide = false
	end
	ball(model, "YarnBall", 1.8, torso + Vector3.new(2.6, -1.0, 0), Color3.fromRGB(255, 120, 180)).CanCollide = false
end

-- White angel wings on the back.
ACCESSORIES.wings = function(model, torso, _head, propColor)
	for _, side in ipairs({ -1, 1 }) do
		local wing = part(model, "Wing", Vector3.new(0.4, 2.6, 2.2), torso + Vector3.new(side * 0.2, 0.8, 1.9), WHITE)
		wing.CFrame = CFrame.new(torso + Vector3.new(side * 0.2, 0.8, 1.9)) * CFrame.Angles(0, side * 0.5, side * 0.4)
		wing.CanCollide = false
	end
end

-- A shopping cart pushed at the side.
ACCESSORIES.cart = function(model, torso, _head, propColor)
	part(model, "CartBasket", Vector3.new(3.0, 2.0, 2.2), torso + Vector3.new(3.2, -0.5, 0), propColor, Enum.Material.Metal).CanCollide = false
	part(model, "CartHandle", Vector3.new(0.4, 0.4, 2.4), torso + Vector3.new(1.6, 0.8, 0), Color3.fromRGB(80, 80, 90), Enum.Material.Metal).CanCollide = false
	for _, dz in ipairs({ -0.8, 0.8 }) do
		ball(model, "CartWheel", 0.8, torso + Vector3.new(3.2, -1.8, dz), DARK).CanCollide = false
	end
end

-- A long lance held upright.
ACCESSORIES.lance = function(model, torso, _head, propColor)
	cylY(model, "LanceShaft", 0.5, 7.0, torso + Vector3.new(2.8, 1.0, 0), Color3.fromRGB(180, 140, 80), Enum.Material.Wood).CanCollide = false
	local tip = wedge(model, "LanceTip", Vector3.new(1.0, 1.6, 0.4), torso + Vector3.new(2.8, 5.0, 0), propColor)
	tip.CanCollide = false
end

-- A galaxy shawl with neon stars draped over the shoulders.
ACCESSORIES.shawl = function(model, torso, _head, propColor)
	part(model, "Shawl", Vector3.new(4.2, 1.2, 3.6), torso + Vector3.new(0, 1.2, 0), propColor).CanCollide = false
	for i = 1, 3 do
		ball(model, "ShawlStar", 0.5, torso + Vector3.new(-1.2 + i * 1.2, 1.9, -1.4), Color3.fromRGB(255, 255, 150), Enum.Material.Neon).CanCollide = false
	end
end

-- A porthole ring with glass on the chest.
ACCESSORIES.porthole = function(model, torso, _head, propColor)
	cylY(model, "PortholeRing", 2.4, 0.5, torso + Vector3.new(0, 0.2, -1.5), Color3.fromRGB(180, 180, 195), Enum.Material.Metal).CanCollide = false
	local glass = cylY(model, "PortholeGlass", 1.8, 0.6, torso + Vector3.new(0, 0.2, -1.5), propColor, Enum.Material.Glass)
	glass.CanCollide = false
end

-- Turntables strapped to the front.
ACCESSORIES.turntables = function(model, torso, _head, propColor)
	part(model, "TurntableDeck", Vector3.new(3.4, 0.8, 2.4), torso + Vector3.new(0, -0.8, -1.6), propColor).CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		cylY(model, "TurntablePlatter", 1.4, 0.3, torso + Vector3.new(side * 0.9, -0.3, -1.6), Color3.fromRGB(200, 200, 210), Enum.Material.Metal).CanCollide = false
	end
end

-- A dial-up modem box with neon lights.
ACCESSORIES.modem = function(model, torso, _head, propColor)
	part(model, "ModemBox", Vector3.new(2.6, 1.6, 1.8), torso + Vector3.new(2.8, -0.5, 0), propColor).CanCollide = false
	for i = 1, 3 do
		part(model, "ModemLight", Vector3.new(0.4, 0.3, 0.3), torso + Vector3.new(2.8, 0.1, -0.8 + i * 0.5), Color3.fromRGB(80, 255, 120), Enum.Material.Neon).CanCollide = false
	end
end

-- Pepperoni discs stuck on the body.
ACCESSORIES.pepperoni = function(model, torso, _head, propColor)
	for i = 1, 3 do
		cylY(model, "BodyPepperoni", 1.0, 0.3, torso + Vector3.new(-1.0 + i * 1.0, 0.8 - i * 0.4, -1.4), propColor).CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Mutation treatment
-- ---------------------------------------------------------------------------

local function applyMutation(model, torso, head, mutation)
	if mutation == "Golden" then
		torso.Material = Enum.Material.Neon
		head.Material = Enum.Material.Neon
	elseif mutation == "Rainbow" then
		torso.Color = Color3.fromRGB(120, 200, 255)
		torso.Material = Enum.Material.Neon
		local shell = ball(model, "RainbowShell", 3.8, head.Position, Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
		shell.Transparency = 0.55
		shell.CanCollide = false
	elseif mutation == "Diamond" then
		torso.Material = Enum.Material.Glass
		head.Material = Enum.Material.Glass
		local shell = ball(model, "DiamondShell", 3.8, head.Position, Color3.fromRGB(180, 240, 255), Enum.Material.Glass)
		shell.Transparency = 0.45
		shell.CanCollide = false
	end
end

-- ---------------------------------------------------------------------------
-- Labels and prompts
-- ---------------------------------------------------------------------------

local function attachLabel(model, def, mutation, head)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 90)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = WHITE
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.36, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = def.rarity .. " • " .. mutation
	rarityLabel.TextColor3 = Cast.rarityColor(def.rarity)
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.Parent = gui

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Size = UDim2.new(1, 0, 0.32, 0)
	rateLabel.Position = UDim2.new(0, 0, 0.66, 0)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = Cast.formatMoney(Cast.baseRate(def, mutation)) .. "/sec"
	rateLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.TextStrokeTransparency = 0
	rateLabel.Parent = gui
end

-- BUY prompt for conveyor brainrots: press E, no hold.
function Factory.attachBuyPrompt(model, def)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "BUY"
	prompt.ObjectText = "BUY " .. Cast.formatMoney(def.cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
end

-- STEAL prompt for based brainrots: hold E for the steal duration.
function Factory.attachStealPrompt(model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "STEAL"
	prompt.ObjectText = "HOLD TO STEAL"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Cast.STEAL_HOLD_SECONDS
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
end

-- ---------------------------------------------------------------------------
-- The build
-- ---------------------------------------------------------------------------

function Factory.buildBrainrot(def, mutation)
	local model = Instance.new("Model")
	model.Name = def.name .. " (" .. mutation .. ")"

	local look = def.look
	local torsoSize = look.torsoSize

	-- Shoes 0-0.5, legs 0-1.4.
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Shoe", Vector3.new(1.0, 0.5, 1.6), Vector3.new(side * 0.6, 0.25, -0.3), look.shoes).CanCollide = false
		part(model, "Leg", Vector3.new(0.8, 1.4, 0.8), Vector3.new(side * 0.6, 0.7, 0), def.color).CanCollide = false
	end

	-- Torso: shape and colour from the character definition.
	local torsoY = 1.4 + torsoSize.Y / 2
	local torsoCentre = Vector3.new(0, torsoY, 0)
	local torso
	if def.shape == "Ball" then
		torso = ball(model, "Torso", math.max(torsoSize.X, torsoSize.Y), torsoCentre, def.color)
	elseif def.shape == "Cylinder" then
		torso = cylY(model, "Torso", torsoSize.X, torsoSize.Y, torsoCentre, def.color)
	elseif def.shape == "Wedge" then
		torso = wedge(model, "Torso", torsoSize, torsoCentre, def.color)
	else
		torso = part(model, "Torso", torsoSize, torsoCentre, def.color)
	end
	torso.CanCollide = false

	-- Short arms angled out from the torso.
	for _, side in ipairs({ -1, 1 }) do
		local arm = part(model, "Arm", Vector3.new(0.8, 2.2, 0.8),
			Vector3.new(side * (torsoSize.X / 2 + 0.5), torsoY + 0.2, 0), def.color)
		arm.CFrame = CFrame.new(Vector3.new(side * (torsoSize.X / 2 + 0.5), torsoY + 0.2, 0))
			* CFrame.Angles(0, 0, side * math.rad(-25))
		arm.CanCollide = false
	end

	-- Big ball head, same colour as the torso.
	local headY = 1.4 + torsoSize.Y + 1.5
	local headCentre = Vector3.new(0, headY, 0)
	local head = ball(model, "Head", 3, headCentre, def.color)
	head.CanCollide = false

	buildFace(model, look.face, headCentre, def.color)

	local hatBuilder = HATS[look.hat]
	if hatBuilder then
		hatBuilder(model, headCentre, def.color)
	end

	local accessoryBuilder = ACCESSORIES[look.accessory]
	if accessoryBuilder then
		accessoryBuilder(model, torsoCentre, headCentre, def.propColor)
	end

	applyMutation(model, torso, head, mutation)

	-- Tag, label and primary part.
	local tag = Instance.new("StringValue")
	tag.Name = "BrainrotDef"
	tag.Value = def.name .. "|" .. mutation
	tag.Parent = model

	attachLabel(model, def, mutation, head)
	model.PrimaryPart = torso

	return model
end

return Factory
