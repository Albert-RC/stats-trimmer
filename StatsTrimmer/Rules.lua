-- Replacement rules for equip lines. No WoW API here: everything that comes from the game is passed in
-- through `context`, so this file can be unit tested outside the game.
--
-- context.lines                  all the item's tooltip data lines ({ leftText = ... })
-- context.equipPrefix            localized "Equip:" prefix
-- context.GetCreatureTypeName(id) localized creature type name ("Bestia" on esES), or nil
--
-- The tooltip wording varies per locale, so lines are matched to the item's stats by their numbers. Each
-- rule turns the item's stats into claims on its equip lines; a line is only rewritten when exactly one
-- claim can own it and that claim owns exactly its share of the lines. Anything else keeps its original
-- text: guessing between two stats with the same number would show a wrong line.
local _, ns = ...

local NumbersMatch = ns.NumbersMatch
local GetOnlyPercent = ns.GetOnlyPercent

-- Creature types a stat can be restricted to: stat key suffix -> creature type ID and output label.
-- All of these ITEM_MOD_<STAT>_VS_<TYPE>_SHORT keys exist in the client; BEAST and ELEMENTAL have been
-- seen on items.
local VS_CREATURE_TYPES = {
	BEAST = { id = 1, label = "beasts" },
	DRAGONKIN = { id = 2, label = "dragonkin" },
	DEMON = { id = 3, label = "demons" },
	ELEMENTAL = { id = 4, label = "elementals" },
	GIANT = { id = 5, label = "giants" },
	UNDEAD = { id = 6, label = "undead" },
	HUMANOID = { id = 7, label = "humanoids" },
	MECHANICAL = { id = 9, label = "mechanicals" },
}

-- Stats that can be restricted to a creature type: ITEM_MOD_<stat>_VS_<TYPE>_SHORT -> line kind and format
local VS_STATS = {
	ATTACK_POWER = { kind = "attackPowerVs", format = "+%d attack power vs %s" },
	SPELL_DAMAGE = { kind = "spellDamageVs", format = "≤%d spell damage vs %s" },
}

