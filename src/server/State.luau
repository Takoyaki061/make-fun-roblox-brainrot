-- State.luau
-- All player state for Brainrot Bazaar, in one place. The server owns
-- every number here; the client only ever sees snapshots.
--
-- A record holds one player's money, progression, base, owned
-- brainrot models, lock timers and slap timers. Bases are handed out
-- in order and returned to the free list when a player leaves, so a
-- freed base is always the next one claimed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cast = require(ReplicatedStorage.Shared.Cast)

local State = {}

local players = {} -- [Player] = record
local baseOwners = {} -- [baseIndex] = Player
local freeBases = {} -- list of base indices with no owner, in order

-- Call once at server start with the number of bases the world built.
function State.setup(baseCount)
	for i = 1, baseCount do
		table.insert(freeBases, i)
	end
end

-- Claim the next free base for a joining player and give them their
-- starting money. Returns the record, or nil when the server is full.
function State.register(player)
	if #freeBases == 0 then
		return nil
	end
	local baseIndex = table.remove(freeBases, 1)
	local record = {
		player = player,
		money = Cast.START_MONEY,
		rebirths = 0,
		upgrade = 0,
		baseIndex = baseIndex,
		owned = {},
		slots = {}, -- [model] = slot index 1..BASE_SLOTS
		lockUntil = 0,
		lockReadyAt = 0,
		lastSlapAt = -math.huge,
		slapBanUntil = 0,
	}
	players[player] = record
	baseOwners[baseIndex] = player
	return record
end

-- A leaving player loses their brainrots and gives their base back.
-- Returns the record so the caller can announce the departure.
function State.remove(player)
	local record = players[player]
	if not record then
		return nil
	end
	for _, model in ipairs(record.owned) do
		if model.Parent then
			model:Destroy()
		end
	end
	record.owned = {}
	record.slots = {}
	baseOwners[record.baseIndex] = nil
	table.insert(freeBases, record.baseIndex)
	table.sort(freeBases)
	players[player] = nil
	return record
end

function State.get(player)
	return players[player]
end

function State.allRecords()
	local list = {}
	for _, record in pairs(players) do
		table.insert(list, record)
	end
	return list
end

function State.baseOwner(baseIndex)
	return baseOwners[baseIndex]
end

function State.freeBaseCount()
	return #freeBases
end

-- ---------------------------------------------------------------------------
-- Locks
-- ---------------------------------------------------------------------------

function State.isBaseLocked(record, now)
	return now < record.lockUntil
end

function State.lockSecondsLeft(record, now)
	return math.max(0, record.lockUntil - now)
end

function State.lockCooldownLeft(record, now)
	return math.max(0, record.lockReadyAt - now)
end

-- Lock the player's own base for LOCK_SECONDS. Returns ok + a message
-- for the feed. A lock on cooldown is refused.
function State.lockBase(player, now)
	local record = players[player]
	if not record then
		return false, "no base to lock"
	end
	if now < record.lockReadyAt then
		local wait = math.ceil(record.lockReadyAt - now)
		return false, "lock recharging: " .. wait .. "s left"
	end
	if State.isBaseLocked(record, now) then
		return false, "base already locked"
	end
	record.lockUntil = now + Cast.LOCK_SECONDS
	record.lockReadyAt = now + Cast.LOCK_COOLDOWN
	return true, "base locked for " .. Cast.LOCK_SECONDS .. "s"
end

-- ---------------------------------------------------------------------------
-- Income
-- ---------------------------------------------------------------------------

-- Read a brainrot model's "name|mutation" tag and price its $/sec.
local function modelRate(model)
	local tag = model:FindFirstChild("BrainrotDef")
	if not tag or not tag:IsA("StringValue") then
		return 0
	end
	local sep = string.find(tag.Value, "|", 1, true)
	if not sep then
		return 0
	end
	local def = Cast.getCharacter(string.sub(tag.Value, 1, sep - 1))
	if not def then
		return 0
	end
	local mutation = string.sub(tag.Value, sep + 1)
	return Cast.baseRate(def, mutation)
end

function State.computeIncome(record)
	local total = 0
	for _, model in ipairs(record.owned) do
		total += modelRate(model)
	end
	local multiplied = total * Cast.incomeMultiplier(record.rebirths, record.upgrade)
	return math.floor(multiplied + 0.5)
end

-- Pay every player one second of income. The server loop calls this
-- once a second.
function State.collectIncome()
	for _, record in pairs(players) do
		record.money += State.computeIncome(record)
	end
end

function State.ownedCount(record)
	return #record.owned
end

-- First free display slot on a base (1..BASE_SLOTS), or nil when full.
-- Slot indices are tracked per model so a stolen middle slot is
-- reused instead of colliding with the brainrot already standing there.
function State.nextSlot(record)
	local used = {}
	for _, index in pairs(record.slots) do
		used[index] = true
	end
	for i = 1, Cast.BASE_SLOTS do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

