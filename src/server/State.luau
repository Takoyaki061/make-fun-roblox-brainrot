-- State.luau — all player state, in one place.
-- One module, one job: who owns what, how much money everyone has, which
-- bases are locked, and every rule that changes those numbers. The server
-- loop and the remote handlers call into here; nothing else mutates state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cast"))

local State = {}

State.players = {} -- [player] = { money, income, rebirths, upgrade, baseIndex, owned = {models}, lockUntil, lockReadyAt, lastSlap }
State.baseOwners = {} -- [baseIndex] = player
State.freeBases = {}

-- Hand a joining player the next free base and starting money.
function State.registerPlayer(player, baseIndex)
	State.players[player] = {
		money = Cast.START_MONEY,
		rebirths = 0,
		upgrade = 0,
		baseIndex = baseIndex,
		owned = {},
		lockUntil = 0,
		lockReadyAt = 0,
		lastSlap = 0,
	}
	State.baseOwners[baseIndex] = player
	return State.players[player]
end

-- Free a player's base when they leave, and hand their brainrots back to
-- the conveyor pool by simply removing them from the world.
function State.removePlayer(player)
	local data = State.players[player]
	if not data then
		return
	end
	for _, model in ipairs(data.owned) do
		if model.Parent then
			model:Destroy()
		end
	end
	State.baseOwners[data.baseIndex] = nil
	table.insert(State.freeBases, data.baseIndex)
	State.players[player] = nil
end

function State.getPlayer(player)
	return State.players[player]
end

-- A base is locked while its lock timer runs.
function State.isBaseLocked(baseIndex)
	local owner = State.baseOwners[baseIndex]
	if not owner then
		return false
	end
	local data = State.players[owner]
	return data and os.clock() < data.lockUntil
end

-- Lock your own base: 20 seconds of safety, then a 60 second cooldown.
function State.lockBase(player)
	local data = State.players[player]
	if not data then
		return false, "no state"
	end
	local now = os.clock()
	if now < data.lockReadyAt then
		return false, "lock cooling down"
	end
	data.lockUntil = now + Cast.LOCK_SECONDS
	data.lockReadyAt = now + Cast.LOCK_COOLDOWN
	return true, "base locked"
end

-- The money a player earns each second from their based brainrots.
-- Each brainrot carries its definition on a StringValue tag, "name|mutation".
function State.computeIncome(player)
	local data = State.players[player]
	if not data then
		return 0
	end
	local base = 0
	for _, model in ipairs(data.owned) do
		local tag = model:FindFirstChild("BrainrotDef")
		if tag then
			local name, mutationName = string.match(tag.Value, "^(.-)|(.+)$")
			local def = name and Cast.findCharacter(name)
			local mutation = mutationName and Cast.findMutation(mutationName)
			if def and mutation then
				base += Cast.baseRate(def, mutation)
			end
		end
	end
	return math.floor(base * Cast.incomeMultiplier(data.rebirths, data.upgrade) + 0.5)
end

-- Tick every player's money by their income. Returns the new totals.
function State.collectIncome()
	for player, data in pairs(State.players) do
		local income = State.computeIncome(player)
		if income > 0 then
			data.money += income
		end
	end
end

-- Buy a conveyor brainrot: pay, take it off the belt, park it on a slot.
function State.buyBrainrot(player, model, def, mutation, slotPosition)
	local data = State.players[player]
	if not data then
		return false, "no state"
	end
	if #data.owned >= Cast.BASE_SLOTS then
		return false, "base is full"
	end
	if data.money < def.cost then
		return false, "not enough money"
	end
	data.money -= def.cost
	table.insert(data.owned, model)
	-- Anchor it on the slot, facing the base gate.
	model:PivotTo(CFrame.new(slotPosition) * CFrame.Angles(0, math.pi, 0))
	local buyPrompt = model:FindFirstChild("BUYPrompt", true)
	if buyPrompt then
		buyPrompt:Destroy()
	end
	return true, "bought"
end

-- Move a brainrot from one player's base to another's (a completed steal).
-- The destination's capacity is checked BEFORE the model leaves the victim,
-- so a failed transfer never strands a brainrot owned by nobody.
function State.transferBrainrot(model, fromPlayer, toPlayer, slotPosition)
	local fromData = State.players[fromPlayer]
	local toData = State.players[toPlayer]
	if not fromData or not toData then
		return false
	end
	if #toData.owned >= Cast.BASE_SLOTS then
		return false
	end
	for i, owned in ipairs(fromData.owned) do
		if owned == model then
			table.remove(fromData.owned, i)
			break
		end
	end
	table.insert(toData.owned, model)
	model:PivotTo(CFrame.new(slotPosition) * CFrame.Angles(0, math.pi, 0))
	return true
end

-- How many brainrots a player owns (nil when the player has no state).
function State.ownedCount(player)
	local data = State.players[player]
	if not data then
		return nil
	end
	return #data.owned
end

-- Slap: on cooldown, and only useful up close. The caller checks range.
function State.canSlap(player)
	local data = State.players[player]
	if not data then
		return false
	end
	local now = os.clock()
	if now - data.lastSlap < Cast.SLAP_COOLDOWN then
		return false
	end
	data.lastSlap = now
	return true
end

-- Rebirth: pay the cost, lose money and brainrots, keep a permanent bonus.
function State.rebirthPlayer(player)
	local data = State.players[player]
	if not data then
		return false, "no state"
	end
	if data.rebirths >= Cast.MAX_REBIRTHS then
		return false, "max rebirths"
	end
	local cost = Cast.rebirthCost(data.rebirths)
	if data.money < cost then
		return false, "need " .. Cast.formatMoney(cost)
	end
	data.money = Cast.START_MONEY
	data.rebirths += 1
	for _, model in ipairs(data.owned) do
		if model.Parent then
			model:Destroy()
		end
	end
	data.owned = {}
	return true, "reborn"
end

-- Golden Conveyor upgrade: the money sink. +25% income per level, max 5.
function State.buyUpgrade(player)
	local data = State.players[player]
	if not data then
		return false, "no state"
	end
	if data.upgrade >= Cast.UPGRADE_MAX then
		return false, "max upgrade"
	end
	local cost = Cast.upgradeCost(data.upgrade)
	if data.money < cost then
		return false, "need " .. Cast.formatMoney(cost)
	end
	data.money -= cost
	data.upgrade += 1
	return true, "upgraded"
end

-- A small snapshot of one player for the HUD: money, income, progress.
function State.snapshot(player)
	local data = State.players[player]
	if not data then
		return nil
	end
	return {
		money = data.money,
		income = State.computeIncome(player),
		owned = #data.owned,
		slots = Cast.BASE_SLOTS,
		rebirths = data.rebirths,
		upgrade = data.upgrade,
		baseIndex = data.baseIndex,
		lockSeconds = math.max(0, math.floor(data.lockUntil - os.clock() + 0.5)),
		lockCooldown = math.max(0, math.floor(data.lockReadyAt - os.clock() + 0.5)),
		rebirthCost = Cast.rebirthCost(data.rebirths),
		upgradeCost = Cast.upgradeCost(data.upgrade),
	}
end

return State
