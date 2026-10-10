-- MinimapButton.lua: what MinimapButtonButton needs to collect it, position, dragging, click and hover
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Minimap button", function()
	local wow, ns, button

	-- Offset from the minimap's center where the button was last placed
	local function Position()
		local point = button.points[#button.points]
		assert.are.equal(wow.env.Minimap, point[2])
		return point[4], point[5]
	end

	before_each(function()
		wow = fakes.NewWoW()
		ns = helpers.StartStatsTrimmer(wow)
		button = wow.env.StatsTrimmerMinimapButton
	end)

	it("is a Minimap child whose name MinimapButtonButton collects", function()
		assert.are.equal(wow.env.Minimap, button:GetParent())
		assert.is_not_nil(button:GetName():find("MinimapButton"))
		assert.is_nil(button:GetName():find("%d$"))
	end)

	describe("position", function()
		-- Minimap is 140 wide, so the button sits 140 / 2 + 10 = 80 from its center
		it("sits on the minimap's edge at the saved angle", function()
			ns.db.minimap.angle = 0
			ns.UpdateMinimapButtonPosition()
			local x, y = Position()
			assert.are.near(80, x, 0.001)
			assert.are.near(0, y, 0.001)

			ns.db.minimap.angle = 90
			ns.UpdateMinimapButtonPosition()
			x, y = Position()
			assert.are.near(0, x, 0.001)
			assert.are.near(80, y, 0.001)
		end)

		it("starts at the angle saved in a previous session", function()
			wow = fakes.NewWoW()
			wow.env.StatsTrimmerDB = { minimap = { angle = 180 } }
			helpers.StartStatsTrimmer(wow)
			button = wow.env.StatsTrimmerMinimapButton
			local x, y = Position()
			assert.are.near(-80, x, 0.001)
			assert.are.near(0, y, 0.001)
		end)
	end)

	describe("when the minimap is resized", function()
		it("moves to the new edge", function()
			ns.db.minimap.angle = 0
			wow.env.Minimap.width = 200
			fakes.Fire(wow.env.Minimap, "OnSizeChanged")
			local x, y = Position()
			assert.are.near(110, x, 0.001)
			assert.are.near(0, y, 0.001)
		end)

		it("stays where MinimapButtonButton put it", function()
			button:SetParent(fakes.NewFrame(wow, "Frame", "MinimapButtonButtonContainer"))
			local points = button.points
			fakes.Fire(wow.env.Minimap, "OnSizeChanged")
			assert.are.equal(points, button.points)
		end)

		it("waits for the saved angle", function()
			wow = fakes.NewWoW()
			helpers.LoadAddon("StatsTrimmer", helpers.TocFiles("StatsTrimmer"), wow.env)
			fakes.Fire(wow.env.Minimap, "OnSizeChanged")
			assert.are.same({}, wow.env.StatsTrimmerMinimapButton.points)
		end)
	end)

	describe("dragging", function()
		-- Cursor positions are in screen pixels: the minimap's UI scale converts them to its coordinates
		before_each(function()
			wow.env.Minimap.scale = 2
			fakes.Fire(button, "OnDragStart")
		end)

		it("follows the cursor around the minimap and saves the angle", function()
			wow.cursor = { 500 * 2, (400 + 30) * 2 } -- straight above the center
			fakes.Fire(button, "OnUpdate")
			assert.are.near(90, ns.db.minimap.angle, 0.001)
			local x, y = Position()
			assert.are.near(0, x, 0.001)
			assert.are.near(80, y, 0.001)

			wow.cursor = { (500 - 30) * 2, 400 * 2 } -- straight left of the center
			fakes.Fire(button, "OnUpdate")
			assert.are.near(180, ns.db.minimap.angle, 0.001)
		end)

		it("stops following the cursor when released", function()
			fakes.Fire(button, "OnDragStop")
			assert.is_nil(button:GetScript("OnUpdate"))
		end)
	end)

	it("can't be dragged once MinimapButtonButton has collected it", function()
		button:SetParent(fakes.NewFrame(wow, "Frame", "MinimapButtonButtonContainer"))
		fakes.Fire(button, "OnDragStart")
		assert.is_nil(button:GetScript("OnUpdate"))
	end)

	it("opens and closes the settings window when clicked", function()
		fakes.Fire(button, "OnClick")
		assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
		fakes.Fire(button, "OnClick")
		assert.is_false(wow.env.StatsTrimmerOptionsFrame:IsShown())
	end)

	it("explains itself on hover", function()
		fakes.Fire(button, "OnEnter")
		local tooltip = wow.env.GameTooltip
		assert.are.equal(button, tooltip:GetOwner())
		assert.are.equal("Stats Trimmer", tooltip.lines[1].text)
		assert.are.equal("Click to open settings.", tooltip.lines[2].text)
		assert.is_true(tooltip:IsShown())

		fakes.Fire(button, "OnLeave")
		assert.is_false(tooltip:IsShown())
	end)
end)
