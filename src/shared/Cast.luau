-- Cast.luau — the brainrot cast, the rarity ladder and the whole economy.
-- One module, one job: every number the game balances on lives here, so the
-- server and the client always agree on prices, rates and rarities.
-- Game: Brainrot Bazaar — collect absurd meme characters off the conveyor,
-- park them on your base, and climb from a soggy crouton to the last slice.

local Cast = {}

Cast.START_MONEY = 100
Cast.BASE_SLOTS = 6
Cast.MAX_REBIRTHS = 10
Cast.REBIRTH_COST = 25000 -- cash needed, times (rebirths + 1)
Cast.REBIRTH_BONUS = 0.5 -- +50% income per rebirth
Cast.UPGRADE_MAX = 5
Cast.UPGRADE_BASE_COST = 5000 -- times 2^level
Cast.UPGRADE_BONUS = 0.25 -- +25% income per Golden Conveyor level
Cast.LOCK_SECONDS = 20
Cast.LOCK_COOLDOWN = 60
Cast.STEAL_SECONDS = 5 -- hold time to steal from another player's base
Cast.SLAP_RANGE = 14
Cast.SLAP_COOLDOWN = 4
Cast.SPAWN_INTERVAL = 4 -- a new brainrot walks onto the conveyor this often
Cast.CONVEYOR_MAX = 10
Cast.THIEF_INTERVAL = 75 -- a Sneaky Snatcher raids a random base this often
Cast.THIEF_STEAL_SECONDS = 8

-- Mutation rolls: most brainrots are Normal; a lucky few are worth far more.
Cast.MUTATIONS = {
	{ name = "Normal", weight = 80, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", weight = 12, multiplier = 3, color = Color3.fromRGB(255, 200, 40) },
	{ name = "Rainbow", weight = 6, multiplier = 5, color = Color3.fromRGB(120, 200, 255) },
	{ name = "Diamond", weight = 2, multiplier = 10, color = Color3.fromRGB(180, 240, 255) },
}

-- The cast. body is the part shape of the torso, accent is the silly prop
-- each one drags around. Costs run $50 -> $50,000, rates $1/s -> $500/s.
Cast.CHARACTERS = {
	{ name = "Soggy Crouton Kevin", rarity = "Common", cost = 50, rate = 1,
		weight = 30, body = "Ball", color = Color3.fromRGB(190, 150, 90),
		accent = "Cracker Lid", accentColor = Color3.fromRGB(220, 190, 130) },
	{ name = "Sandal Lord Zorp", rarity = "Common", cost = 200, rate = 3,
		weight = 22, body = "Block", color = Color3.fromRGB(90, 140, 200),
		accent = "Flip-Flop", accentColor = Color3.fromRGB(255, 120, 180) },
	{ name = "Sprinkler Goblin Nubbs", rarity = "Rare", cost = 600, rate = 8,
		weight = 16, body = "Cylinder", color = Color3.fromRGB(80, 180, 90),
		accent = "Garden Hose", accentColor = Color3.fromRGB(40, 120, 60) },
	{ name = "Grandma Gazebo", rarity = "Rare", cost = 1200, rate = 15,
		weight = 12, body = "Block", color = Color3.fromRGB(200, 120, 170),
		accent = "Doily Hat", accentColor = Color3.fromRGB(250, 240, 220) },
	{ name = "Cinderblock Cherub", rarity = "Epic", cost = 2500, rate = 30,
		weight = 9, body = "Block", color = Color3.fromRGB(140, 140, 150),
		accent = "Mailbox", accentColor = Color3.fromRGB(60, 90, 200) },
	{ name = "The Lawnmower Whisperer", rarity = "Epic", cost = 4500, rate = 55,
		weight = 7, body = "Cylinder", color = Color3.fromRGB(200, 60, 60),
		accent = "Shopping Cart", accentColor = Color3.fromRGB(180, 180, 180) },
	{ name = "Sir Soggybottom III", rarity = "Legendary", cost = 8000, rate = 95,
		weight = 5, body = "Block", color = Color3.fromRGB(160, 140, 200),
		accent = "Pool-Noodle Lance", accentColor = Color3.fromRGB(255, 220, 60) },
	{ name = "Cosmic Grandma Brenda", rarity = "Legendary", cost = 14000, rate = 160,
		weight = 3.5, body = "Ball", color = Color3.fromRGB(90, 40, 160),
		accent = "Galaxy Shawl", accentColor = Color3.fromRGB(200, 80, 255) },
	{ name = "Baron Von Washing Machine", rarity = "Mythic", cost = 20000, rate = 220,
		weight = 2.5, body = "Block", color = Color3.fromRGB(220, 220, 230),
		accent = "Spin Cycle", accentColor = Color3.fromRGB(100, 200, 255) },
	{ name = "DJ Traffic Cone", rarity = "Mythic", cost = 30000, rate = 320,
		weight = 1.8, body = "Cylinder", color = Color3.fromRGB(255, 140, 40),
		accent = "Turntables", accentColor = Color3.fromRGB(40, 40, 40) },
	{ name = "Grandpa Internet", rarity = "Secret", cost = 42000, rate = 420,
		weight = 1.0, body = "Ball", color = Color3.fromRGB(120, 200, 120),
		accent = "Dial-Up Modem", accentColor = Color3.fromRGB(240, 240, 200) },
	{ name = "The Last Slice of Pizza", rarity = "Secret", cost = 50000, rate = 500,
		weight = 0.6, body = "Wedge", color = Color3.fromRGB(255, 200, 60),
		accent = "Pepperoni Crown", accentColor = Color3.fromRGB(200, 40, 40) },
}

Cast.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 60, 90),
	Secret = Color3.fromRGB(60, 255, 170),
}

