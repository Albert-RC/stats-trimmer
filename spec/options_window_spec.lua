-- OptionsWindow.lua: opening and closing, live color editing with preview, resets and the key dropdown
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

local GREEN = { r = 0, g = 1, b = 0 }

describe("Settings window", function()
	local wow, ns

	local function KindIndex(key)
		for index, kind in ipairs(ns.COLOR_KINDS) do
			if kind.key == key then
				return index
			end
		end
	end

	-- Swatches and Reset buttons are created in COLOR_KINDS order
	local function Swatch(key)
		return fakes.FindFrames(wow, { template = "ColorSwatchTemplate" })[KindIndex(key)]
	end

	local function ResetButton(key)
		return fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", text = "Reset" })[KindIndex(key)]
	end

	local function PreviewLine(text)
		for _, line in ipairs(wow.env.StatsTrimmerPreviewTooltip.lines) do
			if line.text == text then
				return line
			end
		end
	end

	local function PreviewColor(key)
		local line = PreviewLine(ns.COLOR_KINDS[KindIndex(key)].sample)
		return { r = line.r, g = line.g, b = line.b }
	end

	before_each(function()
		wow = fakes.NewWoW()
		wow.env.StatsTrimmerDB = { colors = { frostDamage = { r = 0.2, g = 0.6, b = 1 } } }
		ns = helpers.StartStatsTrimmer(wow)
	end)

	describe("opening and closing", function()
		it("is created once and shown", function()
			ns.ShowOptions()
			ns.ShowOptions()
			assert.are.equal(1, #fakes.FindFrames(wow, { template = "PortraitFrameTemplate" }))
			assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
		end)

		it("closes with Escape", function()
			ns.ShowOptions()
			assert.are.same({ "StatsTrimmerOptionsFrame" }, wow.env.UISpecialFrames)
		end)

		it("toggles", function()
			ns.ToggleOptions()
			assert.is_true(wow.env.StatsTrimmerOptionsFrame:IsShown())
			ns.ToggleOptions()
			assert.is_false(wow.env.StatsTrimmerOptionsFrame:IsShown())
		end)

		it("closes with its close button, hiding the preview, with the open and close sounds", function()
			ns.ShowOptions()
			fakes.Fire(wow.env.StatsTrimmerOptionsFrame.CloseButton, "OnClick")
			assert.is_false(wow.env.StatsTrimmerOptionsFrame:IsShown())
			assert.is_false(wow.env.StatsTrimmerPreviewTooltip:IsShown())
			assert.are.same(
				{ wow.env.SOUNDKIT.IG_CHARACTER_INFO_OPEN, wow.env.SOUNDKIT.IG_CHARACTER_INFO_CLOSE },
				wow.sounds
			)
		end)
	end)

	describe("when opened", function()
		before_each(function()
			ns.ShowOptions()
		end)

		it("shows the saved colors in the swatches", function()
			assert.are.same({ r = 0.2, g = 0.6, b = 1 }, Swatch("frostDamage").color)
			assert.are.same(GREEN, Swatch("spellPower").color)
		end)

		it("previews a sample item with every line kind in its color", function()
			assert.are.equal("Sample Item", wow.env.StatsTrimmerPreviewTooltip.lines[1].text)
			for _, kind in ipairs(ns.COLOR_KINDS) do
				assert.are.same(ns.db.colors[kind.key], PreviewColor(kind.key))
			end
			assert.is_true(wow.env.StatsTrimmerPreviewTooltip:IsShown())
		end)
	end)

	describe("editing a color", function()
		before_each(function()
			ns.ShowOptions()
			fakes.Fire(Swatch("frostDamage"), "OnClick")
		end)

		it("opens the color picker on the current color", function()
			local info = wow.colorPicker.info
			assert.are.same({ 0.2, 0.6, 1 }, { info.r, info.g, info.b })
		end)

		it("updates the setting, swatch and preview live while the picker moves", function()
			wow.colorPicker.rgb = { 1, 0, 0 }
			wow.colorPicker.info.swatchFunc()
			local red = { r = 1, g = 0, b = 0 }
			assert.are.same(red, ns.db.colors.frostDamage)
			assert.are.same(red, Swatch("frostDamage").color)
			assert.are.same(red, PreviewColor("frostDamage"))
		end)

		it(
			"still restores the color when cancelled after the window was closed, without showing the preview",
			function()
				wow.colorPicker.rgb = { 1, 0, 0 }
				wow.colorPicker.info.swatchFunc()
				wow.env.StatsTrimmerOptionsFrame:Hide()
				wow.colorPicker.info.cancelFunc({ r = 0.2, g = 0.6, b = 1 })
				assert.are.same({ r = 0.2, g = 0.6, b = 1 }, ns.db.colors.frostDamage)
				assert.is_false(wow.env.StatsTrimmerPreviewTooltip:IsShown())
			end
		)

		it("restores the previous color when cancelled", function()
			wow.colorPicker.rgb = { 1, 0, 0 }
			wow.colorPicker.info.swatchFunc()
			wow.colorPicker.info.cancelFunc({ r = 0.2, g = 0.6, b = 1 })
			local previous = { r = 0.2, g = 0.6, b = 1 }
			assert.are.same(previous, ns.db.colors.frostDamage)
			assert.are.same(previous, Swatch("frostDamage").color)
			assert.are.same(previous, PreviewColor("frostDamage"))
		end)
	end)

	describe("resetting colors", function()
		before_each(function()
			ns.ShowOptions()
			ns.db.colors.spellPower = { r = 1, g = 0, b = 0 }
		end)

		it("resets one kind to its default, leaving the others", function()
			fakes.Fire(ResetButton("frostDamage"), "OnClick")
			assert.are.same(GREEN, ns.db.colors.frostDamage)
			assert.are.same(GREEN, PreviewColor("frostDamage"))
			assert.are.same({ r = 1, g = 0, b = 0 }, ns.db.colors.spellPower)
		end)

		it("resets every kind", function()
			fakes.Fire(fakes.FindFrames(wow, { text = "Reset all colors" })[1], "OnClick")
			for _, kind in ipairs(ns.COLOR_KINDS) do
				assert.are.same(GREEN, ns.db.colors[kind.key])
			end
		end)
	end)

	describe("original text key dropdown", function()
		before_each(function()
			ns.ShowOptions()
		end)

		it("offers Ctrl, Alt and Shift in that order", function()
			assert.are.same({ { "Ctrl", "CTRL" }, { "Alt", "ALT" }, { "Shift", "SHIFT" } }, wow.radioMenu.options)
		end)

		it("marks the saved key and saves a new choice", function()
			assert.is_true(wow.radioMenu.isSelected("CTRL"))
			assert.is_false(wow.radioMenu.isSelected("ALT"))
			wow.radioMenu.setSelected("ALT")
			assert.are.equal("ALT", ns.db.originalTextKey)
			assert.is_true(wow.radioMenu.isSelected("ALT"))
		end)
	end)
end)
