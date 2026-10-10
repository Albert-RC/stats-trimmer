-- Real cases seen in-game on an esES client (text and GetItemStats output), plus enUS variants
local helpers = require("spec.helpers")
local ns = helpers.LoadAddon("StatsTrimmer", { "Util.lua", "Rules.lua" })

-- Creature type names as C_CreatureInfo.GetCreatureTypeInfo returns them. ruRU stands for a locale whose
-- tooltip uses a declined form that doesn't contain the type name.
local CREATURE_TYPES = {
	esES = { [1] = "Bestia", [3] = "Demonio", [4] = "Elemental", [6] = "No-muerto" },
	enUS = {
		[1] = "Beast",
		[2] = "Dragonkin",
		[3] = "Demon",
		[4] = "Elemental",
		[5] = "Giant",
		[6] = "Undead",
		[7] = "Humanoid",
		[9] = "Mechanical",
	},
	ruRU = { [1] = "Животное", [4] = "Элементаль", [6] = "Нежить" },
}

-- ITEM_SPELL_TRIGGER_ONEQUIP per locale
local EQUIP_PREFIXES = { esES = "Equipar:", enUS = "Equip:", ruRU = "Если на персонаже:" }

-- GetReplacement for one equip line; itemLines are the item's other tooltip lines (defaults to just this one)
local function Replace(text, stats, locale, itemLines)
	locale = locale or "esES"
	local context = {
		lines = itemLines or { { leftText = text } },
		equipPrefix = EQUIP_PREFIXES[locale],
		GetCreatureTypeName = function(id)
			return CREATURE_TYPES[locale][id]
		end,
	}
	return ns.GetReplacement(text, stats, context)
end

-- An expected compact line
local function L(kind, text)
	return { kind = kind, text = text }
end

local function Lines(...)
	local lines = {}
	for _, text in ipairs({ ... }) do
		table.insert(lines, { leftText = text })
	end
	return lines
end

describe("spell damage and healing", function()
	-- Cosedora
	local stats = {
		ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8.125,
		ITEM_MOD_STAMINA_SHORT = 3,
		ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30,
		ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10,
	}
	local expected = { L("spellPower", "≤10 spell power"), L("healingPower", "≤30 healing power") }

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
	local expected = { L("spellPower", "≤26 spell power"), L("healingPower", "≤26 healing power") }

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
		assert.are.same({ L("frostDamage", "≤32 frost damage") }, Replace(text, stats))
	end)

	it("names the school (enUS)", function()
		local text = "Equip: Increases damage done by Frost spells and effects by up to 32."
		assert.are.same({ L("frostDamage", "≤32 frost damage") }, Replace(text, stats, "enUS"))
	end)
end)

describe("MP5", function()
	local stats = { ITEM_MOD_MANA_REGENERATION_SHORT = 4, RESISTANCE0_NAME = 35, ITEM_MOD_STAMINA_SHORT = 5 }

	it("expects the value and the 5 seconds (esES)", function()
		assert.are.same({ L("mp5", "+4 MP5") }, Replace("Equipar: Restaura 4 p. de maná cada 5 s.", stats))
	end)

	it("expects the value and the 5 seconds (enUS)", function()
		assert.are.same({ L("mp5", "+4 MP5") }, Replace("Equip: Restores 4 mana per 5 sec.", stats, "enUS"))
	end)

	it("accepts a value of 5, where both numbers are the same", function()
		local text = "Equip: Restores 5 mana per 5 sec."
		assert.are.same({ L("mp5", "+5 MP5") }, Replace(text, { ITEM_MOD_MANA_REGENERATION_SHORT = 5 }, "enUS"))
	end)
end)

describe("HP5", function()
	local stats = { ITEM_MOD_HEALTH_REGEN_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 3, RESISTANCE0_NAME = 17 }

	it("expects the value and the 5 seconds (esES)", function()
		assert.are.same({ L("hp5", "+5 HP5") }, Replace("Equipar: Restaura 5 p. de salud cada 5 s.", stats))
	end)

	it("expects the value and the 5 seconds (enUS)", function()
		assert.are.same({ L("hp5", "+5 HP5") }, Replace("Equip: Restores 5 health per 5 sec.", stats, "enUS"))
	end)
end)

