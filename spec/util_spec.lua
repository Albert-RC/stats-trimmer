local helpers = require("spec.helpers")
local ns = helpers.LoadAddon("StatsTrimmer", { "Util.lua" })

describe("NumbersMatch", function()
	it("accepts a line with exactly the expected number", function()
		assert.is_true(ns.NumbersMatch("Equip: +4 Attack Power.", 4))
	end)

	it("rejects a line with an extra number", function()
		assert.is_false(ns.NumbersMatch("Equipar: Restaura 4 p. de maná cada 5 s.", 4))
	end)

	it("rejects a line missing an expected number", function()
		assert.is_false(ns.NumbersMatch("Equip: +4 Attack Power.", 4, 6))
	end)

	it("accepts two expected values in any order", function()
		local text = "Equipar: Aumenta hasta 30 p. la sanación realizada y hasta 10 p. el daño infligido"
		assert.is_true(ns.NumbersMatch(text, 10, 30))
	end)

	it("treats a repeated number as one value", function()
		assert.is_true(ns.NumbersMatch("Equipar: Restaura 5 p. de salud cada 5 s.", 5, 5))
	end)

	it("rejects a line without numbers", function()
		assert.is_false(ns.NumbersMatch("Equip: Allows underwater breathing.", 1))
	end)
end)

describe("GetOnlyPercent", function()
	it("reads a dot decimal and drops a trailing .0", function()
		local text = "Equipar: Aumenta un 1.0% la probabilidad de bloquear ataques con un escudo."
		assert.are.equal("1", ns.GetOnlyPercent(text))
	end)

	it("reads a comma decimal with a space before %", function()
		assert.are.equal("1.5", ns.GetOnlyPercent("Équipé : augmente de 1,5 % vos chances de bloquer."))
	end)

	it("reads an integer percentage", function()
		assert.are.equal("2", ns.GetOnlyPercent("Equip: Increases your chance to block attacks with a shield by 2%."))
	end)

	it("returns nil without a percentage", function()
		assert.is_nil(ns.GetOnlyPercent("Equip: +4 Attack Power."))
	end)

	it("returns nil when the line has another number", function()
		assert.is_nil(ns.GetOnlyPercent("Equip: Increases your chance to block by 1% for 10 sec."))
	end)
end)

describe("HasOtherRating", function()
	it("ignores the given rating and non-rating stats", function()
		local stats = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 5 }
		assert.is_false(ns.HasOtherRating(stats, "ITEM_MOD_BLOCK_RATING_SHORT"))
	end)

	it("ignores skill ratings, which are plain points", function()
		local stats = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 3 }
		assert.is_false(ns.HasOtherRating(stats, "ITEM_MOD_BLOCK_RATING_SHORT"))
	end)

	it("finds another rating stat", function()
		local stats = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_CRIT_RATING_SHORT = 14 }
		assert.is_true(ns.HasOtherRating(stats, "ITEM_MOD_BLOCK_RATING_SHORT"))
	end)
end)

describe("AnyLineMentions", function()
	local lines = {
		{ leftText = "Nudillos de hueso" },
		{},
		{ leftText = "Equipar: +6 p. de poder de ataque contra bestias." },
	}

	it("finds a lowercase name inside a line, skipping lines without text", function()
		assert.is_true(ns.AnyLineMentions(lines, "bestia"))
	end)

	it("returns false when no line mentions the name", function()
		assert.is_false(ns.AnyLineMentions(lines, "demonio"))
	end)
end)
