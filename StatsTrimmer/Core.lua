-- Startup: loads the saved settings once the client has read them, then sets up the entry points
local addonName, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then
		return
	end
	StatsTrimmerDB = ns.LoadSettings(StatsTrimmerDB)
	ns.db = StatsTrimmerDB

	-- Names the unit frames showed before the settings were loaded
	ns.RefreshUnitNames()
	ns.UpdateMinimapButtonPosition()
	ns.RegisterSettingsCategory()
	self:UnregisterEvent(event)
end)
