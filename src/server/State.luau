-- State.luau — Brainrot Bazaar: all player state lives here, in one place.
-- The server owns all money; the client only ever displays what this module
-- reports through snapshots. A brainrot model carries its identity in a
-- StringValue named "BrainrotDef" holding "name|mutation".

local Cast = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Cast"))

local State = {}

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
-- players[player] = { money, rebirths, upgrade, baseIndex, owned = {models},
--   lockUntil, lockReadyAt, lastSlap, stealBanUntil }
local players = {}
-- baseOwners[baseIndex] = player
local baseOwners = {}
-- freeBases: a queue of base indices with no owner; register() pops the front.
local freeBases = {}

local START_TIME = os.clock()

local function now()
	return os.clock()
end

--- Prepare the base queue (1..baseCount) before the first player joins.
function State.initBases(baseCount)
	freeBases = {}
	for i = 1, baseCount do
		table.insert(freeBases, i)
	end
end

-- ---------------------------------------------------------------------------
-- Join / leave
-- ---------------------------------------------------------------------------

--- Claim the next free base for a joining player and give them start money.
--- Returns the player's record, or nil when no base is free.
function State.register(player)
	if players[player] then
		return players[player]
	end
	local baseIndex = table.remove(freeBases, 1)
	if not baseIndex then
		return nil
	end
	local record = {
		money = Cast.START_MONEY,
		rebirths = 0,
		upgrade = 0,
		baseIndex = baseIndex,
		owned = {},
		lockUntil = 0,
		lockReadyAt = 0,
		lastSlap = 0,
		lastSteal = 0,
		stealBanUntil = 0,
	}
	players[player] = record
	baseOwners[baseIndex] = player
	return record
end

--- A leaving player: destroy their owned brainrots, free their base.
function State.remove(player)
	local record = players[player]
	if not record then
		return
	end
	for _, model in ipairs(record.owned) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	baseOwners[record.baseIndex] = nil
	table.insert(freeBases, record.baseIndex)
	players[player] = nil
end

--- The record for a player, or nil.
function State.get(player)
	return players[player]
end

--- The owner of a base index, or nil.
function State.baseOwner(baseIndex)
	return baseOwners[baseIndex]
end

-- ---------------------------------------------------------------------------
-- Locks
-- ---------------------------------------------------------------------------

--- True while the player's base lock is still running.
function State.isBaseLocked(player)
	local record = players[player]
	if not record then
		return false
	end
	return now() < record.lockUntil
end

--- Lock the player's own base for 20 s (60 s cooldown).
--- Returns success, message.
function State.lockBase(player)
	local record = players[player]
	if not record then
		return false, "No base to lock."
	end
	local t = now()
	if t < record.lockUntil then
		return false, "Your base is already locked."
	end
	if t < record.lockReadyAt then
		return false, "Lock recharging — " .. math.ceil(record.lockReadyAt - t) .. "s left."
	end
	record.lockUntil = t + Cast.LOCK_SECONDS
	record.lockReadyAt = t + Cast.LOCK_COOLDOWN
	return true, "Base locked for " .. Cast.LOCK_SECONDS .. "s!"
end

-- ---------------------------------------------------------------------------
-- Income
-- ---------------------------------------------------------------------------

--- A brainrot's $/sec from its BrainrotDef tag, times the player's multiplier.
-- A brainrot stolen within the last 120 s earns only half: stealing skips the
-- whole climb otherwise, so a fresh thief cannot walk off with a $500/s prize
-- at full power. The halving is stamped on the model, not the player, so it
-- survives the model changing hands again.
local function rateOfModel(model, record)
	local tag = model:FindFirstChild("BrainrotDef")
	if not tag or typeof(tag.Value) ~= "string" then
		return 0
	end
	local name, mutation = string.match(tag.Value, "^(.-)|(.+)$")
	local def = Cast.findCharacter(name)
	if not def then
		return 0
	end
	local rate = Cast.baseRate(def, mutation) * Cast.incomeMultiplier(record.rebirths, record.upgrade)
	local stolenAt = model:GetAttribute("StolenAt")
	if stolenAt and (os.clock() - stolenAt) < 120 then
		rate *= 0.5
	end
	return rate
end

--- A player's total $/sec, rounded to the nearest dollar.
function State.computeIncome(player)
	local record = players[player]
	if not record then
		return 0
	end
	local total = 0
	for _, model in ipairs(record.owned) do
		if model and model.Parent then
			total += rateOfModel(model, record)
		end
	end
	return math.floor(total + 0.5)
end

--- Pay every player one second of income.
function State.collectIncome()
	for player in pairs(players) do
		local record = players[player]
		if record then
			record.money += State.computeIncome(player)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Buying and stealing
-- ---------------------------------------------------------------------------

--- How many brainrots a player owns (models still in the world).
function State.ownedCount(player)
	local record = players[player]
	if not record then
		return 0
	end
	local count = 0
	for _, model in ipairs(record.owned) do
		if model and model.Parent then
			count += 1
		end
	end
	return count
end

--- Buy a conveyor brainrot: checks slot space and money, pays, parks the
--- model on the given slot position facing the base gate, and removes its
--- BUY prompt so it can never be bought twice.
--- Returns success, message.
function State.buyBrainrot(player, model, slotCFrame)
	local record = players[player]
	if not record then
		return false, "You have no base yet."
	end
	local tag = model:FindFirstChild("BrainrotDef")
	if not tag then
		return false, "That brainrot has no price tag."
	end
	local name, mutation = string.match(tag.Value, "^(.-)|(.+)$")
	local def = Cast.findCharacter(name)
	if not def then
		return false, "Unknown brainrot."
	end
	if State.ownedCount(player) >= Cast.BASE_SLOTS then
		return false, "Your base is full — rebirth to make room!"
	end
	if record.money < def.cost then
		return false, "Not enough money — need " .. Cast.formatMoney(def.cost) .. "."
	end
	record.money -= def.cost
	table.insert(record.owned, model)
	model:PivotTo(slotCFrame)
	local prompt = model:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	return true, "Bought " .. def.name .. " (" .. mutation .. ") for " .. Cast.formatMoney(def.cost) .. "!"
