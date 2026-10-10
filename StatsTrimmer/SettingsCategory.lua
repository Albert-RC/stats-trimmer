-- Entry in the game's Options > AddOns list, with a button that opens the Stats Trimmer window
local _, ns = ...

function ns.RegisterSettingsCategory()
	local panel = CreateFrame("Frame")

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Stats Trimmer")

	local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	description:SetText("Compact stat lines in item tooltips. Colors and keys are set in the Stats Trimmer window.")

	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(200, 24)
	open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
	open:SetText("Open Stats Trimmer settings")
	open:SetScript("OnClick", function()
		ns.ShowOptions()
	end)

	local category = Settings.RegisterCanvasLayoutCategory(panel, "Stats Trimmer")
	Settings.RegisterAddOnCategory(category)
end
