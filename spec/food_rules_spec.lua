-- FoodRules.lua over the generated FoodData.lua. The enUS lines of Spongy Morel, Melon Juice and Longjaw Mud
-- Snapper were seen in game; the others are Blizzard's description templates of each language with their
-- numbers filled in. The health or mana a food restores comes from the line: where the game's is unknown, the
-- number is made up.
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")
local ns = helpers.LoadAddon("StatsTrimmer", { "Util.lua", "Config.lua", "FoodData.lua", "Rules.lua", "FoodRules.lua" })

-- ITEM_SPELL_TRIGGER_ONUSE, ITEM_COOLDOWN_TOTAL and SECONDS_ABBR per locale
local CONTEXTS = {
	enUS = { usePrefix = "Use:", cooldownFormat = "(%s Cooldown)", secondsFormat = "%d |4Sec:Sec;" },
	esES = {
		usePrefix = "Usar:",
		cooldownFormat = "(%s de tiempo de reutilización).",
		secondsFormat = "%d |4s:s;",
	},
	deDE = { usePrefix = "Benutzen:", cooldownFormat = "(%s Abklingzeit)", secondsFormat = "%d |4Sek.:Sek.;" },
}

-- GetFoodReplacement for a food spell's Use line, as { kind, text } lines
local function Replace(text, spellID, locale, food)
	local lines = ns.GetFoodReplacement(text, food or ns.FOODS[spellID], CONTEXTS[locale or "enUS"])
	if not lines then
		return nil
	end
	local shown = {}
	for _, line in ipairs(lines) do
		table.insert(shown, { kind = line.kind, text = line.text })
	end
	return shown
end

-- An expected compact line
local function L(kind, text)
	return { kind = kind, text = text }
end

-- Spongy Morel and other foods of spell 435
local MOREL_EN = "Use: Restores 530 health over 24 sec.  Must remain seated while eating."
local MOREL_ES = "Usar: Restaura 530 p. de salud durante 24 s. Debes permanecer sentado mientras comes."
-- Longjaw Mud Snapper: Forever's well fed food, whose spell isn't translated
local SNAPPER_EN = "Use: Restores 530 health over 24 sec.  Must remain seated while eating. If you spend at least "
	.. "10 sec eating, you will become well fed and gain 10 Attack Power for 15 min. Additionally, experience gained "
	.. "from kills is increased by 5%. (1 |4Sec:Sec; Cooldown)"

describe("food and drink", function()
	it("shows the health a food restores and how long it takes (Spongy Morel)", function()
		assert.are.same({ L("health", "+530 health (24 sec)") }, Replace(MOREL_EN, 435))
		assert.are.same({ L("health", "+530 health (24 sec)") }, Replace(MOREL_ES, 435, "esES"))
	end)

	it("shows the mana a drink restores (Melon Juice)", function()
		local text = "Use: Restores 803 mana over 24 sec.  Must remain seated while drinking."
		assert.are.same({ L("mana", "+803 mana (24 sec)") }, Replace(text, 432))
	end)

	it("tells the amount from the duration in any order (deDE)", function()
		local text = "Benutzen: Stellt im Verlauf von 24 Sek. 530 Punkt(e) Gesundheit wieder her. Ihr müsst beim "
			.. "Essen sitzen bleiben."
		assert.are.same({ L("health", "+530 health (24 sec)") }, Replace(text, 435, "deDE"))
	end)

	it("drops the 1 second cooldown foods share, in every language", function()
		local expected = { L("health", "+530 health (24 sec)") }
		assert.are.same(expected, Replace(MOREL_EN .. " (1 |4Sec:Sec; Cooldown)", 435))
		assert.are.same(expected, Replace(MOREL_ES .. " (1 |4s:s; de tiempo de reutilización).", 435, "esES"))
		local de = "Benutzen: Stellt im Verlauf von 24 Sek. 530 Punkt(e) Gesundheit wieder her. "
			.. "(1 |4Sek.:Sek.; Abklingzeit)"
		assert.are.same(expected, Replace(de, 435, "deDE"))
	end)

	it("drops the shared cooldown with its plural escape already resolved", function()
		assert.are.same({ L("health", "+530 health (24 sec)") }, Replace(MOREL_EN .. " (1 Sec Cooldown)", 435))
	end)

	it("reads large amounts with a thousands separator", function()
		local text = "Usar: Restaura 1.392 p. de salud durante 27 s. Debes permanecer sentado mientras comes."
		assert.are.same({ L("health", "+1392 health (27 sec)") }, Replace(text, 1127, "esES"))
	end)
end)

