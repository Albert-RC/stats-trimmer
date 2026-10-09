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

local KEY_DOWN_CHECKS = {
	CTRL = IsControlKeyDown,
	ALT = IsAltKeyDown,
	SHIFT = IsShiftKeyDown,
}

-- True while the user holds the key chosen to see the original tooltip text
local function IsShowingOriginal()
	local isKeyDown = ns.db and KEY_DOWN_CHECKS[ns.db.originalTextKey]
	return isKeyDown and isKeyDown() or false
end

-- Line pre-call: returning true keeps the original line out of the tooltip
local function ReplaceEquipLine(tooltip, lineData)
	local text = lineData.leftText
	if not text or text:sub(1, #EQUIP_PREFIX) ~= EQUIP_PREFIX or IsShowingOriginal() then
		return false
	end

	local link, itemLines = GetProcessingItem(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	local context = { lines = itemLines, equipPrefix = EQUIP_PREFIX, GetCreatureTypeName = GetCreatureTypeName }
	local lines = stats and ns.GetReplacement(text, stats, context)
	if not lines then
		return false
	end

	-- Each line uses the color the user picked for its kind; the original line color is the fallback
	local colors = ns.db and ns.db.colors or {}
	local fallback = lineData.leftColor or NORMAL_FONT_COLOR
	for _, line in ipairs(lines) do
		local color = colors[line.kind]
		if color then
			tooltip:AddLine(line.text, color.r, color.g, color.b)
		else
			tooltip:AddLine(line.text, fallback:GetRGB())
		end
	end
	return true
end

-- In Forever, equip lines arrive with type None, not ItemSpellTriggerOnEquip
TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType.None, ReplaceEquipLine)

-- Rebuilding re-runs the line pre-calls on the tooltip's original data (they never change it), so the
-- tooltip switches between original and compact text. Comparison tooltips follow their main tooltip.
local function RefreshItemTooltip(tooltip)
	if tooltip:IsShown() and tooltip:IsTooltipType(Enum.TooltipDataType.Item) then
		tooltip:RefreshData()
	end
end

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function(_, _, key)
	if ns.db and ns.IsOriginalTextEventKey(ns.db.originalTextKey, key) then
		RefreshItemTooltip(GameTooltip)
		RefreshItemTooltip(ItemRefTooltip)
	end
end)
