-- Unit frames' names that don't fit, shortened (ns.AbbreviateName) instead of cut off with "…": the player, target,
-- focus, party and raid frames. Only the frame's text changes: the unit's tooltip is built from the unit itself.
local _, ns = ...

-- Name FontStrings seen, with the name Blizzard gave each and the short one shown instead, if any:
-- fontString -> { original, short }. Weak, so frames that go away aren't kept.
local names = setmetatable({}, { __mode = "k" })

local function IsAbbreviating()
	return ns.db ~= nil and ns.IsCompacting(ns.db, "misc")
end

-- Shows the short name while the original doesn't fit. A name that is a secret value, or a frame that only
-- reports a secret truncation, keeps its text.
local function Abbreviate(fontString, entry)
	local short = ns.AbbreviateName(entry.original)
	if not short then
		return
	end
	local truncated = fontString:IsTruncated()
	if issecretvalue(truncated) or not truncated then
		return
	end
	fontString:SetText(short)
	entry.short = short
end

-- After Blizzard sets a name
local function OnNameSet(fontString)
	if not fontString then
		return
	end
	local text = fontString:GetText()
	if type(text) ~= "string" or issecretvalue(text) then
		names[fontString] = nil
		return
	end
	local entry = { original = text }
	names[fontString] = entry
	if IsAbbreviating() then
		Abbreviate(fontString, entry)
	end
end

-- After the setting changes: names Blizzard set get the setting's text, unless something else changed them since
function ns.RefreshUnitNames()
	for fontString, entry in pairs(names) do
		if entry.short then
			if fontString:GetText() == entry.short then
				fontString:SetText(entry.original)
			end
			entry.short = nil
		end
		if IsAbbreviating() and fontString:GetText() == entry.original then
			Abbreviate(fontString, entry)
		end
	end
end

-- Player, target, focus, target of target, party and pet frames
hooksecurefunc("UnitFrame_Update", function(frame)
	OnNameSet(frame.name)
end)

-- Raid frames, and raid-style party frames. Nameplates use the same function, and keep their names.
hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
	if type(frame.unit) == "string" and frame.unit:find("^nameplate") then
		return
	end
	OnNameSet(frame.name)
end)
