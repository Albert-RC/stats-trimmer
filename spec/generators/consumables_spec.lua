-- scripts/update-consumables.ps1 on spec/fixtures/consumables, a few rows of Forever's tables (build
-- 1.60.1.70425). scripts/test-generators.ps1 runs it, then this spec reads what it wrote. The expected entries are
-- worked out here from the fixtures' descriptions and effects, not copied from FoodData.lua or AlchemyData.lua.
local dir = assert(os.getenv("STATS_TRIMMER_GENERATED"), "run scripts/test-generators.ps1")
local ns = {}
assert(loadfile(dir .. "/FoodData.lua"))("StatsTrimmer", ns)
assert(loadfile(dir .. "/AlchemyData.lua"))("StatsTrimmer", ns)

-- The spell IDs of a data table, in order
local function Spells(data)
	local spells = {}
	for spellID in pairs(data) do
		table.insert(spells, spellID)
	end
	table.sort(spells)
	return spells
end

describe("update-consumables.ps1, for food and drink", function()
	it("writes a restore whose total the client computes, with its base points (Spongy Morel)", function()
		-- "Restores $o1 health over $d.": aura 84, 115 base points, 24 seconds
		assert.are.same(
			{ numbers = { 24 }, lines = { { stat = "HEALTH", amount = 115, seconds = 24 } } },
			ns.FOODS[435]
		)
	end)

	it("reads a drink's formula as a mana restore the client computes (Melon Juice)", function()
		-- "Restores ${($s1/5)*$d} mana over $d.": aura 85, 174 base points, 24 seconds
		assert.are.same({ numbers = { 24 }, lines = { { stat = "MANA", amount = 174, seconds = 24 } } }, ns.FOODS[432])
	end)

	it("writes a Well Fed buff after the food it includes, and the experience bonus (Longjaw Mud Snapper)", function()
		-- Spongy Morel's text, then 10 seconds of eating, 10 attack power for 15 minutes, and 5% experience
		assert.are.same({
			numbers = { 24, 10, 10, 15 },
			lines = {
				{ stat = "HEALTH", amount = 115, seconds = 24 },
				{ stat = "ITEM_MOD_ATTACK_POWER_SHORT", value = 10, wellFedMinutes = 15 },
			},
			experience = 5,
		}, ns.FOODS[1249506])
	end)

	it("writes a percentage restored every second (Harvest Bread)", function()
		assert.are.same({
			numbers = { 2, 25 },
			lines = { { stat = "HEALTH", value = 2, percent = true, perSecond = true, seconds = 25 } },
		}, ns.FOODS[24005])
	end)

	it("leaves out alcohol, Fishing buffs and Use spells of items that aren't food and drink", function()
		-- Not 11009 (a strong alcoholic beverage), 1249508 (Fishing Skill) or 6615 (Free Action Potion)
		assert.are.same({ 432, 435, 24005, 1249506 }, Spells(ns.FOODS))
	end)
end)

describe("update-consumables.ps1, for potions, elixirs and flasks", function()
	it(
		"writes a flask's stat and how many hours it lasts, without what every flask says (Flask of the Titans)",
		function()
			-- "Increases the player's maximum health by $s1 for $d. You can only have the effect of one flask at a time.
			-- This effect persists through death.": aura 34 of 1200, 2 hours
			assert.are.same(
				{ numbers = { 1200, 2 }, lines = { { stat = "HEALTH", value = 1200, hours = 2 } } },
				ns.ALCHEMY[17626]
			)
		end
	)

	it("writes a stat and a percentage, each with its line, in minutes (Elixir of the Mongoose)", function()
		-- "Increases Agility by $s1 and chance to get a critical hit by $s2%. Lasts for $d.": 25, 2%, 30 minutes
		assert.are.same({
			numbers = { 25, 2, 30 },
			lines = {
				{ stat = "ITEM_MOD_AGILITY_SHORT", value = 25, minutes = 30 },
				{ stat = "ITEM_MOD_CRIT_RATING_SHORT", value = 2, percent = true, minutes = 30 },
			},
		}, ns.ALCHEMY[17538])
	end)

	it(
		"writes two stats of one value as two lines, with the value once in the numbers (Elixir of the Sages)",
		function()
			-- "Increases Intellect and Spirit by $s1 for $d.": two auras of 18, 1 hour
			assert.are.same({
				numbers = { 18, 1 },
				lines = {
					{ stat = "ITEM_MOD_INTELLECT_SHORT", value = 18, hours = 1 },
					{ stat = "ITEM_MOD_SPIRIT_SHORT", value = 18, hours = 1 },
				},
			}, ns.ALCHEMY[17535])
		end
	)

	it("writes health every 5 seconds as HP5, with the 5 in the numbers (Major Troll's Blood Elixir)", function()
		-- "Regenerate $s1 health every 5 sec for $d.": aura 161 of 20, 1 hour
		assert.are.same(
			{ numbers = { 20, 5, 1 }, lines = { { stat = "HP5", value = 20, hours = 1 } } },
			ns.ALCHEMY[24361]
		)
	end)

	it("writes a potion's seconds (Major Frenzy Potion)", function()
		-- "Increases Attack Power by $s1 for $d.": aura 99 of 80 (and 124, ranged attack power), 30 seconds
		assert.are.same(
			{ numbers = { 80, 30 }, lines = { { stat = "ITEM_MOD_ATTACK_POWER_SHORT", value = 80, seconds = 30 } } },
			ns.ALCHEMY[1251940]
		)
	end)

	it("writes a stat against a creature type with its vs key (Potion of Beast Slaying)", function()
		-- "Increases Attack Power by $s1 against Beasts. Lasts $d.": aura 102 for beasts (1), 180, 5 minutes
		assert.are.same({
			numbers = { 180, 5 },
			lines = { { stat = "ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT", value = 180, minutes = 5 } },
		}, ns.ALCHEMY[1252559])
	end)

	it("leaves out what has no stat, a duration in no whole unit, and Use spells of food", function()
		-- Not 6615 (Free Action Potion), 6612 (Rage Potion, "20 to 40"), 4941 (Lesser Stoneshield Potion, 90
		-- seconds) or 435 (Spongy Morel)
		assert.are.same({ 17535, 17538, 17626, 24361, 1251940, 1252559 }, Spells(ns.ALCHEMY))
	end)
end)
