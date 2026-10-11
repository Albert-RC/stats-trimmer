-- Replacement rules for equip lines. No WoW API here: everything that comes from the game is passed in
-- through `context`, so this file can be unit tested outside the game.
--
-- context.lines                  all the item's tooltip data lines ({ leftText = ... })
-- context.equipPrefix            localized "Equip:" prefix
-- context.GetCreatureTypeName(id) localized creature type name ("Bestia" on esES), or nil
-- context.GetStatName(key)        the client's name for a stat key ("Poder de ataque contra bestias"), or nil
--                                 for a missing or untrusted name: a getter made with ns.TrustedNames
-- context.FoldCase(text)          text folded to lowercase, Unicode-aware ("Élémentaire" -> "élémentaire")
--
-- The tooltip wording varies per locale, so lines are matched to the item's stats by their numbers. Each
-- rule turns the item's stats into claims on its equip lines; a line is only rewritten when exactly one
-- claim can own it and that claim owns exactly its share of the lines. Anything else keeps its original
-- text: guessing between two stats with the same number would show a wrong line.
local _, ns = ...

local NumbersMatch = ns.NumbersMatch
local GetOnlyPercent = ns.GetOnlyPercent
local FormatLine = ns.FormatLine
local Line = ns.CompactLine

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

-- Stats that can be restricted to a creature type: ITEM_MOD_<stat>_VS_<TYPE>_SHORT -> line kind, sign and
-- English name
local VS_STATS = {
	ATTACK_POWER = { kind = "attackPowerVs", sign = "+", name = "attack power" },
	SPELL_DAMAGE = { kind = "spellDamageVs", sign = "≤", name = "spell damage" },
}