describe("block rating", function()
	-- Espejo de Rath'mael
	local stats = { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_BLOCK_RATING_SHORT = 5, RESISTANCE0_NAME = 547 }
	local text = "Equipar: Aumenta un 1.0% la probabilidad de bloquear ataques con un escudo."

	it("reads the percentage from the text (esES)", function()
		assert.are.same({ L("blockRating", "+1% block rating") }, Replace(text, stats))
	end)

	it("reads the percentage from the text (enUS)", function()
		local enText = "Equip: Increases your chance to block attacks with a shield by 1%."
		assert.are.same({ L("blockRating", "+1% block rating") }, Replace(enText, stats, "enUS"))
	end)

	it("still works when the item also has defense, which isn't a percentage", function()
		local withDefense = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 3 }
		assert.are.same({ L("blockRating", "+1% block rating") }, Replace(text, withDefense))
	end)

	it("leaves the line alone when another rating could own the percentage", function()
		local withCrit = { ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_CRIT_RATING_SHORT = 14 }
		assert.is_nil(Replace(text, withCrit))
	end)
end)

describe("attack power", function()
	it("replaces a plain attack power line", function()
		local stats = { ITEM_MOD_ATTACK_POWER_SHORT = 4, RESISTANCE0_NAME = 56, ITEM_MOD_SPIRIT_SHORT = 5 }
		assert.are.same({ L("attackPower", "+4 attack power") }, Replace("Equipar: +4 p. de poder de ataque.", stats))
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
			assert.are.same({ L("attackPower", "+6 attack power") }, Replace(plain, stats, "esES", itemLines))
		end)

		it("tells the vs beasts line apart (esES)", function()
			assert.are.same(
				{ L("attackPowerVs", "+6 attack power vs beasts") },
				Replace(vsBeasts, stats, "esES", itemLines)
			)
		end)

		it("tells both lines apart (enUS)", function()
			local enPlain = "Equip: +6 Attack Power."
			local enBeasts = "Equip: +6 Attack Power when fighting Beasts."
			local enLines = Lines(enPlain, enBeasts)
			assert.are.same({ L("attackPower", "+6 attack power") }, Replace(enPlain, stats, "enUS", enLines))
			assert.are.same(
				{ L("attackPowerVs", "+6 attack power vs beasts") },
				Replace(enBeasts, stats, "enUS", enLines)
			)
		end)

		describe("in a locale whose line uses a declined form of the type name", function()
			-- ruRU-style lines, made up: "животных" doesn't contain the type name "Животное"
			local ruPlain = "Если на персонаже: +6 к силе атаки."
			local ruBeasts =
				"Если на персонаже: +6 к силе атаки против животных."

			it("leaves both lines alone", function()
				local ruLines = Lines("Костяные кастеты", ruPlain, ruBeasts)
				assert.is_nil(Replace(ruPlain, stats, "ruRU", ruLines))
				assert.is_nil(Replace(ruBeasts, stats, "ruRU", ruLines))
			end)

			it("doesn't take the type name from the item name", function()
				local ruLines = Lines("Кастеты Животное", ruPlain, ruBeasts)
				assert.is_nil(Replace(ruPlain, stats, "ruRU", ruLines))
				assert.is_nil(Replace(ruBeasts, stats, "ruRU", ruLines))
			end)
		end)
	end)

	it("replaces a vs line without the type name when no other stat has its number", function()
		local stats = { ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6, ITEM_MOD_STAMINA_SHORT = 4 }
		local ruBeasts = "Если на персонаже: +6 к силе атаки против животных."
		assert.are.same({ L("attackPowerVs", "+6 attack power vs beasts") }, Replace(ruBeasts, stats, "ruRU"))
	end)

	describe("one line naming several creature types", function()
		local stats = { ITEM_MOD_ATTACK_POWER_VS_UNDEAD_SHORT = 150, ITEM_MOD_ATTACK_POWER_VS_DEMON_SHORT = 150 }

		it("lists every type, in the line's order (enUS)", function()
			local text = "Equip: +150 Attack Power when fighting Undead and Demons."
			assert.are.same({ L("attackPowerVs", "+150 attack power vs undead/demons") }, Replace(text, stats, "enUS"))
		end)

		it("lists every type, in the line's order (esES)", function()
			local text = "Equipar: +150 p. de poder de ataque contra demonios y no-muertos."
			assert.are.same({ L("attackPowerVs", "+150 attack power vs demons/undead") }, Replace(text, stats))
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
			assert.are.same({ L("attackPower", "+4 attack power") }, Replace(plain, stats, "esES", itemLines))
			assert.are.same(
				{ L("attackPowerVs", "+6 attack power vs elementals") },
				Replace(vsElementals, stats, "esES", itemLines)
			)
		end)

		it("leaves the profession skill line alone", function()
			assert.is_nil(Replace(mining, stats, "esES", itemLines))
		end)
	end)
