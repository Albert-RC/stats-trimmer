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

-- Line pre-call: returning true keeps the original line out of the tooltip
local function ReplaceSpellPowerLine(tooltip, lineData)
	local text = lineData.leftText
	if not text or text:sub(1, #EQUIP_PREFIX) ~= EQUIP_PREFIX then
		return false
	end

	local link = GetProcessingItemLink(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	if not stats then
		return false
	end

	local damage = stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT
	local healing = stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT
	if not (damage or healing) or not NumbersMatch(text, damage, healing) then
		return false
	end

	local r, g, b = (lineData.leftColor or NORMAL_FONT_COLOR):GetRGB()
	if damage then
		tooltip:AddLine(("≤ %d spell power"):format(damage), r, g, b)
	end
	if healing then
		tooltip:AddLine(("≤ %d healing power"):format(healing), r, g, b)
	end
	return true
end

-- In Forever, equip lines arrive with type None, not ItemSpellTriggerOnEquip
TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.None, ReplaceSpellPowerLine)
