-- Real cases seen in-game on an esES client (text and GetItemStats output), plus enUS variants
local helpers = require("spec.helpers")
local ns = helpers.LoadAddon("EasyStats", { "Util.lua", "Rules.lua" })

-- Creature type names as C_CreatureInfo.GetCreatureTypeInfo returns them. ruRU stands for a locale whose
-- tooltip uses a declined form that doesn't contain the type name.
local CREATURE_TYPES = {
	esES = { [1] = "Bestia", [4] = "Elemental" },
	enUS = { [1] = "Beast", [4] = "Elemental" },
	ruRU = { [1] = "Животное", [4] = "Элементаль" },
}

-- GetReplacement for one equip line; itemLines are the item's other tooltip lines (defaults to just this one)
local function Replace(text, stats, locale, itemLines)
	local names = CREATURE_TYPES[locale or "esES"]
	local context = {
		lines = itemLines or { { leftText = text } },
		GetCreatureTypeName = function(id)
			return names[id]
		end,
	}
	return ns.GetReplacement(text, stats, context)
end

local function Lines(...)
	local lines = {}
	for _, text in ipairs({ ... }) do
		table.insert(lines, { leftText = text })
	end
	return lines
end

describe("rule order", function()
	it("is the documented priority", function()
		local names = {}
		for _, rule in ipairs(ns.Rules) do
			table.insert(names, rule.name)
		end
		assert.are.same({
			"combined spell power",
			"spell damage and healing",
			"MP5",
			"HP5",
			"attack power",
			"block chance",
			"school damage",
		}, names)
	end)
end)

describe("spell damage and healing", function()
	-- Cosedora
	local stats = {
		ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.125,
		ITEM_MOD_STAMINA_SHORT = 3,
		ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30,
		ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10,
	}
	local expected = { "≤10 spell power", "≤30 healing power" }

	it("splits different values (esES)", function()
		local text = "Equipar: Aumenta hasta 30 p. la sanación realizada y hasta 10 p. el daño infligido "
			.. "con todos los hechizos y efectos mágicos."
		assert.are.same(expected, Replace(text, stats))
	end)

	it("splits different values (enUS)", function()
		local text = "Equip: Increases healing done by up to 30 and damage done by up to 10 "
			.. "for all magical spells and effects."
		assert.are.same(expected, Replace(text, stats, "enUS"))
	end)
end)

describe("combined spell power", function()
	-- Bastón nudoso de nigromancia
	local stats = {
		ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15.178571,
		ITEM_MOD_SPELL_POWER_SHORT = 26,
		ITEM_MOD_SPIRIT_SHORT = 10,
	}
	local expected = { "≤26 spell power", "≤26 healing power" }

	it("counts as both spell and healing power (esES)", function()
		local text = "Equipar: Aumenta hasta 26 p. el daño infligido y la sanación realizada "
			.. "con hechizos y efectos mágicos."
		assert.are.same(expected, Replace(text, stats))
	end)

	it("counts as both spell and healing power (enUS)", function()
		local text = "Equip: Increases damage and healing done by magical spells and effects by up to 26."
		assert.are.same(expected, Replace(text, stats, "enUS"))
	end)
end)

describe("school damage", function()
	local stats = {
		ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15.138889,
		ITEM_MOD_FROST_DAMAGE_DONE_SHORT = 32,
		ITEM_MOD_FROST_RESISTANCE_SHORT = 13,
		RESISTANCE4_NAME = 13,
	}

	it("names the school (esES)", function()
		local text = "Equipar: Aumenta hasta 32 p. el daño infligido con hechizos y efectos de escarcha."
		assert.are.same({ "≤32 frost damage" }, Replace(text, stats))
	end)

	it("names the school (enUS)", function()
		local text = "Equip: Increases damage done by Frost spells and effects by up to 32."
		assert.are.same({ "≤32 frost damage" }, Replace(text, stats, "enUS"))
	end)
end)

describe("MP5", function()
	local stats = { ITEM_MOD_MANA_REGENERATION_SHORT = 4, RESISTANCE0_NAME = 35, ITEM_MOD_STAMINA_SHORT = 5 }

	it("expects the value and the 5 seconds (esES)", function()
		assert.are.same({ "+4 MP5" }, Replace("Equipar: Restaura 4 p. de maná cada 5 s.", stats))
	end)

	it("expects the value and the 5 seconds (enUS)", function()
		assert.are.same({ "+4 MP5" }, Replace("Equip: Restores 4 mana per 5 sec.", stats, "enUS"))
	end)

	it("accepts a value of 5, where both numbers are the same", function()
		local text = "Equip: Restores 5 mana per 5 sec."
		assert.are.same({ "+5 MP5" }, Replace(text, { ITEM_MOD_MANA_REGENERATION_SHORT = 5 }, "enUS"))
	end)
end)

