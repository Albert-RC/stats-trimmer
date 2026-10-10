-- Settings window, built from Blizzard templates: original-text key, language, a color per line kind and a
-- live preview that is a real GameTooltip. Blizzard's own texts (key names, RESET, COLORS, stat names...)
-- follow the language setting and switch on the spot; the addon's own phrases are in English.
local _, ns = ...

local WIDTH, HEIGHT = 600, 580
local ROW_HEIGHT, GROUP_GAP = 22, 8
-- Room around a button's text when it is sized to fit a translated label
local BUTTON_TEXT_PADDING = 24

local frame, previewTooltip, keyDropdown
local swatches = {} -- kind key -> ColorSwatchTemplate button
local translated = {} -- { widget, GetText, isButton }: texts set again when the language changes

-- A Blizzard text in the chosen language, then in English, then the addon's fallback
local function Text(globalName, fallback)
	return ns.GetText(globalName) or ns.GetEnglishText(globalName) or fallback
end

-- A color row's label, lowercased like the compact lines. MP5 and HP5 read the same in every language.
-- "Attack power vs type" has no Blizzard name of its own: it is a vs stat's name without its creature type.
local function RowLabel(kind)
	if kind.typeStat then
		local name = Text(kind.typeStat)
		local stem = name and name:match("^(.-%S)%s+%S+$")
		return ns.ToLower(stem and stem .. " …" or kind.label)
	elseif kind.stat then
		return ns.ToLower(Text(kind.stat, kind.label))
	end
	return kind.label
end

-- Remembers how to fill a widget's text; ApplyText fills it. A button also remembers its own width.
local function Translate(widget, GetValue, isButton)
	table.insert(translated, {
		widget = widget,
		GetValue = GetValue,
		isButton = isButton,
		width = isButton and widget:GetWidth(),
	})
end

-- Fills every translated text in the current language. Buttons start again from their own width and
-- widen when their text needs more.
local function ApplyText(entry)
	if entry.isButton then
		entry.widget:SetWidth(entry.width)
		entry.widget.fitTextWidthPadding = BUTTON_TEXT_PADDING
		entry.widget:SetTextToFit(entry.GetValue())
	else
		entry.widget:SetText(entry.GetValue())
	end
end

local function RefreshPreview()
	if not (previewTooltip and frame:IsShown()) then
		return
	end
	local panel = previewTooltip:GetParent()
	previewTooltip:SetOwner(panel, "ANCHOR_NONE")
	previewTooltip:ClearAllPoints()
	previewTooltip:SetPoint("TOP", panel, "TOP", 0, -34)
	previewTooltip:AddLine("Sample Item", 0.12, 1, 0)
	previewTooltip:AddLine(Text("ITEM_BIND_ON_EQUIP", "Binds when equipped"), 1, 1, 1)
	previewTooltip:AddLine(ns.FormatLine("+", 5, false, Text("ITEM_MOD_STAMINA_SHORT", "Stamina")), 1, 1, 1)
	for _, kind in ipairs(ns.COLOR_KINDS) do
		local color = ns.db.colors[kind.key]
		for _, line in ipairs(ns.InLanguage({ ns.GetSampleLine(kind) })) do
			previewTooltip:AddLine(line.text, color.r, color.g, color.b)
		end
	end
	previewTooltip:Show()
end

local function RefreshSwatches()
	for kindKey, swatch in pairs(swatches) do
		local color = ns.db.colors[kindKey]
		swatch:SetColorRGB(color.r, color.g, color.b)
	end
end

local function SetColor(kindKey, r, g, b)
	local color = ns.db.colors[kindKey]
	color.r, color.g, color.b = r, g, b
	swatches[kindKey]:SetColorRGB(r, g, b)
	RefreshPreview()
end

-- swatchFunc runs on every change in the picker, which is what makes the preview live
local function OpenColorPicker(kindKey)
	local color = ns.db.colors[kindKey]
	ColorPickerFrame:SetupColorPickerAndShow({
		r = color.r,
		g = color.g,
		b = color.b,
		swatchFunc = function()
			SetColor(kindKey, ColorPickerFrame:GetColorRGB())
		end,
		cancelFunc = function(previous)
			SetColor(kindKey, previous.r, previous.g, previous.b)
		end,
	})
end

local function ResetColor(kindKey)
	local default = ns.GetDefaultColor(kindKey)
	SetColor(kindKey, default.r, default.g, default.b)
end

local function CreateHeader(parent, globalName, fallback)
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", 12, -10)
	Translate(header, function()
		return Text(globalName, fallback)
	end)
end

