-- BrainrotFactory.luau — builds every brainrot out of plain parts.
-- One module, one job: turn a Cast entry (plus a mutation) into a Model
-- that walks the conveyor, wears a readable name/rarity/$-per-sec label,
-- and carries the prompts players buy and steal with. No meshes, no assets.
-- Every character is a chunky little figure now: legs with shoes, arms, a
-- face with eyes and a mouth, a hat or headgear, and a signature 3D prop
-- built from 2-5 parts, so each one reads from across the map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))

local Factory = {}

local EYE_COLOR = Color3.fromRGB(255, 255, 255)
local PUPIL_COLOR = Color3.fromRGB(20, 20, 20)
local DARK = Color3.fromRGB(40, 40, 40)
local CHEEK = Color3.fromRGB(255, 150, 170)

local function newPart(name, size, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		part.Shape = Enum.PartType.Wedge
	else
		part.Shape = Enum.PartType.Block
	end
	return part
end

-- Place a part at a CFrame and parent it. One-liner to keep builders tidy.
local function put(part, model, cframe)
	part.CFrame = cframe
	part.Parent = model
	return part
end

-- The floating label every brainrot wears: name, rarity, $/sec, mutation.
function Factory.attachLabel(model, def, mutation)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.fromOffset(220, 90)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.38)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.fromScale(0, 0.38)
	rarityLabel.Size = UDim2.fromScale(1, 0.3)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = def.rarity .. "  •  " .. mutation.name
	rarityLabel.TextColor3 = Cast.RARITY_COLORS[def.rarity] or Color3.fromRGB(255, 255, 255)
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = gui

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.fromScale(0, 0.68)
	rateLabel.Size = UDim2.fromScale(1, 0.32)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = Cast.formatMoney(Cast.baseRate(def, mutation)) .. "/sec"
	rateLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
	rateLabel.TextStrokeTransparency = 0
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.Parent = gui
end

-- A buy prompt on a conveyor brainrot, or a steal prompt on a based one.
function Factory.attachPrompt(model, kind, cost)
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = kind .. "Prompt"
	prompt.ActionText = kind
	prompt.ObjectText = model.Name
	if kind == "BUY" then
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.ObjectText = "BUY " .. Cast.formatMoney(cost)
	else
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = Cast.STEAL_SECONDS
		prompt.ObjectText = "HOLD TO STEAL"
	end
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	return prompt
end

-- A glow shell around the head, so Rainbow and Diamond brainrots read as
-- special from across the map instead of only on their label.
local function addGlowShell(model, color)
	local shell = newPart("MutationGlow", Vector3.new(3.8, 3.8, 3.8), color, "Ball")
	shell.Material = Enum.Material.Neon
	shell.Transparency = 0.75
	put(shell, model, CFrame.new(0, 5.6, 0))
end

-- Legs with shoes, so the figure stands on something instead of floating.
local function addLegs(model, shoeColor)
	for _, side in ipairs({ -0.85, 0.85 }) do
		local leg = newPart("Leg", Vector3.new(0.9, 1.4, 0.9), DARK, "Block")
		put(leg, model, CFrame.new(side, 0.7, 0))
		local shoe = newPart("Shoe", Vector3.new(1.1, 0.5, 1.7), shoeColor, "Block")
		put(shoe, model, CFrame.new(side, 0.25, 0.25))
	end
end

-- Short arms at the sides, slightly angled out like a waddling figure.
-- NOTE: a Cylinder part's long axis is X, so a vertical arm needs size
-- (length, diameter, diameter) rotated 90 degrees about Z.
local function addArms(model, color)
	for _, side in ipairs({ -1, 1 }) do
		local arm = newPart("Arm", Vector3.new(2.2, 0.7, 0.7), color, "Cylinder")
		local cf = CFrame.new(side * 2.0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90) + side * 0.25)
		put(arm, model, cf)
		local hand = newPart("Hand", Vector3.new(0.8, 0.8, 0.8), color, "Ball")
		put(hand, model, CFrame.new(side * 2.25, 2.0, 0))
	end
