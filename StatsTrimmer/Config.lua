-- Settings model: line kinds, defaults and loading of the saved table. No WoW API here, so this file
-- can be unit tested outside the game.
local _, ns = ...

ns.ICON = "Interface\\Icons\\inv_magicalfishpet"

-- Modifier keys that can be held to see the original tooltip text, in menu order. `labelGlobal` names the
-- client's own text for the key ("Mayús" on esES), `label` is the fallback. `eventKeys` are the names
-- MODIFIER_STATE_CHANGED reports for each side of the keyboard.
ns.ORIGINAL_TEXT_KEYS = {
	{ key = "CTRL", labelGlobal = "CTRL_KEY", label = "Ctrl", eventKeys = { "LCTRL", "RCTRL" } },
	{ key = "ALT", labelGlobal = "ALT_KEY", label = "Alt", eventKeys = { "LALT", "RALT" } },
	{ key = "SHIFT", labelGlobal = "SHIFT_KEY", label = "Shift", eventKeys = { "LSHIFT", "RSHIFT" } },
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

-- Every kind of replacement line, in settings order. `group` separates the rows in the settings window.
-- `stat` is the key of Blizzard's name for the row label (in the chosen language), with `label` as the
-- English fallback; a kind without `stat` or `typeStat` always shows `label`. `sample` is the line the
-- preview tooltip shows: { sign, value, English name, percent = ..., stat = ... }, where its own `stat`
-- overrides the kind's.
ns.COLOR_KINDS = {
	{
		-- Spell damage, also from spell power, which adds damage and healing (see Rules.lua)
		key = "spellDamage",
		group = "spell",
		label = "Spell damage",
		stat = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
		sample = { "≤", 10, "spell damage" },
	},
	{
		key = "spellHealing",
		group = "spell",
		label = "Spell healing",
		stat = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
		sample = { "≤", 30, "spell healing" },
	},
	{
		key = "arcaneDamage",
		group = "school",
		label = "Arcane damage",
		stat = "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT",
		sample = { "≤", 12, "arcane damage" },
	},
	{
		key = "fireDamage",
		group = "school",
		label = "Fire damage",
		stat = "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT",
		sample = { "≤", 12, "fire damage" },
	},
	{
		key = "frostDamage",
		group = "school",
		label = "Frost damage",
		stat = "ITEM_MOD_FROST_DAMAGE_DONE_SHORT",
		sample = { "≤", 32, "frost damage" },
	},
	{
		key = "holyDamage",
		group = "school",
		label = "Holy damage",
		stat = "ITEM_MOD_HOLY_DAMAGE_DONE_SHORT",
		sample = { "≤", 12, "holy damage" },
	},
	{
		key = "natureDamage",
		group = "school",
		label = "Nature damage",
		stat = "ITEM_MOD_NATURE_DAMAGE_DONE_SHORT",
		sample = { "≤", 12, "nature damage" },
	},
	{
		key = "shadowDamage",
		group = "school",
		label = "Shadow damage",
		stat = "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT",
		sample = { "≤", 12, "shadow damage" },
	},
	{
		-- MP5 and HP5 read the same in every language
		key = "mp5",
		group = "regen",
		label = "MP5",
		sample = { "+", 4, "MP5" },
	},
	{
		key = "hp5",
		group = "regen",
		label = "HP5",
		sample = { "+", 5, "HP5" },
	},
	{
		key = "attackPower",
		group = "physical",
		label = "Attack power",
		stat = "ITEM_MOD_ATTACK_POWER_SHORT",
		sample = { "+", 4, "attack power" },
	},
	{
		-- Blizzard only names this per creature type: the label is typeStat's name without its last word,
		-- the type ("poder de ataque contra …")
		key = "attackPowerVs",
		group = "physical",
		label = "Attack power vs type",
		typeStat = "ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT",
		sample = { "+", 6, "attack power vs beasts", stat = "ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT" },
	},
	{
		key = "defense",
		group = "physical",
		label = "Defense",
		stat = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
		sample = { "+", 3, "defense" },
	},
	{
		key = "blockRating",
		group = "physical",
		label = "Block rating",
		stat = "ITEM_MOD_BLOCK_RATING_SHORT",
		sample = { "+", 1, "block rating", percent = true },
	},
	{
		key = "hitRating",
		group = "physical",
		label = "Hit rating",
		stat = "ITEM_MOD_HIT_RATING_SHORT",
		sample = { "+", 1, "hit rating", percent = true },
	},
}

-- The preview's compact line for a kind, in the same shape the rules produce, so ns.LocalizeLines can
-- turn it into the chosen language. A kind without a stat (MP5, HP5) is never translated.
function ns.GetSampleLine(kind)
	local sign, value, name = unpack(kind.sample)
	local percent = kind.sample.percent
	local stat = kind.sample.stat or kind.stat
	return {
		kind = kind.key,
		text = ns.FormatLine(sign, value, percent, name),
		sign = sign,
		value = value,
		percent = percent,
		stats = stat and { stat },
	}
end

-- Same green as the game's own equip lines, so nothing changes until the user picks a color
local EQUIP_GREEN = { r = 0, g = 1, b = 0 }

ns.DEFAULTS = {
	originalTextKey = "CTRL",
	-- "CLIENT" follows the client's language; otherwise a key of ns.LOCALE_STRINGS (Locales.lua)
	language = "CLIENT",
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
		-- Written so that nan, which fails every comparison, is rejected too
		local number = value[channel]
		if type(number) ~= "number" or not (number >= 0 and number <= 1) then
			return false
		end
	end
	return true
end

-- A number the button can be placed at: not nan or infinite
local function IsAngle(value)
	return type(value) == "number" and value > -math.huge and value < math.huge
end

local function IsLanguage(value)
	return value == "CLIENT" or (type(value) == "string" and ns.LOCALE_STRINGS[value] ~= nil)
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
	if not IsLanguage(settings.language) then
		settings.language = ns.DEFAULTS.language
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
	if not IsAngle(settings.minimap.angle) then
		settings.minimap.angle = ns.DEFAULTS.minimap.angle
	end

	return settings
end
