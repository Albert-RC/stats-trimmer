-- Localized "Equip:" prefix, provided by the client in every locale
local EQUIP_PREFIX = ITEM_SPELL_TRIGGER_ONEQUIP

-- Creature types that attack power can be restricted to: stat key suffix -> creature type ID and output label
local VS_CREATURE_TYPES = {
	BEAST = { id = 1, label = "beasts" },
}

-- Link and data lines of the item whose tooltip data is being processed. Mirrors TooltipUtil.GetDisplayedItem,
-- but reads the info being processed instead of the primary one, so appended infos are handled too.
local function GetProcessingItem(tooltip)
	local info = tooltip:GetProcessingTooltipInfo()
	local data = info and info.tooltipData
	if not data or data.type ~= Enum.TooltipDataType.Item then
		return nil
	end
	local link = data.guid and C_Item.GetItemLinkByGUID(data.guid) or data.hyperlink
	return link, data.lines
end

-- Lowercase localized creature type name ("bestia" on esES), or nil if the type is unknown
local function GetCreatureTypeName(creature)
	local creatureType = VS_CREATURE_TYPES[creature]
	local info = creatureType and C_CreatureInfo.GetCreatureTypeInfo(creatureType.id)
	return info and info.name:lower()
end

local function AnyLineMentions(lines, lowerName)
	for _, line in ipairs(lines) do
		if line.leftText and line.leftText:lower():find(lowerName, 1, true) then
			return true
		end
	end
	return false
end

-- The tooltip wording varies per locale and per item, so the line is identified by its numbers:
-- they must be exactly the expected values (a and/or b), nothing more and nothing less.
local function NumbersMatch(text, a, b)
	local expected = {}
	if a then
		expected[a] = true
	end
	if b then
		expected[b] = true
	end

	local found = {}
	for number in text:gmatch("%d+") do
		local value = tonumber(number)
		if not expected[value] then
			return false
		end
		found[value] = true
	end
	for value in pairs(expected) do
		if not found[value] then
			return false
		end
	end
	return true
end

-- The percentage in a line ("1.0%", "1,0 %") as a short string ("1", "1.5").
-- nil unless it is the only number in the line.
local PERCENT_PATTERN = "%d+[%.,]?%d*%s*%%"

local function GetOnlyPercent(text)
	local percent = text:match(PERCENT_PATTERN)
	if not percent or text:gsub(PERCENT_PATTERN, ""):find("%d") then
		return nil
	end
	local value = tonumber((percent:match("[%d%.,]+"):gsub(",", ".")))
	return value and tostring(value)
end

-- True when the item has a rating stat other than the given one
local function HasOtherRating(stats, ratingKey)
	for key in pairs(stats) do
		if key ~= ratingKey and key:find("_RATING_SHORT$") then
			return true
		end
	end
	return false
end

-- Compact lines for an equip line, or nil when it isn't one of this item's stat lines.
-- itemLines are all the item's tooltip data lines, for rules that need to look at sibling lines.
local function GetReplacement(text, stats, itemLines)
	-- "Damage and healing by up to X" is a single spell power stat that counts as both
	local power = stats.ITEM_MOD_SPELL_POWER_SHORT
	if power and NumbersMatch(text, power) then
		return { ("≤%d spell power"):format(power), ("≤%d healing power"):format(power) }
	end

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

	-- "Restores X mana per 5 sec." -> "+X MP5"; the 5 seconds are also a number in the line
	local mp5 = stats.ITEM_MOD_MANA_REGENERATION_SHORT
	if mp5 and NumbersMatch(text, mp5, 5) then
		return { ("+%d MP5"):format(mp5) }
	end

	-- "Restores X health per 5 sec." -> "+X HP5"
	local hp5 = stats.ITEM_MOD_HEALTH_REGEN_SHORT
	if hp5 and NumbersMatch(text, hp5, 5) then
		return { ("+%d HP5"):format(hp5) }
	end

	-- Attack power, plain or against a creature type ("+6 attack power vs beasts"). Both can share the
	-- same number, so the client's localized creature type name tells the lines apart. When that name
	-- can't be found in the tooltip, lines with that number are left untouched rather than guessed.
	local ambiguous = false
	for key, value in pairs(stats) do
		local creature = key:match("^ITEM_MOD_ATTACK_POWER_VS_(%u+)_SHORT$")
		if creature and NumbersMatch(text, value) then
			local name = GetCreatureTypeName(creature)
			if name and text:lower():find(name, 1, true) then
				return { ("+%d attack power vs %s"):format(value, VS_CREATURE_TYPES[creature].label) }
			end
			ambiguous = ambiguous or not (name and AnyLineMentions(itemLines, name))
		end
	end

	local attackPower = stats.ITEM_MOD_ATTACK_POWER_SHORT
	if attackPower and not ambiguous and NumbersMatch(text, attackPower) then
		return { ("+%d attack power"):format(attackPower) }
	end

	-- "+1.0% chance to block with a shield". The stat is a rating (5 for 1% seen so far), so the
	-- percentage is read from the text, and only when no other rating could own that percentage.
	if stats.ITEM_MOD_BLOCK_RATING_SHORT and not HasOtherRating(stats, "ITEM_MOD_BLOCK_RATING_SHORT") then
		local percent = GetOnlyPercent(text)
		if percent then
			return { ("+%s%% block chance"):format(percent) }
		end
	end

	-- Single school damage, e.g. ITEM_MOD_FROST_DAMAGE_DONE_SHORT -> "≤32 frost damage"
	for key, value in pairs(stats) do
		local school = key:match("^ITEM_MOD_(%u+)_DAMAGE_DONE_SHORT$")
		if school and school ~= "SPELL" and NumbersMatch(text, value) then
			return { ("≤%d %s damage"):format(value, school:lower()) }
		end
	end
	return nil
end

-- Line pre-call: returning true keeps the original line out of the tooltip
local function ReplaceEquipLine(tooltip, lineData)
	local text = lineData.leftText
	if not text or text:sub(1, #EQUIP_PREFIX) ~= EQUIP_PREFIX then
		return false
	end

	local link, itemLines = GetProcessingItem(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	local lines = stats and GetReplacement(text, stats, itemLines)
	if not lines then
		return false
	end

	local r, g, b = (lineData.leftColor or NORMAL_FONT_COLOR):GetRGB()
	for _, line in ipairs(lines) do
		tooltip:AddLine(line, r, g, b)
	end
	return true
end

-- In Forever, equip lines arrive with type None, not ItemSpellTriggerOnEquip
TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.None, ReplaceEquipLine)
