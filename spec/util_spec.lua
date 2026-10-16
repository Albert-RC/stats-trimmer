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

	it("rejects a percentage, which isn't a point value", function()
		assert.is_false(ns.NumbersMatch("Equip: Increases your chance to resist Silence effects by 10%.", 10))
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

	it("returns nil when the line has another percentage", function()
		assert.is_nil(ns.GetOnlyPercent("Equip: Improves your chance to hit by 1% and your movement speed by 8%."))
		assert.is_nil(ns.GetOnlyPercent("Équipé : augmente de 1,5 % vos chances de bloquer et de 2 % de parer."))
	end)

	it("returns nil when the line has the same percentage twice", function()
		assert.is_nil(ns.GetOnlyPercent("Equip: Improves your chance to hit by 1% and to dodge by 1%."))
		assert.is_nil(ns.GetOnlyPercent("Equipar: Aumenta un 1.0% el bloqueo y un 1.0% la parada."))
	end)
end)

describe("FormatDetails", function()
	-- Blizzard's esES words, as Locales.lua bundles them
	local function Spanish(name)
		return ({ INT_SPELL_DURATION_SEC = "%d s", INT_SPELL_DURATION_MIN = "%d min", WELL_FED = "bien alimentado" })[name]
	end

	it("is empty without details", function()
		assert.are.equal("", ns.FormatDetails(nil, Spanish))
	end)

	it("adds how long a restore takes", function()
		assert.are.equal(" (24 s)", ns.FormatDetails({ seconds = 24 }, Spanish))
	end)

	it("adds the Well Fed buff's name and how long it lasts", function()
		assert.are.equal(" (bien alimentado, 15 min)", ns.FormatDetails({ wellFedMinutes = 15 }, Spanish))
	end)

	it("marks a rate with /s, the same in every language", function()
		assert.are.equal("/s (25 s)", ns.FormatDetails({ perSecond = true, seconds = 25 }, Spanish))
	end)

	it("fills in the number wherever the language puts it", function()
		local function Words(name)
			return ({ INT_SPELL_DURATION_SEC = "%d Sek." })[name]
		end
		assert.are.equal(" (24 Sek.)", ns.FormatDetails({ seconds = 24 }, Words))
	end)

	it("returns nil when a word is missing", function()
		local function NoWellFed(name)
			return name ~= "WELL_FED" and Spanish(name) or nil
		end
		assert.is_nil(ns.FormatDetails({ wellFedMinutes = 15 }, NoWellFed))
		assert.is_nil(ns.FormatDetails({ seconds = 24 }, function() end))
	end)
end)

describe("CompactLine", function()
	it("writes the English line, with a food line's details", function()
		assert.are.equal("+4 attack power", ns.CompactLine("attackPower", 4, "attack power").text)
		assert.are.equal(
			"+530 health (24 sec)",
			ns.CompactLine("health", 530, "health", nil, nil, { seconds = 24 }).text
		)
		local wellFed = ns.CompactLine("stamina", 6, "stamina", nil, nil, { wellFedMinutes = 15 })
		assert.are.equal("+6 stamina (well fed, 15 min)", wellFed.text)
		local rate = ns.CompactLine("health", 2, "health", nil, true, { perSecond = true, seconds = 25 })
		assert.are.equal("+2% health/s (25 sec)", rate.text)
	end)
end)
