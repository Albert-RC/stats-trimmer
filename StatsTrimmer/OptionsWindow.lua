-- Settings window, built from Blizzard templates: original-text key and language, then a tab for items' lines
-- (combat) and one for food's (SETTINGS_TABS). Each tab has a color per line kind, in collapsible sections, and a
-- live preview that is a real GameTooltip: a sample item, or a sample food. The combat tab also has the spell
-- power split. The color picker it opens gets a palette of Blizzard's class colors (ClassPalette.lua). Blizzard's
-- own texts (key names, RESET, COLORS, tab, stat and class names...) follow the language setting and switch on the
-- spot; the addon's own phrases are in English.
local _, ns = ...

-- The window sizes itself to its texts, which depend on the language and the open sections (FitWindow). Its
-- panels grow for longer texts, but never get smaller than with this language's texts and every section of every
-- tab open, so switching tabs doesn't resize it. The window never gets smaller than this either.
local REFERENCE_LANGUAGE = "esES"
local MIN_WIDTH, MIN_HEIGHT = 600, 690
-- Room above and below the two panels, at the window's sides and between the panels. The rows above the panels
-- start right of the portrait, with their dropdowns this far from their labels.
local TOP_HEIGHT, BOTTOM_HEIGHT, SIDE_MARGIN, PANEL_GAP = 156, 44, 12, 8
local TOP_ROWS_LEFT, DROPDOWN_GAP = 70, 10
-- A color row: the swatch this far from the row's left, the label this far from the swatch and from the Reset
-- button, and the Reset button this far from the row's right. ROW_LEFT and ROW_RIGHT are the room around the
-- label, which FitWindow adds to the longest one.
local SWATCH_LEFT, SWATCH_SIZE, LABEL_GAP_LEFT, LABEL_GAP_RIGHT, RESET_RIGHT = 8, 16, 8, 6, 4
local ROW_LEFT = SWATCH_LEFT + SWATCH_SIZE + LABEL_GAP_LEFT
local ROW_RIGHT = LABEL_GAP_RIGHT + RESET_RIGHT
-- The scroll frame's inset in the colors panel
local SCROLL_LEFT = 6
-- The preview tooltip's offset below its panel's top, and its margin inside the panel
local PREVIEW_TOP, PREVIEW_MARGIN = 34, 12
-- The first tab's offset from the window's bottom left, as Blizzard's inspect window has it
local TAB_LEFT, TAB_TOP = 11, 2
-- Color rows: the swatch (16px) and the Reset button share each row's vertical center. Section headers are
-- ListHeaderThreeSliceTemplate's height.
local ROW_HEIGHT, SECTION_HEADER_HEIGHT, SECTION_GAP = 24, 26, 6
-- The Reset buttons' height; their width follows their text (FitButton)
local RESET_HEIGHT = 20
-- Room on the colors panel's right for the scroll bar
local SCROLL_BAR_SPACE = 26
-- Room around a button's text when it is sized to fit a translated label
local BUTTON_TEXT_PADDING = 24
local frame, previewTooltip, foodTooltip, keyDropdown, splitCheckbox, colorsPanel, colorRows
local swatches = {} -- kind key -> ColorSwatchTemplate button
local rowParts = {} -- { kind, label, reset } of every color row, to size the colors panel
local topRows = {} -- the labels and dropdown of the rows above the panels, to size the window
local sections = {} -- { group, header, body }, in COLOR_GROUPS order
local translated = {} -- { widget, GetValue, Fit }: texts set again when the language changes
local previewTooltips = {} -- SETTINGS_TABS key -> its preview tooltip

-- The tab shown: the first one when the window opens for the first time, then the one left open
local selectedTab = 1

-- The section and tab of each kind, to leave collapsed sections out of the preview and fill each tab's preview
local kindGroups, kindTabs = {}, {}
for _, group in ipairs(ns.COLOR_GROUPS) do
	for _, kind in ipairs(ns.COLOR_KINDS) do
		if kind.group == group.key then
			kindGroups[kind.key] = kind.group
			kindTabs[kind.key] = group.tab
		end
	end
end

local function SelectedTabKey()
	return ns.SETTINGS_TABS[selectedTab].key
end

-- A Blizzard text in the chosen language (or in `language`, a bundled one), then in English, then the
-- addon's fallback
local function Text(globalName, fallback, language)
	return ns.GetTextIn(language or ns.GetLanguage(), globalName) or ns.GetEnglishText(globalName) or fallback
end

