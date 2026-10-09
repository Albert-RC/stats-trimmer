-- Startup: loads the saved settings once the client has read them, then sets up the entry points
local addonName, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then
		return
	end
	EasyStatsDB = ns.LoadSettings(EasyStatsDB)
	ns.db = EasyStatsDB

	ns.UpdateMinimapButtonPosition()
	ns.RegisterSettingsCategory()
	self:UnregisterEvent(event)
end)