-- Stats whose equip line shows exactly the stat value
local POINT_STATS = {
	-- The key says RATING, but defense shows plain skill points ("Increased Defense +3.")
	{ key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", kind = "defense", name = "defense" },
	{ key = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", kind = "rangedAttackPower", name = "ranged attack power" },
	{ key = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", kind = "feralAttackPower", name = "feral attack power" },
	{ key = "ITEM_MOD_BLOCK_VALUE_SHORT", kind = "blockValue", name = "block value" },
	{ key = "ITEM_MOD_SPELL_PENETRATION_SHORT", kind = "spellPenetration", name = "spell penetration" },
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

-- A claim is a stat (or a group of stats) that can own equip lines:
--   numbers   { a[, b] }: the numbers its line shows, exactly (ns.NumbersMatch)
--   percent   true instead of numbers: its line shows a lone percentage
--   size      how many equip lines it owns; a group of weapon skills owns one line per skill
--   creature  { terms, label, stat, key, value } for a "<stat> vs <creature type>" stat whose type is known
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

local function LastWord(text)
	return text and text:match("(%S+)%s*$")
end

local function VsKey(stat, typeKey)
	return "ITEM_MOD_" .. stat .. "_VS_" .. typeKey .. "_SHORT"
end

-- A stat name getter like GetStatName that leaves out the names of "<stat> vs <creature type>" stats it
-- can't trust: the esES client calls spell damage vs beasts "Daño con hechizos contra mecánicos" and vs
-- mechanicals "…contra humanoides". Attack power, the vs stat seen on items, is the reference: its name is
-- trusted when no other creature type's name ends in the same word, and other stats' names must end in the
-- same word as the attack power name for their type. Words are compared folded, so case doesn't matter.
-- The vs names are checked once, here: make one getter per language and keep it.
function ns.TrustedNames(GetStatName, FoldCase)
	local function VsWord(stat, typeKey)
		local word = LastWord(GetStatName(VsKey(stat, typeKey)))
		return word and FoldCase(word)
	end

	-- The last word of each type's attack power name, and how many types end in each word
	local references, uses = {}, {}
	for typeKey in pairs(VS_CREATURE_TYPES) do
		local word = VsWord("ATTACK_POWER", typeKey)
		if word then
			references[typeKey] = word
			uses[word] = (uses[word] or 0) + 1
		end
	end

	local untrusted = {}
	for typeKey in pairs(VS_CREATURE_TYPES) do
		local reference = references[typeKey]
		for stat in pairs(VS_STATS) do
			if not reference or uses[reference] > 1 or VsWord(stat, typeKey) ~= reference then
				untrusted[VsKey(stat, typeKey)] = true
			end
		end
	end

	return function(key)
		if not untrusted[key] then
			return GetStatName(key)
		end
	end
end

-- Folded words that name a creature type in a tooltip line: the client's type name ("Bestia") and the last
-- word of the stat's own localized name ("Poder de ataque contra bestias"), which is usually the form the
-- tooltip uses, even in locales that decline it
local function CreatureTerms(context, creatureType, key)
	local terms = {}
	local typeName = context.GetCreatureTypeName(creatureType.id)
	if typeName then
		table.insert(terms, context.FoldCase(typeName))
	end
	local lastWord = LastWord(context.GetStatName(key))
	if lastWord then
		table.insert(terms, context.FoldCase(lastWord))
	end
	return terms
end

-- Turns the item's stats into claims; each rule calls Add(claim) for every claim it makes. The order
-- doesn't matter: a line with more than one possible owner is left alone.
ns.Rules = {
	{
		-- "Damage and healing by up to X" is a single spell power stat that counts as both: it shows as the
		-- same two lines as an item with separate spell damage and healing
		name = "combined spell power",
		claims = function(stats, _, Add)
			local power = stats.ITEM_MOD_SPELL_POWER_SHORT
			if power then
				Add(Claim({ power }, {
					Line("spellDamage", "≤", power, "spell damage", { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" }),
					Line("spellHealing", "≤", power, "spell healing", { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" }),
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
				table.insert(
					lines,
					Line("spellDamage", "≤", damage, "spell damage", { "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" })
				)
			end
			if healing then
				table.insert(
					lines,
					Line("spellHealing", "≤", healing, "spell healing", { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" })
				)
			end
			Add(Claim({ damage, healing }, lines))
		end,
	},
	{
		-- "Restores X mana per 5 sec." -> "+X MP5" in every language: the line has no stat names to translate.
		-- The 5 seconds are also a number in the line.
		name = "MP5",
		claims = function(stats, _, Add)
			local mp5 = stats.ITEM_MOD_MANA_REGENERATION_SHORT
			if mp5 then
				Add(Claim({ mp5, 5 }, { Line("mp5", "+", mp5, "MP5") }))
			end
		end,
	},
	{
		-- "Restores X health per 5 sec." -> "+X HP5", like MP5
		name = "HP5",
		claims = function(stats, _, Add)
			local hp5 = stats.ITEM_MOD_HEALTH_REGEN_SHORT
			if hp5 then
				Add(Claim({ hp5, 5 }, { Line("hp5", "+", hp5, "HP5") }))
			end
		end,
	},
	{
		name = "attack power",
		claims = function(stats, _, Add)
			local attackPower = stats.ITEM_MOD_ATTACK_POWER_SHORT
			if attackPower then
				local line = Line("attackPower", "+", attackPower, "attack power", { "ITEM_MOD_ATTACK_POWER_SHORT" })
				Add(Claim({ attackPower }, { line }))
			end
		end,
	},
	{
		-- "<stat> vs <creature type>", e.g. ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT -> "+6 attack power vs
		-- beasts". A plain line and a vs line can share the same number, so words naming the creature type
		-- tell them apart (see LocateCreatures). An unknown type still claims its number.
		name = "stat vs creature type",
		claims = function(stats, context, Add)
			for key, value in pairs(stats) do
				local stat, typeKey = key:match("^ITEM_MOD_([%u_]-)_VS_(%u+)_SHORT$")
				local vs = VS_STATS[stat]
				if vs then
					local creatureType = VS_CREATURE_TYPES[typeKey]
					if creatureType then
						local name = vs.name .. " vs " .. creatureType.label
						local claim = Claim({ value }, { Line(vs.kind, vs.sign, value, name, { key }) })
						local terms = CreatureTerms(context, creatureType, key)
						if #terms > 0 then
							claim.creature =
								{ terms = terms, label = creatureType.label, stat = stat, key = key, value = value }
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
					Add(Claim({ value }, { Line(stat.kind, "+", value, stat.name, { stat.key }) }))
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
			local groups = {}
			for _, skill in ipairs(WEAPON_SKILLS) do
				local key = "ITEM_MOD_" .. skill.key .. "_SHORT"
				local value = stats[key]
				if value then
					groups[value] = groups[value] or { labels = {}, keys = {} }
					table.insert(groups[value].labels, skill.label)
					table.insert(groups[value].keys, key)
				end
			end
			for value, group in pairs(groups) do
				local name = table.concat(group.labels, "/") .. " skill"
				local claim = Claim({ value }, { Line("weaponSkill", "+", value, name, group.keys) })
				claim.size = #group.keys
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
							return { Line(rating.kind, "+", GetOnlyPercent(text), rating.label, { key }, true) }
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
					Add(Claim({ value }, { Line(name .. "Damage", "≤", value, name .. " damage", { key }) }))
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

-- Where a folded line first names the claim's creature type, or nil
local function FindCreature(claim, foldedText)
	local first
	for _, term in ipairs(claim.creature and claim.creature.terms or {}) do
		local position = foldedText:find(term, 1, true)
		if position and (not first or position < first) then
			first = position
		end
	end
	return first
end

-- A creature claim is located in the lines it matches that name its creature type. Once located it
-- leaves its other lines, and a line where some claim is located keeps only the claims located there.
-- Only equip lines are searched: the item name can mention a creature type too.
local function LocateCreatures(lines, matches, FoldCase)
	local locatedIn, locatedAnywhere = {}, {}
	for i, text in ipairs(lines) do
		locatedIn[i] = {}
		local foldedText = FoldCase(text)
		for _, claim in ipairs(matches[i]) do
			if FindCreature(claim, foldedText) then
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
local function MatchClaims(lines, claims, FoldCase)
	local matches = {}
	for i, text in ipairs(lines) do
		matches[i] = {}
		for _, claim in ipairs(claims) do
			if Matches(claim, text) then
				table.insert(matches[i], claim)
			end
		end
	end
	LocateCreatures(lines, matches, FoldCase)
	return matches
end

-- One line that names several creature types for the same stat ("+150 Attack Power when fighting Undead
-- and Demons") becomes one compact line with every type, in the order the line names them. nil unless
-- every claim is a creature type of that stat named in the line.
local function CombineCreatures(claims, text, FoldCase)
	local stat = claims[1].creature and claims[1].creature.stat
	local foldedText = FoldCase(text)
	local found = {}
	for _, claim in ipairs(claims) do
		local creature = claim.creature
		local position = creature and creature.stat == stat and FindCreature(claim, foldedText)
		if not position then
			return nil
		end
		table.insert(found, { position = position, creature = creature })
	end
	table.sort(found, function(a, b)
		return a.position < b.position
	end)

	local labels, keys = {}, {}
	for _, entry in ipairs(found) do
		table.insert(labels, entry.creature.label)
		table.insert(keys, entry.creature.key)
	end
	local vs = VS_STATS[stat]
	local name = vs.name .. " vs " .. table.concat(labels, "/")
	return { Line(vs.kind, vs.sign, claims[1].creature.value, name, keys) }
end

-- Compact lines for an equip line (possibly empty, meaning "remove it"), or nil to keep its text: it isn't
-- one of this item's stat lines, or more than one stat could own it.
function ns.GetReplacement(text, stats, context)
	local lines, index = GetEquipLines(text, context)
	local matches = MatchClaims(lines, GetClaims(stats, context), context.FoldCase)

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
		return CombineCreatures(claims, text, context.FoldCase)
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

-- The names for a line's stats, or nil if any is missing or the line has no stat names (MP5, HP5, or a line
-- already localized)
local function GetStatNames(line, GetStatName)
	if not line.stats then
		return nil
	end
	local names = {}
	for i, key in ipairs(line.stats) do
		local name = GetStatName(key)
		if not name then
			return nil
		end
		names[i] = name
	end
	return names
end

-- The compact lines with Blizzard's stat names from GetStatName (a getter made with ns.TrustedNames)
-- instead of English ("≤10 Daño con hechizos"). A line naming several stats (a group of weapon skills,
-- several creature types) becomes one line per stat. A line stays as it is when one of its names is missing
-- or untrusted, so a second pass with other names can still translate it.
function ns.LocalizeLines(lines, GetStatName)
	local localized = {}
	for _, line in ipairs(lines) do
		local names = GetStatNames(line, GetStatName)
		if names then
			for _, name in ipairs(names) do
				table.insert(
					localized,
					{ kind = line.kind, text = FormatLine(line.sign, line.value, line.percent, name) }
				)
			end
		else
			table.insert(localized, line)
		end
	end
	return localized
end
