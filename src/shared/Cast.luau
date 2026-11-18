-- Cast.luau
-- The single source of truth for Brainrot Bazaar's economy and cast.
-- Every price, rate and rule lives here so the server and the client
-- always agree on the numbers. Nothing in this module touches the
-- world, players, or remotes; it is pure data plus small helpers.

local Cast = {}

-- ---------------------------------------------------------------------------
-- Tuning constants
-- ---------------------------------------------------------------------------

Cast.START_MONEY = 100
Cast.BASE_SLOTS = 6
Cast.MAX_PLAYERS = 8
Cast.MAX_REBIRTHS = 10

Cast.REBIRTH_BASE_COST = 25000 -- cost is base x (rebirths + 1)
Cast.REBIRTH_BONUS = 0.5 -- +50% income per rebirth

Cast.UPGRADE_MAX = 5
Cast.UPGRADE_BASE_COST = 5000 -- cost is base x 2^level
Cast.UPGRADE_BONUS = 0.25 -- +25% income per level

Cast.LOCK_SECONDS = 20
Cast.LOCK_COOLDOWN = 60
Cast.STEAL_HOLD_SECONDS = 5
Cast.SLAP_RANGE = 14
Cast.SLAP_COOLDOWN = 4
Cast.SLAP_BAN_SECONDS = 10 -- a slapped thief may not steal for this long

Cast.SPAWN_INTERVAL = 4 -- a new brainrot walks in every 4 seconds
Cast.MAX_WALKERS = 10
Cast.THIEF_INTERVAL = 60 -- the Sneaky Snatcher raids every 60 seconds
Cast.THIEF_CHANNEL = 8 -- its steal channel lasts 8 seconds

Cast.WALK_SPEED_MIN = 5
Cast.WALK_SPEED_MAX = 8

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

function Cast.rarityColor(rarityName)
	local entry = Cast.RARITIES[rarityName]
	if entry then
		return entry.color
	end
	return Color3.fromRGB(200, 200, 200)
end

-- ---------------------------------------------------------------------------
-- Mutations
-- ---------------------------------------------------------------------------

Cast.MUTATIONS = {
	Normal = { weight = 80, multiplier = 1, color = Color3.fromRGB(255, 255, 255) },
	Golden = { weight = 12, multiplier = 3, color = Color3.fromRGB(255, 200, 40) },
	Rainbow = { weight = 6, multiplier = 5, color = Color3.fromRGB(120, 200, 255) },
	Diamond = { weight = 2, multiplier = 10, color = Color3.fromRGB(180, 240, 255) },
}

-- Weighted roll over the mutation table. Returns the mutation name.
function Cast.pickMutation()
	local total = 0
	for _, entry in pairs(Cast.MUTATIONS) do
		total += entry.weight
	end
	local roll = math.random() * total
	local running = 0
	for name, entry in pairs(Cast.MUTATIONS) do
		running += entry.weight
		if roll <= running then
			return name
		end
	end
	return "Normal"
end

-- Unknown mutation names fall back to Normal, so a bad tag can never
-- crash the income math.
function Cast.getMutation(name)
	local entry = Cast.MUTATIONS[name]
	if entry then
		return entry
	end
	return Cast.MUTATIONS.Normal
end

function Cast.mutationMultiplier(name)
	return Cast.getMutation(name).multiplier
end

