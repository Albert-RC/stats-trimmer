-- Blizzard's class colors inside the color picker, in a row under the color wheel: Forever's classes in the
-- game's order, each named in its own color on hover. A click sets the picker's color, which runs swatchFunc
-- like any other change, so OK and Cancel work as usual. The palette is a child of the picker, which cancels
-- on any click outside itself. Only Stats Trimmer's picks show it (ns.ShowClassPalette, right after setting up
-- the picker): the picker gets taller for it while it does, and back to its own height when the pick ends.
local _, ns = ...

-- How much taller the color picker gets for the palette, and its swatches' spacing
local PALETTE_HEIGHT, PALETTE_SWATCH_STEP = 28, 20

local classPalette, pickerHeight

local function ShowClassName(swatch)
	local color = C_ClassColor.GetClassColor(swatch.classFile)
	GameTooltip:SetOwner(swatch, "ANCHOR_TOP")
	GameTooltip:SetText(ns.GetClassName(swatch.classFile) or swatch.classFile, color.r, color.g, color.b)
	GameTooltip:Show()
end

local function HideClassName()
	GameTooltip:Hide()
end

local function PickClassColor(swatch)
	local color = C_ClassColor.GetClassColor(swatch.classFile)
	ColorPickerFrame.Content.ColorPicker:SetColorRGB(color.r, color.g, color.b)
end

-- Ends the palette's pick: hides it and gives the picker its own height back
local function HideClassPalette()
	if classPalette:IsShown() then
		classPalette:Hide()
		ColorPickerFrame:SetHeight(pickerHeight)
	end
end

local function CreateClassPalette()
	classPalette = CreateFrame("Frame", nil, ColorPickerFrame)
	classPalette:Hide()
	classPalette:SetSize(#CLASS_SORT_ORDER * PALETTE_SWATCH_STEP, 16)
	-- Under the color wheel, on the hex box's baseline
	classPalette:SetPoint("BOTTOMLEFT", 23, 44)
	local index = 0
	for _, classFile in ipairs(CLASS_SORT_ORDER) do
		local color = C_ClassColor.GetClassColor(classFile)
		if color then
			local swatch = CreateFrame("Button", nil, classPalette, "ColorSwatchTemplate")
			swatch:SetPoint("LEFT", index * PALETTE_SWATCH_STEP, 0)
			swatch:SetColorRGB(color.r, color.g, color.b)
			swatch.classFile = classFile
			swatch:SetScript("OnClick", PickClassColor)
			swatch:SetScript("OnEnter", ShowClassName)
			swatch:SetScript("OnLeave", HideClassName)
			index = index + 1
		end
	end
	-- Only when the pick ends: the picker also hides with UIParent (Alt+Z), still shown and serving the pick
	ColorPickerFrame:HookScript("OnHide", function()
		if not ColorPickerFrame:IsShown() then
			HideClassPalette()
		end
	end)
	-- Every new pick ends it too: another addon can set up the picker while it is still shown, which runs no
	-- OnHide. ns.ShowClassPalette shows it again for Stats Trimmer's own picks, right after.
	hooksecurefunc(ColorPickerFrame, "SetupColorPickerAndShow", HideClassPalette)
end

-- Shows the palette in the color picker Stats Trimmer has just set up, made the first time
function ns.ShowClassPalette()
	if not classPalette then
		CreateClassPalette()
	end
	if not classPalette:IsShown() then
		pickerHeight = ColorPickerFrame:GetHeight()
		ColorPickerFrame:SetHeight(pickerHeight + PALETTE_HEIGHT)
		classPalette:Show()
	end
end
