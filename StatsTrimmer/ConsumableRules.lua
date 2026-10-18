-- Replacement rules for the Use lines of consumables: food and drink, and potions, elixirs and flasks. No WoW API
-- here: everything that comes from the game is passed in, so this file can be unit tested outside the game.
--
-- context.usePrefix       localized "Use:" prefix
-- context.cooldownFormat  the client's ITEM_COOLDOWN_TOTAL ("(%s Cooldown)"), or nil
-- context.secondsFormat   the client's SECONDS_ABBR ("%d |4Sec:Sec;"), how it writes a cooldown in seconds, or nil
-- context.minutesFormat   the client's MINUTES_ABBR ("%d |4Min:Min;"), the same in minutes, or nil
--
-- A consumable's Use line is its spell's description, so FoodData.lua and AlchemyData.lua know which numbers it
-- shows and what each one is, whatever the language or their order. The line is only rewritten when it shows
-- exactly those numbers, plus, for food, one for each amount the client computes (the health or mana it restores)
-- and the experience bonus some players see. Anything else keeps its original text.
local _, ns = ...

local StatLine = ns.StatLine
local ResolvePlural = ns.ResolvePlural

-- The stat keys FoodData.lua uses -> line kind. Their English names are ns.ENGLISH_NAMES'.
local FOOD_KINDS = {
	HEALTH = "health",
	MANA = "mana",
	ITEM_MOD_STAMINA_SHORT = "stamina",
	ITEM_MOD_INTELLECT_SHORT = "intellect",
	ITEM_MOD_STRENGTH_SHORT = "strength",
	ITEM_MOD_AGILITY_SHORT = "agility",
	ITEM_MOD_SPIRIT_SHORT = "spirit",
	ARMOR = "armor",
	ITEM_MOD_ATTACK_POWER_SHORT = "attackPower",
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spellDamage",
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = "spellHealing",
	ITEM_MOD_CRIT_RATING_SHORT = "critRating",
}

-- The stat keys AlchemyData.lua uses -> line kind, the alchemy tab's own. Their English names are
-- ns.ENGLISH_NAMES'; MP5 and HP5 have no name but their own.
local ALCHEMY_KINDS = {
	ITEM_MOD_STRENGTH_SHORT = "alchemyStrength",
	ITEM_MOD_AGILITY_SHORT = "alchemyAgility",
	ITEM_MOD_STAMINA_SHORT = "alchemyStamina",
	ITEM_MOD_INTELLECT_SHORT = "alchemyIntellect",
	ITEM_MOD_SPIRIT_SHORT = "alchemySpirit",
	ITEM_MOD_ATTACK_POWER_SHORT = "alchemyAttackPower",
	ITEM_MOD_CRIT_RATING_SHORT = "alchemyCritRating",
	HEALTH = "alchemyHealth",
	ARMOR = "alchemyArmor",
	ITEM_MOD_SPELL_RESISTANCE_ALL_SCHOOLS_SHORT = "alchemySpellResistance",
	HP5 = "alchemyHp5",
	MANA = "alchemyMana",
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "alchemySpellDamage",
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = "alchemySpellHealing",
	MP5 = "alchemyMp5",
	ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "alchemyFireDamage",
	ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "alchemyFrostDamage",
	ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "alchemyHolyDamage",
	ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "alchemyNatureDamage",
	ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "alchemyShadowDamage",
}
-- ITEM_MOD_<stat>_VS_<TYPE>_SHORT -> line kind, for every creature type. Their English names are
-- ns.GetVsEnglishName's.
local ALCHEMY_VS_KINDS = {
	ATTACK_POWER = "alchemyAttackPowerVs",
	SPELL_DAMAGE = "alchemySpellDamageVs",
}

