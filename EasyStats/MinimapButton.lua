-- Minimap button with Blizzard's standard minimap button textures. Its global name contains
-- "MinimapButton" and it's a child of Minimap, which is what MinimapButtonButton collects. It is
-- created at load time so it already exists when that addon scans on PLAYER_LOGIN.
local _, ns = ...

local button = CreateFrame("Button", "EasyStatsMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetSize(20, 20)
background:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.ICON)
icon:SetSize(17, 17)
icon:SetPoint("TOPLEFT", 7, -6)
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

-- Places the button on the minimap's edge at the saved angle (degrees)
function ns.UpdateMinimapButtonPosition()
	local angle = math.rad(ns.db.minimap.angle)
	local radius = Minimap:GetWidth() / 2 + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
	local centerX, centerY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimap.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
	ns.UpdateMinimapButtonPosition()
end

-- Once MinimapButtonButton has collected the button it owns the position, so dragging is ignored
button:SetScript("OnDragStart", function(self)
	if self:GetParent() == Minimap then
		self:SetScript("OnUpdate", FollowCursor)
	end
end)
button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function()
	ns.ToggleOptions()
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Easy Stats")
	GameTooltip:AddLine("Click to open settings.", 1, 1, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
