-- init.server.luau
-- The server entry point for Brainrot Bazaar. It wires the world, the
-- player state and the brainrot factory together and runs the game.
--
-- The server owns all money; the client only displays what the server
-- sends. Every client action is validated here before it does anything.
--
-- NOTE: State, World and BrainrotFactory are SIBLINGS of this script
-- (children of the Server folder), so they are required through
-- script.Parent -- requiring them through the script itself would
-- yield forever. MaxPlayers is set in Studio's Game Settings and is
-- never assigned at runtime: it is read-only and assigning it aborts
-- this script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))
local State = require(script.Parent:WaitForChild("State"))
local World = require(script.Parent:WaitForChild("World"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

-- ---------------------------------------------------------------------------
-- Remotes
-- ---------------------------------------------------------------------------

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local ActionRemote = makeRemote("BrainrotAction") -- client -> server
local StateRemote = makeRemote("BrainrotState") -- server -> client snapshots
local FeedRemote = makeRemote("BrainrotFeed") -- server -> all clients, announcements

-- ---------------------------------------------------------------------------
-- World and state
-- ---------------------------------------------------------------------------

local world = World.buildWorld()
State.setup(#world.bases)

local function announce(message)
	FeedRemote:FireAllClients(message)
end

local function sendSnapshot(player)
	local record = State.get(player)
	if not record then
		return
	end
	StateRemote:FireClient(player, State.snapshot(player, os.clock()))
end

local function broadcastSnapshots()
	for _, record in ipairs(State.allRecords()) do
		StateRemote:FireClient(record.player, State.snapshot(record.player, os.clock()))
	end
end

-- Refresh every base sign: locked bases show LOCKED, otherwise the
-- owner's name (or the base number when empty).
local function refreshSigns()
	local now = os.clock()
	for i, base in ipairs(world.bases) do
		local owner = State.baseOwner(i)
		if owner then
			local record = State.get(owner)
			if record and State.isBaseLocked(record, now) then
				base.ownerLabel.Text = "LOCKED - " .. string.upper(owner.Name) .. "'S BASE"
			else
				base.ownerLabel.Text = string.upper(owner.Name) .. "'S BASE"
			end
		else
			base.ownerLabel.Text = "BASE " .. i
		end
	end
end

-- Which player owns this brainrot model, if any.
local function ownerOf(model)
	for _, record in ipairs(State.allRecords()) do
		if table.find(record.owned, model) then
			return record.player
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Conveyor walkers
-- ---------------------------------------------------------------------------

local walkers = {} -- list of { model, speed, phase }

local function removeWalker(model)
	for i, walker in ipairs(walkers) do
		if walker.model == model then
			table.remove(walkers, i)
			return true
		end
	end
	return false
end

local function spawnWalker()
	if #walkers >= Cast.MAX_WALKERS then
		return
	end
	local def = Cast.pickCharacter()
	local mutation = Cast.pickMutation()
	local model = Factory.buildBrainrot(def, mutation)
	model:PivotTo(CFrame.lookAt(world.conveyorStart, world.conveyorStart + Vector3.new(0, 0, -1)))
	model.Parent = workspace
	Factory.attachBuyPrompt(model, def)

	local speed = Cast.WALK_SPEED_MIN + math.random() * (Cast.WALK_SPEED_MAX - Cast.WALK_SPEED_MIN)
	table.insert(walkers, { model = model, speed = speed, phase = math.random() * math.pi * 2 })

	if def.rarity == "Mythic" or def.rarity == "Secret" then
		announce("RARE DROP! " .. def.name .. " (" .. mutation .. ") is on the conveyor!")
	end

	-- Buying: the BUY prompt fires on E.
	local prompt = model.PrimaryPart:FindFirstChild("BuyPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			onBuy(player, model)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Stealing: one active channel per player, one claim per brainrot
-- ---------------------------------------------------------------------------

local activeSteals = {} -- [model] = { thief = Player, owner = Player }
local playerSteal = {} -- [Player] = model they are currently holding on

local function cancelSteal(model, reason)
	local channel = activeSteals[model]
	if not channel then
		return
	end
	activeSteals[model] = nil
	if playerSteal[channel.thief] == model then
		playerSteal[channel.thief] = nil
	end
	if reason then
		FeedRemote:FireClient(channel.thief, reason)
	end
end

-- Cancel every channel a player is part of (they left, were slapped,
-- or their target vanished).
local function cancelStealsFor(player)
	for model, channel in pairs(activeSteals) do
		if channel.thief == player or channel.owner == player then
			activeSteals[model] = nil
			if playerSteal[channel.thief] == model then
				playerSteal[channel.thief] = nil
			end
		end
	end
	if playerSteal[player] then
		playerSteal[player] = nil
	end
end

-- Wire a STEAL prompt on a parked brainrot. Hold-began claims the
-- steal; hold-ended releases it; triggered completes it (after a
-- full re-validation, so a lock or a full base mid-hold still stops it).
local function wireStealPrompt(model)
	local prompt = model.PrimaryPart:FindFirstChild("StealPrompt")
	if not prompt then
		return
	end
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local owner = ownerOf(model)
		if not owner then
			return
		end
		if owner == player then
			FeedRemote:FireClient(player, "That's your own brainrot!")
			return
		end
		if State.isStealBanned(player, os.clock()) then
			FeedRemote:FireClient(player, "You're still dizzy from that slap!")
			return
		end
		if playerSteal[player] then
			return -- one active channel per thief
		end
		if activeSteals[model] then
			FeedRemote:FireClient(player, "Someone is already stealing that one!")
			return
		end
		activeSteals[model] = { thief = player, owner = owner }
		playerSteal[player] = model
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		if playerSteal[player] == model then
			cancelSteal(model)
		end
	end)
	prompt.Triggered:Connect(function(player)
		completeSteal(player, model)
	end)
end

-- The atomic commit: re-check everything at the moment the hold
-- finishes, then move the model in one step. A failed check never
-- strands the brainrot.
function completeSteal(player, model)
	local channel = activeSteals[model]
	if not channel or channel.thief ~= player then
		return
	end
	activeSteals[model] = nil
	playerSteal[player] = nil

	local owner = ownerOf(model)
	if not owner or owner ~= channel.owner then
		FeedRemote:FireClient(player, "Too late -- that brainrot is gone!")
		return
	end
	if owner == player then
		return
	end
	local ownerRecord = State.get(owner)
	local thiefRecord = State.get(player)
	if not ownerRecord or not thiefRecord then
		return
	end
	local now = os.clock()
	if State.isBaseLocked(ownerRecord, now) then
		FeedRemote:FireClient(player, owner.Name .. "'s base is locked!")
		return
	end
	if State.isStealBanned(player, now) then
		FeedRemote:FireClient(player, "You're still dizzy from that slap!")
		return
	end
	local slotIndex = State.nextSlot(thiefRecord)
	if not slotIndex then
		FeedRemote:FireClient(player, "Your base is full!")
		return
	end
	local slotCFrame = world.bases[thiefRecord.baseIndex].slots[slotIndex]
	local ok, _message = State.transferBrainrot(model, owner, player, slotCFrame)
	if not ok then
		FeedRemote:FireClient(player, "Steal failed!")
		return
	end
	announce(player.Name .. " stole a brainrot from " .. owner.Name .. "!")
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

function onBuy(player, model)
	-- The walker must still be on the belt.
	local stillWalking = false
	for _, walker in ipairs(walkers) do
		if walker.model == model then
			stillWalking = true
			break
		end
	end
	if not stillWalking then
		return
	end
	local record = State.get(player)
	if not record then
		return
	end
	local slotIndex = State.nextSlot(record)
	if not slotIndex then
		FeedRemote:FireClient(player, "Your base is full -- rebirth to start over!")
		return
	end
	local slotCFrame = world.bases[record.baseIndex].slots[slotIndex]
	local ok, message = State.buyBrainrot(player, model, slotCFrame)
	if not ok then
		FeedRemote:FireClient(player, message)
		return
	end
	removeWalker(model)
	Factory.attachStealPrompt(model)
	wireStealPrompt(model)
	local tag = model:FindFirstChild("BrainrotDef")
	announce(player.Name .. " bought " .. (tag and tag.Value or "a brainrot") .. "!")
	sendSnapshot(player)
end

-- ---------------------------------------------------------------------------
-- Slap (F)
-- ---------------------------------------------------------------------------

local thief = nil -- the active Sneaky Snatcher NPC, if any

local function flingToSpawn(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(world.spawnPosition)
	end
end

local function doSlap(player)
	local record = State.get(player)
	if not record then
		return
	end
	local now = os.clock()
	if not State.canSlap(player, now) then
		return
	end
	State.markSlap(player, now)

	local slapperRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local slapperPos = slapperRoot and slapperRoot.Position or nil
	local hitAnyone = false

	-- Cancel any mid-steal thief within slap range.
	for model, channel in pairs(activeSteals) do
		local thiefPlayer = channel.thief
		local thiefRoot = thiefPlayer.Character and thiefPlayer.Character:FindFirstChild("HumanoidRootPart")
		if thiefRoot and slapperPos and (thiefRoot.Position - slapperPos).Magnitude <= Cast.SLAP_RANGE then
			cancelSteal(model)
			State.banStealing(thiefPlayer, now)
			flingToSpawn(thiefPlayer)
			-- Disable their steal prompt for 3s so they cannot
			-- instantly re-grab the same brainrot.
			local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("StealPrompt")
			if prompt then
				prompt.Enabled = false
				task.delay(3, function()
					if prompt.Parent then
						prompt.Enabled = true
					end
				end)
			end
			announce(player.Name .. " SLAPPED " .. thiefPlayer.Name .. " away from the steal!")
			hitAnyone = true
		end
	end

	-- Slap the Sneaky Snatcher away while it is stealing.
	if thief and thief.state == "stealing" and slapperPos then
		local thiefModel = thief.model
		local pivot = thiefModel:GetPivot()
		if (pivot.Position - slapperPos).Magnitude <= Cast.SLAP_RANGE then
			thief.state = "fleeing"
			announce(player.Name .. " slapped the Sneaky Snatcher away!")
			hitAnyone = true
		end
	end

	if not hitAnyone then
		announce(player.Name .. " slapped the air. Nobody was stealing!")
	end
end

-- ---------------------------------------------------------------------------
-- Sneaky Snatcher NPC
-- ---------------------------------------------------------------------------

local function buildThiefModel()
	local model = Instance.new("Model")
	model.Name = "SneakySnatcher"
	local black = Color3.fromRGB(25, 25, 30)
	-- Body: dark block torso, ball head, stubby legs.
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(3, 3.5, 2)
	torso.Position = Vector3.new(0, 3, 0)
	torso.Color = black
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.CanCollide = false
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.6, 2.6, 2.6)
	head.Position = Vector3.new(0, 5.6, 0)
	head.Color = black
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model
	-- Purple mask across the face.
	local mask = Instance.new("Part")
	mask.Name = "Mask"
	mask.Size = Vector3.new(2.2, 0.9, 0.5)
	mask.Position = Vector3.new(0, 5.8, -1.2)
	mask.Color = Color3.fromRGB(150, 60, 220)
	mask.Material = Enum.Material.Neon
	mask.Anchored = true
	mask.CanCollide = false
	mask.Parent = model
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Position = Vector3.new(side * 0.6, 5.9, -1.4)
		eye.Color = Color3.fromRGB(255, 255, 255)
		eye.Material = Enum.Material.Neon
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.8, 1.4, 0.8)
		leg.Position = Vector3.new(side * 0.6, 0.7, 0)
		leg.Color = black
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = true
		leg.CanCollide = false
		leg.Parent = model
	end
	-- Red label so everyone sees the raid coming.
	local gui = Instance.new("BillboardGui")
	gui.Name = "ThiefLabel"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SNEAKY SNATCHER"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.Parent = gui
	model.PrimaryPart = torso
	return model
end

local function spawnThief()
	if thief then
		return
	end
	-- Pick a random unlocked, occupied base.
	local candidates = {}
	local now = os.clock()
	for _, record in ipairs(State.allRecords()) do
		if #record.owned > 0 and not State.isBaseLocked(record, now) then
			table.insert(candidates, record)
		end
	end
	if #candidates == 0 then
		return
	end
	local target = candidates[math.random(#candidates)]
	local model = buildThiefModel()
	model:PivotTo(CFrame.new(0, 2, -180))
	model.Parent = workspace
	thief = {
		model = model,
		state = "walking",
		targetPlayer = target.player,
		targetBase = world.bases[target.baseIndex],
		channelUntil = 0,
		victim = nil,
	}
	announce("The Sneaky Snatcher is raiding " .. target.player.Name .. "'s base!")
end

local function updateThief(dt)
	if not thief then
		return
	end
	local model = thief.model
	local pivot = model:GetPivot()
	local pos = pivot.Position

	if thief.state == "walking" then
		local goal = thief.targetBase.centre
		local toGoal = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
		local dist = toGoal.Magnitude
		if dist < 6 then
			-- Arrived: pick a victim brainrot and start the 8s channel.
			local record = State.get(thief.targetPlayer)
			if not record or #record.owned == 0 then
				thief.state = "fleeing"
				return
			end
			thief.victim = record.owned[math.random(#record.owned)]
			thief.channelUntil = os.clock() + Cast.THIEF_CHANNEL
			thief.state = "stealing"
			announce("The Sneaky Snatcher is stealing from " .. thief.targetPlayer.Name .. "!")
		else
			local step = toGoal.Unit * math.min(10 * dt, dist)
			model:PivotTo(CFrame.lookAt(pos + step, pos + toGoal))
		end
	elseif thief.state == "stealing" then
		local record = State.get(thief.targetPlayer)
		-- Give up if the base got locked, the owner left, or the
		-- victim brainrot is gone.
		if not record or State.isBaseLocked(record, os.clock()) or not thief.victim
			or not table.find(record.owned, thief.victim) then
			thief.state = "fleeing"
			announce("The Sneaky Snatcher gave up and fled!")
			return
		end
		if os.clock() >= thief.channelUntil then
			local taken = State.takeBrainrot(thief.targetPlayer, thief.victim)
			if taken then
				taken:Destroy()
				announce("The Sneaky Snatcher stole a brainrot from " .. thief.targetPlayer.Name .. "!")
			end
			thief.state = "fleeing"
		end
	elseif thief.state == "fleeing" then
		local goal = Vector3.new(0, 2, -180)
		local toGoal = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
		local dist = toGoal.Magnitude
		if dist < 6 then
			model:Destroy()
			thief = nil
		else
			local step = toGoal.Unit * math.min(16 * dt, dist)
			model:PivotTo(CFrame.lookAt(pos + step, pos + toGoal))
		end
	end
end

-- ---------------------------------------------------------------------------
-- Grinder Pit sweeper
-- ---------------------------------------------------------------------------

local sweeperAngle = 0

local function updateSweeper(dt)
	sweeperAngle += 1.2 * dt
	local centre = world.pitCentre
	world.sweeper.CFrame = CFrame.new(Vector3.new(centre.X, 3, centre.Z)) * CFrame.Angles(0, sweeperAngle, 0)

	-- The bar is a line through the centre at sweeperAngle. Any player
	-- within 32 studs whose distance to that line is under 2.5 studs
	-- gets knocked back to spawn.
	local dir = Vector3.new(math.cos(sweeperAngle), 0, -math.sin(sweeperAngle))
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local rel = root.Position - centre
			rel = Vector3.new(rel.X, 0, rel.Z)
			local dist = rel.Magnitude
			if dist > 2 and dist <= 32 then
				-- Perpendicular distance to the bar's line.
				local cross = math.abs(rel.X * dir.Z - rel.Z * dir.X)
				if cross < 2.5 then
					flingToSpawn(player)
					announce(player.Name .. " got swept into the Grinder Pit and sent back to spawn!")
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Client actions
-- ---------------------------------------------------------------------------

ActionRemote.OnServerEvent:Connect(function(player, action)
	local record = State.get(player)
	if not record then
		return
	end
	local now = os.clock()
	if action == "Lock" then
		local ok, message = State.lockBase(player, now)
		if ok then
			announce(player.Name .. " locked their base for " .. Cast.LOCK_SECONDS .. "s!")
		else
			FeedRemote:FireClient(player, message)
		end
		refreshSigns()
		sendSnapshot(player)
	elseif action == "Slap" then
		doSlap(player)
	elseif action == "Rebirth" then
		local ok, message = State.rebirthPlayer(player)
		if ok then
			announce(player.Name .. " REBIRTHED! " .. message)
		else
			FeedRemote:FireClient(player, message)
		end
		refreshSigns()
		sendSnapshot(player)
	elseif action == "Upgrade" then
		local ok, message = State.buyUpgrade(player)
		if ok then
			announce(player.Name .. " upgraded: " .. message)
		else
			FeedRemote:FireClient(player, message)
		end
		sendSnapshot(player)
	end
end)

-- ---------------------------------------------------------------------------
-- Joining and leaving
-- ---------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	local record = State.register(player)
	if not record then
		player:Kick("Brainrot Bazaar is full (8 players max).")
		return
	end
	local base = world.bases[record.baseIndex]
	refreshSigns()
	announce(player.Name .. " joined and claimed Base " .. record.baseIndex .. "!")
	sendSnapshot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	cancelStealsFor(player)
	local record = State.remove(player)
	if record then
		announce(player.Name .. " left; Base " .. record.baseIndex .. " is free again.")
	end
	refreshSigns()
end)

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

-- Seed the conveyor so the first screenshot already has brainrots walking.
for _ = 1, 3 do
	spawnWalker()
end

local spawnTimer = 0
local thiefTimer = 0
local incomeTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- Walk the conveyor: south to north, with a slight bob.
	local time = os.clock()
	for i = #walkers, 1, -1 do
		local walker = walkers[i]
		local model = walker.model
		if not model.Parent then
			table.remove(walkers, i)
		else
			local pivot = model:GetPivot()
			local pos = pivot.Position
			local newZ = pos.Z - walker.speed * dt
			if newZ <= world.conveyorEnd.Z then
				model:Destroy()
				table.remove(walkers, i)
			else
				local bob = math.sin(time * 6 + walker.phase) * 0.15
				model:PivotTo(CFrame.lookAt(
					Vector3.new(pos.X, world.conveyorStart.Y + bob, newZ),
					Vector3.new(pos.X, world.conveyorStart.Y + bob, newZ - 1)
				))
			end
		end
	end

	updateThief(dt)
	updateSweeper(dt)

	-- Spawn a new walker every 4 seconds.
	spawnTimer += dt
	if spawnTimer >= Cast.SPAWN_INTERVAL then
		spawnTimer = 0
		spawnWalker()
	end

	-- Raid every 60 seconds.
	thiefTimer += dt
	if thiefTimer >= Cast.THIEF_INTERVAL then
		thiefTimer = 0
		spawnThief()
	end

	-- Every second: pay income, refresh signs, broadcast snapshots.
	incomeTimer += dt
	if incomeTimer >= 1 then
		incomeTimer = 0
		State.collectIncome()
		refreshSigns()
		broadcastSnapshots()
	end
end)

print("Brainrot Bazaar server running: 8 bases, conveyor live, sweeper spinning.")
