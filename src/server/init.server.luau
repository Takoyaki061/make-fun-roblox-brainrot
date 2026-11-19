-- init.server.luau — Brainrot Bazaar: wire it together and run the game.
-- The server owns all money; the client only displays what the server sends.
-- NOTE: MaxPlayers is set in Studio's Game Settings, never assigned at
-- runtime — it is read-only and assigning it aborts this script. The other
-- modules are SIBLINGS of this script (children of the Server folder), so
-- they are required through script.Parent, never through the script itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cast = require(Shared:WaitForChild("Cast"))
local State = require(script.Parent:WaitForChild("State"))
local World = require(script.Parent:WaitForChild("World"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

-- ---------------------------------------------------------------------------
-- World and remotes
-- ---------------------------------------------------------------------------

local built = World.buildWorld()
local bases = built.bases
local SPAWN_POSITION = built.spawnPosition

local BrainrotAction = Instance.new("RemoteEvent")
BrainrotAction.Name = "BrainrotAction"
BrainrotAction.Parent = ReplicatedStorage

local BrainrotState = Instance.new("RemoteEvent")
BrainrotState.Name = "BrainrotState"
BrainrotState.Parent = ReplicatedStorage

local BrainrotFeed = Instance.new("RemoteEvent")
BrainrotFeed.Name = "BrainrotFeed"
BrainrotFeed.Parent = ReplicatedStorage

State.initBases(#bases)

local function announce(text)
	BrainrotFeed:FireAllClients(text)
end

local function sendSnapshot(player)
	local snap = State.snapshot(player)
	if snap then
		BrainrotState:FireClient(player, snap)
	end
end

-- ---------------------------------------------------------------------------
-- Conveyor walkers
-- ---------------------------------------------------------------------------

local walkers = {} -- { model, speed, bobPhase }
local spawnTimer = 0

local function spawnWalker(seed)
	if #walkers >= Cast.MAX_WALKERS then
		return
	end
	local def = Cast.rollCharacter()
	local mutation = Cast.rollMutation()
	local model = Factory.buildBrainrot(def, mutation)
	model:PivotTo(CFrame.new(built.conveyorStart))
	Factory.attachBuyPrompt(model, def.cost)
	model.Parent = built.world
	local speed = 5 + math.random() * 3
	table.insert(walkers, { model = model, speed = speed, bobPhase = math.random() * math.pi * 2 })
	if def.rarity == "Mythic" or def.rarity == "Secret" then
		announce("A " .. mutation .. " " .. def.name .. " (" .. def.rarity .. ") just spawned on the conveyor!")
	end
end

local function removeWalker(index, destroy)
	local entry = walkers[index]
	if not entry then
		return
	end
	table.remove(walkers, index)
	if destroy and entry.model and entry.model.Parent then
		entry.model:Destroy()
	end
end

local function findWalker(model)
	for i, entry in ipairs(walkers) do
		if entry.model == model then
			return i
		end
	end
	return nil
end

-- Seed 3 brainrots AFTER the prompt wiring below, so their BUY prompts are
-- connected. (They are spawned here in code order, after the DescendantAdded
-- hook, not at the top of the file.)

-- ---------------------------------------------------------------------------
-- Stealing (single-writer: one active steal per brainrot)
-- ---------------------------------------------------------------------------

-- The Sneaky Snatcher NPC. Declared here, above doSlap, so the slap code
-- sees this local instead of a global: a local declared after a function is
-- invisible to it in Luau.
local snatcher = nil -- { model, state, target, targetBase, channelUntil, victim }
local thiefTimer = 0

-- activeSteals[model] = { thief = player, started = clock }
local activeSteals = {}

local function clearStealFor(player)
	for model, steal in pairs(activeSteals) do
		if steal.thief == player then
			activeSteals[model] = nil
		end
	end
end

local function onStealHoldBegan(player, model)
	-- Only one thief may hold a brainrot at a time.
	if activeSteals[model] then
		return
	end
	if State.isStealBanned(player) then
		announce(player.DisplayName .. " was slapped recently and cannot steal yet!")
		return
	end
	activeSteals[model] = { thief = player, started = os.clock() }
end

local function onStealHoldEnded(player, model)
	local steal = activeSteals[model]
	if steal and steal.thief == player then
		activeSteals[model] = nil
	end
end

local function onStealTriggered(player, model)
	local steal = activeSteals[model]
	if not steal or steal.thief ~= player then
		return
	end
	activeSteals[model] = nil
	if State.isStealBanned(player) then
		return
	end
	-- Whose brainrot is it? Find the victim by scanning every base.
	local victim = nil
	for _, other in ipairs(Players:GetPlayers()) do
		local record = State.get(other)
		if record then
			for _, owned in ipairs(record.owned) do
				if owned == model then
					victim = other
					break
				end
			end
		end
		if victim then
			break
		end
	end
	if not victim then
		return
	end
	if victim == player then
		announce("You cannot steal from yourself!")
		return
	end
	if State.isBaseLocked(victim) then
		announce(victim.DisplayName .. "'s base is locked — the steal failed!")
		return
	end
	if not State.canSteal(player) then
		announce(player.DisplayName .. " must wait before stealing again!")
		return
	end
	local thiefRecord = State.get(player)
	if not thiefRecord then
		return
	end
	local slotIndex = State.ownedCount(player) + 1
	local slotCFrame = bases[thiefRecord.baseIndex].slots[slotIndex]
	local ok, message = State.transferBrainrot(player, victim, model, slotCFrame)
	if ok then
		local tag = model:FindFirstChild("BrainrotDef")
		local name = tag and string.match(tag.Value, "^(.-)|") or "a brainrot"
		announce(player.DisplayName .. " stole " .. name .. " from " .. victim.DisplayName .. "!")
	else
		announce(message)
	end
end

-- ---------------------------------------------------------------------------
-- Buying (BUY prompt fires on E)
-- ---------------------------------------------------------------------------

local function onBuyTriggered(player, model)
	local walkerIndex = findWalker(model)
	if not walkerIndex then
		return -- no longer on the belt (already bought or despawned)
	end
	local record = State.get(player)
	if not record then
		return
	end
	local slotIndex = State.ownedCount(player) + 1
	local slotCFrame = bases[record.baseIndex].slots[slotIndex]
	local ok, message = State.buyBrainrot(player, model, slotCFrame)
	if not ok then
		announce(message)
		return
	end
	removeWalker(walkerIndex, false)
	model.Parent = built.world
	Factory.attachStealPrompt(model)
	local tag = model:FindFirstChild("BrainrotDef")
	local name = tag and string.match(tag.Value, "^(.-)|") or "a brainrot"
	announce(player.DisplayName .. " bought " .. name .. "!")
	sendSnapshot(player)
end

-- Re-wire prompts whenever a new brainrot enters the world.
-- NOTE: the seed walkers are spawned after this hook is connected (see the
-- loop at the end of this section), so their BUY prompts get wired too.
built.world.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
		local model = descendant.Parent
		if model and model:IsA("Model") then
			if descendant.Name == "BuyPrompt" then
				descendant.Triggered:Connect(function(player)
					onBuyTriggered(player, model)
				end)
			elseif descendant.Name == "StealPrompt" then
				descendant.PromptButtonHoldBegan:Connect(function(player)
					onStealHoldBegan(player, model)
				end)
				descendant.PromptButtonHoldEnded:Connect(function(player)
					onStealHoldEnded(player, model)
				end)
				descendant.Triggered:Connect(function(player)
					onStealTriggered(player, model)
				end)
			end
		end
	end
end)

-- Seed 3 brainrots so the first screenshot already has brainrots walking.
-- This runs after the DescendantAdded hook above, so their BUY prompts are wired.
for _ = 1, 3 do
	spawnWalker()
end

-- ---------------------------------------------------------------------------
-- Slap (F)
-- ---------------------------------------------------------------------------

local function slapPlayer(target)
	local character = target.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end
	rootPart.CFrame = CFrame.new(SPAWN_POSITION)
	humanoid:TakeDamage(0)
end

local function doSlap(player)
	if not State.canSlap(player) then
		return
	end
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	local hitAnyone = false
	if myRoot then
		-- A thief mid-steal within 14 studs gets cancelled, banned, and flung.
		for model, steal in pairs(activeSteals) do
			local thief = steal.thief
			if thief ~= player and thief.Character then
				local thiefRoot = thief.Character:FindFirstChild("HumanoidRootPart")
				if thiefRoot and (thiefRoot.Position - myRoot.Position).Magnitude <= Cast.SLAP_RANGE then
					activeSteals[model] = nil
					State.banStealing(thief)
					slapPlayer(thief)
					announce(player.DisplayName .. " SLAPPED " .. thief.DisplayName .. " away from the steal!")
					hitAnyone = true
				end
			end
		end
		-- The Sneaky Snatcher, while stealing, can be slapped away too.
		if snatcher and snatcher.state == "stealing" then
			local snatcherRoot = snatcher.model and snatcher.model.PrimaryPart
			if snatcherRoot and (snatcherRoot.Position - myRoot.Position).Magnitude <= Cast.SLAP_RANGE then
				snatcher.state = "fleeing"
				announce(player.DisplayName .. " slapped the Sneaky Snatcher away!")
				hitAnyone = true
			end
		end
	end
	if not hitAnyone then
		announce(player.DisplayName .. " slapped at thin air...")
	end
end

-- ---------------------------------------------------------------------------
-- Sneaky Snatcher NPC (declared above, next to doSlap)
-- ---------------------------------------------------------------------------

local function buildSnatcher()
	local model = Instance.new("Model")
	model.Name = "Sneaky Snatcher"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 2, -180)
	root.Parent = model
	model.PrimaryPart = root

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 4, 2)
	body.CFrame = CFrame.new(0, 4, -180)
	body.Color = Color3.fromRGB(20, 20, 25)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = false
	body.CanCollide = false
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.6, 2.6, 2.6)
	head.CFrame = CFrame.new(0, 7.2, -180)
	head.Color = Color3.fromRGB(20, 20, 25)
	head.Material = Enum.Material.SmoothPlastic
	head.Shape = Enum.PartType.Ball
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model
	local mask = Instance.new("Part")
	mask.Name = "Mask"
	mask.Size = Vector3.new(2.0, 0.8, 0.4)
	mask.CFrame = CFrame.new(0, 7.4, -178.6)
	mask.Color = Color3.fromRGB(160, 60, 255)
	mask.Material = Enum.Material.Neon
	mask.Anchored = false
	mask.CanCollide = false
	mask.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "SnatcherLabel"
	gui.Size = UDim2.new(0, 220, 0, 40)
	gui.StudsOffset = Vector3.new(0, 9.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SNEAKY SNATCHER"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = built.world
	return model
end

local function maybeSpawnSnatcher()
	if snatcher then
		return
	end
	-- Pick a random unlocked, occupied base.
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local record = State.get(player)
		if record and State.ownedCount(player) > 0 and not State.isBaseLocked(player) then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return
	end
	local victim = candidates[math.random(#candidates)]
	local record = State.get(victim)
	snatcher = {
		model = buildSnatcher(),
		state = "walking",
		victim = victim,
		targetBase = record.baseIndex,
		channelUntil = 0,
	}
	announce("The Sneaky Snatcher is on the loose! Guard your base!")
end

local function updateSnatcher(dt)
	if not snatcher then
		return
	end
	local root = snatcher.model.PrimaryPart
	if not root then
		snatcher = nil
		return
	end
	local targetPos
	if snatcher.state == "walking" then
		targetPos = bases[snatcher.targetBase].centre
		local pos = root.Position
		local toTarget = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
		local dist = toTarget.Magnitude
		if dist < 6 then
			snatcher.state = "stealing"
			snatcher.channelUntil = os.clock() + Cast.THIEF_CHANNEL
			announce("The Sneaky Snatcher is stealing from " .. snatcher.victim.DisplayName .. "'s base!")
		else
			local step = toTarget.Unit * math.min(10 * dt, dist)
			root.CFrame = CFrame.new(pos + step)
		end
	elseif snatcher.state == "stealing" then
		-- Give up if the base gets locked or the owner leaves.
		local record = State.get(snatcher.victim)
		if not record or State.isBaseLocked(snatcher.victim) then
			snatcher.state = "fleeing"
			announce("The Sneaky Snatcher gave up — the base was locked!")
			return
		end
		if os.clock() >= snatcher.channelUntil then
			-- Destroy the newest brainrot on the victim's base.
			local owned = record.owned
			local stolen = owned[#owned]
			if stolen then
				State.dropBrainrot(snatcher.victim, stolen)
				stolen:Destroy()
				announce("The Sneaky Snatcher stole a brainrot from " .. snatcher.victim.DisplayName .. "!")
				sendSnapshot(snatcher.victim)
			end
			snatcher.state = "fleeing"
		end
	elseif snatcher.state == "fleeing" then
		targetPos = Vector3.new(0, 2, -180)
		local pos = root.Position
		local toTarget = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
		local dist = toTarget.Magnitude
		if dist < 4 then
			snatcher.model:Destroy()
			snatcher = nil
		else
			local step = toTarget.Unit * math.min(16 * dt, dist)
			root.CFrame = CFrame.new(pos + step)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Grinder Pit sweeper
-- ---------------------------------------------------------------------------

local sweeperAngle = 0

local function updateSweeper(dt)
	sweeperAngle += 1.2 * dt
	local centre = built.pitCentre
	built.sweeper.CFrame = CFrame.new(centre + Vector3.new(0, 4, 0)) * CFrame.Angles(0, sweeperAngle, 0)
	-- Any player within 32 studs of the centre (and more than 2 away) who is
	-- lined up with the bar gets teleported back to spawn.
	local barDir = Vector3.new(math.cos(sweeperAngle), 0, -math.sin(sweeperAngle))
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local offset = Vector3.new(rootPart.Position.X - centre.X, 0, rootPart.Position.Z - centre.Z)
			local dist = offset.Magnitude
			if dist > 2 and dist <= 32 then
				local across = math.abs(offset.Unit:Dot(Vector3.new(-barDir.Z, 0, barDir.X)))
				if across < 0.12 then
					slapPlayer(player)
					announce(player.DisplayName .. " got swept by the Grinder Pit!")
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Client actions
-- ---------------------------------------------------------------------------

BrainrotAction.OnServerEvent:Connect(function(player, action)
	local record = State.get(player)
	if not record then
		return
	end
	if action == "Lock" then
		local ok, message = State.lockBase(player)
		announce(message)
		if ok then
			bases[record.baseIndex].label.Text = "LOCKED - " .. string.upper(player.DisplayName) .. "'S BASE"
		end
		sendSnapshot(player)
	elseif action == "Slap" then
		doSlap(player)
	elseif action == "Rebirth" then
		local ok, message = State.rebirthPlayer(player)
		announce(message)
		if ok then
			bases[record.baseIndex].label.Text = string.upper(player.DisplayName) .. "'S BASE"
		end
		sendSnapshot(player)
	elseif action == "Upgrade" then
		local ok, message = State.buyUpgrade(player)
		announce(message)
		sendSnapshot(player)
	end
end)

-- ---------------------------------------------------------------------------
-- Joining and leaving
-- ---------------------------------------------------------------------------

local function onPlayerAdded(player)
	local record = State.register(player)
	if not record then
		player:Kick("Brainrot Bazaar is full (8 players max).")
		return
	end
	bases[record.baseIndex].label.Text = string.upper(player.DisplayName) .. "'S BASE"
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = CFrame.new(SPAWN_POSITION)
		end
	end)
	player:LoadCharacter()
	announce(player.DisplayName .. " joined the Bazaar!")
	sendSnapshot(player)
end

local function onPlayerRemoving(player)
	clearStealFor(player)
	local record = State.get(player)
	if record then
		bases[record.baseIndex].label.Text = "BASE " .. record.baseIndex
	end
	if snatcher and snatcher.victim == player then
		snatcher.state = "fleeing"
	end
	State.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

local incomeTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- Walk the conveyor.
	for i = #walkers, 1, -1 do
		local entry = walkers[i]
		local model = entry.model
		if not model or not model.Parent then
			table.remove(walkers, i)
		else
			local root = model.PrimaryPart
			if root then
				local pos = root.Position
				local bob = math.sin(os.clock() * 6 + entry.bobPhase) * 0.25
				local newPos = pos + Vector3.new(0, 0, -entry.speed * dt)
				newPos = Vector3.new(newPos.X, 2 + bob, newPos.Z)
				root.CFrame = CFrame.new(newPos)
				if newPos.Z <= built.conveyorEnd.Z then
					removeWalker(i, true)
				end
			end
		end
	end

	-- Spawn on the 4 s timer.
	spawnTimer += dt
	if spawnTimer >= Cast.SPAWN_INTERVAL then
		spawnTimer = 0
		spawnWalker()
	end

	-- The thief raids every 60 s.
	thiefTimer += dt
	if thiefTimer >= Cast.THIEF_INTERVAL then
		thiefTimer = 0
		maybeSpawnSnatcher()
	end
	updateSnatcher(dt)
	updateSweeper(dt)

	-- Every 1 s: pay income and broadcast a snapshot to every player.
	incomeTimer += dt
	if incomeTimer >= 1 then
		incomeTimer = 0
		State.collectIncome()
		for _, player in ipairs(Players:GetPlayers()) do
			sendSnapshot(player)
			-- Clear a finished lock's sign.
			local record = State.get(player)
			if record and not State.isBaseLocked(player) then
				local label = bases[record.baseIndex].label
				if string.sub(label.Text, 1, 6) == "LOCKED" then
					label.Text = string.upper(player.DisplayName) .. "'S BASE"
				end
			end
		end
	end
end)

print("Brainrot Bazaar server running: 8 bases, conveyor live, sweeper spinning.")