describe("health and mana", function()
	it("gives the larger number to the larger base points, in any order (Essence Mango)", function()
		local expected = { L("health", "+2550 health (30 sec)"), L("mana", "+4410 mana (30 sec)") }
		local text = "Use: Restores 2550 health and 4410 mana over 30 sec.  Must remain seated while eating."
		assert.are.same(expected, Replace(text, 24384))
		local reversed = "Use: Restores 4410 mana and 2550 health over 30 sec."
		assert.are.same(expected, Replace(reversed, 24384))
	end)

	it("shows the same amount for both when their base points are the same (Senggin Root)", function()
		local text = "Use: Restores 294 health and 294 mana over 21 sec. Must remain seated while eating."
		assert.are.same({ L("health", "+294 health (21 sec)"), L("mana", "+294 mana (21 sec)") }, Replace(text, 2639))
	end)

	it("keeps the text when amounts of the same base points differ", function()
		local text = "Use: Restores 294 health and 300 mana over 21 sec. Must remain seated while eating."
		assert.is_nil(Replace(text, 2639))
	end)

	it("shows a total percentage as it is (Restorative Bread)", function()
		local text = "Use: Restores 100% health and 100% Mana over 20 sec. Must remain seated while drinking."
		assert.are.same(
			{ L("health", "+100% health (20 sec)"), L("mana", "+100% mana (20 sec)") },
			Replace(text, 1312719)
		)
	end)
end)

describe("percentage per second", function()
	it("marks the rate with /s (Harvest Bread)", function()
		local text = "Use: Restores 2% of your health per second for 25 sec.  Must remain seated while eating."
		assert.are.same({ L("health", "+2% health/s (25 sec)") }, Replace(text, 24005))
	end)

	it("shows health and mana with the rate the line gives both (Refreshing Red Apple)", function()
		local text = "Use: Restores 4% of your health and mana per second for 25 sec.  Must remain seated while eating."
		assert.are.same(
			{ L("health", "+4% health/s (25 sec)"), L("mana", "+4% mana/s (25 sec)") },
			Replace(text, 29055)
		)
	end)
end)

describe("well fed", function()
	local snapper = {
		L("health", "+530 health (24 sec)"),
		L("attackPower", "+10 attack power (well fed, 15 min)"),
		L("experience", "+5% experience gained from kills"),
	}

	it("shows the buff's stat, how long it lasts and the experience bonus (Longjaw Mud Snapper)", function()
		assert.are.same(snapper, Replace(SNAPPER_EN, 1249506))
	end)

	it("leaves the experience out for players who don't see it", function()
		local text = SNAPPER_EN:gsub(" Additionally, experience gained from kills is increased by 5%%%.", "")
		assert.are.same({ snapper[1], snapper[2] }, Replace(text, 1249506))
	end)

	it("reads the experience bonus when the buff has the same number (esES)", function()
		local text = "Usar: Restaura 530 p. de salud durante 24 s. Debes permanecer sentado mientras comes. Si pasas "
			.. "al menos 10 s comiendo, quedarás bien alimentado y ganarás 5 p. de aguante durante 15 min. Además, la "
			.. "experiencia obtenida al matar enemigos aumenta un 5%. (1 |4s:s; de tiempo de reutilización)."
		assert.are.same({
			L("health", "+530 health (24 sec)"),
			L("stamina", "+5 stamina (well fed, 15 min)"),
			L("experience", "+5% experience gained from kills"),
		}, Replace(text, 1248386, "esES"))
	end)

	it("shows two stats with the same value as two lines (Goblin Deviled Clams)", function()
		local text = "Use: Restores 530 health over 24 sec.  Must remain seated while eating.  If you spend at least "
			.. "10 seconds eating you will become well fed and gain 6 Stamina and Spirit for 15 min."
		assert.are.same({
			L("health", "+530 health (24 sec)"),
			L("stamina", "+6 stamina (well fed, 15 min)"),
			L("spirit", "+6 spirit (well fed, 15 min)"),
		}, Replace(text, 5006))
	end)

	it("shows two stats with their own values (Filet o' Flank)", function()
		local text = "Use: Restores 2550 health over 30 sec.  Must remain seated while eating. If you spend at least "
			.. "10 sec eating you will become Well Fed and gain 25 Agility and 10 Stamina for 15 min."
		assert.are.same({
			L("health", "+2550 health (30 sec)"),
			L("agility", "+25 agility (well fed, 15 min)"),
			L("stamina", "+10 stamina (well fed, 15 min)"),
		}, Replace(text, 1225771))
	end)

	it("shows a crit chance as a percentage (Grilled Squid)", function()
		local text = "Use: Restores 1650 health over 30 sec.  Must remain seated while eating. If you spend at least "
			.. "10 sec eating, you will become well fed and gain 1% Critical Strike chance for 15 min. Additionally, "
			.. "experience gained from kills is increased by 5%. (1 |4Sec:Sec; Cooldown)"
		assert.are.same({
			L("health", "+1650 health (30 sec)"),
			L("critRating", "+1% critical strike (well fed, 15 min)"),
			L("experience", "+5% experience gained from kills"),
		}, Replace(text, 1249522))
	end)
end)

