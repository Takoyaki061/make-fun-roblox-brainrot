-- init.server.luau — Brainrot Bazaar server entry point.
-- One script, one job: wire the world, the cast and the state together and
-- run the game: spawn brainrots on the conveyor, walk them, pay owners every
-- second, handle buying, stealing, slapping, locks, rebirths, upgrades, the
-- sweeper hazard and the Sneaky Snatcher thief. The server owns all money;
-- the client only displays what the server sends it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))
-- NOTE: World/State/BrainrotFactory are SIBLINGS of this script (children of
-- the Server folder), not children of the script itself, so require them
-- through script.Parent. (script:WaitForChild("World") yields forever and
-- the world never builds, which is what the first Play test showed.)
local World = require(script.Parent:WaitForChild("World"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))
local State = require(script.Parent:WaitForChild("State"))

-- Eight bases, eight players: a ninth joiner would otherwise be handed a
-- base someone already owns, so the server is capped at the base count.
-- (MaxPlayers is set in Studio's Game Settings, not here: it is read-only
-- at runtime, and assigning it aborts this script before the world builds.)

local world = World.buildWorld()

-- Remotes: the client asks with BrainrotAction, the server answers with
-- BrainrotState snapshots and BrainrotFeed announcements.
local actionEvent = Instance.new("RemoteEvent")
actionEvent.Name = "BrainrotAction"
actionEvent.Parent = ReplicatedStorage

local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "BrainrotState"
stateEvent.Parent = ReplicatedStorage

local feedEvent = Instance.new("RemoteEvent")
feedEvent.Name = "BrainrotFeed"
feedEvent.Parent = ReplicatedStorage

local function announce(message)
	feedEvent:FireAllClients(message)
end

-- Forward declarations: the buy handler, the steal handler and the thief
-- state are used by functions defined before them.
local onBuyPrompt
local onStealComplete
local thiefNpc = { model = nil, phase = "idle", timer = Cast.THIEF_INTERVAL, targetBase = nil, targetModel = nil }

-- Base assignment: players take bases in order; freed bases go back in line.
local nextBase = 1
local function claimBase()
	if #State.freeBases > 0 then
		return table.remove(State.freeBases, 1)
	end
	local index = nextBase
	nextBase += 1
	if nextBase > Cast.MAX_PLAYERS then
		nextBase = 1
	end
	return index
end

-- Conveyor walkers: brainrots strolling from the south end to the arch.
local walkers = {} -- { model, def, mutation, speed }
local activeSteals = {} -- [thiefPlayer] = model being stolen
local stealBlockedUntil = {} -- [thiefPlayer] = os.clock() until which stealing is banned (after a slap)

local function spawnBrainrot()
	if #walkers >= Cast.CONVEYOR_MAX then
		return
	end
	local def = Cast.rollCharacter()
	local mutation = Cast.rollMutation()
	local model = Factory.buildBrainrot(def, mutation)
	model:PivotTo(CFrame.new(world.conveyorStart))
	model.Parent = world.folder
	local prompt = Factory.attachPrompt(model, "BUY", def.cost)
	prompt.Triggered:Connect(function(player)
		onBuyPrompt(prompt, player)
	end)
	table.insert(walkers, {
		model = model,
		def = def,
		mutation = mutation,
		speed = 5 + math.random() * 3,
	})
	if def.rarity == "Mythic" or def.rarity == "Secret" then
		announce("RARE SPAWN: " .. def.name .. " (" .. mutation.name .. ") is on the conveyor!")
	end
end

-- Walk every conveyor brainrot one step toward the arch; despawn at the end.
local function walkConveyor(dt)
	for i = #walkers, 1, -1 do
		local walker = walkers[i]
		local model = walker.model
		if not model.Parent then
			table.remove(walkers, i)
			continue
		end
		local pos = model:GetPivot().Position
		local newZ = pos.Z - walker.speed * dt
		if newZ <= world.conveyorEnd.Z then
			model:Destroy()
			table.remove(walkers, i)
		else
			local bob = math.sin(os.clock() * 6 + i) * 0.25
			model:PivotTo(CFrame.new(pos.X, world.conveyorStart.Y + bob, newZ))
		end
	end
end

