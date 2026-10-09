-- SettingsCategory.lua: the entry in the game's Options > AddOns list
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Options > AddOns entry", function()
	local wow, category

	before_each(function()
		wow = fakes.NewWoW()
		helpers.StartEasyStats(wow)
		category = wow.categories[1]
	end)

	it("is listed as Easy Stats among the addons", function()
		assert.are.equal("Easy Stats", category.name)
		assert.is_true(category.isAddOn)
	end)

	it("opens the settings window from its button, and clicking again keeps it open", function()
		local open = fakes.FindFrames(wow, { text = "Open Easy Stats settings", parent = category.frame })[1]
		fakes.Fire(open, "OnClick")
		assert.is_true(wow.env.EasyStatsOptionsFrame:IsShown())
		fakes.Fire(open, "OnClick")
		assert.is_true(wow.env.EasyStatsOptionsFrame:IsShown())
	end)
end)