describe("food lines that keep their text", function()
	it("when it isn't a Use line", function()
		assert.is_nil(Replace(MOREL_EN:gsub("^Use:", "Equip:"), 435))
	end)

	it("when a number the food's line shows is missing", function()
		assert.is_nil(Replace("Use: Restores 530 health over 27 sec.", 435))
	end)

	it("when the line has a number too many", function()
		assert.is_nil(Replace("Use: Restores 530 health over 24 sec, 10 more at once.", 435))
		assert.is_nil(Replace(SNAPPER_EN:gsub("by 5%%", "by 5%% and 3%%"), 1249506))
	end)

	it("when the amount is missing", function()
		assert.is_nil(Replace("Use: Restores health over 24 sec.", 435))
	end)

	it("when its cooldown is longer than the one foods share", function()
		assert.is_nil(Replace(MOREL_EN .. " (2 |4Min:Min; Cooldown)", 435))
		assert.is_nil(Replace(MOREL_EN .. " (2 |4Sec:Sec; Cooldown)", 435))
	end)

	it("when its cooldown is 1 of a longer unit", function()
		assert.is_nil(Replace(MOREL_EN .. " (1 |4Min:Min; Cooldown)", 435))
		assert.is_nil(Replace(MOREL_EN .. " (1 |4Hr:Hr; Cooldown)", 435))
		assert.is_nil(Replace(MOREL_EN .. " (1 Min Cooldown)", 435))
		assert.is_nil(Replace(MOREL_ES .. " (1 |4min:min; de tiempo de reutilización).", 435, "esES"))
	end)

	it("when its cooldown has more than one unit", function()
		assert.is_nil(Replace(MOREL_EN .. " (1 |4Min:Min; 1 |4Sec:Sec; Cooldown)", 435))
	end)

	it("when the client's cooldown text is unknown, as its number is then one too many", function()
		local context = { usePrefix = "Use:" }
		assert.is_nil(ns.GetFoodReplacement(SNAPPER_EN, ns.FOODS[1249506], context))
	end)

	it("when the client's text for seconds is unknown, so no cooldown is known to be the shared one", function()
		local context = { usePrefix = "Use:", cooldownFormat = "(%s Cooldown)" }
		assert.is_nil(ns.GetFoodReplacement(SNAPPER_EN, ns.FOODS[1249506], context))
	end)

	it("when the food has a stat no rule knows", function()
		local food = { numbers = { 5, 24 }, lines = { { stat = "ITEM_MOD_FISHING_SHORT", value = 5, seconds = 24 } } }
		assert.is_nil(Replace("Use: Gain 5 fishing for 24 sec.", nil, "enUS", food))
	end)
end)

