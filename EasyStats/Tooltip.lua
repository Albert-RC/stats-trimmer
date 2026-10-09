-- Game-facing glue: reads the item behind a tooltip line and swaps equip lines for compact ones
local _, ns = ...

-- Localized "Equip:" prefix, provided by the client in every locale
local EQUIP_PREFIX = ITEM_SPELL_TRIGGER_ONEQUIP

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

local function GetCreatureTypeName(id)
	local info = C_CreatureInfo.GetCreatureTypeInfo(id)
	return info and info.name
end

-- Line pre-call: returning true keeps the original line out of the tooltip
local function ReplaceEquipLine(tooltip, lineData)
	local text = lineData.leftText
	if not text or text:sub(1, #EQUIP_PREFIX) ~= EQUIP_PREFIX then
		return false
	end

	local link, itemLines = GetProcessingItem(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	local context = { lines = itemLines, GetCreatureTypeName = GetCreatureTypeName }
	local lines = stats and ns.GetReplacement(text, stats, context)
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
