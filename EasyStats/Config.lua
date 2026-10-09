-- Settings model: line kinds, defaults and loading of the saved table. No WoW API here, so this file
-- can be unit tested outside the game.
local _, ns = ...

ns.ICON = "Interface\\Icons\\INV_Misc_Note_01"

-- Modifier keys that can be held to see the original tooltip text, in menu order. `eventKeys` are the
-- names MODIFIER_STATE_CHANGED reports for each side of the keyboard.
ns.ORIGINAL_TEXT_KEYS = {
	{ key = "CTRL", label = "Ctrl", eventKeys = { "LCTRL", "RCTRL" } },
	{ key = "ALT", label = "Alt", eventKeys = { "LALT", "RALT" } },
	{ key = "SHIFT", label = "Shift", eventKeys = { "LSHIFT", "RSHIFT" } },
}

-- True when a MODIFIER_STATE_CHANGED key ("LCTRL") belongs to the configured key ("CTRL")
function ns.IsOriginalTextEventKey(settingKey, eventKey)
	for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
		if option.key == settingKey then
			for _, candidate in ipairs(option.eventKeys) do
				if candidate == eventKey then
					return true
				end
			end
		end
	end
	return false
end

-- Every kind of replacement line, in settings order. `group` separates the rows in the settings
-- window and `sample` is what the preview tooltip shows.
ns.COLOR_KINDS = {
	{ key = "spellPower", group = "spell", label = "Spell power", sample = "≤10 spell power" },
	{ key = "healingPower", group = "spell", label = "Healing power", sample = "≤30 healing power" },
	{ key = "arcaneDamage", group = "school", label = "Arcane damage", sample = "≤12 arcane damage" },
	{ key = "fireDamage", group = "school", label = "Fire damage", sample = "≤12 fire damage" },
	{ key = "frostDamage", group = "school", label = "Frost damage", sample = "≤32 frost damage" },
	{ key = "holyDamage", group = "school", label = "Holy damage", sample = "≤12 holy damage" },
	{ key = "natureDamage", group = "school", label = "Nature damage", sample = "≤12 nature damage" },
	{ key = "shadowDamage", group = "school", label = "Shadow damage", sample = "≤12 shadow damage" },
	{ key = "mp5", group = "regen", label = "Mana regen (MP5)", sample = "+4 MP5" },
	{ key = "hp5", group = "regen", label = "Health regen (HP5)", sample = "+5 HP5" },
	{ key = "attackPower", group = "physical", label = "Attack power", sample = "+4 attack power" },
	{ key = "attackPowerVs", group = "physical", label = "Attack power vs type", sample = "+6 attack power vs beasts" },
	{ key = "defense", group = "physical", label = "Defense", sample = "+3 defense" },
	{ key = "blockRating", group = "physical", label = "Block rating", sample = "+1% block rating" },
	{ key = "hitRating", group = "physical", label = "Hit rating", sample = "+1% hit rating" },
}

-- Same green as the game's own equip lines, so nothing changes until the user picks a color
local EQUIP_GREEN = { r = 0, g = 1, b = 0 }

ns.DEFAULTS = {
	originalTextKey = "CTRL",
	colors = {},
	minimap = { angle = 200 },
}
for _, kind in ipairs(ns.COLOR_KINDS) do
	ns.DEFAULTS.colors[kind.key] = EQUIP_GREEN
end

local function IsColor(value)
	if type(value) ~= "table" then
		return false
	end
	for _, channel in ipairs({ "r", "g", "b" }) do
		local number = value[channel]
		if type(number) ~= "number" or number < 0 or number > 1 then
			return false
		end
	end
	return true
end

local function IsOriginalTextKey(value)
	for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
		if option.key == value then
			return true
		end
	end
	return false
end

-- A fresh copy of a kind's default color, never the shared default table
function ns.GetDefaultColor(kindKey)
	local default = ns.DEFAULTS.colors[kindKey]
	return { r = default.r, g = default.g, b = default.b }
end

-- Completes the saved settings table in place and returns it: missing or invalid values get a copy of
-- their default, valid saved values are kept.
function ns.LoadSettings(saved)
	local settings = type(saved) == "table" and saved or {}

	if not IsOriginalTextKey(settings.originalTextKey) then
		settings.originalTextKey = ns.DEFAULTS.originalTextKey
	end

	if type(settings.colors) ~= "table" then
		settings.colors = {}
	end
	for kindKey in pairs(ns.DEFAULTS.colors) do
		if not IsColor(settings.colors[kindKey]) then
			settings.colors[kindKey] = ns.GetDefaultColor(kindKey)
		end
	end

	if type(settings.minimap) ~= "table" then
		settings.minimap = {}
	end
	if type(settings.minimap.angle) ~= "number" then
		settings.minimap.angle = ns.DEFAULTS.minimap.angle
	end

	return settings
end
