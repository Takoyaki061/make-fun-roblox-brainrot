-- Cast.luau — Brainrot Bazaar: the cast, the rarity ladder, and every economy number.
-- One module, one job: server and client both require it, so both sides always agree on
-- prices, rates, and rules. Nothing in here touches the game world; it is pure data
-- plus the small pure functions that turn that data into answers.

local Cast = {}

-- ---------------------------------------------------------------------------
-- Economy constants
-- ---------------------------------------------------------------------------
Cast.START_MONEY = 100
Cast.BASE_SLOTS = 6
Cast.MAX_PLAYERS = 8
Cast.MAX_REBIRTHS = 10
Cast.MAX_UPGRADE = 5

Cast.REBIRTH_BASE_COST = 25000
Cast.REBIRTH_INCOME_BONUS = 0.5 -- +50% income per rebirth
Cast.UPGRADE_BASE_COST = 5000
Cast.UPGRADE_INCOME_BONUS = 0.25 -- +25% income per upgrade level

Cast.LOCK_SECONDS = 20
Cast.LOCK_COOLDOWN = 60
Cast.STEAL_HOLD_SECONDS = 5
Cast.SLAP_RANGE = 14
Cast.SLAP_COOLDOWN = 4
Cast.SLAPPED_STEAL_BAN = 10 -- a slapped thief cannot steal for this long

Cast.SPAWN_INTERVAL = 4 -- a new brainrot joins the conveyor every 4 s
Cast.MAX_WALKERS = 10
Cast.THIEF_INTERVAL = 60 -- Sneaky Snatcher raids every 60 s
Cast.THIEF_CHANNEL = 8 -- its steal channel, in seconds

-- ---------------------------------------------------------------------------
-- Rarities
-- ---------------------------------------------------------------------------
Cast.RARITIES = {
	Common = { order = 1, color = Color3.fromRGB(200, 200, 200) },
	Rare = { order = 2, color = Color3.fromRGB(80, 180, 255) },
	Epic = { order = 3, color = Color3.fromRGB(180, 80, 255) },
	Legendary = { order = 4, color = Color3.fromRGB(255, 170, 0) },
	Mythic = { order = 5, color = Color3.fromRGB(255, 60, 90) },
	Secret = { order = 6, color = Color3.fromRGB(60, 255, 170) },
}

