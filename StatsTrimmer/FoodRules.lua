-- Replacement rules for the Use lines of food and drink. No WoW API here: everything that comes from the game
-- is passed in, so this file can be unit tested outside the game.
--
-- context.usePrefix       localized "Use:" prefix
-- context.cooldownFormat  the client's ITEM_COOLDOWN_TOTAL ("(%s Cooldown)"), or nil
-- context.secondsFormat   the client's SECONDS_ABBR ("%d |4Sec:Sec;"), how it writes a cooldown in seconds, or nil
--
-- A food's Use line is its spell's description, so FoodData.lua knows which numbers it shows and what each one
-- is, whatever the language or their order. The line is only rewritten when it shows exactly those numbers,
-- plus one for each amount the client computes (the health or mana it restores) and the experience bonus some
-- players see. Anything else keeps its original text.
local _, ns = ...

local Line = ns.CompactLine

-- The stat keys FoodData.lua uses: line kind and English name
local FOOD_STATS = {
	HEALTH = { kind = "health", name = "health" },
	MANA = { kind = "mana", name = "mana" },
	ITEM_MOD_STAMINA_SHORT = { kind = "stamina", name = "stamina" },
	ITEM_MOD_INTELLECT_SHORT = { kind = "intellect", name = "intellect" },
	ITEM_MOD_STRENGTH_SHORT = { kind = "strength", name = "strength" },
	ITEM_MOD_AGILITY_SHORT = { kind = "agility", name = "agility" },
	ITEM_MOD_SPIRIT_SHORT = { kind = "spirit", name = "spirit" },
	ARMOR = { kind = "armor", name = "armor" },
	ITEM_MOD_ATTACK_POWER_SHORT = { kind = "attackPower", name = "attack power" },
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = { kind = "spellDamage", name = "spell damage" },
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = { kind = "spellHealing", name = "spell healing" },
	ITEM_MOD_CRIT_RATING_SHORT = { kind = "critRating", name = "crit rating" },
}

-- Foods share a 1 second cooldown, which the client adds at the end of the line. Any other is worth knowing,
-- so a line with one keeps its original text.
local SHARED_COOLDOWN = 1

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

-- The text with the client's plural escapes in their singular form: "1 |4Sec:Sec;" -> "1 Sec"
local function Singular(text)
	return (text:gsub("|4([^:;]*):[^;]*;", "%1"))
end

-- True when a cooldown's duration is the shared one, written as the client writes 1 second with SECONDS_ABBR:
-- "1 |4Sec:Sec;", or "1 Sec" with its escape already resolved. Its number alone can't tell: "1 |4Min:Min;" is a
-- minute. Without SECONDS_ABBR, no cooldown is known to be the shared one.
local function IsSharedCooldown(duration, secondsFormat)
	if not secondsFormat then
		return false
	end
	local shared = secondsFormat:gsub("%%d", tostring(SHARED_COOLDOWN), 1)
	duration = duration:match("^%s*(.-)%s*$")
	return duration == shared or duration == Singular(shared)
end

-- The line without the cooldown at its end ("(1 |4Sec:Sec; Cooldown)"), or nil when it isn't the shared one
local function WithoutCooldown(text, context)
	if not context.cooldownFormat then
		return text
	end
	local start, _, duration = text:find("%s*" .. CooldownPattern(context.cooldownFormat) .. "%s*$")
	if not start then
		return text
	end
	if not IsSharedCooldown(duration, context.secondsFormat) then
		return nil
	end
	return text:sub(1, start - 1)
end

-- How many times the line shows each number, and how many numbers it shows. A thousands separator, which some
-- languages may add to large numbers ("2,148", "2.148"), is part of the number.
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

-- Compact lines for a food's Use line, or nil to keep its text: it isn't the line FoodData.lua describes, or
-- shows a longer cooldown than the shared one. `food` is the line's entry in ns.FOODS.
function ns.GetFoodReplacement(text, food, context)
	local prefix = context.usePrefix
	if text:sub(1, #prefix) ~= prefix then
		return nil
	end
	local body = WithoutCooldown(text:sub(#prefix + 1), context)
	if not body then
		return nil
	end

	local counts, left = CountNumbers(body)
	for _, number in ipairs(food.numbers) do
		if not Take(counts, number) then
			return nil
		end
		left = left - 1
	end
	local amountLines = {}
	for _, line in ipairs(food.lines) do
		if line.amount then
			table.insert(amountLines, line)
		end
	end
	-- The experience bonus is one number more, when the client shows it
	local showsExperience = food.experience ~= nil and left == #amountLines + 1 and Take(counts, food.experience)
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
	for _, line in ipairs(food.lines) do
		local stat = FOOD_STATS[line.stat]
		if not stat then
			return nil
		end
		-- The data line holds the details: perSecond, seconds and wellFedMinutes
		local value = line.amount and amounts[line] or line.value
		table.insert(lines, Line(stat.kind, value, stat.name, { line.stat }, line.percent, line))
	end
	-- The bonus only counts for kills, which its name says: Blizzard's words from the bonus buff
	if showsExperience then
		local name = "experience gained from kills"
		table.insert(lines, Line("experience", food.experience, name, { "KILL_EXPERIENCE" }, true))
	end
	return lines
end