-- A color row's label, lowercased like the compact lines, in the chosen language or `language`. MP5 and HP5
-- read the same in every language. "Attack power vs type" has no Blizzard name of its own: it is a vs stat's
-- name without its creature type.
local function RowLabel(kind, language)
	if kind.typeStat then
		local name = Text(kind.typeStat, nil, language)
		local stem = name and name:match("^(.-%S)%s+%S+$")
		return ns.ToLower(stem and stem .. " …" or kind.label)
	elseif kind.stat then
		return ns.ToLower(Text(kind.stat, ns.ENGLISH_NAMES[kind.stat] or kind.label, language))
	end
	return kind.label
end

-- Remembers how to fill a widget's text; ApplyText fills it. `Fit(widget, text)` sets a text that sizes its
-- widget (a button's or a tab's).
local function Translate(widget, GetValue, Fit)
	table.insert(translated, { widget = widget, GetValue = GetValue, Fit = Fit })
end

-- Sizes a button to its text and padding. UIPanelButtonTemplate's buttons get narrower too
-- (fitTextCanWidthDecrease), so they take no width of their own.
local function FitButton(button, text)
	button.fitTextWidthPadding = BUTTON_TEXT_PADDING
	button:SetTextToFit(text)
end

-- Sizes a tab to its text, as Blizzard's tabs do when shown
local function FitTab(tab, text)
	tab:SetText(text)
	PanelTemplates_TabResize(tab)
end

-- Fills a translated text in the current language
local function ApplyText(entry)
	if entry.Fit then
		entry.Fit(entry.widget, entry.GetValue())
	else
		entry.widget:SetText(entry.GetValue())
	end
end

local function IsCollapsed(groupKey)
	return ns.db.collapsedSections[groupKey] == true
end

-- The preview's compact lines in each language ("CLIENT" or a bundled one), made once: the color picker
-- refreshes the preview on every change
local sampleLines = {}

local function GetSampleLines(language)
	if not sampleLines[language] then
		local lines = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			for _, line in ipairs(ns.InLanguage({ ns.GetSampleLine(kind) }, language)) do
				table.insert(lines, line)
			end
		end
		sampleLines[language] = lines
	end
	return sampleLines[language]
end

-- Fills the preview tooltips, in the chosen language or `language`: the sample item's, with the combat tab's
-- lines, and the sample food's, with the food tab's. Only the shown tab's preview shows. Unless `everything`,
-- they leave out collapsed sections, and split spell power, which looks like the spell damage and healing
-- samples already there. Returns the room the preview takes: the largest of both tooltips, which take turns in
-- the same place, so switching tabs doesn't resize the window.
local function FillPreview(language, everything)
	local panel = previewTooltip:GetParent()
	for _, tooltip in pairs(previewTooltips) do
		tooltip:SetOwner(panel, "ANCHOR_NONE")
		tooltip:ClearAllPoints()
		tooltip:SetPoint("TOPLEFT", panel, "TOPLEFT", PREVIEW_MARGIN, -PREVIEW_TOP)
	end
	previewTooltip:AddLine("Sample Item", 0.12, 1, 0)
	previewTooltip:AddLine(Text("ITEM_BIND_ON_EQUIP", "Binds when equipped", language), 1, 1, 1)
	previewTooltip:AddLine(ns.FormatLine(5, false, Text("ITEM_MOD_STAMINA_SHORT", "Stamina", language)), 1, 1, 1)
	foodTooltip:AddLine("Sample Food", 1, 1, 1)

	for _, line in ipairs(GetSampleLines(language or ns.GetLanguage())) do
		local hidden = (ns.db.splitSpellPower and line.kind == "spellPower") or IsCollapsed(kindGroups[line.kind])
		if everything or not hidden then
			local color = ns.db.colors[line.kind]
			previewTooltips[kindTabs[line.kind]]:AddLine(line.text, color.r, color.g, color.b)
		end
	end
	local width, height = 0, 0
	for tabKey, tooltip in pairs(previewTooltips) do
		-- A GameTooltip takes its size when shown
		tooltip:Show()
		width = math.max(width, tooltip:GetWidth())
		height = math.max(height, tooltip:GetHeight())
		tooltip:SetShown(tabKey == SelectedTabKey())
	end
	return width, height
end

-- The sizes with REFERENCE_LANGUAGE's texts and every section of every tab open, below which the panels never
-- shrink:
-- { rowsWidth, previewWidth, previewHeight }. Measured once, on the window's own labels, Reset button and
-- preview, which get the chosen language's texts back before anything is drawn.
local reference

