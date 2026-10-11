local helpers = require("spec.helpers")

local function LoadConfig()
	return helpers.LoadAddon("StatsTrimmer", { "Util.lua", "Config.lua", "Locales.lua" })
end

describe("DEFAULTS", function()
	local ns = LoadConfig()

	it("has a default color for every line kind", function()
		for _, kind in ipairs(ns.COLOR_KINDS) do
			assert.are.same({ r = 0, g = 1, b = 0 }, ns.DEFAULTS.colors[kind.key])
		end
	end)

	it("has unique kind keys, so every kind gets its own row in the window", function()
		local seen = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			assert.is_nil(seen[kind.key])
			seen[kind.key] = true
		end
	end)

	it("hands out a fresh default color each time", function()
		local first = ns.GetDefaultColor("spellDamage")
		first.r = 1
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.GetDefaultColor("spellDamage"))
	end)

	it("covers every colored kind the rules can produce", function()
		local keys = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			keys[kind.key] = true
		end
		for _, key in ipairs({
			"spellDamage",
			"spellHealing",
			"arcaneDamage",
			"fireDamage",
			"frostDamage",
			"holyDamage",
			"natureDamage",
			"shadowDamage",
			"mp5",
			"hp5",
			"attackPower",
			"attackPowerVs",
			"defense",
			"blockRating",
			"hitRating",
		}) do
			assert.is_true(keys[key])
		end
	end)
end)

describe("sample lines", function()
	local ns = LoadConfig()

	local function Kind(key)
		for _, kind in ipairs(ns.COLOR_KINDS) do
			if kind.key == key then
				return kind
			end
		end
	end

	it("are compact lines the client's language can rebuild", function()
		assert.are.same({
			kind = "hitRating",
			text = "+1% hit rating",
			value = 1,
			percent = true,
			stats = { "ITEM_MOD_HIT_RATING_SHORT" },
		}, ns.GetSampleLine(Kind("hitRating")))
	end)

	it("leave MP5 and HP5 without stat names, so they never change language", function()
		assert.is_nil(ns.GetSampleLine(Kind("mp5")).stats)
		assert.are.equal("+4 MP5", ns.GetSampleLine(Kind("mp5")).text)
		assert.is_nil(ns.GetSampleLine(Kind("hp5")).stats)
	end)

	it("can use another stat than the row label's", function()
		local line = ns.GetSampleLine(Kind("attackPowerVs"))
		assert.are.equal("+6 attack power vs beasts", line.text)
		assert.are.same({ "ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT" }, line.stats)
	end)
end)

describe("languages", function()
	local ns = LoadConfig()

	it("offers every bundled language on a client with the Latin alphabet", function()
		local all = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }
		assert.are.same(all, ns.GetOfferedLanguages("esES"))
		assert.are.same(all, ns.GetOfferedLanguages("enUS"))
	end)

	it("offers only English on a client whose font may lack accented letters", function()
		assert.are.same({ "enUS" }, ns.GetOfferedLanguages("ruRU"))
		assert.are.same({ "enUS" }, ns.GetOfferedLanguages("zhCN"))
	end)

	it("show a saved language the client offers", function()
		assert.are.equal("deDE", ns.ResolveLanguage("deDE", "esES"))
		assert.are.equal("enUS", ns.ResolveLanguage("enUS", "koKR"))
	end)

	it("show the client's own for its language saved by name, or nothing saved", function()
		assert.are.equal("CLIENT", ns.ResolveLanguage("esES", "esES"))
		assert.are.equal("CLIENT", ns.ResolveLanguage("CLIENT", "esES"))
		assert.are.equal("CLIENT", ns.ResolveLanguage(nil, "esES"))
	end)

	it("show the client's own for a saved language its font can't show", function()
		assert.are.equal("CLIENT", ns.ResolveLanguage("deDE", "ruRU"))
	end)
end)

describe("original text key labels", function()
	local ns = LoadConfig()

	it("name the client's own text for each key", function()
		local globals = {}
		for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
			table.insert(globals, option.labelGlobal)
		end
		assert.are.same({ "CTRL_KEY", "ALT_KEY", "SHIFT_KEY" }, globals)
	end)
end)

describe("IsOriginalTextEventKey", function()
	local ns = LoadConfig()

	it("matches both sides of the chosen modifier", function()
		assert.is_true(ns.IsOriginalTextEventKey("CTRL", "LCTRL"))
		assert.is_true(ns.IsOriginalTextEventKey("CTRL", "RCTRL"))
	end)

	it("ignores other modifiers", function()
		assert.is_false(ns.IsOriginalTextEventKey("CTRL", "LSHIFT"))
		assert.is_false(ns.IsOriginalTextEventKey("ALT", "RCTRL"))
	end)

	it("ignores an unknown setting", function()
		assert.is_false(ns.IsOriginalTextEventKey("F13", "LCTRL"))
	end)

	it("lists both sides for every option", function()
		for _, option in ipairs(ns.ORIGINAL_TEXT_KEYS) do
			assert.are.same({ "L" .. option.key, "R" .. option.key }, option.eventKeys)
		end
	end)
end)

describe("LoadSettings", function()
	local ns

	before_each(function()
		ns = LoadConfig()
	end)

	it("returns the defaults when nothing is saved", function()
		local settings = ns.LoadSettings(nil)
		assert.are.equal("CTRL", settings.originalTextKey)
		assert.are.equal("CLIENT", settings.language)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.frostDamage)
		assert.are.equal(200, settings.minimap.angle)
	end)

	it("keeps saved values and fills the missing ones", function()
		local saved = {
			originalTextKey = "ALT",
			language = "deDE",
			colors = { frostDamage = { r = 0.2, g = 0.6, b = 1 } },
			minimap = { angle = 45 },
		}
		local settings = ns.LoadSettings(saved)
		assert.are.equal(saved, settings)
		assert.are.equal("ALT", settings.originalTextKey)
		assert.are.equal("deDE", settings.language)
		assert.are.same({ r = 0.2, g = 0.6, b = 1 }, settings.colors.frostDamage)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellDamage)
		assert.are.equal(45, settings.minimap.angle)
	end)

	it("doesn't share color tables with the defaults", function()
		local settings = ns.LoadSettings(nil)
		settings.colors.spellDamage.r = 1
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.DEFAULTS.colors.spellDamage)
		assert.is_false(settings.colors.spellDamage == settings.colors.spellHealing)
	end)

	it("replaces invalid values with defaults", function()
		local settings = ns.LoadSettings({
			originalTextKey = "F13",
			language = "KLINGON",
			colors = { spellDamage = { r = 2, g = 0, b = 0 }, hp5 = "red" },
			minimap = "left",
		})
		assert.are.equal("CTRL", settings.originalTextKey)
		assert.are.equal("CLIENT", settings.language)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellDamage)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.hp5)
		assert.are.equal(200, settings.minimap.angle)
	end)

	it("replaces numbers that aren't finite with defaults", function()
		local nan = 0 / 0
		local settings = ns.LoadSettings({
			colors = { spellDamage = { r = nan, g = 0, b = 0 } },
			minimap = { angle = nan },
		})
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellDamage)
		assert.are.equal(200, settings.minimap.angle)
		assert.are.equal(200, ns.LoadSettings({ minimap = { angle = math.huge } }).minimap.angle)
		assert.are.equal(200, ns.LoadSettings({ minimap = { angle = -math.huge } }).minimap.angle)
	end)
end)