end)

describe("hit rating", function()
	-- Stats seen in-game; line texts not captured, they follow the usual Classic wording
	local stats = { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_HIT_RATING_SHORT = 4, ITEM_MOD_AGILITY_SHORT = 4 }

	it("reads the percentage from the text, not the rating (esES)", function()
		local text = "Equipar: Mejora tu probabilidad de golpear un 1%."
		assert.are.same({ L("hitRating", "+1% hit rating") }, Replace(text, stats))
	end)

	it("reads the percentage from the text, not the rating (enUS)", function()
		local text = "Equip: Improves your chance to hit by 1%."
		assert.are.same({ L("hitRating", "+1% hit rating") }, Replace(text, stats, "enUS"))
	end)
end)

describe("defense", function()
	-- Stats seen in-game; the esES line text wasn't captured, it follows the usual Classic wording
	local stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14.347826, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 3 }

	it("shows the skill points (esES)", function()
		assert.are.same({ L("defense", "+3 defense") }, Replace("Equipar: Defensa aumentada +3.", stats))
	end)

	it("shows the skill points (enUS)", function()
		assert.are.same({ L("defense", "+3 defense") }, Replace("Equip: Increased Defense +3.", stats, "enUS"))
	end)
end)

-- The cases below follow the usual Classic wording; they haven't been seen on Forever items yet
describe("percentage ratings", function()
	local cases = {
		{
			"ITEM_MOD_CRIT_RATING_SHORT",
			"Equip: Improves your chance to get a critical strike by 1%.",
			"critRating",
			"+1% crit rating",
		},
		{
			"ITEM_MOD_CRIT_SPELL_RATING_SHORT",
			"Equip: Improves your chance to get a critical strike with spells by 1%.",
			"spellCritRating",
			"+1% spell crit rating",
		},
		{
			"ITEM_MOD_HIT_SPELL_RATING_SHORT",
			"Equip: Improves your chance to hit with spells by 1%.",
			"spellHitRating",
			"+1% spell hit rating",
		},
		{
			"ITEM_MOD_DODGE_RATING_SHORT",
			"Equip: Increases your chance to dodge an attack by 1%.",
			"dodgeRating",
			"+1% dodge rating",
		},
		{
			"ITEM_MOD_PARRY_RATING_SHORT",
			"Equip: Increases your chance to parry an attack by 2%.",
			"parryRating",
			"+2% parry rating",
		},
	}
	for _, case in ipairs(cases) do
		local key, text, kind, expected = case[1], case[2], case[3], case[4]
		it(expected, function()
			assert.are.same({ L(kind, expected) }, Replace(text, { [key] = 14 }, "enUS"))
		end)
	end

	it("leaves both lines alone when an item has two percentage ratings", function()
		local stats = { ITEM_MOD_HIT_RATING_SHORT = 4, ITEM_MOD_CRIT_RATING_SHORT = 5 }
		assert.is_nil(Replace("Equip: Improves your chance to hit by 1%.", stats, "enUS"))
		assert.is_nil(Replace("Equip: Improves your chance to get a critical strike by 1%.", stats, "enUS"))
	end)
end)

describe("point stats", function()
	local cases = {
		{
			"ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
			24,
			"Equip: +24 ranged Attack Power.",
			"rangedAttackPower",
			"+24 ranged attack power",
		},
		{
			"ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
			60,
			"Equip: +60 Attack Power in Cat, Bear, and Dire Bear forms only.",
			"feralAttackPower",
			"+60 feral attack power",
		},
		{
			"ITEM_MOD_BLOCK_VALUE_SHORT",
			15,
			"Equip: Increases the block value of your shield by 15.",
			"blockValue",
			"+15 block value",
		},
		{
			"ITEM_MOD_SPELL_PENETRATION_SHORT",
			10,
			"Equip: Decreases the magical resistances of your spell targets by 10.",
			"spellPenetration",
			"+10 spell penetration",
		},
	}
	for _, case in ipairs(cases) do
		local key, value, text, kind, expected = case[1], case[2], case[3], case[4], case[5]
		it(expected, function()
			assert.are.same({ L(kind, expected) }, Replace(text, { [key] = value }, "enUS"))
		end)
	end
end)