local function MeasureReference()
	local labelWidth = 0
	for _, row in ipairs(rowParts) do
		row.label:SetText(RowLabel(row.kind, REFERENCE_LANGUAGE))
		labelWidth = math.max(labelWidth, row.label:GetUnboundedStringWidth())
		row.label:SetText(RowLabel(row.kind))
	end
	local reset = rowParts[1].reset
	FitButton(reset, Text("RESET", "Reset", REFERENCE_LANGUAGE))
	local resetWidth = reset:GetWidth()
	FitButton(reset, Text("RESET", "Reset"))

	local previewWidth, previewHeight = FillPreview(REFERENCE_LANGUAGE, true)
	reference = {
		rowsWidth = ROW_LEFT + labelWidth + ROW_RIGHT + resetWidth,
		previewWidth = previewWidth,
		previewHeight = previewHeight,
	}
end

-- Sizes the window to what it shows: the colors panel to its longest row in either tab, so no stat name is cut
-- off, and the window to that panel, the preview (`tooltipsWidth` and `tooltipsHeight`, from FillPreview), the
-- rows above them and the preview's height. The panels keep at least their reference size.
local function FitWindow(tooltipsWidth, tooltipsHeight)
	local labelWidth, resetWidth = 0, 0
	for _, row in ipairs(rowParts) do
		labelWidth = math.max(labelWidth, row.label:GetUnboundedStringWidth())
		resetWidth = math.max(resetWidth, row.reset:GetWidth())
	end
	local rowsWidth = math.max(reference.rowsWidth, ROW_LEFT + labelWidth + ROW_RIGHT + resetWidth)
	local colorsWidth = SCROLL_LEFT + rowsWidth + SCROLL_BAR_SPACE
	colorRows:SetWidth(rowsWidth)
	colorsPanel:SetWidth(colorsWidth)

	local widestTopRow = math.max(
		topRows.keyLabel:GetUnboundedStringWidth() + DROPDOWN_GAP + keyDropdown:GetWidth(),
		topRows.languageLabel:GetUnboundedStringWidth() + DROPDOWN_GAP + topRows.languageDropdown:GetWidth(),
		topRows.help:GetUnboundedStringWidth(),
		splitCheckbox:GetWidth() + splitCheckbox.Text:GetUnboundedStringWidth()
	)
	local topRowsWidth = TOP_ROWS_LEFT + widestTopRow + SIDE_MARGIN
	local previewWidth = math.max(reference.previewWidth, tooltipsWidth) + 2 * PREVIEW_MARGIN
	local panelsWidth = 2 * SIDE_MARGIN + colorsWidth + PANEL_GAP + previewWidth
	local previewHeight = PREVIEW_TOP + math.max(reference.previewHeight, tooltipsHeight) + PREVIEW_MARGIN
	local width = math.max(MIN_WIDTH, topRowsWidth, panelsWidth)
	local height = math.max(MIN_HEIGHT, TOP_HEIGHT + previewHeight + BOTTOM_HEIGHT)
	frame:SetSize(width, height)
	-- The tabs extend below the frame. Include them in both the scale and the screen bounds, so they stay
	-- visible on a small screen (a large UI scale) and when the window is dragged to the bottom edge.
	local tabsBelow = 0
	for _, tab in ipairs(frame.Tabs) do
		tabsBelow = math.max(tabsBelow, tab:GetHeight() - TAB_TOP)
	end
	frame:SetClampRectInsets(0, 0, 0, -tabsBelow)
	frame:SetScale(math.min(1, UIParent:GetWidth() / width, UIParent:GetHeight() / (height + tabsBelow)))
end