-- Stats whose equip line shows exactly the stat value
local POINT_STATS = {
	-- The key says RATING, but defense shows plain skill points ("Increased Defense +3.")
	{ key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", kind = "defense", format = "+%d defense" },
	{ key = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", kind = "rangedAttackPower", format = "+%d ranged attack power" },
	{ key = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", kind = "feralAttackPower", format = "+%d feral attack power" },
	{ key = "ITEM_MOD_BLOCK_VALUE_SHORT", kind = "blockValue", format = "+%d block value" },
	{ key = "ITEM_MOD_SPELL_PENETRATION_SHORT", kind = "spellPenetration", format = "+%d spell penetration" },
}

-- Weapon skills, in output order: ITEM_MOD_<key>_SHORT -> label
local WEAPON_SKILLS = {
	{ key = "AXES", label = "axes" },
	{ key = "TWOHANDED_AXES", label = "two-handed axes" },
	{ key = "BOWS", label = "bows" },
	{ key = "CROSSBOWS", label = "crossbows" },
	{ key = "DAGGERS", label = "daggers" },
	{ key = "FIST_WEAPONS", label = "fist weapons" },
	{ key = "GUNS", label = "guns" },
	{ key = "MACES", label = "maces" },
	{ key = "TWOHANDED_MACES", label = "two-handed maces" },
	{ key = "POLEARMS", label = "polearms" },
	{ key = "STAVES", label = "staves" },
	{ key = "SWORDS", label = "swords" },
	{ key = "TWOHANDED_SWORDS", label = "two-handed swords" },
	{ key = "THROWN", label = "thrown" },
	{ key = "WANDS", label = "wands" },
}

-- Ratings whose equip line shows a percentage: stat key -> line kind and output label
local PERCENT_RATINGS = {
	ITEM_MOD_BLOCK_RATING_SHORT = { kind = "blockRating", label = "block rating" },
	ITEM_MOD_HIT_RATING_SHORT = { kind = "hitRating", label = "hit rating" },
	ITEM_MOD_CRIT_RATING_SHORT = { kind = "critRating", label = "crit rating" },
	ITEM_MOD_HIT_SPELL_RATING_SHORT = { kind = "spellHitRating", label = "spell hit rating" },
	ITEM_MOD_CRIT_SPELL_RATING_SHORT = { kind = "spellCritRating", label = "spell crit rating" },
	ITEM_MOD_DODGE_RATING_SHORT = { kind = "dodgeRating", label = "dodge rating" },
	ITEM_MOD_PARRY_RATING_SHORT = { kind = "parryRating", label = "parry rating" },
}

-- A compact line; `kind` picks its color (ns.COLOR_KINDS), unknown kinds keep the original line color
local function Line(kind, text)
	return { kind = kind, text = text }
end

-- A claim is a stat (or a group of stats) that can own equip lines:
--   numbers   { a[, b] }: the numbers its line shows, exactly (ns.NumbersMatch)
--   percent   true instead of numbers: its line shows a lone percentage
--   size      how many equip lines it owns; a group of weapon skills owns one line per skill
--   creature  { name, label, stat, value } for a "<stat> vs <creature type>" stat whose type is known
--   Render    function(text) -> compact lines. nil when the owner is known but has no compact form: it
--             still keeps other stats from taking its line.
local function Claim(numbers, lines)
	return {
		numbers = numbers,
		size = 1,
		Render = function()
			return lines
		end,
	}
end

-- Turns the item's stats into claims; each rule calls Add(claim) for every claim it makes. The order
-- doesn't matter: a line with more than one possible owner is left alone.
ns.Rules = {
	{
		-- "Damage and healing by up to X" is a single spell power stat that counts as both
		name = "combined spell power",
		claims = function(stats, _, Add)
			local power = stats.ITEM_MOD_SPELL_POWER_SHORT
			if power then
				Add(Claim({ power }, {
					Line("spellPower", ("≤%d spell power"):format(power)),
					Line("healingPower", ("≤%d healing power"):format(power)),
				}))
			end
		end,
	},
	{
		-- Spell damage and/or healing; an item with both shows them in one line
		name = "spell damage and healing",
		claims = function(stats, _, Add)
			local damage = stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT
			local healing = stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT
			if not (damage or healing) then
				return
			end
			local lines = {}
			if damage then
				table.insert(lines, Line("spellPower", ("≤%d spell power"):format(damage)))
			end
			if healing then
				table.insert(lines, Line("healingPower", ("≤%d healing power"):format(healing)))
			end
			Add(Claim({ damage, healing }, lines))
		end,
	},
	{
		-- "Restores X mana per 5 sec." -> "+X MP5"; the 5 seconds are also a number in the line
		name = "MP5",
		claims = function(stats, _, Add)
			local mp5 = stats.ITEM_MOD_MANA_REGENERATION_SHORT
			if mp5 then
				Add(Claim({ mp5, 5 }, { Line("mp5", ("+%d MP5"):format(mp5)) }))
			end
		end,
	},
	{
		-- "Restores X health per 5 sec." -> "+X HP5"
		name = "HP5",
		claims = function(stats, _, Add)
			local hp5 = stats.ITEM_MOD_HEALTH_REGEN_SHORT
			if hp5 then
				Add(Claim({ hp5, 5 }, { Line("hp5", ("+%d HP5"):format(hp5)) }))
			end
		end,
	},
	{
		name = "attack power",
		claims = function(stats, _, Add)
			local attackPower = stats.ITEM_MOD_ATTACK_POWER_SHORT
			if attackPower then
				Add(Claim({ attackPower }, { Line("attackPower", ("+%d attack power"):format(attackPower)) }))
			end
		end,
	},
	{
		-- "<stat> vs <creature type>", e.g. ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT -> "+6 attack power vs
		-- beasts". A plain line and a vs line can share the same number, so the client's localized creature
		-- type name tells them apart (see LocateCreatures). An unknown type still claims its number.
		name = "stat vs creature type",
		claims = function(stats, context, Add)
			for key, value in pairs(stats) do
				local stat, typeKey = key:match("^ITEM_MOD_([%u_]-)_VS_(%u+)_SHORT$")
				local vs = VS_STATS[stat]
				if vs then
					local creatureType = VS_CREATURE_TYPES[typeKey]
					if creatureType then
						local claim = Claim({ value }, { Line(vs.kind, vs.format:format(value, creatureType.label)) })
						local name = context.GetCreatureTypeName(creatureType.id)
						if name then
							claim.creature =
								{ name = name:lower(), label = creatureType.label, stat = stat, value = value }
						end
						Add(claim)
					else
						Add({ numbers = { value }, size = 1 })
					end
				end
			end
		end,
	},
	{
		name = "point stats",
		claims = function(stats, _, Add)
			for _, stat in ipairs(POINT_STATS) do
				local value = stats[stat.key]
				if value then
					Add(Claim({ value }, { Line(stat.kind, stat.format:format(value)) }))
				end
			end
		end,
	},
	{
		-- "Increased Swords +7." Some items raise several skills by the same amount, one line each, and
		-- numbers can't tell those lines apart: the skills with the same value form one claim whose first
		-- line becomes a combined line ("+7 axes/daggers/swords skill") and whose other lines are removed.
		name = "weapon skills",
		claims = function(stats, _, Add)
			local labelsByValue = {}
			for _, skill in ipairs(WEAPON_SKILLS) do
				local value = stats["ITEM_MOD_" .. skill.key .. "_SHORT"]
				if value then
					labelsByValue[value] = labelsByValue[value] or {}
					table.insert(labelsByValue[value], skill.label)
				end
			end
			for value, labels in pairs(labelsByValue) do
				local text = ("+%d %s skill"):format(value, table.concat(labels, "/"))
				local claim = Claim({ value }, { Line("weaponSkill", text) })
				claim.size = #labels
				Add(claim)
			end
		end,
	},
	{
		-- Stats stored as a rating but shown as a percentage ("+1.0% chance to block with a shield",
		-- "improves your chance to hit by 1%"). The rating isn't the shown number (5 block rating showed
		-- as 1%), so the claim is on the line with a lone percentage and the value is read from its text.
		-- Ratings without an entry in PERCENT_RATINGS still claim such a line. Skill ratings (defense) are
		-- plain points, not percentages.
		name = "rating percentage",
		claims = function(stats, _, Add)
			for key in pairs(stats) do
				if key:find("_RATING_SHORT$") and not key:find("_SKILL_RATING_SHORT$") then
					local rating = PERCENT_RATINGS[key]
					local claim = { percent = true, size = 1 }
					if rating then
						claim.Render = function(text)
							return { Line(rating.kind, ("+%s%% %s"):format(GetOnlyPercent(text), rating.label)) }
						end
					end
					Add(claim)
				end
			end
		end,
	},
	{
		-- Single school damage, e.g. ITEM_MOD_FROST_DAMAGE_DONE_SHORT -> "≤32 frost damage"
		name = "school damage",
		claims = function(stats, _, Add)
			for key, value in pairs(stats) do
				local school = key:match("^ITEM_MOD_(%u+)_DAMAGE_DONE_SHORT$")
				if school and school ~= "SPELL" then
					local name = school:lower()
					Add(Claim({ value }, { Line(name .. "Damage", ("≤%d %s damage"):format(value, name)) }))
				end
			end
		end,
	},
}

local function GetClaims(stats, context)
	local claims = {}
	local function Add(claim)
		table.insert(claims, claim)
	end
	for _, rule in ipairs(ns.Rules) do
		rule.claims(stats, context, Add)
	end
	return claims
end

-- Texts of the item's equip lines in tooltip order, and the position of `text` among them
local function GetEquipLines(text, context)
	local lines, index = {}, nil
	for _, line in ipairs(context.lines or {}) do
		local lineText = line.leftText
		if lineText and lineText:sub(1, #context.equipPrefix) == context.equipPrefix then
			table.insert(lines, lineText)
			if not index and lineText == text then
				index = #lines
			end
		end
	end
	if not index then
		table.insert(lines, text)
		index = #lines
	end
	return lines, index
end

local function Matches(claim, text)
	if claim.percent then
		return GetOnlyPercent(text) ~= nil
	end
	return NumbersMatch(text, claim.numbers[1], claim.numbers[2])
end

-- A creature claim is located in the lines it matches that name its creature type. Once located it
-- leaves its other lines, and a line where some claim is located keeps only the claims located there.
-- Only equip lines are searched: the item name can mention a creature type too.
local function LocateCreatures(lines, matches)
	local locatedIn, locatedAnywhere = {}, {}
	for i, text in ipairs(lines) do
		locatedIn[i] = {}
		local lowerText = text:lower()
		for _, claim in ipairs(matches[i]) do
			if claim.creature and lowerText:find(claim.creature.name, 1, true) then
				locatedIn[i][claim] = true
				locatedAnywhere[claim] = true
			end
		end
	end
	for i in ipairs(lines) do
		local hasLocated = next(locatedIn[i]) ~= nil
		local kept = {}
		for _, claim in ipairs(matches[i]) do
			if locatedIn[i][claim] or not (hasLocated or locatedAnywhere[claim]) then
				table.insert(kept, claim)
			end
		end
		matches[i] = kept
	end
end

-- matches[i]: the claims that could own equip line i
local function MatchClaims(lines, claims)
	local matches = {}
	for i, text in ipairs(lines) do
		matches[i] = {}
		for _, claim in ipairs(claims) do
			if Matches(claim, text) then
				table.insert(matches[i], claim)
			end
		end
	end
	LocateCreatures(lines, matches)
	return matches
end

-- One line that names several creature types for the same stat ("+150 Attack Power when fighting Undead
-- and Demons") becomes one compact line with every type, in the order the line names them. nil unless
-- every claim is a creature type of that stat named in the line.
local function CombineCreatures(claims, text)
	local stat = claims[1].creature and claims[1].creature.stat
	local lowerText = text:lower()
	local found = {}
	for _, claim in ipairs(claims) do
		local creature = claim.creature
		local position = creature and creature.stat == stat and lowerText:find(creature.name, 1, true)
		if not position then
			return nil
		end
		table.insert(found, { position = position, label = creature.label })
	end
	table.sort(found, function(a, b)
		return a.position < b.position
	end)

	local labels = {}
	for _, entry in ipairs(found) do
		table.insert(labels, entry.label)
	end
	local vs = VS_STATS[stat]
	return { Line(vs.kind, vs.format:format(claims[1].creature.value, table.concat(labels, "/"))) }
end

-- Compact lines for an equip line (possibly empty, meaning "remove it"), or nil to keep its text: it isn't
-- one of this item's stat lines, or more than one stat could own it.
function ns.GetReplacement(text, stats, context)
	local lines, index = GetEquipLines(text, context)
	local matches = MatchClaims(lines, GetClaims(stats, context))

	-- Each claim must match exactly its own number of lines: an extra line with the same numbers could be
	-- an unrelated effect or a stat no rule knows
	local lineCounts = {}
	for _, lineMatches in ipairs(matches) do
		for _, claim in ipairs(lineMatches) do
			lineCounts[claim] = (lineCounts[claim] or 0) + 1
		end
	end

	local claims = matches[index]
	if #claims == 0 then
		return nil
	end
	for _, claim in ipairs(claims) do
		if lineCounts[claim] ~= claim.size then
			return nil
		end
	end
	if #claims > 1 then
		return CombineCreatures(claims, text)
	end

	local claim = claims[1]
	if not claim.Render then
		return nil
	end
	-- A group shows its combined line once, on the first of its lines
	for i = 1, index - 1 do
		for _, other in ipairs(matches[i]) do
			if other == claim then
				return {}
			end
		end
	end
	return claim.Render(text)
end
