-- Localized "Equip:" prefix, provided by the client in every locale
local EQUIP_PREFIX = ITEM_SPELL_TRIGGER_ONEQUIP

-- Link of the item whose tooltip data is being processed. Mirrors TooltipUtil.GetDisplayedItem,
-- but reads the info being processed instead of the primary one, so appended infos are handled too.
local function GetProcessingItemLink(tooltip)
	local info = tooltip:GetProcessingTooltipInfo()
	local data = info and info.tooltipData
	if not data or data.type ~= Enum.TooltipDataType.Item then
		return nil
	end
	if data.guid then
		return C_Item.GetItemLinkByGUID(data.guid)
	end
	return data.hyperlink
end

-- The tooltip wording varies per locale and per item, so the line is identified by its numbers:
-- they must be exactly the item's spell damage/healing values, nothing more and nothing less.
local function NumbersMatch(text, damage, healing)
	local expected = {}
	if damage then
		expected[damage] = true
	end
	if healing then
		expected[healing] = true
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

-- Compact lines for an equip line, or nil when it isn't one of this item's stat lines
local function GetReplacement(text, stats)
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

	local link = GetProcessingItemLink(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	local lines = stats and GetReplacement(text, stats)
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
