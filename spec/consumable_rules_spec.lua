-- ConsumableRules.lua over the generated FoodData.lua and AlchemyData.lua. The enUS lines of Spongy Morel, Melon
-- Juice and Longjaw Mud
-- Snapper were seen in game; the others are Blizzard's description templates of each language with their
-- numbers filled in. The health or mana a food restores comes from the line: where the game's is unknown, the
-- number is made up.
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")
local ns = helpers.LoadAddon(
	"StatsTrimmer",
	{ "Util.lua", "Config.lua", "FoodData.lua", "AlchemyData.lua", "Rules.lua", "ConsumableRules.lua" }
)

-- ITEM_SPELL_TRIGGER_ONUSE, ITEM_COOLDOWN_TOTAL, SECONDS_ABBR and MINUTES_ABBR per locale
local CONTEXTS = {
	enUS = {
		usePrefix = "Use:",
		cooldownFormat = "(%s Cooldown)",
		secondsFormat = "%d |4Sec:Sec;",
		minutesFormat = "%d |4Min:Min;",
	},
	esES = {
		usePrefix = "Usar:",
		cooldownFormat = "(%s de tiempo de reutilización).",
		secondsFormat = "%d |4s:s;",
		minutesFormat = "%d |4min:min;",
	},
	deDE = {
		usePrefix = "Benutzen:",
		cooldownFormat = "(%s Abklingzeit)",
		secondsFormat = "%d |4Sek.:Sek.;",
		minutesFormat = "%d |4Min.:Min.;",
	},
	frFR = {
		usePrefix = "Utiliser :",
		cooldownFormat = "(%s de recharge.)",
		secondsFormat = "%d s",
		minutesFormat = "%d min",
	},
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

-- GetAlchemyReplacement for a potion's, elixir's or flask's Use line, as { kind, text } lines
local function ReplaceAlchemy(text, spellID, locale, entry)
	local lines = ns.GetAlchemyReplacement(text, entry or ns.ALCHEMY[spellID], CONTEXTS[locale or "enUS"])
	if not lines then
		return nil
	end
	local shown = {}
	for _, line in ipairs(lines) do
		table.insert(shown, { kind = line.kind, text = line.text })
	end
	return shown
end

-- Flask of the Titans, as the client showed it in an Alchemy recipe; the esES line is its description with its
-- numbers filled in
local TITANS_EN = "Use: Increases the player's maximum health by 1,200 for 2 hrs. You can only have the effect of "
	.. "one flask at a time. This effect persists through death."
local TITANS_ES = "Usar: Aumenta la salud máxima 1200 p. durante 2 h. Solo puedes beneficiarte del efecto de un "
	.. "frasco cada vez. Este efecto persiste en la muerte."
-- Major Frenzy Potion
local FRENZY_EN = "Use: Increases Attack Power by 80 for 30 sec."

describe("potions, elixirs and flasks", function()
	it("shows a flask's stat and how long it lasts, without what every flask says (Flask of the Titans)", function()
		assert.are.same({ L("alchemyHealth", "+1200 health (2 hrs)") }, ReplaceAlchemy(TITANS_EN, 17626))
		assert.are.same({ L("alchemyHealth", "+1200 health (2 hrs)") }, ReplaceAlchemy(TITANS_ES, 17626, "esES"))
	end)

	it("shows one hour in the singular", function()
		local text = "Use: Increases Intellect and Spirit by 18 for 1 hour."
		assert.are.same(
			{ L("alchemyIntellect", "+18 intellect (1 hour)"), L("alchemySpirit", "+18 spirit (1 hour)") },
			ReplaceAlchemy(text, 17535)
		)
	end)

	it("shows a stat and a crit chance, each in its line (Elixir of the Mongoose)", function()
		local text = "Use: Increases Agility by 25 and chance to get a critical hit by 2%. Lasts for 30 min."
		local expected =
			{ L("alchemyAgility", "+25 agility (30 min)"), L("alchemyCritRating", "+2% critical strike (30 min)") }
		assert.are.same(expected, ReplaceAlchemy(text, 17538))
		-- frFR writes a no-break space before the percentage
		local french = "Utiliser : Augmente l’Agilité de 25 et vos chances de réaliser un coup critique de 2\194\160%. "
			.. "Dure 30 min."
		assert.are.same(expected, ReplaceAlchemy(french, 17538, "frFR"))
	end)

	it("shows health every 5 seconds as HP5, whatever the order of the numbers (deDE)", function()
		local text = "Benutzen: Alle 5 Sekunden 20 Punkt(e) Gesundheit regenerieren. Hält 1 Stunde lang an."
		assert.are.same({ L("alchemyHp5", "+20 HP5 (1 hour)") }, ReplaceAlchemy(text, 24361, "deDE"))
	end)

	it("shows health and mana every 5 seconds as HP5 and MP5 (Elixir of Wicked Regeneration)", function()
		local text = "Usar: Bebe esto para restaurar 9 p. de salud y 10 p. de maná cada 5 s. Dura 30 min."
		assert.are.same(
			{ L("alchemyHp5", "+9 HP5 (30 min)"), L("alchemyMp5", "+10 MP5 (30 min)") },
			ReplaceAlchemy(text, 1250932, "esES")
		)
	end)

	it("shows a potion's seconds (Major Frenzy Potion)", function()
		assert.are.same({ L("alchemyAttackPower", "+80 attack power (30 sec)") }, ReplaceAlchemy(FRENZY_EN, 1251940))
	end)

	it("shows a stat against a creature type (Potion of Beast Slaying, Potion of Elemental Purging)", function()
		local beasts = "Use: Increases Attack Power by 180 against Beasts. Lasts 5 min."
		assert.are.same(
			{ L("alchemyAttackPowerVs", "+180 attack power vs beasts (5 min)") },
			ReplaceAlchemy(beasts, 1252559)
		)
		local elementals = "Usar: Aumenta 105 p. el daño con hechizos contra elementales. Dura 5 min."
		assert.are.same(
			{ L("alchemySpellDamageVs", "+105 spell damage vs elementals (5 min)") },
			ReplaceAlchemy(elementals, 1252558, "esES")
		)
	end)

	it("shows resistance to every school as spell resistance (Minor Magic Resistance Potion)", function()
		local text = "Use: Increases your resistance to all schools of magic by 25 for 3 min."
		assert.are.same({ L("alchemySpellResistance", "+25 spell resistance (3 min)") }, ReplaceAlchemy(text, 2380))
	end)

	it("drops the 3 seconds elixirs and flasks share", function()
		assert.are.same(
			{ L("alchemyHealth", "+1200 health (2 hrs)") },
			ReplaceAlchemy(TITANS_EN .. " (3 |4Sec:Sec; Cooldown)", 17626)
		)
		assert.are.same(
			{ L("alchemyHealth", "+1200 health (2 hrs)") },
			ReplaceAlchemy(TITANS_ES .. " (3 |4s:s; de tiempo de reutilización).", 17626, "esES")
		)
	end)

	it("drops the 2 minutes potions share, with or without its plural escape", function()
		local expected = { L("alchemyAttackPower", "+80 attack power (30 sec)") }
		assert.are.same(expected, ReplaceAlchemy(FRENZY_EN .. " (2 |4Min:Min; Cooldown)", 1251940))
		assert.are.same(expected, ReplaceAlchemy(FRENZY_EN .. " (2 Min Cooldown)", 1251940))
		local french = "Utiliser : Augmente de 80 la puissance d’attaque pendant 30 sec. (2 min de recharge.)"
		assert.are.same(expected, ReplaceAlchemy(french, 1251940, "frFR"))
	end)
end)

describe("potion, elixir and flask lines that keep their text", function()
	it("when a number the line shows is missing or another one is there", function()
		assert.is_nil(ReplaceAlchemy("Use: Increases Attack Power by 81 for 30 sec.", 1251940))
		assert.is_nil(ReplaceAlchemy("Use: Increases Attack Power by 80 for 30 sec and 10 more.", 1251940))
	end)

	it("when a shared cooldown comes in the other unit, or another cooldown", function()
		assert.is_nil(ReplaceAlchemy(FRENZY_EN .. " (3 |4Min:Min; Cooldown)", 1251940))
		assert.is_nil(ReplaceAlchemy(FRENZY_EN .. " (2 |4Sec:Sec; Cooldown)", 1251940))
		assert.is_nil(ReplaceAlchemy(FRENZY_EN .. " (5 |4Min:Min; Cooldown)", 1251940))
	end)

	it("when the client's text for minutes is unknown, so no cooldown in minutes is known to be shared", function()
		local context = setmetatable({ minutesFormat = false }, { __index = CONTEXTS.enUS })
		local text = FRENZY_EN .. " (2 |4Min:Min; Cooldown)"
		assert.is_nil(ns.GetAlchemyReplacement(text, ns.ALCHEMY[1251940], context))
	end)

	it("when a line has a stat no rule knows", function()
		local entry =
			{ numbers = { 5, 30 }, lines = { { stat = "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT", value = 5, minutes = 30 } } }
		assert.is_nil(ReplaceAlchemy("Use: Increases spell arcane damage by up to 5 for 30 min.", nil, nil, entry))
		local vs =
			{ numbers = { 5, 30 }, lines = { { stat = "ITEM_MOD_HEALING_VS_UNDEAD_SHORT", value = 5, minutes = 30 } } }
		assert.is_nil(ReplaceAlchemy("Use: Increases healing by 5 against Undead for 30 min.", nil, nil, vs))
	end)
end)

describe("potion, elixir and flask data", function()
	it("describes every potion, elixir and flask spell it had, so losing one shows up", function()
		local spells = {}
		for spellID in pairs(ns.ALCHEMY) do
			table.insert(spells, spellID)
		end
		table.sort(spells)
		local expected = {
			673,
			2367,
			2374,
			2378,
			2380,
			3160,
			3164,
			3166,
			3219,
			3220,
			3222,
			3223,
			3593,
			7844,
			11328,
			11334,
			11348,
			11349,
			11364,
			11390,
			11396,
			11405,
			11406,
			11474,
			17535,
			17537,
			17538,
			17539,
			17540,
			17626,
			17627,
			17628,
			17629,
			21920,
			24361,
			24363,
			439959,
			1245244,
			1250918,
			1250920,
			1250922,
			1250924,
			1250925,
			1250926,
			1250928,
			1250931,
			1250932,
			1250940,
			1250941,
			1250942,
			1250944,
			1250948,
			1250971,
			1250972,
			1250974,
			1250976,
			1250978,
			1250979,
			1250981,
			1250984,
			1250985,
			1250986,
			1250988,
			1250989,
			1251919,
			1251922,
			1251923,
			1251924,
			1251931,
			1251932,
			1251933,
			1251935,
			1251936,
			1251937,
			1251938,
			1251940,
			1251942,
			1251944,
			1251945,
			1251946,
			1251947,
			1251948,
			1252558,
			1252559,
			1310077,
		}
		assert.are.same(expected, spells)
	end)

	it("leaves out what the rules don't understand: instant restores, zone bonuses, effects with no stat", function()
		-- Major Healing Potion, Flask of Natural Accuracy, Flask of Petrification, Free Action Potion
		for _, spellID in ipairs({ 17534, 1293740, 17624, 6615 }) do
			assert.is_nil(ns.ALCHEMY[spellID])
		end
	end)

	it("renders every potion, elixir and flask whose line shows its numbers, in kinds of the alchemy tab", function()
		local kinds = {}
		for _, kind in ipairs(ns.COLOR_KINDS) do
			if kind.group:find("^alchemy") then
				kinds[kind.key] = true
			end
		end
		for spellID, entry in pairs(ns.ALCHEMY) do
			local lines = ns.GetAlchemyReplacement("Use: " .. table.concat(entry.numbers, " "), entry, CONTEXTS.enUS)
			assert.are.same({ spellID, true }, { spellID, lines ~= nil })
			for _, line in ipairs(lines) do
				assert.are.same({ spellID, line.kind, true }, { spellID, line.kind, kinds[line.kind] })
			end
		end
	end)
end)

describe("potion, elixir and flask lines in the client's language", function()
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

	it("use Blizzard's names and words for the duration, in the plural when it is", function()
		local lines = ns.GetAlchemyReplacement(TITANS_EN, ns.ALCHEMY[17626], CONTEXTS.enUS)
		assert.are.same({ "+1200 Salud (2 h)" }, Texts(ns.LocalizeLines(lines, Names(fakes.LocaleStrings("esES")))))
		assert.are.same(
			{ "+1200 Gesundheit (2 Stunden)" },
			Texts(ns.LocalizeLines(lines, Names(fakes.LocaleStrings("deDE"))))
		)
	end)

	it("keep MP5 and HP5 and translate only how long they last", function()
		local text = "Use: Drink to restore 9 health and 10 mana every 5 sec. Lasts for 30 min."
		local lines = ns.GetAlchemyReplacement(text, ns.ALCHEMY[1250932], CONTEXTS.enUS)
		assert.are.same(
			{ "+9 HP5 (30 Min.)", "+10 MP5 (30 Min.)" },
			Texts(ns.LocalizeLines(lines, Names(fakes.LocaleStrings("deDE"))))
		)
	end)

	it("name a stat against a creature type with the client's name", function()
		local text = "Use: Increases Attack Power by 180 against Beasts. Lasts 5 min."
		local lines = ns.GetAlchemyReplacement(text, ns.ALCHEMY[1252559], CONTEXTS.enUS)
		assert.are.same(
			{ "+180 Poder de ataque contra bestias (5 min)" },
			Texts(ns.LocalizeLines(lines, Names(fakes.LocaleStrings("esES"))))
		)
	end)
end)