-- Cooldowns that every consumable of a kind shares, which the client adds at the end of the line: their length
-- and the context's format for its unit. Any other is worth knowing, so a line with one keeps its original text.
-- Food shares 1 second.
local FOOD_COOLDOWNS = { { 1, "secondsFormat" } }
-- Elixirs and flasks share 3 seconds, potions 2 minutes (ItemEffect's category cooldowns)
local ALCHEMY_COOLDOWNS = { { 3, "secondsFormat" }, { 2, "minutesFormat" } }

-- The text without the client's plural escapes ("|4Sec:Sec;"): their 4 isn't a number the player sees
local function WithoutEscapes(text)
	return (text:gsub("|4[^;]*;", ""))
end

-- A Lua pattern for the cooldown texts a Blizzard format string makes, capturing what its %s stands for. A
-- duration has no parentheses, so the match can't start at an earlier one in the line ("Punkt(e)" in deDE).
local function CooldownPattern(format)
	local escaped = format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return (escaped:gsub("%%%%s", "([^()]-)"))
end

-- True when a cooldown's duration is one of the shared ones, written as the client writes it with its unit's
-- format: "1 |4Sec:Sec;", or "1 Sec" with its escape already resolved. Its number alone can't tell: "1 |4Min:Min;"
-- is a minute. Without the unit's format, no cooldown in that unit is known to be a shared one.
local function IsSharedCooldown(duration, context, cooldowns)
	duration = duration:match("^%s*(.-)%s*$")
	for _, cooldown in ipairs(cooldowns) do
		local length, formatKey = unpack(cooldown)
		local format = context[formatKey]
		if format then
			local shared = format:gsub("%%d", tostring(length), 1)
			if duration == shared or duration == ResolvePlural(shared, length) then
				return true
			end
		end
	end
	return false
end

-- The line without the cooldown at its end ("(1 |4Sec:Sec; Cooldown)"), or nil when it isn't a shared one
local function WithoutCooldown(text, context, cooldowns)
	if not context.cooldownFormat then
		return text
	end
	local start, _, duration = text:find("%s*" .. CooldownPattern(context.cooldownFormat) .. "%s*$")
	if not start then
		return text
	end
	if not IsSharedCooldown(duration, context, cooldowns) then
		return nil
	end
	return text:sub(1, start - 1)
end

-- How many times the line shows each number, and how many numbers it shows. A thousands separator ("1,200",
-- "2.148") is part of the number.
local function CountNumbers(text)
	local counts, total = {}, 0
	for number in WithoutEscapes(text):gsub("(%d)[,%.](%d%d%d)%f[%D]", "%1%2"):gmatch("%d+") do
		local value = tonumber(number)
		counts[value] = (counts[value] or 0) + 1
		total = total + 1
	end
	return counts, total
end

-- Takes one of the line's numbers; false when the line doesn't show it (any more)
local function Take(counts, value)
	if (counts[value] or 0) == 0 then
		return false
	end
	counts[value] = counts[value] - 1
	return true
end

-- The numbers left in `counts` for the lines with an amount: the larger number goes to the larger base points,
-- as the client computes every amount of a food in the same way. nil when two amounts with the same base
-- points get different numbers.
local function ReadAmounts(counts, amountLines)
	local found = {}
	for value, count in pairs(counts) do
		for _ = 1, count do
			table.insert(found, value)
		end
	end
	table.sort(found, function(a, b)
		return a > b
	end)
	local ordered = { unpack(amountLines) }
	table.sort(ordered, function(a, b)
		return a.amount > b.amount
	end)
	local amounts = {}
	for i, line in ipairs(ordered) do
		local previous = ordered[i - 1]
		if previous and previous.amount == line.amount and found[i - 1] ~= found[i] then
			return nil
		end
		amounts[line] = found[i]
	end
	return amounts
end

-- Compact lines for a consumable's Use line, or nil to keep its text: it isn't the line `entry` (its entry in the
-- data file) describes, or shows a cooldown other than the shared `cooldowns`. Line(dataLine, value) makes each
-- compact line, or nil for one it doesn't know.
local function GetUseReplacement(text, entry, context, cooldowns, Line)
	local prefix = context.usePrefix
	if text:sub(1, #prefix) ~= prefix then
		return nil
	end
	local body = WithoutCooldown(text:sub(#prefix + 1), context, cooldowns)
	if not body then
		return nil
	end

	local counts, left = CountNumbers(body)
	for _, number in ipairs(entry.numbers) do
		if not Take(counts, number) then
			return nil
		end
		left = left - 1
	end
	local amountLines = {}
	for _, line in ipairs(entry.lines) do
		if line.amount then
			table.insert(amountLines, line)
		end
	end
	-- The experience bonus is one number more, when the client shows it
	local showsExperience = entry.experience ~= nil and left == #amountLines + 1 and Take(counts, entry.experience)
	if showsExperience then
		left = left - 1
	end
	if left ~= #amountLines then
		return nil
	end
	local amounts = ReadAmounts(counts, amountLines)
	if not amounts then
		return nil
	end

	local lines = {}
	for _, line in ipairs(entry.lines) do
		local compact = Line(line, line.amount and amounts[line] or line.value)
		if not compact then
			return nil
		end
		table.insert(lines, compact)
	end
	-- The bonus only counts for kills, which its name says: Blizzard's words from the bonus buff
	if showsExperience then
		table.insert(lines, StatLine("experience", entry.experience, "KILL_EXPERIENCE", true))
	end
	return lines
end

-- A food's compact line. The data line holds the details: perSecond, seconds and wellFedMinutes.
local function FoodLine(line, value)
	local kind = FOOD_KINDS[line.stat]
	return kind and StatLine(kind, value, line.stat, line.percent, line)
end

-- A potion's, elixir's or flask's compact line. The data line holds how long it lasts: seconds, minutes or hours.
local function AlchemyLine(line, value)
	local vsStat = line.stat:match("^ITEM_MOD_([%u_]-)_VS_%u+_SHORT$")
	if vsStat then
		local kind, name = ALCHEMY_VS_KINDS[vsStat], ns.GetVsEnglishName(line.stat)
		return kind and name and ns.CompactLine(kind, value, name, { line.stat }, line.percent, line)
	end
	local kind = ALCHEMY_KINDS[line.stat]
	if line.stat == "MP5" or line.stat == "HP5" then
		-- Named the same in every language
		return ns.CompactLine(kind, value, line.stat, nil, false, line)
	end
	return kind and StatLine(kind, value, line.stat, line.percent, line)
end

-- Compact lines for a food's Use line, or nil to keep its text. `food` is the line's entry in ns.FOODS.
function ns.GetFoodReplacement(text, food, context)
	return GetUseReplacement(text, food, context, FOOD_COOLDOWNS, FoodLine)
end

-- Compact lines for a potion's, elixir's or flask's Use line, or nil to keep its text. `entry` is the line's entry
-- in ns.ALCHEMY.
function ns.GetAlchemyReplacement(text, entry, context)
	return GetUseReplacement(text, entry, context, ALCHEMY_COOLDOWNS, AlchemyLine)
end