end

-- Face: two googly eyes, pupils, a mouth, and chubby cheeks. Variants:
-- "default" (smile), "droopy" (soggy, with a tear), "toothy" (grin),
-- "shout" (open mouth), "glasses" (spectacles + smile).
local function addFace(model, variant, headY, headZ)
	local eyeY = headY + 0.35
	local mouthY = headY - 0.55
	if variant == "droopy" then
		eyeY = headY + 0.1
		mouthY = headY - 0.75
	end
	for _, side in ipairs({ -0.65, 0.65 }) do
		local eye = newPart("Eye", Vector3.new(0.75, 0.9, 0.4), EYE_COLOR, "Ball")
		put(eye, model, CFrame.new(side, eyeY, headZ))
		local pupil = newPart("Pupil", Vector3.new(0.35, 0.45, 0.2), PUPIL_COLOR, "Ball")
		put(pupil, model, CFrame.new(side, eyeY, headZ + 0.25))
	end
	if variant == "droopy" then
		-- A tear dripping from the left eye, and a downturned mouth.
		local tear = newPart("Tear", Vector3.new(0.3, 0.6, 0.2), Color3.fromRGB(120, 200, 255), "Ball")
		tear.Material = Enum.Material.Glass
		put(tear, model, CFrame.new(-0.65, eyeY - 0.9, headZ + 0.1))
		local mouth = newPart("Mouth", Vector3.new(1.0, 0.25, 0.2), PUPIL_COLOR, "Block")
		put(mouth, model, CFrame.new(0, mouthY, headZ + 0.05) * CFrame.Angles(0, 0, math.rad(180)))
	elseif variant == "toothy" then
		for i = -1, 1 do
			local tooth = newPart("Tooth", Vector3.new(0.45, 0.4, 0.2), Color3.fromRGB(255, 255, 255), "Block")
			put(tooth, model, CFrame.new(i * 0.5, mouthY, headZ + 0.05))
		end
		local mouth = newPart("Mouth", Vector3.new(1.7, 0.5, 0.2), PUPIL_COLOR, "Block")
		put(mouth, model, CFrame.new(0, mouthY - 0.05, headZ))
	elseif variant == "shout" then
		local mouth = newPart("Mouth", Vector3.new(0.9, 0.9, 0.3), PUPIL_COLOR, "Block")
		put(mouth, model, CFrame.new(0, mouthY, headZ + 0.05))
	elseif variant == "glasses" then
		-- Spectacles: a square frame of four thin blocks per eye, so the
		-- eyes stay visible through the middle.
		for _, side in ipairs({ -0.65, 0.65 }) do
			local fz = headZ + 0.15
			local top = newPart("GlassesFrame", Vector3.new(1.1, 0.15, 0.1), DARK, "Block")
			put(top, model, CFrame.new(side, eyeY + 0.5, fz))
			local bottom = newPart("GlassesFrame", Vector3.new(1.1, 0.15, 0.1), DARK, "Block")
			put(bottom, model, CFrame.new(side, eyeY - 0.5, fz))
			local left = newPart("GlassesFrame", Vector3.new(0.15, 1.1, 0.1), DARK, "Block")
			put(left, model, CFrame.new(side - 0.5, eyeY, fz))
			local right = newPart("GlassesFrame", Vector3.new(0.15, 1.1, 0.1), DARK, "Block")
			put(right, model, CFrame.new(side + 0.5, eyeY, fz))
		end
		local bridge = newPart("GlassesBridge", Vector3.new(0.6, 0.15, 0.15), DARK, "Block")
		put(bridge, model, CFrame.new(0, eyeY, headZ + 0.1))
		local mouth = newPart("Mouth", Vector3.new(0.9, 0.25, 0.2), PUPIL_COLOR, "Block")
		put(mouth, model, CFrame.new(0, mouthY, headZ + 0.05))
	else
		-- Default: a gentle smile made of three tiny blocks.
		for i, off in ipairs({ -0.45, 0, 0.45 }) do
			local bit = newPart("Mouth", Vector3.new(0.4, 0.22, 0.2), PUPIL_COLOR, "Block")
			local tilt = (i - 2) * 0.5
			put(bit, model, CFrame.new(off, mouthY + math.abs(off) * 0.25, headZ + 0.05)
				* CFrame.Angles(0, 0, tilt))
		end
	end
	-- Chubby cheeks on every face.
	for _, side in ipairs({ -1.05, 1.05 }) do
		local cheek = newPart("Cheek", Vector3.new(0.5, 0.5, 0.3), CHEEK, "Ball")
		put(cheek, model, CFrame.new(side, headY - 0.25, headZ - 0.05))
	end