-- Pick a random character, weighted so commons flood the conveyor and
-- secrets almost never show up.
function Cast.rollCharacter()
	local total = 0
	for _, def in ipairs(Cast.CHARACTERS) do
		total += def.weight
	end
	local roll = math.random() * total
	for _, def in ipairs(Cast.CHARACTERS) do
		roll -= def.weight
		if roll <= 0 then
			return def
		end
	end
	return Cast.CHARACTERS[1]
end

-- Pick a random mutation, weighted toward Normal.
function Cast.rollMutation()
	local total = 0
	for _, mut in ipairs(Cast.MUTATIONS) do
		total += mut.weight
	end
	local roll = math.random() * total
	for _, mut in ipairs(Cast.MUTATIONS) do
		roll -= mut.weight
		if roll <= 0 then
			return mut
		end
	end
	return Cast.MUTATIONS[1]
end

-- The money a brainrot earns per second, before the owner's multipliers.
function Cast.baseRate(def, mutation)
	return def.rate * mutation.multiplier
end

-- A player's income multiplier from rebirths and Golden Conveyor upgrades.
function Cast.incomeMultiplier(rebirths, upgradeLevel)
	return (1 + rebirths * Cast.REBIRTH_BONUS) * (1 + upgradeLevel * Cast.UPGRADE_BONUS)
end

-- Cash a rebirth costs at this rebirth count.
function Cast.rebirthCost(rebirths)
	return Cast.REBIRTH_COST * (rebirths + 1)
end

-- Cash a Golden Conveyor upgrade costs at this upgrade level.
function Cast.upgradeCost(upgradeLevel)
	return Cast.UPGRADE_BASE_COST * (2 ^ upgradeLevel)
end

-- Short money text: 1250 -> "$1,250", 2500000 -> "$2.5M".
function Cast.formatMoney(amount)
	amount = math.floor(amount + 0.5)
	if amount >= 1000000 then
		return string.format("$%.1fM", amount / 1000000)
	elseif amount >= 10000 then
		local s = tostring(amount)
		local out = ""
		while #s > 3 do
			out = "," .. string.sub(s, -3) .. out
			s = string.sub(s, 1, -4)
		end
		return "$" .. s .. out
	else
		return "$" .. tostring(amount)
	end
end

return Cast
