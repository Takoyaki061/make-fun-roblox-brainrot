-- BrainrotFactory.luau — builds every brainrot out of plain parts.
-- One module, one job: turn a Cast entry (plus a mutation) into a Model
-- that walks the conveyor, wears a readable name/rarity/$-per-sec label,
-- and carries the prompts players buy and steal with. No meshes, no assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))

local Factory = {}

local EYE_COLOR = Color3.fromRGB(255, 255, 255)
local PUPIL_COLOR = Color3.fromRGB(20, 20, 20)

local function newPart(name, size, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
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

-- The floating label every brainrot wears: name, rarity, $/sec, mutation.
function Factory.attachLabel(model, def, mutation)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.fromOffset(220, 90)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
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
	local shell = newPart("MutationGlow", Vector3.new(3.4, 3.4, 3.4), color, "Ball")
	shell.Material = Enum.Material.Neon
	shell.Transparency = 0.75
	shell.CFrame = CFrame.new(0, 5.2, 0)
	shell.Parent = model
end

-- Build the Model for one brainrot. Returns the model; the caller places it.
function Factory.buildBrainrot(def, mutation)
	local model = Instance.new("Model")
	model.Name = def.name

	-- Torso: the shape and colour are the character's silhouette.
	local body = newPart("Body", Vector3.new(3, 3.4, 2.4), def.color, def.body)
	body.CFrame = CFrame.new(0, 2.6, 0)
	body.Parent = model

	-- Head: a big ball with two googly eyes, because brainrot.
	local head = newPart("Head", Vector3.new(2.6, 2.6, 2.6), def.color, "Ball")
	head.CFrame = CFrame.new(0, 5.2, 0)
	head.Parent = model

	for _, side in ipairs({ -0.6, 0.6 }) do
		local eye = newPart("Eye", Vector3.new(0.7, 0.9, 0.4), EYE_COLOR, "Ball")
		eye.CFrame = CFrame.new(side, 5.5, 1.2)
		eye.Parent = model
		local pupil = newPart("Pupil", Vector3.new(0.35, 0.45, 0.2), PUPIL_COLOR, "Ball")
		pupil.CFrame = CFrame.new(side, 5.5, 1.45)
		pupil.Parent = model
	end

	-- The silly prop it drags around, floating at its side, named for what
	-- it is so the place tree reads like the cast list.
	local accent = newPart(def.accent, Vector3.new(1.4, 1.4, 1.4), def.accentColor, "Ball")
	accent.CFrame = CFrame.new(2.4, 1.4, 0.6)
	accent.Parent = model

	-- Stubby legs so it waddles instead of gliding.
	for _, side in ipairs({ -0.8, 0.8 }) do
		local leg = newPart("Leg", Vector3.new(0.8, 1.2, 0.8), Color3.fromRGB(40, 40, 40), "Block")
		leg.CFrame = CFrame.new(side, 0.6, 0)
		leg.Parent = model
	end

	-- Mutation treatment: golden brainrots shine, rainbow ones glow blue,
	-- diamond ones turn to glass with a bright shell.
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