-- Numbers alone can't tell these lines apart, and guessing would show a wrong line, so they keep their
-- text. See "Rules" in docs/DEVELOPMENT.md.
describe("lines with more than one possible owner keep their text", function()
	-- Every equip line of the item keeps its text
	local function AssertAllUntouched(stats, ...)
		local itemLines = Lines(...)
		for _, line in ipairs(itemLines) do
			assert.is_nil(Replace(line.leftText, stats, "enUS", itemLines))
		end
	end

	it("two schools with the same value", function()
		AssertAllUntouched(
			{ ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = 20, ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = 20 },
			"Equip: Increases damage done by Fire spells and effects by up to 20.",
			"Equip: Increases damage done by Shadow spells and effects by up to 20."
		)
	end)

	it("MP5 and HP5 with the same value", function()
		AssertAllUntouched(
			{ ITEM_MOD_MANA_REGENERATION_SHORT = 4, ITEM_MOD_HEALTH_REGEN_SHORT = 4 },
			"Equip: Restores 4 mana per 5 sec.",
			"Equip: Restores 4 health per 5 sec."
		)
	end)

	it("MP5 of 5 and attack power of 5, whose lines both show only 5s", function()
		AssertAllUntouched(
			{ ITEM_MOD_MANA_REGENERATION_SHORT = 5, ITEM_MOD_ATTACK_POWER_SHORT = 5 },
			"Equip: Restores 5 mana per 5 sec.",
			"Equip: +5 Attack Power."
		)
	end)

	it("attack power and ranged attack power with the same value", function()
		AssertAllUntouched(
			{ ITEM_MOD_ATTACK_POWER_SHORT = 24, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 24 },
			"Equip: +24 Attack Power.",
			"Equip: +24 ranged Attack Power."
		)
	end)

	it("two point stats with the same value", function()
		AssertAllUntouched(
			{ ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 7, ITEM_MOD_BLOCK_VALUE_SHORT = 7 },
			"Equip: Increased Defense +7.",
			"Equip: Increases the block value of your shield by 7."
		)
	end)

	it("a stat whose number is also in an unrelated equip line", function()
		AssertAllUntouched(
			{ ITEM_MOD_ATTACK_POWER_SHORT = 1 },
			"Equip: +1 Attack Power.",
			"Equip: Increases your effective stealth level by 1."
		)
	end)

	it("a percentage rating next to an unrelated percentage line", function()
		AssertAllUntouched(
			{ ITEM_MOD_HIT_RATING_SHORT = 10 },
			"Equip: Improves your chance to hit by 1%.",
			"Equip: Increases your movement speed by 8%."
		)
	end)

	it("a creature type no rule knows, next to attack power with the same value", function()
		AssertAllUntouched(
			{ ITEM_MOD_ATTACK_POWER_SHORT = 6, ITEM_MOD_ATTACK_POWER_VS_CRITTER_SHORT = 6 },
			"Equip: +6 Attack Power.",
			"Equip: +6 Attack Power when fighting Critters."
		)
	end)

	it("a group of weapon skills sharing its number with another stat, without removing any line", function()
		AssertAllUntouched(
			{
				ITEM_MOD_AXES_SHORT = 7,
				ITEM_MOD_DAGGERS_SHORT = 7,
				ITEM_MOD_SWORDS_SHORT = 7,
				ITEM_MOD_ATTACK_POWER_SHORT = 7,
			},
			"Equip: Increased Axes +7.",
			"Equip: Increased Daggers +7.",
			"Equip: Increased Swords +7.",
			"Equip: +7 Attack Power."
		)
	end)
end)

describe("percentages", function()
	it("aren't read as a point stat with the same number", function()
		local stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10 }
		local spell = "Equip: Increases damage done by magical spells and effects by up to 10."
		local silence = "Equip: Increases your chance to resist Silence and Interrupt effects by 10%."
		local itemLines = Lines(spell, silence)
		assert.are.same({ L("spellPower", "≤10 spell power") }, Replace(spell, stats, "enUS", itemLines))
		assert.is_nil(Replace(silence, stats, "enUS", itemLines))
	end)

	it("give the rating to the only line with a lone percentage", function()
		local stats = { ITEM_MOD_HIT_RATING_SHORT = 10 }
		local hit = "Equip: Improves your chance to hit by 1%."
		local struck = "Equip: When struck in combat has a 5% chance to stun the attacker for 3 sec."
		local itemLines = Lines(hit, struck)
		assert.are.same({ L("hitRating", "+1% hit rating") }, Replace(hit, stats, "enUS", itemLines))
		assert.is_nil(Replace(struck, stats, "enUS", itemLines))
	end)

	it("stay as they are for a rating no rule knows", function()
		local text = "Equip: Improves your chance to hit by 1%."
		assert.is_nil(Replace(text, { ITEM_MOD_EXPERTISE_RATING_SHORT = 10 }, "enUS"))
	end)