-- The preview shows the sections that are open, and the window fits it. A color change keeps every size
-- (`keepSize`): the color picker changes the color on every move.
local function RefreshPreview(keepSize)
	if not (previewTooltip and frame:IsShown()) then
		return
	end
	if not reference then
		MeasureReference()
	end
	local tooltipsWidth, tooltipsHeight = FillPreview()
	if not keepSize then
		FitWindow(tooltipsWidth, tooltipsHeight)
	end
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
	RefreshPreview(true)
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
	ns.ShowClassPalette()
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
	local center = y - ROW_HEIGHT / 2
	local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
	swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
	swatch:SetPoint("LEFT", parent, "TOPLEFT", SWATCH_LEFT, center)
	swatch:SetScript("OnClick", function()
		OpenColorPicker(kind.key)
	end)
	swatches[kind.key] = swatch

	local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	reset:SetHeight(RESET_HEIGHT)
	reset:SetPoint("RIGHT", parent, "TOPRIGHT", -RESET_RIGHT, center)
	Translate(reset, function()
		return Text("RESET", "Reset")
	end, FitButton)
	reset:SetScript("OnClick", function()
		ResetColor(kind.key)
	end)

	-- Between the swatch and the button. FitWindow makes room for the longest name, so none is cut off.
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", swatch, "RIGHT", LABEL_GAP_LEFT, 0)
	label:SetPoint("RIGHT", reset, "LEFT", -LABEL_GAP_RIGHT, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	Translate(label, function()
		return RowLabel(kind)
	end)
	table.insert(rowParts, { kind = kind, label = label, reset = reset })
end

-- Stacks the shown tab's sections: each header under the previous section's rows, or under its header when
-- that section is collapsed. The only section of a tab has no header (ns.IsCollapsible). Other tabs' sections
-- hide. The scroll child takes their height.
local function LayoutSections()
	local height, above = 0, nil
	-- Anchors a region under the previous one, `gap` below it, or at the top
	local function Stack(region, gap)
		region:ClearAllPoints()
		if above then
			region:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
			region:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -gap)
			height = height + gap
		else
			region:SetPoint("TOPLEFT")
			region:SetPoint("TOPRIGHT")
		end
		above = region
	end

	for _, section in ipairs(sections) do
		local shown = section.group.tab == SelectedTabKey()
		local titled = shown and ns.IsCollapsible(section.group.key)
		local collapsed = IsCollapsed(section.group.key)
		section.header:SetShown(titled)
		section.header:UpdateCollapsedState(collapsed)
		section.body:SetShown(shown and not collapsed)
		if titled then
			Stack(section.header, SECTION_GAP)
			height = height + SECTION_HEADER_HEIGHT
		end
		if shown and not collapsed then
			Stack(section.body, 0)
			height = height + section.bodyHeight
		end
	end
	colorRows:SetHeight(height)
end

local function ToggleSection(groupKey)
	ns.db.collapsedSections[groupKey] = not IsCollapsed(groupKey) or nil
	LayoutSections()
	RefreshPreview()
end

-- A section: a header titled with Blizzard's name for it, which collapses and expands it, over its kinds'
-- rows in COLOR_KINDS order
local function CreateColorSection(group)
	local header = CreateFrame("Button", nil, colorRows, "ListHeaderThreeSliceTemplate")
	header:SetHeight(SECTION_HEADER_HEIGHT)
	header:SetClickHandler(function()
		ToggleSection(group.key)
	end)
	Translate(header.Name, function()
		return Text(group.labelGlobal, group.label) .. (group.labelSuffix or "")
	end)

	-- LayoutSections places it
	local body = CreateFrame("Frame", nil, colorRows)
	local y = 0
	for _, kind in ipairs(ns.COLOR_KINDS) do
		if kind.group == group.key then
			CreateColorRow(body, kind, y)
			y = y - ROW_HEIGHT
		end
	end
	body:SetHeight(-y)
	table.insert(sections, { group = group, header = header, body = body, bodyHeight = -y })
end

-- A label and a dropdown whose options are { text, value } radio entries
local function CreateDropdownRow(text, width)
	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetText(text)

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(width)
	dropdown:SetPoint("LEFT", label, "RIGHT", DROPDOWN_GAP, 0)
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
	label:SetPoint("TOPLEFT", TOP_ROWS_LEFT, -38)

	local help = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	help:SetText("Hold the key over an item to see its original text. Shift also compares items.")
	topRows.keyLabel, topRows.help = label, help
	return help
end

-- The client's language first, then the bundled ones its font can show (ns.GetOfferedLanguages)
local function LanguageOptions()
	local client = GetLocale()
	local options = { { LocaleUtil.GetLocaleDisplayName(client), "CLIENT" } }
	for _, locale in ipairs(ns.GetOfferedLanguages(client)) do
		if locale ~= client then
			table.insert(options, { LocaleUtil.GetLocaleDisplayName(locale), locale })
		end
	end
	return options
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
	topRows.languageLabel, topRows.languageDropdown = label, dropdown
	MenuUtil.CreateRadioMenu(dropdown, function(language)
		return ns.GetLanguage() == language
	end, SetLanguage, unpack(LanguageOptions()))
	return label
end

-- Spell power that adds damage and healing: its own line (the default) or spell damage and healing lines
local function CreateSplitSpellPowerRow(above)
	splitCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	splitCheckbox:SetSize(26, 26)
	splitCheckbox:SetPoint("TOPLEFT", above, "BOTTOMLEFT", -6, -10)
	splitCheckbox.Text:SetFontObject("GameFontNormal")
	splitCheckbox.Text:SetText("Split spell power into spell damage and spell healing when both values are the same")
	-- The click has already toggled the box
	splitCheckbox:SetScript("OnClick", function(checkbox)
		ns.db.splitSpellPower = checkbox:GetChecked()
		RefreshPreview()
		ns.RefreshItemTooltips()
	end)