-- Park a conveyor brainrot on the buyer's base. Checks capacity and
-- money first; on failure nothing moves and nothing is charged.
-- slotCFrame faces the model toward the base gate. The BUY prompt is
-- destroyed so the parked brainrot can only be stolen, not re-bought.
function State.buyBrainrot(player, model, slotCFrame)
	local record = players[player]
	if not record then
		return false, "no base yet"
	end
	local slotIndex = State.nextSlot(record)
	if not slotIndex then
		return false, "base is full"
	end
	local tag = model:FindFirstChild("BrainrotDef")
	if not tag then
		return false, "not a brainrot"
	end
	local sep = string.find(tag.Value, "|", 1, true)
	local def = sep and Cast.getCharacter(string.sub(tag.Value, 1, sep - 1)) or nil
	if not def then
		return false, "unknown brainrot"
	end
	if record.money < def.cost then
		return false, "need " .. Cast.formatMoney(def.cost)
	end
	record.money -= def.cost
	model:PivotTo(slotCFrame)
	local buyPrompt = model:FindFirstChild("BuyPrompt")
	if buyPrompt then
		buyPrompt:Destroy()
	end
	table.insert(record.owned, model)
	record.slots[model] = slotIndex
	return true, "bought " .. def.name .. " for " .. Cast.formatMoney(def.cost), slotIndex
end

-- ---------------------------------------------------------------------------
-- Stealing
-- ---------------------------------------------------------------------------
-- Move a brainrot from one player's base to another's. The destination
-- capacity is checked BEFORE the model leaves the victim, so a failed
-- transfer can never strand a brainrot between bases.

function State.transferBrainrot(model, fromPlayer, toPlayer, slotCFrame)
	local fromRecord = players[fromPlayer]
	local toRecord = players[toPlayer]
	if not fromRecord or not toRecord then
		return false, "player gone"
	end
	if #toRecord.owned >= Cast.BASE_SLOTS then
		return false, "your base is full"
	end
	local slotIndex = State.nextSlot(toRecord)
	if not slotIndex then
		return false, "your base is full"
	end
	local slot = table.find(fromRecord.owned, model)
	if not slot then
		return false, "already gone"
	end
	table.remove(fromRecord.owned, slot)
	fromRecord.slots[model] = nil
	model:PivotTo(slotCFrame)
	table.insert(toRecord.owned, model)
	toRecord.slots[model] = slotIndex
	return true, "stolen", slotIndex
end

-- Remove one owned brainrot without a destination (the Snatcher
-- destroys what it takes). Returns the model or nil.
function State.takeBrainrot(fromPlayer, model)
	local record = players[fromPlayer]
	if not record then
		return nil
	end
	local slot = table.find(record.owned, model)
	if not slot then
		return nil
	end
	table.remove(record.owned, slot)
	record.slots[model] = nil
	return model
end

-- ---------------------------------------------------------------------------
-- Slap
-- ---------------------------------------------------------------------------

function State.canSlap(player, now)
	local record = players[player]
	if not record then
		return false
	end
	return (now - record.lastSlapAt) >= Cast.SLAP_COOLDOWN
end

function State.markSlap(player, now)
	local record = players[player]
	if record then
		record.lastSlapAt = now
	end
end

-- A slapped thief may not start a steal until this time passes.
function State.banStealing(player, now)
	local record = players[player]
	if record then
		record.slapBanUntil = now + Cast.SLAP_BAN_SECONDS
	end
end

function State.isStealBanned(player, now)
	local record = players[player]
	if not record then
		return true
	end
	return now < record.slapBanUntil
end

-- ---------------------------------------------------------------------------
-- Progression
-- ---------------------------------------------------------------------------

function State.rebirthPlayer(player)
	local record = players[player]
	if not record then
		return false, "no base yet"
	end
	if record.rebirths >= Cast.MAX_REBIRTHS then
		return false, "max rebirths reached"
	end
	local cost = Cast.rebirthCost(record.rebirths)
	if record.money < cost then
		return false, "need " .. Cast.formatMoney(cost) .. " to rebirth"
	end
	for _, model in ipairs(record.owned) do
		if model.Parent then
			model:Destroy()
		end
	end
	record.owned = {}
	record.slots = {}
	record.money = Cast.START_MONEY
	record.rebirths += 1
	return true, "rebirth " .. record.rebirths .. "! +50% income forever"
end

function State.buyUpgrade(player)
	local record = players[player]
	if not record then
		return false, "no base yet"
	end
	if record.upgrade >= Cast.UPGRADE_MAX then
		return false, "conveyor maxed out"
	end
	local cost = Cast.upgradeCost(record.upgrade)
	if record.money < cost then
		return false, "need " .. Cast.formatMoney(cost) .. " to upgrade"
	end
	record.money -= cost
	record.upgrade += 1
	return true, "conveyor level " .. record.upgrade .. " (+25% income)"
end

-- ---------------------------------------------------------------------------
-- HUD snapshot
-- ---------------------------------------------------------------------------

function State.snapshot(player, now)
	local record = players[player]
	if not record then
		return nil
	end
	return {
		money = record.money,
		income = State.computeIncome(record),
		owned = #record.owned,
		slots = Cast.BASE_SLOTS,
		rebirths = record.rebirths,
		upgrade = record.upgrade,
		baseIndex = record.baseIndex,
		lockLeft = State.lockSecondsLeft(record, now),
		lockCooldownLeft = State.lockCooldownLeft(record, now),
		rebirthCost = Cast.rebirthCost(record.rebirths),
		upgradeCost = Cast.upgradeCost(record.upgrade),
	}
end

return State