-- ---------------------------------------------------------------------------
-- The cast of twelve
-- ---------------------------------------------------------------------------
-- Fields per character:
--   name, rarity, cost, rate ($/sec), weight (spawn weight),
--   shape ("Ball" | "Block" | "Cylinder" | "Wedge"),
--   color (torso/head Color3), prop (signature prop name),
--   propColor, look (hat / accessory / face / shoe color / torso size)
-- The look table is read by BrainrotFactory; the numbers here are the
-- only place a character's economy ever changes.

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
		look = { hat = "crust", accessory = "puddle", face = "droopy",
			shoes = Color3.fromRGB(120, 80, 40), torsoSize = Vector3.new(3.4, 3.2, 3.0) },
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
		look = { hat = "headband", accessory = "flipflop", face = "default",
			shoes = Color3.fromRGB(255, 120, 180), torsoSize = Vector3.new(3.2, 4.0, 2.6) },
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
		look = { hat = "nozzle", accessory = "hose", face = "toothy",
			shoes = Color3.fromRGB(40, 140, 60), torsoSize = Vector3.new(3.4, 3.0, 2.8) },
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
		look = { hat = "doily", accessory = "needles", face = "glasses",
			shoes = Color3.fromRGB(240, 230, 200), torsoSize = Vector3.new(3.6, 3.6, 3.0) },
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
		look = { hat = "halo", accessory = "wings", face = "default",
			shoes = Color3.fromRGB(120, 120, 120), torsoSize = Vector3.new(3.4, 3.4, 2.6) },
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
		look = { hat = "cap", accessory = "cart", face = "shout",
			shoes = Color3.fromRGB(60, 60, 60), torsoSize = Vector3.new(3.4, 3.8, 2.8) },
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
		look = { hat = "helm", accessory = "lance", face = "default",
			shoes = Color3.fromRGB(120, 80, 180), torsoSize = Vector3.new(3.6, 3.8, 2.8) },
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
		look = { hat = "starhat", accessory = "shawl", face = "glasses",
			shoes = Color3.fromRGB(120, 60, 200), torsoSize = Vector3.new(3.6, 3.6, 3.4) },
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
		look = { hat = "panel", accessory = "porthole", face = "default",
			shoes = Color3.fromRGB(140, 140, 150), torsoSize = Vector3.new(3.6, 3.8, 3.0) },
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
		look = { hat = "headphones", accessory = "turntables", face = "toothy",
			shoes = Color3.fromRGB(50, 50, 50), torsoSize = Vector3.new(3.2, 4.2, 3.0) },
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
		look = { hat = "antenna", accessory = "modem", face = "glasses",
			shoes = Color3.fromRGB(60, 160, 60), torsoSize = Vector3.new(3.6, 3.4, 3.4) },
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
		look = { hat = "pepperoni", accessory = "pepperoni", face = "toothy",
			shoes = Color3.fromRGB(200, 160, 90), torsoSize = Vector3.new(3.4, 3.4, 3.0) },
	},
}

-- Name lookup. Unknown names return nil so callers can reject them.
function Cast.getCharacter(name)
	for _, def in ipairs(Cast.CHARACTERS) do
		if def.name == name then
			return def
		end
	end
	return nil
end

-- Weighted random pick over the cast. Rarer characters are rarer.
function Cast.pickCharacter()
	local total = 0
	for _, def in ipairs(Cast.CHARACTERS) do
		total += def.weight
	end
	local roll = math.random() * total
	local running = 0
	for _, def in ipairs(Cast.CHARACTERS) do
		running += def.weight
		if roll <= running then
			return def
		end
	end
	return Cast.CHARACTERS[1]
end

-- A brainrot's base $/sec before rebirth and upgrade multipliers.
function Cast.baseRate(def, mutation)
	return def.rate * Cast.mutationMultiplier(mutation)
end

-- The income multiplier from a player's progression.
function Cast.incomeMultiplier(rebirths, upgradeLevel)
	return (1 + rebirths * Cast.REBIRTH_BONUS) * (1 + upgradeLevel * Cast.UPGRADE_BONUS)
end

function Cast.rebirthCost(rebirths)
	return Cast.REBIRTH_BASE_COST * (rebirths + 1)
end

function Cast.upgradeCost(level)
	return Cast.UPGRADE_BASE_COST * (2 ^ level)
end

-- Money formatting for the HUD and the feed.
--   1250    -> "$1,250"
--   2500000 -> "$2.5M"
--   999     -> "$999"
function Cast.formatMoney(amount)
	amount = math.floor(amount + 0.5)
	if amount >= 1000000 then
		local millions = amount / 1000000
		-- One decimal, dropping a trailing ".0" (so $2M, not $2.0M).
		local text = string.format("%.1f", millions)
		if string.sub(text, -2) == ".0" then
			text = string.sub(text, 1, -3)
		end
		return "$" .. text .. "M"
	elseif amount >= 1000 then
		local digits = tostring(amount)
		local grouped = ""
		while #digits > 3 do
			grouped = "," .. string.sub(digits, -3) .. grouped
			digits = string.sub(digits, 1, -4)
		end
		return "$" .. digits .. grouped
	else
		return "$" .. tostring(amount)
	end
end

return Cast
