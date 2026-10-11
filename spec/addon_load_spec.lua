-- The whole addon as the client loads it. Loading every .toc file here also makes the coverage report
-- account for all of them.
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Stats Trimmer load order", function()
	local files = helpers.TocFiles("StatsTrimmer")

	it("loads pure helpers before the rules that use them and startup last", function()
		local position = {}
		for index, file in ipairs(files) do
			position[file] = index
		end
		assert.is_true(position["Util.lua"] < position["Rules.lua"])
		assert.is_true(position["Config.lua"] < position["Core.lua"])
		assert.are.equal("Core.lua", files[#files])
	end)

	it("loads every .toc file against the WoW API and starts on ADDON_LOADED", function()
		local wow = fakes.NewWoW()
		local ns = helpers.StartStatsTrimmer(wow)
		assert.is_not_nil(ns.db)
		assert.are.equal(1, #wow.preCalls)
		assert.is_not_nil(wow.env.StatsTrimmerMinimapButton)
		assert.are.equal(1, #wow.categories)
	end)

	it("works without Locales.lua, which /reload doesn't load right after an update", function()
		local wow = fakes.NewWoW()
		local withoutLocales = {}
		for _, file in ipairs(files) do
			if file ~= "Locales.lua" then
				table.insert(withoutLocales, file)
			end
		end
		local ns = helpers.LoadAddon("StatsTrimmer", withoutLocales, wow.env)
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")

		-- The esES client names spell damage vs beasts wrongly, so this line needs the English names
		wow.items["item:vsbeasts"] = { ITEM_MOD_SPELL_DAMAGE_VS_BEAST_SHORT = 15 }
		local tooltip = fakes.ItemTooltip(wow, { hyperlink = "item:vsbeasts" })
		local text = "Equipar: Aumenta hasta 15 p. el daño infligido a bestias con hechizos y efectos mágicos."
		wow.preCalls[1].handler(tooltip, { leftText = text, leftColor = fakes.Color(0, 1, 0) })
		assert.are.equal("+15 spell damage vs beasts", tooltip.lines[1].text)

		ns.ShowOptions()
		assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
	end)
end)
