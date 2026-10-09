-- Replacement rules for equip lines. No WoW API here: everything that comes from the game is passed in
-- through `context`, so this file can be unit tested outside the game.
--
-- context.lines                  all the item's tooltip data lines ({ leftText = ... })
-- context.GetCreatureTypeName(id) localized creature type name ("Bestia" on esES), or nil
local _, ns = ...

local NumbersMatch = ns.NumbersMatch
local GetOnlyPercent = ns.GetOnlyPercent
local HasOtherRating = ns.HasOtherRating
local AnyLineMentions = ns.AnyLineMentions

-- Creature types that attack power can be restricted to: stat key suffix -> creature type ID and output label.
-- Only BEAST and ELEMENTAL have been seen in-game; the other keys follow the same naming. A wrong key
-- just never matches, which leaves the line untouched.
local VS_CREATURE_TYPES = {
	BEAST = { id = 1, label = "beasts" },
	DRAGONKIN = { id = 2, label = "dragonkin" },
	DEMON = { id = 3, label = "demons" },
	ELEMENTAL = { id = 4, label = "elementals" },
	GIANT = { id = 5, label = "giants" },
	UNDEAD = { id = 6, label = "undead" },
	HUMANOID = { id = 7, label = "humanoids" },
}

-- Ordered: the first rule that returns lines wins. The order matters when two lines of an item
-- share the same numbers. Each rule returns the compact lines for an equip line, or nil.
ns.Rules = {
	{
		-- "Damage and healing by up to X" is a single spell power stat that counts as both
		name = "combined spell power",
		replace = function(text, stats)
			local power = stats.ITEM_MOD_SPELL_POWER_SHORT
			if power and NumbersMatch(text, power) then
				return { ("≤%d spell power"):format(power), ("≤%d healing power"):format(power) }
			end
		end,
	},
	{
		name = "spell damage and healing",
		replace = function(text, stats)
			local damage = stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT
			local healing = stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT
			if (damage or healing) and NumbersMatch(text, damage, healing) then
				local lines = {}
				if damage then
					table.insert(lines, ("≤%d spell power"):format(damage))
				end
				if healing then
					table.insert(lines, ("≤%d healing power"):format(healing))
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
				return { ("+%d MP5"):format(mp5) }
			end
		end,
	},
	{
		-- "Restores X health per 5 sec." -> "+X HP5"
		name = "HP5",
		replace = function(text, stats)
			local hp5 = stats.ITEM_MOD_HEALTH_REGEN_SHORT
			if hp5 and NumbersMatch(text, hp5, 5) then
				return { ("+%d HP5"):format(hp5) }
			end
		end,
	},
	{
		-- Attack power, plain or against a creature type ("+6 attack power vs beasts"). Both can share the
		-- same number, so the client's localized creature type name tells the lines apart. When that name
		-- can't be found in the tooltip, lines with that number are left untouched rather than guessed.
		name = "attack power",
		replace = function(text, stats, context)
			local ambiguous = false
			for key, value in pairs(stats) do
				local creature = key:match("^ITEM_MOD_ATTACK_POWER_VS_(%u+)_SHORT$")
				if creature and NumbersMatch(text, value) then
					local creatureType = VS_CREATURE_TYPES[creature]
					local name = creatureType and context.GetCreatureTypeName(creatureType.id)
					name = name and name:lower()
					if name and text:lower():find(name, 1, true) then
						return { ("+%d attack power vs %s"):format(value, creatureType.label) }
					end
					ambiguous = ambiguous or not (name and AnyLineMentions(context.lines, name))
				end
			end

			local attackPower = stats.ITEM_MOD_ATTACK_POWER_SHORT
			if attackPower and not ambiguous and NumbersMatch(text, attackPower) then
				return { ("+%d attack power"):format(attackPower) }
			end
		end,
	},
	{
		-- "+1.0% chance to block with a shield". The stat is a rating (5 for 1% seen so far), so the
		-- percentage is read from the text, and only when no other rating could own that percentage.
		name = "block chance",
		replace = function(text, stats)
			if stats.ITEM_MOD_BLOCK_RATING_SHORT and not HasOtherRating(stats, "ITEM_MOD_BLOCK_RATING_SHORT") then
				local percent = GetOnlyPercent(text)
				if percent then
					return { ("+%s%% block chance"):format(percent) }
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
					return { ("≤%d %s damage"):format(value, school:lower()) }
				end
			end
		end,
	},
}

-- Compact lines for an equip line, or nil when it isn't one of this item's stat lines
function ns.GetReplacement(text, stats, context)
	for _, rule in ipairs(ns.Rules) do
		local lines = rule.replace(text, stats, context)
		if lines then
			return lines
		end
	end
	return nil
end
