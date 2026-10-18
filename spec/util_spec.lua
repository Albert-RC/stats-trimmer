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
		assert.are.equal("/s", ns.FormatDetails({ perSecond = true }, Spanish))
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
		assert.is_nil(ns.FormatDetails({ hours = 2 }, Spanish))
	end)

	it("adds how long a potion, elixir or flask lasts, in its unit, with the plural for more than one", function()
		-- Blizzard's enUS words
		local function English(name)
			return ({ INT_SPELL_DURATION_MIN = "%d min", INT_SPELL_DURATION_HOURS = "%d |4hour:hrs;" })[name]
		end
		assert.are.equal(" (30 min)", ns.FormatDetails({ minutes = 30 }, English))
		assert.are.equal(" (1 hour)", ns.FormatDetails({ hours = 1 }, English))
		assert.are.equal(" (2 hrs)", ns.FormatDetails({ hours = 2 }, English))
	end)
end)

describe("ResolvePlural", function()
	it("takes the singular for one and the plural otherwise", function()
		assert.are.equal("1 Stunde", ns.ResolvePlural("1 |4Stunde:Stunden;", 1))
		assert.are.equal("2 Stunden", ns.ResolvePlural("2 |4Stunde:Stunden;", 2))
		assert.are.equal("0 Stunden", ns.ResolvePlural("0 |4Stunde:Stunden;", 0))
	end)

	it("leaves a text without escapes as it is", function()
		assert.are.equal("2 h", ns.ResolvePlural("2 h", 2))
	end)
end)

describe("ENGLISH_NAMES", function()
	it("are Blizzard's enUS names, lowercased", function()
		local fakes = require("spec.fakes")
		local english = fakes.LocaleStrings("enUS")
		for key, name in pairs(ns.ENGLISH_NAMES) do
			assert.are.same({ key, english[key] and english[key]:lower() }, { key, name })
		end
	end)

	it("name ratings without the word rating", function()
		assert.are.equal("+1% hit", ns.StatLine("hitRating", 1, "ITEM_MOD_HIT_RATING_SHORT", true).text)
		assert.are.equal("+1% critical strike", ns.StatLine("critRating", 1, "ITEM_MOD_CRIT_RATING_SHORT", true).text)
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
		assert.are.equal("+1200 health (2 hrs)", ns.CompactLine("health", 1200, "health", nil, nil, { hours = 2 }).text)
	end)
end)