end

--- Move a brainrot from a victim's base to the thief's next slot.
--- Capacity is checked BEFORE the model is removed from the victim, so a
--- failed transfer can never strand a brainrot between bases. A successful
--- steal stamps the model so it earns half income for 120 s, and starts the
--- thief's 15 s steal cooldown.
--- Returns success, message.
function State.transferBrainrot(thief, victim, model, slotCFrame)
	local thiefRecord = players[thief]
	local victimRecord = players[victim]
	if not thiefRecord or not victimRecord then
		return false, "Steal failed."
	end
	if State.ownedCount(thief) >= Cast.BASE_SLOTS then
		return false, "Your base is full — no room for a stolen brainrot!"
	end
	-- Find and remove from the victim's list first, then park it.
	local found = false
	for i, owned in ipairs(victimRecord.owned) do
		if owned == model then
			table.remove(victimRecord.owned, i)
			found = true
			break
		end
	end
	if not found then
		return false, "That brainrot is already gone."
	end
	table.insert(thiefRecord.owned, model)
	model:PivotTo(slotCFrame)
	model:SetAttribute("StolenAt", now())
	thiefRecord.lastSteal = now()
	return true, "Stolen!"
end

--- True when the player's steal cooldown (15 s between successful steals)
--- has run out. A fresh $100 player cannot chain-steal a whole base in
--- seconds; each steal has to be earned one at a time.
function State.canSteal(player)
	local record = players[player]
	if not record then
		return false
	end
	return now() - record.lastSteal >= 15
end

--- Forget a model a player no longer owns (e.g. the Snatcher destroyed it).
function State.dropBrainrot(player, model)
	local record = players[player]
	if not record then
		return
	end
	for i, owned in ipairs(record.owned) do
		if owned == model then
			table.remove(record.owned, i)
			return
		end
	end
end

-- ---------------------------------------------------------------------------
-- Slap
-- ---------------------------------------------------------------------------

--- True when the player's slap is off cooldown; records the slap time.
function State.canSlap(player)
	local record = players[player]
	if not record then
		return false
	end
	local t = now()
	if t - record.lastSlap < Cast.SLAP_COOLDOWN then
		return false
	end
	record.lastSlap = t
	return true
end

--- Ban a player from stealing for 10 s (they were just slapped).
function State.banStealing(player)
	local record = players[player]
	if record then
		record.stealBanUntil = now() + Cast.SLAPPED_STEAL_BAN
	end
end

--- True while the player's steal ban is still running.
function State.isStealBanned(player)
	local record = players[player]
	if not record then
		return false
	end
	return now() < record.stealBanUntil
end

-- ---------------------------------------------------------------------------
-- Rebirth and upgrade
-- ---------------------------------------------------------------------------

--- Rebirth: checks the cap and the money, then resets money to start,
--- adds one rebirth, and destroys every owned brainrot.
--- Returns success, message.
function State.rebirthPlayer(player)
	local record = players[player]
	if not record then
		return false, "You have no base yet."
	end
	if record.rebirths >= Cast.MAX_REBIRTHS then
		return false, "Max rebirths reached!"
	end
	local cost = Cast.rebirthCost(record.rebirths)
	if record.money < cost then
		return false, "Rebirth costs " .. Cast.formatMoney(cost) .. "."
	end
	for _, model in ipairs(record.owned) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	record.owned = {}
	record.money = Cast.START_MONEY
	record.rebirths += 1
	return true, "REBIRTH! Permanent +" .. math.floor(Cast.REBIRTH_INCOME_BONUS * 100) .. "% income forever."
end

--- Buy the next Golden Conveyor upgrade: checks the cap and the money.
--- Returns success, message.
function State.buyUpgrade(player)
	local record = players[player]
	if not record then
		return false, "You have no base yet."
	end
	if record.upgrade >= Cast.MAX_UPGRADE then
		return false, "Conveyor is maxed out!"
	end
	local cost = Cast.upgradeCost(record.upgrade)
	if record.money < cost then
		return false, "Upgrade costs " .. Cast.formatMoney(cost) .. "."
	end
	record.money -= cost
	record.upgrade += 1
	return true, "Golden Conveyor Lv " .. record.upgrade .. " — +25% income!"
end

-- ---------------------------------------------------------------------------
-- HUD snapshot
-- ---------------------------------------------------------------------------

--- Everything the HUD needs, in one table.
function State.snapshot(player)
	local record = players[player]
	if not record then
		return nil
	end
	local t = now()
	local income = State.computeIncome(player)
	return {
		money = record.money,
		income = income,
		owned = State.ownedCount(player),
		slots = Cast.BASE_SLOTS,
		rebirths = record.rebirths,
		upgrade = record.upgrade,
		baseIndex = record.baseIndex,
		lockLeft = math.max(0, math.ceil(record.lockUntil - t)),
		lockCooldownLeft = math.max(0, math.ceil(record.lockReadyAt - t)),
		rebirthCost = Cast.rebirthCost(record.rebirths),
		upgradeCost = Cast.upgradeCost(record.upgrade),
	}
end

--- Every registered player (for the server's broadcast loop).
function State.allPlayers()
	local list = {}
	for player in pairs(players) do
		table.insert(list, player)
	end
	return list
end

return State
