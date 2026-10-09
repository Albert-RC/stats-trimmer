local addonName = ...

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. addonName .. "|r: " .. msg)
end

local button = CreateFrame("Button", "HelloForeverButton", UIParent, "UIPanelButtonTemplate")
button:SetSize(140, 26)
button:SetPoint("CENTER")
button:SetText("Hello Forever")

-- Draggable with the left mouse button
button:SetMovable(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", button.StartMoving)
button:SetScript("OnDragStop", button.StopMovingOrSizing)

button:SetScript("OnClick", function()
	HelloForeverDB.clicks = HelloForeverDB.clicks + 1
	Print(("Hello, Forever! Click #%d."):format(HelloForeverDB.clicks))
end)

-- SavedVariables are available from ADDON_LOADED onwards
button:RegisterEvent("ADDON_LOADED")
button:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then
		return
	end
	HelloForeverDB = HelloForeverDB or {}
	HelloForeverDB.clicks = HelloForeverDB.clicks or 0
	Print(("loaded (%d clicks saved). Click the button or type /helloforever."):format(HelloForeverDB.clicks))
	self:UnregisterEvent(event)
end)

SLASH_HELLOFOREVER1 = "/helloforever"
SlashCmdList.HELLOFOREVER = function()
	button:SetShown(not button:IsShown())
end