end)

describe("weapon skills", function()
	-- Expected names are written out here, not taken from the rules' table, so a typo there shows up
	local skills = {
		{ "AXES", "Axes", "axes" },
		{ "TWOHANDED_AXES", "Two-handed Axes", "two-handed axes" },
		{ "BOWS", "Bows", "bows" },
		{ "CROSSBOWS", "Crossbows", "crossbows" },
		{ "DAGGERS", "Daggers", "daggers" },
		{ "FIST_WEAPONS", "Fist Weapons", "fist weapons" },
		{ "GUNS", "Guns", "guns" },
		{ "MACES", "Maces", "maces" },
		{ "TWOHANDED_MACES", "Two-handed Maces", "two-handed maces" },
		{ "POLEARMS", "Polearms", "polearms" },
		{ "STAVES", "Staves", "staves" },
		{ "SWORDS", "Swords", "swords" },
		{ "TWOHANDED_SWORDS", "Two-handed Swords", "two-handed swords" },
		{ "THROWN", "Thrown", "thrown" },
		{ "WANDS", "Wands", "wands" },
	}
	for _, skill in ipairs(skills) do
		local key, inGame, label = skill[1], skill[2], skill[3]
		it(("names %s"):format(label), function()
			local stats = { ["ITEM_MOD_" .. key .. "_SHORT"] = 4 }
			local text = ("Equip: Increased %s +4."):format(inGame)
			assert.are.same({ L("weaponSkill", ("+4 %s skill"):format(label)) }, Replace(text, stats, "enUS"))
		end)
	end

	it("replaces skills with different numbers one by one", function()
		local stats = { ITEM_MOD_AXES_SHORT = 5, ITEM_MOD_SWORDS_SHORT = 7 }
		local axes, swords = "Equip: Increased Axes +5.", "Equip: Increased Swords +7."
		local itemLines = Lines(axes, swords)
		assert.are.same({ L("weaponSkill", "+5 axes skill") }, Replace(axes, stats, "enUS", itemLines))
		assert.are.same({ L("weaponSkill", "+7 swords skill") }, Replace(swords, stats, "enUS", itemLines))
	end)

	it("names a single skill", function()
		local stats = { ITEM_MOD_SWORDS_SHORT = 7 }
		assert.are.same({ L("weaponSkill", "+7 swords skill") }, Replace("Equip: Increased Swords +7.", stats, "enUS"))
	end)

	it("names two-handed skills", function()
		local stats = { ITEM_MOD_TWOHANDED_MACES_SHORT = 3 }
		local text = "Equip: Increased Two-handed Maces +3."
		assert.are.same({ L("weaponSkill", "+3 two-handed maces skill") }, Replace(text, stats, "enUS"))
	end)

	describe("several skills with the same number (Edgemaster's Handguards)", function()
		local stats = { ITEM_MOD_AXES_SHORT = 7, ITEM_MOD_DAGGERS_SHORT = 7, ITEM_MOD_SWORDS_SHORT = 7 }
		local axes = "Equip: Increased Axes +7."
		local daggers = "Equip: Increased Daggers +7."
		local swords = "Equip: Increased Swords +7."
		local itemLines = Lines("Edgemaster's Handguards", "+7 Agility", axes, daggers, swords)

		it("turns the first line into a combined line", function()
			local expected = { L("weaponSkill", "+7 axes/daggers/swords skill") }
			assert.are.same(expected, Replace(axes, stats, "enUS", itemLines))
		end)

		it("removes the other lines", function()
			assert.are.same({}, Replace(daggers, stats, "enUS", itemLines))
			assert.are.same({}, Replace(swords, stats, "enUS", itemLines))
		end)

		it("leaves the lines alone when their count doesn't match the skills", function()
			local fewerLines = Lines(axes, daggers)
			assert.is_nil(Replace(axes, stats, "enUS", fewerLines))
		end)
	end)

	it("groups the skills apart from a vs line with the same number", function()
		local stats = { ITEM_MOD_AXES_SHORT = 7, ITEM_MOD_DAGGERS_SHORT = 7, ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 7 }
		local axes = "Equip: Increased Axes +7."
		local daggers = "Equip: Increased Daggers +7."
		local beasts = "Equip: +7 Attack Power when fighting Beasts."
		local itemLines = Lines(axes, daggers, beasts)
		assert.are.same({ L("weaponSkill", "+7 axes/daggers skill") }, Replace(axes, stats, "enUS", itemLines))
		assert.are.same({}, Replace(daggers, stats, "enUS", itemLines))
		assert.are.same({ L("attackPowerVs", "+7 attack power vs beasts") }, Replace(beasts, stats, "enUS", itemLines))
	end)
end)

