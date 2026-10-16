-- scripts/update-foods.ps1 on spec/fixtures/foods, a few rows of Forever's tables (build 1.60.1.70425).
-- scripts/test-generators.ps1 runs it, then this spec reads what it wrote. The expected entries are worked out
-- here from the fixtures' descriptions and effects, not copied from FoodData.lua.
local dir = assert(os.getenv("STATS_TRIMMER_GENERATED"), "run scripts/test-generators.ps1")
local ns = {}
assert(loadfile(dir .. "/FoodData.lua"))("StatsTrimmer", ns)

describe("update-foods.ps1", function()
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
		local spells = {}
		for spellID in pairs(ns.FOODS) do
			table.insert(spells, spellID)
		end
		table.sort(spells)
		-- Not 11009 (a strong alcoholic beverage), 1249508 (Fishing Skill) or 6615 (Free Action Potion)
		assert.are.same({ 432, 435, 24005, 1249506 }, spells)
	end)
end)
