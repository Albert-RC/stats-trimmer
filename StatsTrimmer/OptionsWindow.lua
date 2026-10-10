-- Settings window, built from Blizzard templates: original-text key, a color per line kind and a
-- live preview that is a real GameTooltip
local _, ns = ...

local WIDTH, HEIGHT = 600, 550
local ROW_HEIGHT, GROUP_GAP = 22, 8

local frame, previewTooltip
local swatches = {} -- kind key -> ColorSwatchTemplate button

local function RefreshPreview()
	if not (previewTooltip and frame:IsShown()) then
		return
	end
	local panel = previewTooltip:GetParent()
	previewTooltip:SetOwner(panel, "ANCHOR_NONE")
	previewTooltip:ClearAllPoints()
	previewTooltip:SetPoint("TOP", panel, "TOP", 0, -34)
	previewTooltip:AddLine("Sample Item", 0.12, 1, 0)
	previewTooltip:AddLine("Binds when equipped", 1, 1, 1)
	previewTooltip:AddLine("+5 Stamina", 1, 1, 1)
	for _, kind in ipairs(ns.COLOR_KINDS) do
		local color = ns.db.colors[kind.key]
		previewTooltip:AddLine(kind.sample, color.r, color.g, color.b)
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

local function CreateHeader(parent, text)
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", 12, -10)
	header:SetText(text)
	return header
end

local function CreateColorRow(parent, kind, y)
	local swatch = CreateFrame("Button", nil, parent, "ColorSwatchTemplate")
	swatch:SetPoint("TOPLEFT", 14, y)
	swatch:SetScript("OnClick", function()
		OpenColorPicker(kind.key)
	end)
	swatches[kind.key] = swatch

	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
	label:SetText(kind.label)

	-- Anchored on the swatch's vertical center (it is 16px tall)
	local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	reset:SetSize(60, 20)
	reset:SetPoint("RIGHT", parent, "TOPRIGHT", -10, y - 8)
	reset:SetText("Reset")
	reset:SetScript("OnClick", function()
		ResetColor(kind.key)
	end)
end

local function CreateOriginalTextRow()
	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", 70, -38)
	label:SetText("Show original text while holding")

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(110)
	dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)

	local options = {}
	for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
		table.insert(options, { option.label, option.key })
	end
	MenuUtil.CreateRadioMenu(dropdown, function(key)
		return ns.db.originalTextKey == key
	end, function(key)
		ns.db.originalTextKey = key
	end, unpack(options))

	local help = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
	help:SetText("Hold the key over an item to see its original text. Shift also compares items.")
end

local function CreateColorsPanel()
	local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	panel:SetPoint("TOPLEFT", 12, -96)
	panel:SetPoint("BOTTOMLEFT", 12, 44)
	panel:SetWidth(300)
	CreateHeader(panel, "Colors")

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
	resetAll:SetText("Reset all colors")
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
	CreateHeader(panel, "Preview")

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

	CreateOriginalTextRow()
	CreatePreviewPanel(CreateColorsPanel())

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
