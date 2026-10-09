-- Replacement rules for equip lines. No WoW API here: everything that comes from the game is passed in
-- through `context`, so this file can be unit tested outside the game.
--
-- context.lines                  all the item's tooltip data lines ({ leftText = ... })
-- context.equipPrefix            localized "Equip:" prefix
-- context.GetCreatureTypeName(id) localized creature type name ("Bestia" on esES), or nil
local _, ns = ...

local NumbersMatch = ns.NumbersMatch
local GetOnlyPercent = ns.GetOnlyPercent
local HasOtherRating = ns.HasOtherRating
local AnyLineMentions = ns.AnyLineMentions

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
	{ key = "ITEM_MOD_BLOCK_RATING_SHORT", kind = "blockRating", label = "block rating" },
	{ key = "ITEM_MOD_HIT_RATING_SHORT", kind = "hitRating", label = "hit rating" },
	{ key = "ITEM_MOD_CRIT_RATING_SHORT", kind = "critRating", label = "crit rating" },
	{ key = "ITEM_MOD_HIT_SPELL_RATING_SHORT", kind = "spellHitRating", label = "spell hit rating" },
	{ key = "ITEM_MOD_CRIT_SPELL_RATING_SHORT", kind = "spellCritRating", label = "spell crit rating" },
	{ key = "ITEM_MOD_DODGE_RATING_SHORT", kind = "dodgeRating", label = "dodge rating" },
	{ key = "ITEM_MOD_PARRY_RATING_SHORT", kind = "parryRating", label = "parry rating" },
}

-- A compact line; `kind` picks its color (ns.COLOR_KINDS), unknown kinds keep the original line color
local function Line(kind, text)
	return { kind = kind, text = text }
end

-- "<stat> vs <creature type>" lines, e.g. ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT. A plain line and a vs line
-- can share the same number, so the client's localized creature type name tells them apart. Returns the
-- vs line when this is one, and whether lines with this number can't be told apart (the name isn't found
-- anywhere in the tooltip, or the type is unknown); those are left untouched rather than guessed.
local function MatchVsCreature(text, stats, context, stat, kind, format)
	local ambiguous = false
	local pattern = "^ITEM_MOD_" .. stat .. "_VS_(%u+)_SHORT$"
	for key, value in pairs(stats) do
		local creature = key:match(pattern)
		if creature and NumbersMatch(text, value) then
			local creatureType = VS_CREATURE_TYPES[creature]
			local name = creatureType and context.GetCreatureTypeName(creatureType.id)
			name = name and name:lower()
			if name and text:lower():find(name, 1, true) then
				return { Line(kind, format:format(value, creatureType.label)) }, false
			end
			ambiguous = ambiguous or not (name and AnyLineMentions(context.lines, name))
		end
	end
	return nil, ambiguous
end

