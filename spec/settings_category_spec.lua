-- SettingsCategory.lua: the entry in the game's Options > AddOns list
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Options > AddOns entry", function()
	local wow, category

	before_each(function()
		wow = fakes.NewWoW()
		helpers.StartStatsTrimmer(wow)
		category = wow.categories[1]
	end)

	it("is listed as Stats Trimmer among the addons", function()
		assert.are.equal("Stats Trimmer", category.name)
		assert.is_true(category.isAddOn)
	end)

	it("opens the settings window from its button, and clicking again keeps it open", function()
		local open = fakes.FindFrames(wow, { text = "Open Stats Trimmer settings", parent = category.frame })[1]
		fakes.Fire(open, "OnClick")
		assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
		fakes.Fire(open, "OnClick")
		assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
	end)
end)
