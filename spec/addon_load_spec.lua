-- The whole addon as the client loads it. Loading every .toc file here also makes the coverage report
-- account for all of them.
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Easy Stats load order", function()
	local files = helpers.TocFiles("EasyStats")

	it("loads pure helpers before the rules that use them and startup last", function()
		local position = {}
		for index, file in ipairs(files) do
			position[file] = index
		end
		assert.is_true(position["Util.lua"] < position["Rules.lua"])
		assert.is_true(position["Config.lua"] < position["Core.lua"])
		assert.are.equal("Core.lua", files[#files])
	end)

	it("loads every .toc file against the WoW API and starts on ADDON_LOADED", function()
		local wow = fakes.NewWoW()
		local ns = helpers.StartEasyStats(wow)
		assert.is_not_nil(ns.db)
		assert.are.equal(1, #wow.preCalls)
		assert.is_not_nil(wow.env.EasyStatsMinimapButton)
		assert.are.equal(1, #wow.categories)
	end)
end)
