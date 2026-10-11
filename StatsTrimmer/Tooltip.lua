-- Game-facing glue: reads the item behind a tooltip line and swaps equip lines for compact ones
local _, ns = ...

-- Localized "Equip:" prefix, provided by the client in every locale
local EQUIP_PREFIX = ITEM_SPELL_TRIGGER_ONEQUIP

-- Unicode-aware lowercase, so type names like "Élémentaire" or "Нежить" are found whatever their case.
-- C_Intl.FoldCase may return nothing.
local IntlFoldCase = C_Intl and C_Intl.FoldCase
local function FoldCase(text)
	return IntlFoldCase and IntlFoldCase(text) or text:lower()
end

local function NonEmpty(value)
	if type(value) == "string" and value ~= "" then
		return value
	end
end

-- A Blizzard string in the client's own language (an ITEM_MOD_*_SHORT stat name, RESET...), or nil. Equip
-- lines are always recognized with these: the tooltip is in the client's language.
function ns.GetClientText(name)
	return NonEmpty(_G[name])
end

-- The language Blizzard's texts are shown in: "CLIENT" or a bundled language (ns.ResolveLanguage)
function ns.GetLanguage()
	return ns.ResolveLanguage(ns.db and ns.db.language, GetLocale())
end

-- A Blizzard string in a language ("CLIENT" or a bundled one), or nil
local function GetTextIn(language, name)
	if language == "CLIENT" then
		return ns.GetClientText(name)
	end
	local strings = ns.LOCALE_STRINGS[language]
	return strings and NonEmpty(strings[name]) or nil
end

-- A Blizzard string in the language chosen in the settings, or nil
function ns.GetText(name)
	return GetTextIn(ns.GetLanguage(), name)
end

-- A Blizzard string in English, the fallback when the chosen language lacks it or names it wrongly
function ns.GetEnglishText(name)
	return GetLocale() == "enUS" and ns.GetClientText(name) or GetTextIn("enUS", name)
end

-- Lowercase for display, following the client's language rules. C_Intl.ToLower may return nothing.
local IntlToLower = C_Intl and C_Intl.ToLower
function ns.ToLower(text)
	return IntlToLower and IntlToLower(text) or text:lower()
end

-- The client's stat names, as the rules recognize equip lines with them
local clientNames = ns.TrustedNames(ns.GetClientText, FoldCase)

-- Stat name getters for the compact lines: Blizzard's names lowercased like the rest of the line (Blizzard's
-- own capitalization is uneven: "Daño Arcano", "golpe"). Made once per language, since ns.TrustedNames
-- reads every creature type's name.
local namesIn = {} -- language -> getter
local englishNames

local function LowercasedNames(GetName)
	return ns.TrustedNames(function(key)
		local name = GetName(key)
		return name and ns.ToLower(name)
	end, FoldCase)
end

-- The compact lines with Blizzard's stat names in the chosen language, then in English for any line that
-- language can't name. MP5 and HP5 have no names and stay as they are.
function ns.InLanguage(lines)
	local language = ns.GetLanguage()
	namesIn[language] = namesIn[language] or LowercasedNames(function(key)
		return GetTextIn(language, key)
	end)
	englishNames = englishNames or LowercasedNames(ns.GetEnglishText)
	return ns.LocalizeLines(ns.LocalizeLines(lines, namesIn[language]), englishNames)
end

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

-- Tooltip text can be a secret value, which addon code can't compare or search. The type check comes
-- first so issecretvalue only ever gets a string.
local function IsReadable(text)
	return type(text) == "string" and not issecretvalue(text)
end

-- The item's data lines whose text the rules can read
local function GetReadableLines(lines)
	local readable = {}
	for _, line in ipairs(lines) do
		if IsReadable(line.leftText) then
			table.insert(readable, { leftText = line.leftText })
		end
	end
	return readable
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
	if not IsReadable(text) or text:sub(1, #EQUIP_PREFIX) ~= EQUIP_PREFIX or IsShowingOriginal() then
		return false
	end

	local link, itemLines = GetProcessingItem(tooltip)
	local stats = link and C_Item.GetItemStats(link)
	if not stats then
		return false
	end
	local context = {
		lines = GetReadableLines(itemLines),
		equipPrefix = EQUIP_PREFIX,
		GetCreatureTypeName = GetCreatureTypeName,
		GetStatName = clientNames,
		FoldCase = FoldCase,
		splitSpellPower = ns.db and ns.db.splitSpellPower,
	}
	local lines = ns.GetReplacement(text, stats, context)
	if not lines then
		return false
	end
	lines = ns.InLanguage(lines)

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

-- Rebuilds the shown item tooltips, e.g. after a setting changed what their lines look like
function ns.RefreshItemTooltips()
	RefreshItemTooltip(GameTooltip)
	RefreshItemTooltip(ItemRefTooltip)
end

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function(_, _, key)
	if ns.db and ns.IsOriginalTextEventKey(ns.db.originalTextKey, key) then
		ns.RefreshItemTooltips()
	end
end)