-- Texts of the item's equip lines whose numbers are exactly `value`, in tooltip order
local function EquipLinesWithNumber(context, value)
	local found = {}
	for _, line in ipairs(context.lines) do
		local text = line.leftText
		if text and text:sub(1, #context.equipPrefix) == context.equipPrefix and NumbersMatch(text, value) then
			table.insert(found, text)
		end
	end
	return found
end

-- Ordered: the first rule that returns lines wins. The order matters when two lines of an item share the
-- same numbers. Each rule returns the compact lines for an equip line, an empty list to remove the line,
-- or nil when the line isn't its own.
ns.Rules = {
	{
		-- "Damage and healing by up to X" is a single spell power stat that counts as both
		name = "combined spell power",
		replace = function(text, stats)
			local power = stats.ITEM_MOD_SPELL_POWER_SHORT
			if power and NumbersMatch(text, power) then
				return {
					Line("spellPower", ("≤%d spell power"):format(power)),
					Line("healingPower", ("≤%d healing power"):format(power)),
				}
			end
		end,
	},
	{
		-- Spell damage and/or healing, or spell damage against a creature type
		name = "spell damage and healing",
		replace = function(text, stats, context)
			local vsLines, ambiguous =
				MatchVsCreature(text, stats, context, "SPELL_DAMAGE", "spellDamageVs", "≤%d spell damage vs %s")
			if vsLines then
				return vsLines
			end

			local damage = stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT
			local healing = stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT
			if (damage or healing) and not ambiguous and NumbersMatch(text, damage, healing) then
				local lines = {}
				if damage then
					table.insert(lines, Line("spellPower", ("≤%d spell power"):format(damage)))
				end
				if healing then
					table.insert(lines, Line("healingPower", ("≤%d healing power"):format(healing)))
				end
				return lines
			end
		end,
	},
	{
		-- "Restores X mana per 5 sec." -> "+X MP5"; the 5 seconds are also a number in the line
		name = "MP5",
		replace = function(text, stats)
			local mp5 = stats.ITEM_MOD_MANA_REGENERATION_SHORT
			if mp5 and NumbersMatch(text, mp5, 5) then
				return { Line("mp5", ("+%d MP5"):format(mp5)) }
			end
		end,
	},
	{
		-- "Restores X health per 5 sec." -> "+X HP5"
		name = "HP5",
		replace = function(text, stats)
			local hp5 = stats.ITEM_MOD_HEALTH_REGEN_SHORT
			if hp5 and NumbersMatch(text, hp5, 5) then
				return { Line("hp5", ("+%d HP5"):format(hp5)) }
			end
		end,
	},
	{
		-- Attack power, plain or against a creature type ("+6 attack power vs beasts")
		name = "attack power",
		replace = function(text, stats, context)
			local vsLines, ambiguous =
				MatchVsCreature(text, stats, context, "ATTACK_POWER", "attackPowerVs", "+%d attack power vs %s")
			if vsLines then
				return vsLines
			end

			local attackPower = stats.ITEM_MOD_ATTACK_POWER_SHORT
			if attackPower and not ambiguous and NumbersMatch(text, attackPower) then
				return { Line("attackPower", ("+%d attack power"):format(attackPower)) }
			end
		end,
	},
	{
		name = "point stats",
		replace = function(text, stats)
			for _, stat in ipairs(POINT_STATS) do
				local value = stats[stat.key]
				if value and NumbersMatch(text, value) then
					return { Line(stat.kind, stat.format:format(value)) }
				end
			end
		end,
	},
	{
		-- "Increased Swords +7." Some items raise several skills by the same amount, one line each, and
		-- numbers can't tell those lines apart: the first one becomes a combined line
		-- ("+7 axes/daggers/swords skill") and the others are removed. Left untouched when the number of
		-- such lines doesn't match the number of skills.
		name = "weapon skills",
		replace = function(text, stats, context)
			local labels, value = {}, nil
			for _, skill in ipairs(WEAPON_SKILLS) do
				local skillValue = stats["ITEM_MOD_" .. skill.key .. "_SHORT"]
				if skillValue and NumbersMatch(text, skillValue) then
					table.insert(labels, skill.label)
					value = skillValue
				end
			end
			if #labels == 0 then
				return nil
			end

			if #labels > 1 then
				local sameLines = EquipLinesWithNumber(context, value)
				if #sameLines ~= #labels then
					return nil
				elseif sameLines[1] ~= text then
					return {}
				end
			end
			return { Line("weaponSkill", ("+%d %s skill"):format(value, table.concat(labels, "/"))) }
		end,
	},
	{
		-- Stats stored as a rating but shown as a percentage ("+1.0% chance to block with a shield",
		-- "improves your chance to hit by 1%"). The rating isn't the shown number (5 block rating showed
		-- as 1%), so the percentage is read from the text, and only when no other rating could own it.
		name = "rating percentage",
		replace = function(text, stats)
			for _, rating in ipairs(PERCENT_RATINGS) do
				if stats[rating.key] and not HasOtherRating(stats, rating.key) then
					local percent = GetOnlyPercent(text)
					if percent then
						return { Line(rating.kind, ("+%s%% %s"):format(percent, rating.label)) }
					end
				end
			end
		end,
	},
	{
		-- Single school damage, e.g. ITEM_MOD_FROST_DAMAGE_DONE_SHORT -> "≤32 frost damage"
		name = "school damage",
		replace = function(text, stats)
			for key, value in pairs(stats) do
				local school = key:match("^ITEM_MOD_(%u+)_DAMAGE_DONE_SHORT$")
				if school and school ~= "SPELL" and NumbersMatch(text, value) then
					local name = school:lower()
					return { Line(name .. "Damage", ("≤%d %s damage"):format(value, name)) }
				end
			end
		end,
	},
}

-- Compact lines for an equip line (possibly empty, meaning "remove it"), or nil when it isn't one of this
-- item's stat lines
function ns.GetReplacement(text, stats, context)
	for _, rule in ipairs(ns.Rules) do
		local lines = rule.replace(text, stats, context)
		if lines then
			return lines
		end
	end
	return nil
end