describe("HP5", function()
	local stats = { ITEM_MOD_HEALTH_REGEN_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 3, RESISTANCE0_NAME = 17 }

	it("expects the value and the 5 seconds (esES)", function()
		assert.are.same({ "+5 HP5" }, Replace("Equipar: Restaura 5 p. de salud cada 5 s.", stats))
	end)

	it("expects the value and the 5 seconds (enUS)", function()
		assert.are.same({ "+5 HP5" }, Replace("Equip: Restores 5 health per 5 sec.", stats, "enUS"))
	end)
end)

describe("block chance", function()
	-- Espejo de Rath'mael
	local stats = { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_BLOCK_RATING_SHORT = 5, RESISTANCE0_NAME = 547 }
	local text = "Equipar: Aumenta un 1.0% la probabilidad de bloquear ataques con un escudo."

	it("reads the percentage from the text (esES)", function()
		assert.are.same({ "+1% block chance" }, Replace(text, stats))
	end)

	it("reads the percentage from the text (enUS)", function()
		local enText = "Equip: Increases your chance to block attacks with a shield by 1%."
		assert.are.same({ "+1% block chance" }, Replace(enText, stats, "enUS"))
	end)

	it("leaves the line alone when another rating could own the percentage", function()
		local withCrit = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_CRIT_RATING_SHORT = 14 }
		assert.is_nil(Replace(text, withCrit))
	end)
end)

describe("attack power", function()
	it("replaces a plain attack power line", function()
		local stats = { ITEM_MOD_ATTACK_POWER_SHORT = 4, RESISTANCE0_NAME = 56, ITEM_MOD_SPIRIT_SHORT = 5 }
		assert.are.same({ "+4 attack power" }, Replace("Equipar: +4 p. de poder de ataque.", stats))
	end)

	describe("vs beasts with the same number (Nudillos de hueso)", function()
		local stats = {
			ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12.25,
			ITEM_MOD_ATTACK_POWER_SHORT = 6,
			ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6,
		}
		local plain = "Equipar: +6 p. de poder de ataque."
		local vsBeasts = "Equipar: +6 p. de poder de ataque contra bestias."
		local itemLines = Lines(
			"Nudillos de hueso",
			"Se liga al recogerlo",
			"Mano principal",
			"17 - 32 Daño",
			"(12,2 daño por segundo)",
			plain,
			vsBeasts,
			"Necesitas ser de nivel 13"
		)

		it("tells the plain line apart (esES)", function()
			assert.are.same({ "+6 attack power" }, Replace(plain, stats, "esES", itemLines))
		end)

		it("tells the vs beasts line apart (esES)", function()
			assert.are.same({ "+6 attack power vs beasts" }, Replace(vsBeasts, stats, "esES", itemLines))
		end)

		it("tells both lines apart (enUS)", function()
			local enPlain = "Equip: +6 Attack Power."
			local enBeasts = "Equip: +6 Attack Power when fighting Beasts."
			local enLines = Lines(enPlain, enBeasts)
			assert.are.same({ "+6 attack power" }, Replace(enPlain, stats, "enUS", enLines))
			assert.are.same({ "+6 attack power vs beasts" }, Replace(enBeasts, stats, "enUS", enLines))
		end)

		it("leaves both lines alone when the type name isn't in the tooltip", function()
			assert.is_nil(Replace(plain, stats, "ruRU", itemLines))
			assert.is_nil(Replace(vsBeasts, stats, "ruRU", itemLines))
		end)
	end)

	describe("vs elementals with a different number", function()
		-- Stats seen in-game; line texts not captured, written in the same style as Nudillos de hueso
		local stats = {
			ITEM_MOD_ATTACK_POWER_SHORT = 4,
			ITEM_MOD_STAMINA_SHORT = 5,
			ITEM_MOD_MINING_SHORT = 2,
			ITEM_MOD_ATTACK_POWER_VS_ELEMENTAL_SHORT = 6,
			RESISTANCE0_NAME = 20,
		}
		local plain = "Equipar: +4 p. de poder de ataque."
		local vsElementals = "Equipar: +6 p. de poder de ataque contra elementales."
		local mining = "Equipar: Minería +2."
		local itemLines = Lines(plain, vsElementals, mining)

		it("replaces both attack power lines", function()
			assert.are.same({ "+4 attack power" }, Replace(plain, stats, "esES", itemLines))
			assert.are.same({ "+6 attack power vs elementals" }, Replace(vsElementals, stats, "esES", itemLines))
		end)

		it("leaves the profession skill line alone", function()
			assert.is_nil(Replace(mining, stats, "esES", itemLines))
		end)
	end)
end)

describe("lines that must keep their text", function()
	it("ignores an equip line without a matching stat", function()
		local stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10 }
		assert.is_nil(Replace("Equip: Improves your chance to get a critical strike by 1%.", stats, "enUS"))
	end)

	it("ignores an equip line without numbers", function()
		assert.is_nil(Replace("Equip: Allows underwater breathing.", { ITEM_MOD_STAMINA_SHORT = 5 }, "enUS"))
	end)
end)