-- ---------------------------------------------------------------------------
-- Mutations: weighted roll, income multiplier, look colour
-- ---------------------------------------------------------------------------
Cast.MUTATIONS = {
	Normal = { weight = 80, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	Golden = { weight = 12, multiplier = 3, color = Color3.fromRGB(255, 200, 40) },
	Rainbow = { weight = 6, multiplier = 5, color = Color3.fromRGB(120, 200, 255) },
	Diamond = { weight = 2, multiplier = 10, color = Color3.fromRGB(180, 240, 255) },
}

-- ---------------------------------------------------------------------------
-- The cast. Fields, in order:
--   name, rarity, cost, base $/sec, spawn weight, torso shape, torso colour,
--   signature prop name, prop colour, hat, accessory, face, shoe colour, torso size.
-- ---------------------------------------------------------------------------
Cast.CHARACTERS = {
	{
		name = "Soggy Crouton Kevin",
		rarity = "Common",
		cost = 50,
		rate = 1,
		weight = 30,
		shape = "Ball",
		color = Color3.fromRGB(190, 150, 90),
		prop = "Cracker Lid",
		propColor = Color3.fromRGB(220, 190, 130),
		hat = "crust",
		accessory = "puddle",
		face = "droopy",
		shoes = Color3.fromRGB(120, 80, 40),
		size = Vector3.new(3.4, 3.2, 3.0),
	},
	{
		name = "Sandal Lord Zorp",
		rarity = "Common",
		cost = 200,
		rate = 3,
		weight = 22,
		shape = "Block",
		color = Color3.fromRGB(90, 140, 200),
		prop = "Flip-Flop",
		propColor = Color3.fromRGB(255, 120, 180),
		hat = "headband",
		accessory = "flipflop",
		face = "default",
		shoes = Color3.fromRGB(255, 120, 180),
		size = Vector3.new(3.2, 4.0, 2.6),
	},
	{
		name = "Sprinkler Goblin Nubbs",
		rarity = "Rare",
		cost = 600,
		rate = 8,
		weight = 16,
		shape = "Cylinder",
		color = Color3.fromRGB(80, 180, 90),
		prop = "Garden Hose",
		propColor = Color3.fromRGB(40, 120, 60),
		hat = "nozzle",
		accessory = "hose",
		face = "toothy",
		shoes = Color3.fromRGB(40, 120, 60),
		size = Vector3.new(3.4, 3.0, 2.8),
	},
	{
		name = "Grandma Gazebo",
		rarity = "Rare",
		cost = 1200,
		rate = 15,
		weight = 12,
		shape = "Block",
		color = Color3.fromRGB(200, 120, 170),
		prop = "Doily Hat",
		propColor = Color3.fromRGB(250, 240, 220),
		hat = "doily",
		accessory = "needles",
		face = "glasses",
		shoes = Color3.fromRGB(250, 240, 220),
		size = Vector3.new(3.6, 3.6, 3.0),
	},
	{
		name = "Cinderblock Cherub",
		rarity = "Epic",
		cost = 2500,
		rate = 30,
		weight = 9,
		shape = "Block",
		color = Color3.fromRGB(140, 140, 150),
		prop = "Mailbox",
		propColor = Color3.fromRGB(60, 90, 200),
		hat = "halo",
		accessory = "wings",
		face = "default",
		shoes = Color3.fromRGB(140, 140, 150),
		size = Vector3.new(3.4, 3.4, 2.6),
	},
	{
		name = "The Lawnmower Whisperer",
		rarity = "Epic",
		cost = 4500,
		rate = 55,
		weight = 7,
		shape = "Cylinder",
		color = Color3.fromRGB(200, 60, 60),
		prop = "Shopping Cart",
		propColor = Color3.fromRGB(180, 180, 180),
		hat = "cap",
		accessory = "cart",
		face = "shout",
		shoes = Color3.fromRGB(40, 40, 40),
		size = Vector3.new(3.4, 3.8, 2.8),
	},
	{
		name = "Sir Soggybottom III",
		rarity = "Legendary",
		cost = 8000,
		rate = 95,
		weight = 5,
		shape = "Block",
		color = Color3.fromRGB(160, 140, 200),
		prop = "Pool-Noodle Lance",
		propColor = Color3.fromRGB(255, 220, 60),
		hat = "helm",
		accessory = "lance",
		face = "default",
		shoes = Color3.fromRGB(160, 140, 200),
		size = Vector3.new(3.6, 3.8, 2.8),
	},
	{
		name = "Cosmic Grandma Brenda",
		rarity = "Legendary",
		cost = 14000,
		rate = 160,
		weight = 3.5,
		shape = "Ball",
		color = Color3.fromRGB(90, 40, 160),
		prop = "Galaxy Shawl",
		propColor = Color3.fromRGB(200, 80, 255),
		hat = "starhat",
		accessory = "shawl",
		face = "glasses",
		shoes = Color3.fromRGB(120, 60, 200),
		size = Vector3.new(3.6, 3.6, 3.4),
	},
	{
		name = "Baron Von Washing Machine",
		rarity = "Mythic",
		cost = 20000,
		rate = 220,
		weight = 2.5,
		shape = "Block",
		color = Color3.fromRGB(220, 220, 230),
		prop = "Spin Cycle",
		propColor = Color3.fromRGB(100, 200, 255),
		hat = "panel",
		accessory = "porthole",
		face = "default",
		shoes = Color3.fromRGB(140, 140, 150),
		size = Vector3.new(3.6, 3.8, 3.0),
	},
	{
		name = "DJ Traffic Cone",
		rarity = "Mythic",
		cost = 30000,
		rate = 320,
		weight = 1.8,
		shape = "Cylinder",
		color = Color3.fromRGB(255, 140, 40),
		prop = "Turntables",
		propColor = Color3.fromRGB(40, 40, 40),
		hat = "headphones",
		accessory = "turntables",
		face = "toothy",
		shoes = Color3.fromRGB(40, 40, 40),
		size = Vector3.new(3.2, 4.2, 3.0),
	},
	{
		name = "Grandpa Internet",
		rarity = "Secret",
		cost = 42000,
		rate = 420,
		weight = 1.0,
		shape = "Ball",
		color = Color3.fromRGB(120, 200, 120),
		prop = "Dial-Up Modem",
		propColor = Color3.fromRGB(240, 240, 200),
		hat = "antenna",
		accessory = "modem",
		face = "glasses",
		shoes = Color3.fromRGB(40, 120, 60),
		size = Vector3.new(3.6, 3.4, 3.4),
	},
	{
		name = "The Last Slice of Pizza",
		rarity = "Secret",
		cost = 50000,
		rate = 500,
		weight = 0.6,
		shape = "Wedge",
		color = Color3.fromRGB(255, 200, 60),
		prop = "Pepperoni Crown",
		propColor = Color3.fromRGB(200, 40, 40),
		hat = "pepperoni",
		accessory = "pepperoni",
		face = "toothy",
		shoes = Color3.fromRGB(200, 160, 100),
		size = Vector3.new(3.4, 3.4, 3.0),
	},
}

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------

local byName = {}
for _, def in ipairs(Cast.CHARACTERS) do
	byName[def.name] = def
end

--- The character definition for a name, or nil when the name is unknown.
function Cast.findCharacter(name)
	return byName[name]
end

--- The mutation definition for a name, defaulting to Normal when unknown.
function Cast.findMutation(name)
	return Cast.MUTATIONS[name] or Cast.MUTATIONS.Normal
end

--- The rarity colour for a rarity name, grey when unknown.
function Cast.rarityColor(rarity)
	local entry = Cast.RARITIES[rarity]
	if entry then
		return entry.color
	end
	return Color3.fromRGB(200, 200, 200)
end

-- ---------------------------------------------------------------------------
-- Weighted random picks
-- ---------------------------------------------------------------------------

local function pickWeighted(entries, weightOf)
	local total = 0
	for _, entry in ipairs(entries) do
		total += weightOf(entry)
	end
	local roll = math.random() * total
	for _, entry in ipairs(entries) do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

--- A random character definition, weighted by spawn weight.
function Cast.rollCharacter()
	return pickWeighted(Cast.CHARACTERS, function(def)
		return def.weight
	end)
end

--- A random mutation name, weighted by the mutation table.
function Cast.rollMutation()
	local names = {}
	for name in pairs(Cast.MUTATIONS) do
		table.insert(names, name)
	end
	table.sort(names) -- stable order, so the roll is not order-of-hashmap
	local picked = pickWeighted(names, function(name)
		return Cast.MUTATIONS[name].weight
	end)
	return picked
end

-- ---------------------------------------------------------------------------
-- Money math
-- ---------------------------------------------------------------------------

--- A brainrot's base $/sec: its character rate times its mutation multiplier.
function Cast.baseRate(def, mutationName)
	local mutation = Cast.findMutation(mutationName)
	return def.rate * mutation.multiplier
end

--- The income multiplier for a player: rebirths and conveyor upgrades stack.
function Cast.incomeMultiplier(rebirths, upgradeLevel)
	return (1 + rebirths * Cast.REBIRTH_INCOME_BONUS) * (1 + upgradeLevel * Cast.UPGRADE_INCOME_BONUS)
end

--- What the next rebirth costs at the given rebirth count.
function Cast.rebirthCost(rebirths)
	return Cast.REBIRTH_BASE_COST * (rebirths + 1)
end

--- What the next conveyor upgrade costs at the given level.
function Cast.upgradeCost(level)
	return Cast.UPGRADE_BASE_COST * (2 ^ level)
end

--- Money formatter: 1250 -> "$1,250", 2500000 -> "$2.5M".
function Cast.formatMoney(amount)
	local n = math.floor(amount + 0.5)
	if n >= 1000000 then
		local millions = n / 1000000
		-- One decimal, dropping a trailing ".0" (2.0M reads as 2M).
		local text = string.format("%.1f", millions)
		text = string.gsub(text, "%.0$", "")
		return "$" .. text .. "M"
	elseif n >= 10000 then
		-- Comma-grouped, e.g. 12500 -> "$12,500".
		local text = tostring(n)
		local grouped = ""
		while #text > 3 do
			grouped = "," .. string.sub(text, -3) .. grouped
			text = string.sub(text, 1, -4)
		end
		return "$" .. text .. grouped
	else
		return "$" .. tostring(n)
	end
end

return Cast
