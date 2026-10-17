-- The whole addon as the client loads it. Loading every .toc file here also makes the coverage report
-- account for all of them.
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

-- Spongy Morel and Flask of the Titans on the esES client, from their spells' esES descriptions
local MOREL_LINE = "Usar: Restaura 530 p. de salud durante 24 s. Debes permanecer sentado mientras comes."
local TITANS_LINE = "Usar: Aumenta la salud máxima 1200 p. durante 2 h. Solo puedes beneficiarte del efecto de un "
	.. "frasco cada vez. Este efecto persiste en la muerte."

describe("Stats Trimmer load order", function()
	local files = helpers.TocFiles("StatsTrimmer")

	it("loads pure helpers before the rules that use them and startup last", function()
		local position = {}
		for index, file in ipairs(files) do
			position[file] = index
		end
		assert.is_true(position["Util.lua"] < position["Rules.lua"])
		assert.is_true(position["Util.lua"] < position["ConsumableRules.lua"])
		assert.is_true(position["Rules.lua"] < position["ConsumableRules.lua"])
		assert.is_true(position["Config.lua"] < position["FoodData.lua"])
		assert.is_true(position["Config.lua"] < position["AlchemyData.lua"])
		assert.is_true(position["Config.lua"] < position["Core.lua"])
		assert.are.equal("Core.lua", files[#files])
	end)

	it("loads every .toc file against the WoW API and starts on ADDON_LOADED", function()
		local wow = fakes.NewWoW()
		local ns = helpers.StartStatsTrimmer(wow)
		assert.is_not_nil(ns.db)
		assert.are.equal(2, #wow.preCalls)
		assert.is_not_nil(ns.FOODS[435])
		assert.is_not_nil(ns.ALCHEMY[17626])
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

	-- Shows Spongy Morel's and Flask of the Titans' Use lines in GameTooltip; returns the texts it shows
	local function ShowConsumables(wow)
		local onUse = wow.env.Enum.TooltipDataLineType.ItemSpellTriggerOnUse
		fakes.ShowItem(wow, wow.env.GameTooltip, wow.env.UIParent, "ANCHOR_NONE", {
			lines = {
				{ leftText = MOREL_LINE, type = onUse, spellID = 435 },
				{ leftText = TITANS_LINE, type = onUse, spellID = 17626 },
			},
		})
		return { wow.env.GameTooltip.lines[1].text, wow.env.GameTooltip.lines[2].text }
	end

	-- The .toc files but these
	local function FilesBut(left)
		local kept = {}
		for _, file in ipairs(files) do
			if not left[file] then
				table.insert(kept, file)
			end
		end
		return kept
	end

	it("works without the consumable files, which /reload doesn't load right after the update adding them", function()
		local wow = fakes.NewWoW()
		local without = { ["FoodData.lua"] = true, ["AlchemyData.lua"] = true, ["ConsumableRules.lua"] = true }
		local ns = helpers.LoadAddon("StatsTrimmer", FilesBut(without), wow.env)
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")

		assert.are.same({ MOREL_LINE, TITANS_LINE }, ShowConsumables(wow))
		ns.ShowOptions()
		assert.are.equal("+530 salud (24 s)", wow.env.StatsTrimmerFoodPreviewTooltip.lines[2].text)
		assert.are.equal("+1200 salud (2 h)", wow.env.StatsTrimmerAlchemyPreviewTooltip.lines[10].text)
	end)

	it("works with 0.5.1's files after a /reload: FoodData.lua, but not the rules FoodRules.lua became", function()
		local wow = fakes.NewWoW()
		local ns = helpers.LoadAddon(
			"StatsTrimmer",
			FilesBut({ ["AlchemyData.lua"] = true, ["ConsumableRules.lua"] = true }),
			wow.env
		)
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")

		assert.is_not_nil(ns.FOODS[435])
		assert.are.same({ MOREL_LINE, TITANS_LINE }, ShowConsumables(wow))
	end)
end)