end

-- The color sections scroll inside the panel: they are taller than the window. FitWindow sets its width.
local function CreateColorsPanel()
	colorsPanel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	colorsPanel:SetPoint("TOPLEFT", SIDE_MARGIN, -TOP_HEIGHT)
	colorsPanel:SetPoint("BOTTOMLEFT", SIDE_MARGIN, BOTTOM_HEIGHT)
	CreateHeader(colorsPanel, "COLORS", "Colors")

	local scrollFrame = CreateFrame("ScrollFrame", nil, colorsPanel, "ScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", SCROLL_LEFT, -32)
	scrollFrame:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, 6)
	colorRows = CreateFrame("Frame", nil, scrollFrame)
	for _, group in ipairs(ns.COLOR_GROUPS) do
		CreateColorSection(group)
	end
	scrollFrame:SetScrollChild(colorRows)

	-- Only the shown tab's colors
	local resetShown = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	resetShown:SetHeight(22)
	resetShown:SetPoint("BOTTOMLEFT", 12, 14)
	Translate(resetShown, function()
		return "Reset these colors"
	end, FitButton)
	resetShown:SetScript("OnClick", function()
		for _, kind in ipairs(ns.COLOR_KINDS) do
			if kindTabs[kind.key] == SelectedTabKey() then
				ResetColor(kind.key)
			end
		end
	end)
end

local function CreatePreviewPanel()
	local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	panel:SetPoint("TOPLEFT", colorsPanel, "TOPRIGHT", PANEL_GAP, 0)
	panel:SetPoint("BOTTOMRIGHT", -SIDE_MARGIN, BOTTOM_HEIGHT)
	CreateHeader(panel, "PREVIEW", "Preview")

	-- Kept in the window's strata so the color picker (DIALOG) stays on top of them
	previewTooltip = CreateFrame("GameTooltip", "StatsTrimmerPreviewTooltip", panel, "GameTooltipTemplate")
	foodTooltip = CreateFrame("GameTooltip", "StatsTrimmerFoodPreviewTooltip", panel, "GameTooltipTemplate")
	previewTooltips = { combat = previewTooltip, food = foodTooltip }
	for _, tooltip in pairs(previewTooltips) do
		tooltip:SetFrameStrata(frame:GetFrameStrata())
		tooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
	end
end

-- Shows the selected tab: its tab button, its sections, its preview and, in the combat tab, the spell power
-- split
local function ShowSelectedTab()
	PanelTemplates_SetTab(frame, selectedTab)
	splitCheckbox:SetShown(ns.SETTINGS_TABS[selectedTab].spellPowerSplit == true)
	LayoutSections()
	RefreshPreview()
end

-- Blizzard's tabs under the window, as in its inspect window: one per SETTINGS_TABS entry, named with Blizzard's
-- text for it
local function CreateTabs()
	for index, tab in ipairs(ns.SETTINGS_TABS) do
		local button = CreateFrame("Button", "$parentTab" .. index, frame, "PanelTabButtonTemplate")
		button:SetID(index)
		Translate(button, function()
			return Text(tab.labelGlobal, tab.label)
		end, FitTab)
		button:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			selectedTab = self:GetID()
			ShowSelectedTab()
		end)
		if index == 1 then
			button:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", TAB_LEFT, TAB_TOP)
		end
	end
	-- Anchors each tab after the previous one
	PanelTemplates_SetNumTabs(frame, #ns.SETTINGS_TABS)
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StatsTrimmerOptionsFrame", UIParent, "PortraitFrameTemplate")
	frame:Hide()
	frame:SetSize(MIN_WIDTH, MIN_HEIGHT)
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

	CreateSplitSpellPowerRow(CreateLanguageRow(CreateOriginalTextRow()))
	CreateColorsPanel()
	CreatePreviewPanel()
	CreateTabs()
	for _, entry in ipairs(translated) do
		ApplyText(entry)
	end
	SetupKeyMenu()

	frame:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		splitCheckbox:SetChecked(ns.db.splitSpellPower)
		RefreshSwatches()
		ShowSelectedTab()
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
		previewTooltip:Hide()
		foodTooltip:Hide()
	end)
	frame:RegisterEvent("UI_SCALE_CHANGED")
	frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
	frame:SetScript("OnEvent", function()
		RefreshPreview()
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