end

-- Hats and headgear, one kind per character. headTopY is the top of the head.
local function addHat(model, kind, color, headTopY)
	if kind == "crust" then
		-- A darker crust cap layered on the crouton's head.
		local cap = newPart("Hat", Vector3.new(3.2, 0.6, 3.2), Color3.fromRGB(140, 100, 50), "Block")
		put(cap, model, CFrame.new(0, headTopY + 0.1, 0))
	elseif kind == "headband" then
		local band = newPart("Hat", Vector3.new(3.1, 0.45, 3.1), Color3.fromRGB(255, 200, 40), "Block")
		put(band, model, CFrame.new(0, headTopY - 0.7, 0))
	elseif kind == "nozzle" then
		-- Sprinkler nozzle: a cylinder on top with spray-hole nubs.
		-- (Cylinder axis is X: an upright nozzle is (h, d, d) + Z 90.)
		local noz = newPart("Hat", Vector3.new(1.0, 1.4, 1.4), Color3.fromRGB(40, 120, 60), "Cylinder")
		put(noz, model, CFrame.new(0, headTopY + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 1, 4 do
			local a = math.rad(i * 90)
			local hole = newPart("SprayHole", Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(200, 230, 255), "Ball")
			put(hole, model, CFrame.new(math.cos(a) * 0.8, headTopY + 0.9, math.sin(a) * 0.8))
		end
	elseif kind == "doily" then
		-- Doily hat: a flat white disc with scalloped rim balls.
		local disc = newPart("Hat", Vector3.new(0.3, 3.6, 3.6), Color3.fromRGB(250, 240, 220), "Cylinder")
		put(disc, model, CFrame.new(0, headTopY + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 1, 8 do
			local a = math.rad(i * 45)
			local scallop = newPart("DoilyRim", Vector3.new(0.5, 0.3, 0.5), Color3.fromRGB(250, 240, 220), "Ball")
			put(scallop, model, CFrame.new(math.cos(a) * 1.8, headTopY + 0.2, math.sin(a) * 1.8))
		end
	elseif kind == "halo" then
		local halo = newPart("Hat", Vector3.new(0.25, 2.8, 2.8), Color3.fromRGB(255, 210, 60), "Cylinder")
		halo.Material = Enum.Material.Neon
		put(halo, model, CFrame.new(0, headTopY + 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif kind == "cap" then
		local dome = newPart("Hat", Vector3.new(0.9, 2.8, 2.8), Color3.fromRGB(200, 60, 60), "Cylinder")
		put(dome, model, CFrame.new(0, headTopY + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local brim = newPart("HatBrim", Vector3.new(2.4, 0.25, 1.4), Color3.fromRGB(180, 40, 40), "Block")
		put(brim, model, CFrame.new(0, headTopY, 1.6))
	elseif kind == "helm" then
		-- Great helm: a cylinder covering the head top, with a visor slit.
		local helm = newPart("Hat", Vector3.new(2.0, 2.9, 2.9), color, "Cylinder")
		put(helm, model, CFrame.new(0, headTopY + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local visor = newPart("Visor", Vector3.new(2.2, 0.5, 0.3), Color3.fromRGB(20, 20, 20), "Block")
		put(visor, model, CFrame.new(0, headTopY - 0.1, 1.45))
	elseif kind == "starhat" then
		local brim = newPart("Hat", Vector3.new(0.3, 3.8, 3.8), Color3.fromRGB(255, 220, 60), "Cylinder")
		put(brim, model, CFrame.new(0, headTopY + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 1, 5 do
			local a = math.rad(i * 72)
			local point = newPart("StarPoint", Vector3.new(1.0, 1.6, 0.4), Color3.fromRGB(255, 220, 60), "Wedge")
			put(point, model, CFrame.new(math.cos(a) * 1.2, headTopY + 0.8, math.sin(a) * 1.2)
				* CFrame.Angles(0, -a, 0))
		end
	elseif kind == "panel" then
		-- Washing-machine control panel with dials.
		local panel = newPart("Hat", Vector3.new(2.6, 0.8, 2.6), Color3.fromRGB(60, 60, 70), "Block")
		put(panel, model, CFrame.new(0, headTopY + 0.3, 0))
		for i = -1, 1 do
			local dial = newPart("Dial", Vector3.new(0.3, 0.5, 0.5), Color3.fromRGB(100, 200, 255), "Cylinder")
			put(dial, model, CFrame.new(i * 0.8, headTopY + 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
	elseif kind == "headphones" then
		for _, side in ipairs({ -1.55, 1.55 }) do
			local cup = newPart("Headphone", Vector3.new(0.7, 1.1, 1.1), Color3.fromRGB(40, 40, 40), "Ball")
			put(cup, model, CFrame.new(side, headTopY - 0.6, 0))
		end
		local band = newPart("HeadphoneBand", Vector3.new(3.4, 0.3, 0.5), Color3.fromRGB(40, 40, 40), "Block")
		put(band, model, CFrame.new(0, headTopY + 0.6, 0))
	elseif kind == "antenna" then
		local rod = newPart("Hat", Vector3.new(2.2, 0.25, 0.25), Color3.fromRGB(180, 180, 180), "Cylinder")
		put(rod, model, CFrame.new(0, headTopY + 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local tip = newPart("AntennaTip", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 80, 80), "Ball")
		tip.Material = Enum.Material.Neon
		put(tip, model, CFrame.new(0, headTopY + 2.2, 0))
	elseif kind == "pepperoni" then
		-- A crown of pepperoni discs on the pizza slice.
		for i = 1, 5 do
			local a = math.rad(i * 72)
			local disc = newPart("PepperoniCrown", Vector3.new(0.25, 0.9, 0.9), Color3.fromRGB(200, 40, 40), "Cylinder")
			put(disc, model, CFrame.new(math.cos(a) * 1.1, headTopY + 0.2, math.sin(a) * 1.1)
				* CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

-- Signature accessories, carried at the figure's side (or on the body).
-- Each is 2-5 parts, built to read from a distance.
local function addAccessory(model, kind, def)
	if kind == "puddle" then
		local puddle = newPart("Puddle", Vector3.new(0.2, 4.2, 4.2), Color3.fromRGB(120, 180, 230), "Cylinder")
		puddle.Transparency = 0.4
		put(puddle, model, CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 1, 3 do
			local crumb = newPart("Crumb", Vector3.new(0.5, 0.5, 0.5), def.color, "Ball")
			put(crumb, model, CFrame.new(-1.5 + i * 0.4, 0.3, 1.8 + i * 0.5))
		end
	elseif kind == "flipflop" then
		-- A spare oversized flip-flop held out to the side.
		local sole = newPart("FlipFlop", Vector3.new(1.2, 0.3, 2.4), Color3.fromRGB(255, 120, 180), "Wedge")
		put(sole, model, CFrame.new(2.9, 1.6, 0.4) * CFrame.Angles(0, math.rad(30), 0))
		local strap = newPart("FlipFlopStrap", Vector3.new(0.9, 0.2, 0.2), Color3.fromRGB(255, 220, 60), "Block")
		put(strap, model, CFrame.new(2.9, 1.85, 0.9) * CFrame.Angles(0, math.rad(30), 0))
	elseif kind == "hose" then
		-- Garden hose coil: three stacked rings plus a brass nozzle.
		for i = 1, 3 do
			local ring = newPart("HoseCoil", Vector3.new(0.3, 1.8, 1.8), Color3.fromRGB(40, 120, 60), "Cylinder")
			put(ring, model, CFrame.new(2.7, 1.2 + i * 0.35, 0.3) * CFrame.Angles(0, 0, math.rad(90)))
		end
		local noz = newPart("HoseNozzle", Vector3.new(1.0, 0.5, 0.5), Color3.fromRGB(200, 170, 60), "Cylinder")
		put(noz, model, CFrame.new(2.7, 2.6, 0.3) * CFrame.Angles(0, 0, math.rad(65)))
	elseif kind == "needles" then
		for i, off in ipairs({ -0.2, 0.2 }) do
			local needle = newPart("KnittingNeedle", Vector3.new(2.4, 0.15, 0.15), Color3.fromRGB(200, 200, 200), "Cylinder")
			put(needle, model, CFrame.new(2.6 + off, 2.4, 0.3) * CFrame.Angles(math.rad(15), 0, math.rad(80)))
		end
		local yarn = newPart("YarnBall", Vector3.new(1.0, 1.0, 1.0), Color3.fromRGB(255, 120, 180), "Ball")
		put(yarn, model, CFrame.new(2.6, 1.0, 0.3))
	elseif kind == "wings" then
		for _, side in ipairs({ -1, 1 }) do
			local wing = newPart("Wing", Vector3.new(0.3, 2.4, 2.2), Color3.fromRGB(255, 255, 255), "Wedge")
			put(wing, model, CFrame.new(side * 1.6, 4.2, -1.3) * CFrame.Angles(0, side * math.rad(35), side * math.rad(-25)))
		end
	elseif kind == "cart" then
		-- Shopping cart: a wireframe basket on four little wheels.
		local basket = newPart("CartBasket", Vector3.new(2.6, 1.6, 1.8), Color3.fromRGB(180, 180, 180), "Block")
		basket.Transparency = 0.55
		put(basket, model, CFrame.new(3.0, 2.0, 0.3))
		local handle = newPart("CartHandle", Vector3.new(0.25, 0.25, 2.2), Color3.fromRGB(120, 120, 120), "Block")
		put(handle, model, CFrame.new(1.8, 2.9, 0.3))
		for _, dx in ipairs({ -1.0, 1.0 }) do
			for _, dz in ipairs({ -0.7, 0.7 }) do
				local wheel = newPart("CartWheel", Vector3.new(0.5, 0.5, 0.5), DARK, "Cylinder")
				put(wheel, model, CFrame.new(3.0 + dx, 0.6, 0.3 + dz))
			end
		end
	elseif kind == "lance" then
		local shaft = newPart("Lance", Vector3.new(6.5, 0.5, 0.5), Color3.fromRGB(120, 220, 120), "Cylinder")
		put(shaft, model, CFrame.new(2.8, 3.6, 0.3) * CFrame.Angles(0, 0, math.rad(90)))
		local tip = newPart("LanceTip", Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(160, 240, 160), "Ball")
		put(tip, model, CFrame.new(2.8, 7.0, 0.3))
	elseif kind == "shawl" then
		local shawl = newPart("Shawl", Vector3.new(3.8, 1.0, 3.8), Color3.fromRGB(120, 60, 200), "Ball")
		put(shawl, model, CFrame.new(0, 4.9, 0))
		for i = 1, 5 do
			local a = math.rad(i * 72)
			local star = newPart("ShawlStar", Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(255, 255, 255), "Ball")
			star.Material = Enum.Material.Neon
			put(star, model, CFrame.new(math.cos(a) * 1.6, 5.1, math.sin(a) * 1.6))
		end
	elseif kind == "porthole" then
		-- Flat ring facing forward: cylinder (thin, d, d) rotated about Y.
		local ring = newPart("PortholeRing", Vector3.new(0.3, 2.4, 2.4), Color3.fromRGB(120, 120, 130), "Cylinder")
		put(ring, model, CFrame.new(0, 3.2, 1.35) * CFrame.Angles(0, math.rad(90), 0))
		local glass = newPart("PortholeGlass", Vector3.new(1.8, 1.8, 0.2), Color3.fromRGB(120, 200, 255), "Ball")
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.3
		put(glass, model, CFrame.new(0, 3.2, 1.45))
		local handle = newPart("PortholeHandle", Vector3.new(1.2, 0.3, 0.3), Color3.fromRGB(100, 200, 255), "Block")
		put(handle, model, CFrame.new(0, 4.6, 1.4))
	elseif kind == "turntables" then
		local deck = newPart("TurntableDeck", Vector3.new(3.0, 1.0, 2.2), Color3.fromRGB(40, 40, 40), "Block")
		put(deck, model, CFrame.new(3.0, 1.8, 0.3))
		for _, dz in ipairs({ -0.55, 0.55 }) do
			local platter = newPart("Turntable", Vector3.new(0.2, 1.4, 1.4), Color3.fromRGB(20, 20, 20), "Cylinder")
			put(platter, model, CFrame.new(3.0, 2.4, 0.3 + dz) * CFrame.Angles(0, 0, math.rad(90)))
			local label = newPart("VinylLabel", Vector3.new(0.25, 0.5, 0.5), Color3.fromRGB(255, 80, 80), "Cylinder")
			put(label, model, CFrame.new(3.0, 2.5, 0.3 + dz) * CFrame.Angles(0, 0, math.rad(90)))
		end
	elseif kind == "modem" then
		local box = newPart("Modem", Vector3.new(2.4, 1.4, 1.6), Color3.fromRGB(240, 240, 200), "Block")
		put(box, model, CFrame.new(2.9, 1.8, 0.3))
		for i = 1, 3 do
			local light = newPart("ModemLight", Vector3.new(0.3, 0.3, 0.2), Color3.fromRGB(80, 255, 120), "Ball")
			light.Material = Enum.Material.Neon
			put(light, model, CFrame.new(2.3 + i * 0.5, 2.2, 1.15))
		end
	elseif kind == "pepperoni" then
		-- Pepperoni discs stuck on the pizza body.
		for i, pos in ipairs({ { -0.8, 3.4, 1.2 }, { 0.8, 2.6, 1.3 }, { 0, 4.2, 1.2 } }) do
			local disc = newPart("Pepperoni", Vector3.new(0.2, 0.9, 0.9), Color3.fromRGB(200, 40, 40), "Cylinder")
			put(disc, model, CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
end

-- Per-character look: hat kind, accessory kind, face variant, shoe colour,
-- and body/head size overrides. Economy (cost/rate/rarity) is NOT here.
local LOOKS = {
	["Soggy Crouton Kevin"] = { hat = "crust", acc = "puddle", face = "droopy",
		shoes = Color3.fromRGB(120, 90, 50), bodySize = Vector3.new(3.4, 3.2, 3.0) },
	["Sandal Lord Zorp"] = { hat = "headband", acc = "flipflop", face = "default",
		shoes = Color3.fromRGB(255, 120, 180), bodySize = Vector3.new(3.2, 4.0, 2.6) },
	["Sprinkler Goblin Nubbs"] = { hat = "nozzle", acc = "hose", face = "toothy",
		shoes = Color3.fromRGB(40, 120, 60), bodySize = Vector3.new(3.4, 3.0, 2.8) },
	["Grandma Gazebo"] = { hat = "doily", acc = "needles", face = "glasses",
		shoes = Color3.fromRGB(250, 240, 220), bodySize = Vector3.new(3.6, 3.6, 3.0) },
	["Cinderblock Cherub"] = { hat = "halo", acc = "wings", face = "default",
		shoes = Color3.fromRGB(120, 120, 130), bodySize = Vector3.new(3.4, 3.4, 2.6) },
	["The Lawnmower Whisperer"] = { hat = "cap", acc = "cart", face = "shout",
		shoes = Color3.fromRGB(60, 60, 60), bodySize = Vector3.new(3.4, 3.8, 2.8) },
	["Sir Soggybottom III"] = { hat = "helm", acc = "lance", face = "default",
		shoes = Color3.fromRGB(120, 100, 160), bodySize = Vector3.new(3.6, 3.8, 2.8) },
	["Cosmic Grandma Brenda"] = { hat = "starhat", acc = "shawl", face = "glasses",
		shoes = Color3.fromRGB(90, 40, 160), bodySize = Vector3.new(3.6, 3.6, 3.4) },
	["Baron Von Washing Machine"] = { hat = "panel", acc = "porthole", face = "default",
		shoes = Color3.fromRGB(100, 100, 110), bodySize = Vector3.new(3.6, 3.8, 3.0) },
	["DJ Traffic Cone"] = { hat = "headphones", acc = "turntables", face = "toothy",
		shoes = Color3.fromRGB(40, 40, 40), bodySize = Vector3.new(3.2, 4.2, 3.0) },
	["Grandpa Internet"] = { hat = "antenna", acc = "modem", face = "glasses",
		shoes = Color3.fromRGB(100, 140, 100), bodySize = Vector3.new(3.6, 3.4, 3.4) },
	["The Last Slice of Pizza"] = { hat = "pepperoni", acc = "pepperoni", face = "toothy",
		shoes = Color3.fromRGB(200, 160, 90), bodySize = Vector3.new(3.4, 3.4, 3.0) },
}

-- Mutation treatment: golden brainrots shine, rainbow ones glow blue,
-- diamond ones turn to glass with a bright shell.
local function applyMutation(model, body, head, mutation)
	if mutation.name == "Golden" then
		body.Material = Enum.Material.Neon
		head.Material = Enum.Material.Neon
	elseif mutation.name == "Rainbow" then
		body.Color = Color3.fromRGB(120, 200, 255)
		body.Material = Enum.Material.Neon
		addGlowShell(model, Color3.fromRGB(120, 200, 255))
	elseif mutation.name == "Diamond" then
		body.Material = Enum.Material.Glass
		head.Material = Enum.Material.Glass
		addGlowShell(model, Color3.fromRGB(180, 240, 255))
	end
end

-- Build the Model for one brainrot. Returns the model; the caller places it.
-- Layout (local Y): shoes 0-0.5, legs 0-1.4, body centre ~2.8, head centre
-- ~5.6, hat above 7. The pivot sits at the feet, so conveyorStart Y=2 puts
-- the figure standing on the belt.
function Factory.buildBrainrot(def, mutation)
	local model = Instance.new("Model")
	model.Name = def.name
	local look = LOOKS[def.name] or { hat = nil, acc = nil, face = "default",
		shoes = DARK, bodySize = Vector3.new(3.4, 3.6, 2.8) }

	addLegs(model, look.shoes)

	-- Torso: the shape and colour are the character's silhouette.
	local bodySize = look.bodySize
	local body = newPart("Body", bodySize, def.color, def.body)
	put(body, model, CFrame.new(0, 2.8, 0))

	addArms(model, def.color)

	-- Head: a big ball with a proper face.
	local head = newPart("Head", Vector3.new(3.0, 3.0, 3.0), def.color, "Ball")
	put(head, model, CFrame.new(0, 5.6, 0))
	-- Head front face sits at z ~1.5 on a 3-stud ball.
	addFace(model, look.face, 5.6, 1.35)

	if look.hat then
		addHat(model, look.hat, def.color, 7.1)
	end
	if look.acc then
		addAccessory(model, look.acc, def)
	end

	applyMutation(model, body, head, mutation)

	model.PrimaryPart = body
	Factory.attachLabel(model, def, mutation)

	local tag = Instance.new("StringValue")
	tag.Name = "BrainrotDef"
	tag.Value = def.name .. "|" .. mutation.name
	tag.Parent = model

	return model
end

-- Look a character definition up by name (used when a steal moves a model).
function Factory.findDef(name)
	return Cast.findCharacter(name)
end

function Factory.findMutation(name)
	return Cast.findMutation(name)
end

return Factory