local function CreateColorRow(parent, kind, y)
	local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
	swatch:SetPoint("TOPLEFT", 14, y)
	swatch:SetScript("OnClick", function()
		OpenColorPicker(kind.key)
	end)
	swatches[kind.key] = swatch

	-- Anchored on the swatch's vertical center (it is 16px tall)
	local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	reset:SetSize(60, 20)
	reset:SetPoint("RIGHT", parent, "TOPRIGHT", -10, y - 8)
	Translate(reset, function()
		return Text("RESET", "Reset")
	end, true)
	reset:SetScript("OnClick", function()
		ResetColor(kind.key)
	end)

	-- Between the swatch and the button: a long stat name is cut off instead of running under the button
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
	label:SetPoint("RIGHT", reset, "LEFT", -6, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	Translate(label, function()
		return RowLabel(kind)
	end)
end

-- A label and a dropdown whose options are { text, value } radio entries
local function CreateDropdownRow(text, width)
	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetText(text)

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(width)
	dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
	return label, dropdown
end

-- The key options are Blizzard's key names, so the menu is built again when the language changes
local function SetupKeyMenu()
	local options = {}
	for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
		table.insert(options, { Text(option.labelGlobal, option.label), option.key })
	end
	MenuUtil.CreateRadioMenu(keyDropdown, function(key)
		return ns.db.originalTextKey == key
	end, function(key)
		ns.db.originalTextKey = key
	end, unpack(options))
end

local function CreateOriginalTextRow()
	local label
	label, keyDropdown = CreateDropdownRow("Show original text while holding", 110)
	label:SetPoint("TOPLEFT", 70, -38)

	local help = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	help:SetText("Hold the key over an item to see its original text. Shift also compares items.")
	return help
end

-- The client's language first, then the bundled ones its font can show: all of them on a client with the
-- Latin alphabet, only English on the others (Cyrillic, Korean and Chinese fonts may lack accented letters)
local function LanguageOptions()
	local client = GetLocale()
	local options = { { LocaleUtil.GetLocaleDisplayName(client), "CLIENT" } }
	local offered = ns.LOCALE_STRINGS[client] and ns.LOCALES or { "enUS" }
	for _, locale in ipairs(offered) do
		if locale ~= client then
			table.insert(options, { LocaleUtil.GetLocaleDisplayName(locale), locale })
		end
	end
	return options
end

-- The saved language as a menu value: the client's own language, saved by name, is the "CLIENT" entry
local function SelectedLanguage()
	local language = ns.db.language
	return language == GetLocale() and "CLIENT" or language
end

local function SetLanguage(language)
	ns.db.language = language
	for _, entry in ipairs(translated) do
		ApplyText(entry)
	end
	SetupKeyMenu()
	RefreshPreview()
	ns.RefreshItemTooltips()
end

local function CreateLanguageRow(above)
	local label, dropdown = CreateDropdownRow("Language", 160)
	label:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -14)
	MenuUtil.CreateRadioMenu(dropdown, function(language)
		return SelectedLanguage() == language
	end, SetLanguage, unpack(LanguageOptions()))
end

local function CreateColorsPanel()
	local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	panel:SetPoint("TOPLEFT", 12, -126)
	panel:SetPoint("BOTTOMLEFT", 12, 44)
	panel:SetWidth(300)
	CreateHeader(panel, "COLORS", "Colors")

	local y, previousGroup = -34, nil
	for _, kind in ipairs(ns.COLOR_KINDS) do
		if previousGroup and kind.group ~= previousGroup then
			y = y - GROUP_GAP
		end
		CreateColorRow(panel, kind, y)
		y = y - ROW_HEIGHT
		previousGroup = kind.group
	end

	local resetAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	resetAll:SetSize(140, 22)
	resetAll:SetPoint("BOTTOMLEFT", 12, 14)
	Translate(resetAll, function()
		return "Reset all colors"
	end, true)
	resetAll:SetScript("OnClick", function()
		for _, kind in ipairs(ns.COLOR_KINDS) do
			ResetColor(kind.key)
		end
	end)
	return panel
end

local function CreatePreviewPanel(colorsPanel)
	local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	panel:SetPoint("TOPLEFT", colorsPanel, "TOPRIGHT", 8, 0)
	panel:SetPoint("BOTTOMRIGHT", -12, 44)
	CreateHeader(panel, "PREVIEW", "Preview")

	-- Kept in the window's strata so the color picker (DIALOG) stays on top of it
	previewTooltip = CreateFrame("GameTooltip", "StatsTrimmerPreviewTooltip", panel, "GameTooltipTemplate")
	previewTooltip:SetFrameStrata(frame:GetFrameStrata())
	previewTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StatsTrimmerOptionsFrame", UIParent, "PortraitFrameTemplate")
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle("Stats Trimmer")
	frame:SetPortraitToAsset(ns.ICON)
	-- Plain Hide: this window isn't managed by the UI panel system
	frame.CloseButton:SetScript("OnClick", function()
		frame:Hide()
	end)
	tinsert(UISpecialFrames, frame:GetName())

	CreateLanguageRow(CreateOriginalTextRow())
	CreatePreviewPanel(CreateColorsPanel())
	for _, entry in ipairs(translated) do
		ApplyText(entry)
	end
	SetupKeyMenu()

	frame:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		RefreshSwatches()
		RefreshPreview()
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
		previewTooltip:Hide()
	end)
end

function ns.ShowOptions()
	if not frame then
		CreateWindow()
	end
	frame:Show()
	frame:Raise()
end

function ns.ToggleOptions()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		ns.ShowOptions()
	end
end
