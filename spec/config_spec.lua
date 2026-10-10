local helpers = require("spec.helpers")

local function LoadConfig()
	return helpers.LoadAddon("StatsTrimmer", { "Config.lua" })
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
		local first = ns.GetDefaultColor("spellPower")
		first.r = 1
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.GetDefaultColor("spellPower"))
	end)

	it("covers every colored kind the rules can produce", function()
		local keys = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			keys[kind.key] = true
		end
		for _, key in ipairs({
			"spellPower",
			"healingPower",
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
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.frostDamage)
		assert.are.equal(200, settings.minimap.angle)
	end)

	it("keeps saved values and fills the missing ones", function()
		local saved = {
			originalTextKey = "ALT",
			colors = { frostDamage = { r = 0.2, g = 0.6, b = 1 } },
			minimap = { angle = 45 },
		}
		local settings = ns.LoadSettings(saved)
		assert.are.equal(saved, settings)
		assert.are.equal("ALT", settings.originalTextKey)
		assert.are.same({ r = 0.2, g = 0.6, b = 1 }, settings.colors.frostDamage)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellPower)
		assert.are.equal(45, settings.minimap.angle)
	end)

	it("doesn't share color tables with the defaults", function()
		local settings = ns.LoadSettings(nil)
		settings.colors.spellPower.r = 1
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.DEFAULTS.colors.spellPower)
		assert.is_false(settings.colors.spellPower == settings.colors.healingPower)
	end)

	it("replaces invalid values with defaults", function()
		local settings = ns.LoadSettings({
			originalTextKey = "F13",
			colors = { spellPower = { r = 2, g = 0, b = 0 }, hp5 = "red" },
			minimap = "left",
		})
		assert.are.equal("CTRL", settings.originalTextKey)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellPower)
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.hp5)
		assert.are.equal(200, settings.minimap.angle)
	end)

	it("replaces numbers that aren't finite with defaults", function()
		local nan = 0 / 0
		local settings = ns.LoadSettings({
			colors = { spellPower = { r = nan, g = 0, b = 0 } },
			minimap = { angle = nan },
		})
		assert.are.same({ r = 0, g = 1, b = 0 }, settings.colors.spellPower)
		assert.are.equal(200, settings.minimap.angle)
		assert.are.equal(200, ns.LoadSettings({ minimap = { angle = math.huge } }).minimap.angle)
		assert.are.equal(200, ns.LoadSettings({ minimap = { angle = -math.huge } }).minimap.angle)
	end)
end)