-- Buying: the prompt on a conveyor brainrot fires when a player presses E.
onBuyPrompt = function(prompt, player)
	local model = prompt.Parent and prompt.Parent.Parent
	if not model then
		return
	end
	for i, walker in ipairs(walkers) do
		if walker.model == model then
			local data = State.getPlayer(player)
			if not data then
				return
			end
			local slotIndex = #data.owned + 1
			if slotIndex > Cast.BASE_SLOTS then
				announce(player.Name .. ": base is full!")
				return
			end
			local slot = world.bases[data.baseIndex].slots[slotIndex]
			local ok, message = State.buyBrainrot(player, model, walker.def, walker.mutation, slot)
			if ok then
				table.remove(walkers, i)
				local stealPrompt = Factory.attachPrompt(model, "STEAL", 0)
				stealPrompt.PromptButtonHoldBegan:Connect(function(thief)
					activeSteals[thief] = model
				end)
				stealPrompt.PromptButtonHoldEnded:Connect(function(thief)
					activeSteals[thief] = nil
				end)
				stealPrompt.Triggered:Connect(function(thief)
					onStealComplete(thief, model)
				end)
				announce(player.Name .. " bought " .. walker.def.name .. " for " .. Cast.formatMoney(walker.def.cost) .. "!")
			else
				announce(player.Name .. ": " .. message)
			end
			return
		end
	end
end