describe("every creature type", function()
	-- stat key suffix, how enUS tooltips name the type, expected label
	local types = {
		{ "BEAST", "Beasts", "beasts" },
		{ "DRAGONKIN", "Dragonkin", "dragonkin" },
		{ "DEMON", "Demons", "demons" },
		{ "ELEMENTAL", "Elementals", "elementals" },
		{ "GIANT", "Giants", "giants" },
		{ "UNDEAD", "Undead", "undead" },
		{ "HUMANOID", "Humanoids", "humanoids" },
		{ "MECHANICAL", "Mechanicals", "mechanicals" },
	}
	for _, creature in ipairs(types) do
		local key, inGame, label = creature[1], creature[2], creature[3]

		-- A plain line with the same number makes the vs line depend on the type's ID and name
		it(("attack power vs %s"):format(label), function()
			local stats = { ITEM_MOD_ATTACK_POWER_SHORT = 30, ["ITEM_MOD_ATTACK_POWER_VS_" .. key .. "_SHORT"] = 30 }
			local plain = "Equip: +30 Attack Power."
			local vs = ("Equip: +30 Attack Power when fighting %s."):format(inGame)
			local itemLines = Lines(plain, vs)
			assert.are.same(
				{ L("attackPowerVs", ("+30 attack power vs %s"):format(label)) },
				Replace(vs, stats, "enUS", itemLines)
			)
			assert.are.same({ L("attackPower", "+30 attack power") }, Replace(plain, stats, "enUS", itemLines))
		end)

		it(("spell damage vs %s"):format(label), function()
			local stats =
				{ ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 15, ["ITEM_MOD_SPELL_DAMAGE_VS_" .. key .. "_SHORT"] = 15 }
			local plain = "Equip: Increases damage done by magical spells and effects by up to 15."
			local vs = ("Equip: Increases damage done to %s by magical spells and effects by up to 15."):format(inGame)
			local itemLines = Lines(plain, vs)
			assert.are.same(
				{ L("spellDamageVs", ("≤15 spell damage vs %s"):format(label)) },
				Replace(vs, stats, "enUS", itemLines)
			)
			assert.are.same({ L("spellPower", "≤15 spell power") }, Replace(plain, stats, "enUS", itemLines))
		end)
	end
end)

describe("spell damage vs creature type", function()
	local stats = { ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT = 20 }

	it("names the creature type (enUS)", function()
		local text = "Equip: Increases damage done to Undead by magical spells and effects by up to 20."
		assert.are.same({ L("spellDamageVs", "≤20 spell damage vs undead") }, Replace(text, stats, "enUS"))
	end)

	it("names the creature type (esES)", function()
		local text = "Equipar: Aumenta hasta 20 p. el daño infligido a no-muertos con hechizos y efectos mágicos."
		assert.are.same({ L("spellDamageVs", "≤20 spell damage vs undead") }, Replace(text, stats))
	end)

	it("tells a plain spell damage line with the same number apart", function()
		local both = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 20, ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT = 20 }
		local plain = "Equip: Increases damage done by magical spells and effects by up to 20."
		local vsUndead = "Equip: Increases damage done to Undead by magical spells and effects by up to 20."
		local itemLines = Lines(plain, vsUndead)
		assert.are.same({ L("spellPower", "≤20 spell power") }, Replace(plain, both, "enUS", itemLines))
		assert.are.same(
			{ L("spellDamageVs", "≤20 spell damage vs undead") },
			Replace(vsUndead, both, "enUS", itemLines)
		)
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