describe("food data", function()
	it("describes every food spell it had, so losing one shows up", function()
		-- The food spells of build 1.60.1.70425: scripts/update-foods.ps1 lists the ones it adds or removes
		local expected = {
			430,
			431,
			432,
			433,
			434,
			435,
			1127,
			1129,
			1131,
			1133,
			1135,
			1137,
			2639,
			5004,
			5006,
			5007,
			7737,
			10256,
			22734,
			23692,
			24005,
			24384,
			25660,
			29008,
			29055,
			29073,
			468767,
			1225771,
			1248377,
			1248378,
			1248379,
			1248380,
			1248381,
			1248382,
			1248383,
			1248384,
			1248386,
			1248387,
			1248388,
			1248389,
			1248390,
			1248391,
			1248392,
			1248393,
			1248394,
			1248395,
			1248396,
			1248397,
			1248398,
			1248399,
			1248400,
			1248401,
			1249500,
			1249501,
			1249503,
			1249504,
			1249506,
			1249507,
			1249509,
			1249510,
			1249512,
			1249513,
			1249515,
			1249516,
			1249522,
			1249914,
			1249915,
			1249916,
			1249917,
			1249918,
			1249919,
			1249920,
			1249921,
			1249922,
			1249923,
			1249924,
			1249925,
			1255415,
			1269354,
			1302066,
			1312719,
			1319311,
		}
		local spells = {}
		for spellID in pairs(ns.FOODS) do
			table.insert(spells, spellID)
		end
		table.sort(spells)
		assert.are.same(expected, spells)
	end)

	it("leaves out foods whose line has more than the rules understand", function()
		-- Alcohol, a Fishing Skill buff, and Enriched Manna Biscuit's text for inside Naxxramas
		assert.is_nil(ns.FOODS[11009])
		assert.is_nil(ns.FOODS[1249508])
		assert.is_nil(ns.FOODS[1226814])
	end)

	it("renders every food whose line shows its numbers, in kinds with a color row", function()
		local kinds = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			kinds[kind.key] = true
		end
		local count = 0
		for spellID, food in pairs(ns.FOODS) do
			-- Amounts that grow with their base points, as the client's do
			local numbers = { unpack(food.numbers) }
			for _, line in ipairs(food.lines) do
				if line.amount then
					table.insert(numbers, 10000 + line.amount)
				end
			end
			local lines = ns.GetFoodReplacement("Use: " .. table.concat(numbers, " "), food, CONTEXTS.enUS)
			assert.are.same({ spellID, true }, { spellID, lines ~= nil })
			for _, line in ipairs(lines) do
				assert.are.same({ spellID, line.kind, true }, { spellID, line.kind, kinds[line.kind] })
			end
			count = count + 1
		end
		assert.is_true(count > 50)
	end)
end)

describe("food lines in the client's language", function()
	local ES_STRINGS = fakes.LocaleStrings("esES")

	local function Names(strings)
		return ns.TrustedNames(function(key)
			return strings[key]
		end, fakes.FoldCase)
	end

	local function Texts(lines)
		local texts = {}
		for _, line in ipairs(lines) do
			table.insert(texts, line.text)
		end
		return texts
	end

	it("use Blizzard's names and words", function()
		local lines = ns.GetFoodReplacement(SNAPPER_EN, ns.FOODS[1249506], CONTEXTS.enUS)
		assert.are.same({
			"+530 Salud (24 s)",
			"+10 Poder de ataque (Bien alimentado, 15 min)",
			"+5% Experiencia obtenida al matar enemigos",
		}, Texts(ns.LocalizeLines(lines, Names(ES_STRINGS))))
	end)

	it("stay for the next pass when a word is missing", function()
		local strings = setmetatable({ WELL_FED = false }, { __index = ES_STRINGS })
		local lines = ns.GetFoodReplacement(SNAPPER_EN, ns.FOODS[1249506], CONTEXTS.enUS)
		local localized = ns.LocalizeLines(lines, Names(strings))
		assert.are.same(
			{ "+530 Salud (24 s)", "+10 attack power (well fed, 15 min)", "+5% Experiencia obtenida al matar enemigos" },
			Texts(localized)
		)
		assert.are.same(
			{ "+530 Salud (24 s)", "+10 Attack Power (Well Fed, 15 min)", "+5% Experiencia obtenida al matar enemigos" },
			Texts(ns.LocalizeLines(localized, Names(fakes.LocaleStrings("enUS"))))
		)
	end)
end)