-- A steal finishes when the thief holds E for the full steal time.
onStealComplete = function(thief, model)
	local thiefData = State.getPlayer(thief)
	if not thiefData then
		return
	end
	activeSteals[thief] = nil
	-- A thief slapped off a base cannot start another steal for a while.
	local blockedUntil = stealBlockedUntil[thief]
	if blockedUntil and os.clock() < blockedUntil then
		announce(thief.Name .. " is still shaken from that slap — no stealing yet!")
		return
	end
	-- Find whose base this brainrot sits on.
	local victim = nil
	for player, data in pairs(State.players) do
		for _, owned in ipairs(data.owned) do
			if owned == model then
				victim = player
				break
			end
		end
		if victim then
			break
		end
	end
	if not victim or victim == thief then
		return
	end
	local victimData = State.getPlayer(victim)
	if State.isBaseLocked(victimData.baseIndex) then
		announce(thief.Name .. " bounced off " .. victim.Name .. "'s LOCKED base!")
		return
	end
	if #thiefData.owned >= Cast.BASE_SLOTS then
		announce(thief.Name .. ": base is full, steal failed!")
		return
	end
	local slot = world.bases[thiefData.baseIndex].slots[#thiefData.owned + 1]
	if State.transferBrainrot(model, victim, thief, slot) then
		announce(thief.Name .. " STOLE " .. model.Name .. " from " .. victim.Name .. "!")
	end
end

-- Slap: interrupt a thief mid-steal, stun them and fling them to spawn.
local function slapPlayer(player)
	if not State.canSlap(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local slappedAnyone = false
	-- Interrupt a player thief standing close by.
	for thief, model in pairs(activeSteals) do
		if thief ~= player and thief.Character then
			local thiefRoot = thief.Character:FindFirstChild("HumanoidRootPart")
			if thiefRoot and (thiefRoot.Position - root.Position).Magnitude <= Cast.SLAP_RANGE then
				activeSteals[thief] = nil
				-- A slapped thief cannot steal again for a few seconds.
				stealBlockedUntil[thief] = os.clock() + Cast.SLAP_STEAL_BAN
				local prompt = model:FindFirstChild("STEALPrompt", true)
				if prompt then
					prompt.Enabled = false
					task.delay(3, function()
						if prompt.Parent then
							prompt.Enabled = true
						end
					end)
				end
				thiefRoot.CFrame = CFrame.new(world.spawnPosition)
				announce(player.Name .. " SLAPPED " .. thief.Name .. " and stopped the steal!")
				slappedAnyone = true
			end
		end
	end
	-- Interrupt the Sneaky Snatcher thief the same way.
	if thiefNpc.model and thiefNpc.phase == "stealing" then
		local npcRoot = thiefNpc.model.PrimaryPart
		if npcRoot and (npcRoot.Position - root.Position).Magnitude <= Cast.SLAP_RANGE then
			thiefNpc.phase = "fleeing"
			announce(player.Name .. " SLAPPED the Sneaky Snatcher away!")
			slappedAnyone = true
		end
	end
	if not slappedAnyone then
		announce(player.Name .. " slapped the air. Nobody near!")
	end
end

-- The Sneaky Snatcher: a solo-play threat that raids a random occupied base
-- when nobody else is around to steal from you.
local function buildThiefNpc()
	local model = Instance.new("Model")
	model.Name = "Sneaky Snatcher"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3.4, 2.4)
	body.Color = Color3.fromRGB(30, 30, 30)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CFrame = CFrame.new(0, 2.6, 0)
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.Shape = Enum.PartType.Ball
	head.Color = Color3.fromRGB(30, 30, 30)
	head.Anchored = true
	head.CFrame = CFrame.new(0, 5, 0)
	head.Parent = model
	local mask = Instance.new("Part")
	mask.Name = "Mask"
	mask.Size = Vector3.new(2.6, 0.8, 0.5)
	mask.Color = Color3.fromRGB(120, 0, 160)
	mask.Anchored = true
	mask.CFrame = CFrame.new(0, 5.2, 1.2)
	mask.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Name = "ThiefLabel"
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "ThiefText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SNEAKY SNATCHER"
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	model.PrimaryPart = body
	return model
end

local function sendThief()
	local occupied = {}
	for player, data in pairs(State.players) do
		if #data.owned > 0 and not State.isBaseLocked(data.baseIndex) then
			table.insert(occupied, { player = player, data = data })
		end
	end
	if #occupied == 0 then
		return
	end
	local pick = occupied[math.random(#occupied)]
	local model = buildThiefNpc()
	model:PivotTo(CFrame.new(0, 2, -180))
	model.Parent = world.folder
	thiefNpc.model = model
	thiefNpc.phase = "walking"
	thiefNpc.targetBase = pick.data.baseIndex
	thiefNpc.targetModel = pick.data.owned[1]
	thiefNpc.timer = 0
	announce("WARNING: the Sneaky Snatcher is coming for " .. pick.player.Name .. "'s base! Slap it!")
end

-- Drive the thief: walk to the base, channel a steal, grab and run.
local function updateThief(dt)
	local npc = thiefNpc
	if npc.phase == "idle" then
		npc.timer += dt
		if npc.timer >= Cast.THIEF_INTERVAL then
			npc.timer = 0
			sendThief()
		end
		return
	end
	if not npc.model or not npc.model.Parent then
		npc.phase = "idle"
		npc.timer = 0
		return
	end
	local target = world.bases[npc.targetBase]
	if not target then
		npc.phase = "idle"
		return
	end
	local pos = npc.model:GetPivot().Position
	if npc.phase == "walking" then
		local dest = target.center
		local dir = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
		if dir.Magnitude < 8 then
			npc.phase = "stealing"
			npc.timer = 0
			announce("The Sneaky Snatcher is stealing! SLAP it (F)!")
		else
			local step = dir.Unit * 10 * dt
			npc.model:PivotTo(CFrame.new(pos + step))
		end
	elseif npc.phase == "stealing" then
		npc.timer += dt
		local victim = State.baseOwners[npc.targetBase]
		if not victim or State.isBaseLocked(npc.targetBase) then
			npc.phase = "fleeing"
			announce("The Sneaky Snatcher gave up on the locked base!")
			return
		end
		if npc.timer >= Cast.THIEF_STEAL_SECONDS then
			local victimData = State.getPlayer(victim)
			if victimData and npc.targetModel and npc.targetModel.Parent then
				for i, owned in ipairs(victimData.owned) do
					if owned == npc.targetModel then
						table.remove(victimData.owned, i)
						break
					end
				end
				npc.targetModel:Destroy()
				announce("The Sneaky Snatcher STOLE " .. npc.targetModel.Name .. " from " .. victim.Name .. "!")
			end
			npc.phase = "fleeing"
		end
	elseif npc.phase == "fleeing" then
		local dir = Vector3.new(0 - pos.X, 0, -180 - pos.Z)
		if dir.Magnitude < 10 then
			npc.model:Destroy()
			npc.model = nil
			npc.phase = "idle"
			npc.timer = 0
		else
			local step = dir.Unit * 16 * dt
			npc.model:PivotTo(CFrame.new(pos + step))
		end
	end
end

-- The Grinder Pit sweeper: spin the bar, and knock anyone it touches back
-- to spawn. Solo players feel this even with no thieves around.
local sweeperAngle = 0
local function updateSweeper(dt)
	sweeperAngle += dt * 1.2
	local bar = world.sweeperBar
	-- The bar is 60 studs long, centred on the hub: rotating it around Y
	-- sweeps the whole pit. Its long axis points along (cos a, 0, -sin a).
	bar.CFrame = CFrame.new(world.pitCenter) * CFrame.Angles(0, sweeperAngle, 0)
	local barDir = Vector3.new(math.cos(sweeperAngle), 0, -math.sin(sweeperAngle))
	local perp = Vector3.new(-barDir.Z, 0, barDir.X)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local toPlayer = root.Position - world.pitCenter
			toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
			if toPlayer.Magnitude < 32 and toPlayer.Magnitude > 2 then
				local along = math.abs(toPlayer.Unit:Dot(barDir))
				local across = math.abs(toPlayer.Unit:Dot(perp))
				if along > 0.92 and across < 0.12 then
					root.CFrame = CFrame.new(world.spawnPosition)
					announce(player.Name .. " got SWEPT by the Grinder Pit!")
				end
			end
		end
	end
end

-- Client actions: lock, slap, rebirth, upgrade. All validated server-side.
actionEvent.OnServerEvent:Connect(function(player, action)
	local data = State.getPlayer(player)
	if not data then
		return
	end
	if action == "Lock" then
		local ok, message = State.lockBase(player)
		if ok then
			-- A visible padlock on the base, so thieves reroute instead of
			-- wasting a steal attempt on a locked base. The label only
			-- reverts once the lock has actually run out, so re-locking
			-- inside the window cannot clear it early.
			local base = world.bases[data.baseIndex]
			base.ownerLabel.Text = "LOCKED - " .. string.upper(player.Name) .. "'s BASE"
			task.delay(Cast.LOCK_SECONDS, function()
				if State.getPlayer(player) and world.bases[data.baseIndex]
					and not State.isBaseLocked(data.baseIndex) then
					world.bases[data.baseIndex].ownerLabel.Text = string.upper(player.Name) .. "'s BASE"
				end
			end)
		end
		announce(player.Name .. ": " .. message)
	elseif action == "Slap" then
		slapPlayer(player)
	elseif action == "Rebirth" then
		local ok, message = State.rebirthPlayer(player)
		if ok then
			announce(player.Name .. " REBIRTHED! +" .. tostring(math.floor(Cast.REBIRTH_BONUS * 100)) .. "% income forever!")
		else
			announce(player.Name .. ": " .. message)
		end
	elseif action == "Upgrade" then
		local ok, message = State.buyUpgrade(player)
		if ok then
			announce(player.Name .. " bought a Golden Conveyor upgrade! +25% income!")
		else
			announce(player.Name .. ": " .. message)
		end
	end
end)

-- Joining: claim a base, label it, spawn the character, send the first HUD.
local function onPlayerAdded(player)
	local baseIndex = claimBase()
	State.registerPlayer(player, baseIndex)
	world.bases[baseIndex].ownerLabel.Text = string.upper(player.Name) .. "'s BASE"
	player:LoadCharacter()
	announce(player.Name .. " joined! Base " .. tostring(baseIndex) .. " is theirs.")
	local snapshot = State.snapshot(player)
	if snapshot then
		stateEvent:FireClient(player, snapshot)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	-- A leaver mid-steal must not leave a stale entry behind.
	activeSteals[player] = nil
	stealBlockedUntil[player] = nil
	State.removePlayer(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Main loops: walk the conveyor, spawn on a timer, pay income every second.
local spawnTimer = 0
local incomeTimer = 0
RunService.Heartbeat:Connect(function(dt)
	walkConveyor(dt)
	updateThief(dt)
	updateSweeper(dt)
	spawnTimer += dt
	if spawnTimer >= Cast.SPAWN_INTERVAL then
		spawnTimer = 0
		spawnBrainrot()
	end
	incomeTimer += dt
	if incomeTimer >= 1 then
		incomeTimer = 0
		State.collectIncome()
		for _, player in ipairs(Players:GetPlayers()) do
			local snapshot = State.snapshot(player)
			if snapshot then
				stateEvent:FireClient(player, snapshot)
			end
		end
	end
end)

-- Seed the conveyor so the first screenshot already has brainrots walking.
spawnBrainrot()
spawnBrainrot()
spawnBrainrot()
print("Brainrot Bazaar server running: 8 bases, conveyor live, sweeper spinning.")
