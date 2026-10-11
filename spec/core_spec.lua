-- Core.lua: startup once the client has loaded the saved settings
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("ADDON_LOADED", function()
	local wow, ns

	before_each(function()
		wow = fakes.NewWoW()
		ns = helpers.LoadAddon("StatsTrimmer", helpers.TocFiles("StatsTrimmer"), wow.env)
	end)

	it("ignores other addons", function()
		fakes.FireEvent(wow, "ADDON_LOADED", "Questie")
		assert.is_nil(ns.db)
		assert.are.equal(0, #wow.categories)
	end)

	it("starts with the defaults on a first run", function()
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		assert.are.equal("CTRL", ns.db.originalTextKey)
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.db.colors.spellDamage)
	end)

	it("keeps the saved settings in the table the client saves", function()
		wow.env.StatsTrimmerDB = { originalTextKey = "ALT", colors = { frostDamage = { r = 0.2, g = 0.6, b = 1 } } }
		local saved = wow.env.StatsTrimmerDB
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		assert.are.equal(saved, ns.db)
		assert.are.equal(saved, wow.env.StatsTrimmerDB)
		assert.are.equal("ALT", ns.db.originalTextKey)
		assert.are.same({ r = 0.2, g = 0.6, b = 1 }, ns.db.colors.frostDamage)
		assert.are.same({ r = 0, g = 1, b = 0 }, ns.db.colors.spellDamage)
	end)

	it("places the minimap button and adds the Options entry", function()
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		assert.are.equal(1, #wow.env.StatsTrimmerMinimapButton.points)
		assert.are.equal(1, #wow.categories)
	end)

	it("only starts once", function()
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		assert.are.equal(1, #wow.categories)
	end)
end)
