-- OptionsWindow.lua: opening and closing, the tabs, live color editing with preview, resets, the dropdowns, the
-- spell power checkbox and the client's own texts. The fake client is esES unless a test says otherwise.
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
		return fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", text = "Reiniciar" })[KindIndex(key)]
	end

	-- The color of a kind's sample line in the preview: one line per kind, after the item's three lines, or for
	-- the food section's kinds after the food's name, in the food's tooltip
	local function PreviewColor(key)
		local itemIndex, foodIndex = 3, 1
		for _, kind in ipairs(ns.COLOR_KINDS) do
			local food = kind.group == "food"
			itemIndex = itemIndex + (food and 0 or 1)
			foodIndex = foodIndex + (food and 1 or 0)
			if kind.key == key then
				local line = food and wow.env.StatsTrimmerFoodPreviewTooltip.lines[foodIndex]
					or wow.env.StatsTrimmerPreviewTooltip.lines[itemIndex]
				return { r = line.r, g = line.g, b = line.b }
			end
		end
	end

	local function TooltipTexts(tooltip)
		local texts = {}
		for _, line in ipairs(tooltip.lines) do
			table.insert(texts, line.text)
		end
		return texts
	end

	local function PreviewTexts()
		return TooltipTexts(wow.env.StatsTrimmerPreviewTooltip)
	end

	local function FoodPreviewTexts()
		return TooltipTexts(wow.env.StatsTrimmerFoodPreviewTooltip)
	end

	-- Shows Bastón nudoso de nigromancia, with its combined spell power line, in GameTooltip
	local function ShowStaff()
		wow.items["item:staff"] = { ITEM_MOD_SPELL_POWER_SHORT = 26 }
		fakes.ShowItem(wow, wow.env.GameTooltip, wow.env.UIParent, "ANCHOR_NONE", {
			hyperlink = "item:staff",
			lines = {
				{
					leftText = "Equipar: Aumenta hasta 26 p. el daño infligido y la sanación realizada con hechizos y "
						.. "efectos mágicos.",
				},
			},
		})
	end

	local function HasText(text)
		return fakes.FindFrames(wow, { text = text })[1] ~= nil
	end

	-- A tab under the window, by its title
	local function Tab(title)
		return fakes.FindFrames(wow, { template = "PanelTabButtonTemplate", text = title })[1]
	end

	-- Clicks the second tab, food and drink, whatever the language
	local function ShowFoodTab()
		fakes.Fire(wow.env.StatsTrimmerOptionsFrame.Tabs[2], "OnClick", "LeftButton")
	end

	-- Whether a kind's row is shown: rows sit in their section's body
	local function RowShown(key)
		return Swatch(key):GetParent():IsShown()
	end

	-- The latest radio menu offering a value: menus are built again when the language changes
	local function LatestMenu(value)
		for index = #wow.radioMenus, 1, -1 do
			for _, option in ipairs(wow.radioMenus[index].options) do
				if option[2] == value then
					return wow.radioMenus[index]
				end
			end
		end
	end

	local function KeyMenu()
		return LatestMenu("CTRL")
	end

	local function LanguageMenu()
		return LatestMenu("CLIENT")
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
			assert.is_false(wow.env.StatsTrimmerFoodPreviewTooltip:IsShown())
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
			assert.are.same(GREEN, Swatch("spellDamage").color)
		end)

		it("previews every line kind in its color, in a sample item or a sample food", function()
			assert.are.equal("Sample Item", wow.env.StatsTrimmerPreviewTooltip.lines[1].text)
			assert.are.equal("Sample Food", wow.env.StatsTrimmerFoodPreviewTooltip.lines[1].text)
			for _, kind in ipairs(ns.COLOR_KINDS) do
				assert.are.same(ns.db.colors[kind.key], PreviewColor(kind.key))
			end
		end)

		it("shows the food tab's lines in a sample food, where the sample item was", function()
			ShowFoodTab()
			assert.are.same({
				"Sample Food",
				"+530 salud (24 s)",
				"+803 maná (24 s)",
				"+5% experiencia obtenida al matar enemigos",
				"+6 aguante (bien alimentado, 15 min)",
				"+6 intelecto (bien alimentado, 15 min)",
				"+6 fuerza (bien alimentado, 15 min)",
				"+6 agilidad (bien alimentado, 15 min)",
				"+6 espíritu (bien alimentado, 15 min)",
				"+150 armadura (bien alimentado, 15 min)",
			}, FoodPreviewTexts())
			local item, food = wow.env.StatsTrimmerPreviewTooltip, wow.env.StatsTrimmerFoodPreviewTooltip
			assert.is_true(food.points[1][2] == item.points[1][2])
			assert.are.same({ "TOPLEFT", "TOPLEFT", 12, -34 }, { food.points[1][1], unpack(food.points[1], 3) })
			assert.are.same({ "TOPLEFT", "TOPLEFT", 12, -34 }, { item.points[1][1], unpack(item.points[1], 3) })
			assert.are.equal("+12 daño de las sombras", PreviewTexts()[#PreviewTexts()])
		end)
	end)

	describe("tabs", function()
		before_each(function()
			ns.ShowOptions()
		end)

		it("are combat and food and drink, under the window, with Blizzard's names", function()
			local tabs = wow.env.StatsTrimmerOptionsFrame.Tabs
			assert.are.same({ "Combate", "Comida y bebida" }, { tabs[1].text, tabs[2].text })
			assert.are.equal(2, wow.env.StatsTrimmerOptionsFrame.numTabs)
			local point, relativeTo, relativePoint, x, y = unpack(tabs[1].points[1])
			assert.is_true(relativeTo == wow.env.StatsTrimmerOptionsFrame)
			assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 11, 2 }, { point, relativePoint, x, y })
			assert.are.equal("StatsTrimmerOptionsFrameTab2", tabs[2]:GetName())
		end)

		it("open on combat: its sections, the sample item and the spell power checkbox", function()
			assert.is_true(Tab("Combate").selected)
			assert.is_true(RowShown("frostDamage"))
			assert.is_false(RowShown("health"))
			assert.is_true(wow.env.StatsTrimmerPreviewTooltip:IsShown())
			assert.is_false(wow.env.StatsTrimmerFoodPreviewTooltip:IsShown())
			assert.is_true(fakes.FindFrames(wow, { template = "UICheckButtonTemplate" })[1]:IsShown())
		end)

		it("show food and drink's rows and the sample food, without the checkbox, with a click", function()
			ShowFoodTab()
			assert.is_true(Tab("Comida y bebida").selected)
			assert.is_false(Tab("Combate").selected)
			assert.is_false(RowShown("frostDamage"))
			assert.is_true(RowShown("health"))
			assert.is_false(wow.env.StatsTrimmerPreviewTooltip:IsShown())
			assert.is_true(wow.env.StatsTrimmerFoodPreviewTooltip:IsShown())
			assert.is_false(fakes.FindFrames(wow, { template = "UICheckButtonTemplate" })[1]:IsShown())
			assert.are.equal(wow.env.SOUNDKIT.IG_CHARACTER_INFO_TAB, wow.sounds[#wow.sounds])
		end)

		it("keep the window's size", function()
			local window = wow.env.StatsTrimmerOptionsFrame
			local width, height = window:GetWidth(), window:GetHeight()
			ShowFoodTab()
			assert.are.same({ width, height }, { window:GetWidth(), window:GetHeight() })
		end)

		it("open on the tab left open", function()
			ShowFoodTab()
			wow.env.StatsTrimmerOptionsFrame:Hide()
			ns.ShowOptions()
			assert.is_true(Tab("Comida y bebida").selected)
			assert.is_true(RowShown("health"))
		end)

		it("follow the language", function()
			LanguageMenu().setSelected("enUS")
			local tabs = wow.env.StatsTrimmerOptionsFrame.Tabs
			assert.are.same({ "Combat", "Food & Drink" }, { tabs[1].text, tabs[2].text })
			assert.are.equal(#"Food & Drink" * 6 + 20, tabs[2]:GetWidth())
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
			ns.db.colors.spellDamage = { r = 1, g = 0, b = 0 }
		end)

		it("resets one kind to its default, leaving the others", function()
			fakes.Fire(ResetButton("frostDamage"), "OnClick")
			assert.are.same(GREEN, ns.db.colors.frostDamage)
			assert.are.same(GREEN, PreviewColor("frostDamage"))
			assert.are.same({ r = 1, g = 0, b = 0 }, ns.db.colors.spellDamage)
		end)

		it("resets every kind of the shown tab only", function()
			ns.db.colors.health = { r = 1, g = 0, b = 0 }
			local resetShown = fakes.FindFrames(wow, { text = "Reset these colors" })[1]
			fakes.Fire(resetShown, "OnClick")
			for _, kind in ipairs(ns.COLOR_KINDS) do
				if kind.group ~= "food" then
					assert.are.same(GREEN, ns.db.colors[kind.key])
				end
			end
			assert.are.same({ r = 1, g = 0, b = 0 }, ns.db.colors.health)

			ShowFoodTab()
			fakes.Fire(resetShown, "OnClick")
			assert.are.same(GREEN, ns.db.colors.health)
		end)
	end)

	describe("color sections", function()
		-- A section's header, by its title
		local function Section(title)
			for _, header in ipairs(fakes.FindFrames(wow, { template = "ListHeaderThreeSliceTemplate" })) do
				if header.Name.text == title then
					return header
				end
			end
		end

		before_each(function()
			ns.ShowOptions()
		end)

		it("start expanded", function()
			for _, title in ipairs({ "Ataque", "Defensa", "Hechizos", "Daño extra" }) do
				assert.is_false(Section(title).collapsed)
				assert.is_true(Section(title):IsShown())
			end
			assert.is_true(RowShown("frostDamage"))
		end)

		it("collapse and expand with a click on their header, and remember it", function()
			fakes.Fire(Section("Hechizos"), "OnClick", "LeftButton")
			assert.is_true(Section("Hechizos").collapsed)
			assert.is_false(RowShown("spellDamage"))
			assert.is_true(RowShown("frostDamage"))
			assert.is_true(RowShown("attackPower"))
			assert.are.same({ spell = true }, ns.db.collapsedSections)

			fakes.Fire(Section("Hechizos"), "OnClick", "LeftButton")
			assert.is_false(Section("Hechizos").collapsed)
			assert.is_true(RowShown("spellDamage"))
			assert.are.same({}, ns.db.collapsedSections)
		end)

		it("leave a collapsed section's lines out of the preview", function()
			fakes.Fire(Section("Daño extra"), "OnClick", "LeftButton")
			local texts = PreviewTexts()
			assert.are.equal(3 + 7 + 6 + 8, #texts)
			assert.are.equal("+4 MP5", texts[#texts])
		end)

		it("have no header in a tab of their own, as the tab names them, and always show", function()
			ShowFoodTab()
			assert.is_false(Section("Comida y bebida"):IsShown())
			assert.is_true(RowShown("health"))
			assert.are.equal(10, #FoodPreviewTexts())
			-- Only sections of the combat tab hide when the food tab shows
			for _, title in ipairs({ "Ataque", "Defensa", "Hechizos", "Daño extra" }) do
				assert.is_false(Section(title):IsShown())
			end
		end)

		it("open collapsed when they were saved collapsed", function()
			wow = fakes.NewWoW()
			wow.env.StatsTrimmerDB = { collapsedSections = { spell = true } }
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.is_true(Section("Hechizos").collapsed)
			assert.is_false(RowShown("spellDamage"))
			assert.is_false(Section("Ataque").collapsed)
		end)
	end)

	describe("class color palette", function()
		local BASE_HEIGHT = 210

		-- The palette is the color picker's only child the addon makes
		local function Palette()
			return fakes.FindFrames(wow, { parent = wow.env.ColorPickerFrame })[1]
		end

		local function PaletteSwatches()
			return fakes.FindFrames(wow, { template = "ColorSwatchTemplate", parent = Palette() })
		end

		before_each(function()
			ns.ShowOptions()
			fakes.Fire(Swatch("frostDamage"), "OnClick")
		end)

		it("shows Forever's class colors in the color picker, in the game's order", function()
			assert.is_true(Palette():IsShown())
			local colors = {}
			for _, swatch in ipairs(PaletteSwatches()) do
				table.insert(colors, swatch.color)
			end
			assert.are.same({
				{ r = 0.8, g = 0.6, b = 0.4 },
				{ r = 1, g = 0.6, b = 0.8 },
				{ r = 1, g = 1, b = 1 },
				{ r = 0, g = 0.4, b = 0.8 },
				{ r = 1, g = 0.4, b = 0 },
				{ r = 1, g = 1, b = 0.4 },
				{ r = 0.2, g = 0.8, b = 1 },
				{ r = 0.6, g = 0.6, b = 1 },
				{ r = 0.6, g = 0.8, b = 0.4 },
			}, colors)
		end)

		it("names each class in its color on hover", function()
			local mage = PaletteSwatches()[7]
			fakes.Fire(mage, "OnEnter")
			assert.is_true(wow.env.GameTooltip:IsShown())
			assert.are.same({ { text = "Mago", r = 0.2, g = 0.8, b = 1 } }, wow.env.GameTooltip.lines)
			fakes.Fire(mage, "OnLeave")
			assert.is_false(wow.env.GameTooltip:IsShown())
		end)

		it("names the classes in the chosen language, in English where Blizzard has none for it", function()
			LanguageMenu().setSelected("deDE")
			fakes.Fire(PaletteSwatches()[1], "OnEnter")
			assert.are.equal("Krieger", wow.env.GameTooltip.text)
			-- Forever's Italian data has no class names
			LanguageMenu().setSelected("itIT")
			fakes.Fire(PaletteSwatches()[1], "OnEnter")
			assert.are.equal("Warrior", wow.env.GameTooltip.text)
		end)

		it("sets the picker to the clicked class color, which updates the row live", function()
			fakes.Fire(PaletteSwatches()[7], "OnClick")
			local mage = { r = 0.2, g = 0.8, b = 1 }
			assert.are.same({ 0.2, 0.8, 1 }, wow.colorPicker.rgb)
			assert.are.same(mage, ns.db.colors.frostDamage)
			assert.are.same(mage, Swatch("frostDamage").color)
			assert.are.same(mage, PreviewColor("frostDamage"))
		end)

		it("leaves the previous color when the picker is cancelled", function()
			fakes.Fire(PaletteSwatches()[7], "OnClick")
			wow.colorPicker.info.cancelFunc({ r = 0.2, g = 0.6, b = 1 })
			assert.are.same({ r = 0.2, g = 0.6, b = 1 }, ns.db.colors.frostDamage)
		end)

		it("makes the picker taller only while it shows", function()
			assert.is_true(wow.env.ColorPickerFrame:GetHeight() > BASE_HEIGHT)
			-- Another row opens the picker while it is still shown
			fakes.Fire(Swatch("spellDamage"), "OnClick")
			wow.env.ColorPickerFrame:Hide()
			assert.is_false(Palette():IsShown())
			assert.are.equal(BASE_HEIGHT, wow.env.ColorPickerFrame:GetHeight())
		end)

		it("stays while the picker only hides with UIParent (Alt+Z), still shown", function()
			fakes.Fire(wow.env.ColorPickerFrame, "OnHide")
			assert.is_true(Palette():IsShown())
			assert.is_true(wow.env.ColorPickerFrame:GetHeight() > BASE_HEIGHT)
		end)

		it("grows the picker once when another row opens it while it still shows", function()
			fakes.Fire(Swatch("spellDamage"), "OnClick")
			assert.is_true(Palette():IsShown())
			assert.are.equal(238, wow.env.ColorPickerFrame:GetHeight())
		end)

		it("isn't shown when another addon opens the picker", function()
			wow.env.ColorPickerFrame:Hide()
			wow.env.ColorPickerFrame:SetupColorPickerAndShow({ r = 1, g = 1, b = 1, swatchFunc = function() end })
			assert.is_false(Palette():IsShown())
			assert.are.equal(BASE_HEIGHT, wow.env.ColorPickerFrame:GetHeight())
		end)

		it("leaves for another addon's pick made while it shows, and comes back for the next row", function()
			-- The picker stays shown: no OnHide runs
			wow.env.ColorPickerFrame:SetupColorPickerAndShow({ r = 1, g = 1, b = 1, swatchFunc = function() end })
			assert.is_true(wow.env.ColorPickerFrame:IsShown())
			assert.is_false(Palette():IsShown())
			assert.are.equal(BASE_HEIGHT, wow.env.ColorPickerFrame:GetHeight())
			fakes.Fire(Swatch("spellDamage"), "OnClick")
			assert.is_true(Palette():IsShown())
			assert.are.equal(238, wow.env.ColorPickerFrame:GetHeight())
		end)

		it("is made once, however often the picker opens", function()
			wow.env.ColorPickerFrame:Hide()
			fakes.Fire(Swatch("spellDamage"), "OnClick")
			assert.is_true(Palette():IsShown())
			assert.are.equal(1, #fakes.FindFrames(wow, { parent = wow.env.ColorPickerFrame }))
			assert.are.equal(9, #PaletteSwatches())
		end)
	end)

	describe("size", function()
		local LANGUAGES = { "CLIENT", "enUS", "deDE", "esMX", "frFR", "itIT", "ptBR" }

		local function Window()
			return wow.env.StatsTrimmerOptionsFrame
		end

		local function ColorsPanel()
			return fakes.FindFrames(wow, { template = "InsetFrameTemplate" })[1]
		end

		-- The preview panel's width: the window's, without the colors panel, the window's sides (12 each) and
		-- the gap between the panels (8). The item's and the food's tooltips, which take turns in the same place,
		-- need it with a margin of 12 on each side.
		local function PreviewFits()
			local room = Window():GetWidth() - ColorsPanel():GetWidth() - 2 * 12 - 8
			local item, food = wow.env.StatsTrimmerPreviewTooltip, wow.env.StatsTrimmerFoodPreviewTooltip
			return math.max(item:GetWidth(), food:GetWidth()) + 2 * 12 <= room
		end

		-- A row label's room: the colors panel's width without the scroll frame's inset (6) and scroll bar (26),
		-- the swatch and its gaps (32), and the Reset button with its gaps (10). Rows sit in their section's body.
		local function LabelsFit()
			local panelWidth = ColorsPanel():GetWidth()
			local bodies = {}
			for _, kind in ipairs(ns.COLOR_KINDS) do
				bodies[Swatch(kind.key):GetParent()] = true
			end
			for _, region in ipairs(wow.frames) do
				if region.frameType == "FontString" and bodies[region.parent] then
					local reset =
						fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", parent = region.parent })[1]
					if region:GetUnboundedStringWidth() > panelWidth - 6 - 26 - 32 - 10 - reset:GetWidth() then
						return false
					end
				end
			end
			return true
		end

		before_each(function()
			ns.ShowOptions()
		end)

		it("fits the preview's longest line and every whole stat name, in every language", function()
			for _, language in ipairs(LANGUAGES) do
				LanguageMenu().setSelected(language)
				assert.is_true(PreviewFits())
				assert.is_true(LabelsFit())
			end
		end)

		it("grows for longer texts and narrows again when they go", function()
			local spanish = Window():GetWidth()
			-- The longest French line, "+5% expérience gagnée en tuant des adversaires", is the sample food's,
			-- which the window makes room for in either tab
			LanguageMenu().setSelected("frFR")
			local french = Window():GetWidth()
			assert.is_true(french > spanish)
			ShowFoodTab()
			assert.are.equal(french, Window():GetWidth())
			assert.is_true(PreviewFits())
			LanguageMenu().setSelected("CLIENT")
			assert.are.equal(spanish, Window():GetWidth())
		end)

		it("narrows when the section with the longest line collapses", function()
			-- Wider letters for the sample item's longest line, "+20 daño con hechizos contra no-muertos"
			ns.LOCALE_STRINGS.frFR.ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT =
				"Dégâts des sorts magiques et puissants contre les morts-vivants"
			LanguageMenu().setSelected("frFR")
			local wide = Window():GetWidth()
			for _, header in ipairs(fakes.FindFrames(wow, { template = "ListHeaderThreeSliceTemplate" })) do
				if header.Name.text == "Sorts" then
					fakes.Fire(header, "OnClick", "LeftButton")
				end
			end
			assert.is_true(Window():GetWidth() < wide)
			assert.is_true(PreviewFits())
		end)

		it("keeps its Spanish size with shorter texts: English, or sections collapsed", function()
			local width, height, colorsWidth = Window():GetWidth(), Window():GetHeight(), ColorsPanel():GetWidth()
			LanguageMenu().setSelected("enUS")
			assert.are.equal(width, Window():GetWidth())
			assert.are.equal(colorsWidth, ColorsPanel():GetWidth())
			LanguageMenu().setSelected("CLIENT")
			for _, header in ipairs(fakes.FindFrames(wow, { template = "ListHeaderThreeSliceTemplate" })) do
				fakes.Fire(header, "OnClick", "LeftButton")
			end
			assert.are.equal(width, Window():GetWidth())
			assert.are.equal(height, Window():GetHeight())
			assert.are.equal(colorsWidth, ColorsPanel():GetWidth())
		end)

		it("measures its Spanish size on any client, and keeps the client's own texts", function()
			local spanishWidth = Window():GetWidth()
			wow = fakes.NewWoW({ locale = "enUS" })
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.are.equal(spanishWidth, Window():GetWidth())
			assert.is_true(HasText("attack power"))
			assert.are.equal("+4 attack power", PreviewTexts()[4])
			local resets = fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", text = "Reset" })
			assert.are.equal(#ns.COLOR_KINDS, #resets)
		end)

		it("grows taller when the preview needs it, keeping it whole", function()
			wow = fakes.NewWoW()
			wow.textMetrics.lineHeight = 20
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			-- The preview panel is the window's height without 156 above it and 44 below; the tooltip starts 34
			-- below its top and keeps a margin of 12 below
			local room = Window():GetHeight() - 156 - 44
			assert.is_true(Window():GetHeight() > 690)
			assert.is_true(34 + wow.env.StatsTrimmerPreviewTooltip:GetHeight() + 12 <= room)
			-- And keeps that height, its Spanish one, with every section collapsed
			local height = Window():GetHeight()
			for _, header in ipairs(fakes.FindFrames(wow, { template = "ListHeaderThreeSliceTemplate" })) do
				fakes.Fire(header, "OnClick", "LeftButton")
			end
			assert.are.equal(height, Window():GetHeight())
		end)

		-- The frame and the tabs below it must both fit, and the screen clamp must cover every tab, which keeps them
		-- on screen when the window is dragged down. The fake doesn't clamp: the drag itself is checked in game.
		local function AssertWindowAndTabsFit()
			local window = Window()
			local bottomInset = select(4, window:GetClampRectInsets())
			local tabTop = window.Tabs[1].points[1][5]
			for _, tab in ipairs(window.Tabs) do
				assert.is_true(bottomInset <= tabTop - tab:GetHeight())
			end
			local scale = window:GetScale()
			assert.is_true((window:GetHeight() - bottomInset) * scale <= wow.env.UIParent:GetHeight() + 0.001)
			assert.is_true(window:GetWidth() * scale <= wow.env.UIParent:GetWidth() + 0.001)
		end

		it("scales down with its tabs on a screen too short for it", function()
			assert.are.equal(1, Window():GetScale())
			wow = fakes.NewWoW()
			-- A large UI scale
			wow.env.UIParent.height = 600
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.is_true(Window():GetHeight() > 600)
			AssertWindowAndTabsFit()
			ShowFoodTab()
			AssertWindowAndTabsFit()
		end)

		it("extends its screen clamp below the frame to cover its tabs", function()
			AssertWindowAndTabsFit()
		end)

		it("fits again when the UI scale or display size changes while open", function()
			for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
				for _, size in ipairs({ { 1365, 600 }, { 500, 768 }, { 1365, 768 } }) do
					wow.env.UIParent:SetSize(unpack(size))
					fakes.FireEvent(wow, event)
					AssertWindowAndTabsFit()
				end
				assert.are.equal(1, Window():GetScale())
			end
		end)
	end)

	describe("original text key dropdown", function()
		before_each(function()
			ns.ShowOptions()
		end)

		it("offers Ctrl, Alt and Shift in that order, with the client's key names", function()
			assert.are.same({ { "Control", "CTRL" }, { "Alt", "ALT" }, { "Mayús", "SHIFT" } }, KeyMenu().options)
		end)

		it("marks the saved key and saves a new choice", function()
			assert.is_true(KeyMenu().isSelected("CTRL"))
			assert.is_false(KeyMenu().isSelected("ALT"))
			KeyMenu().setSelected("ALT")
			assert.are.equal("ALT", ns.db.originalTextKey)
			assert.is_true(KeyMenu().isSelected("ALT"))
		end)
	end)

	describe("language dropdown", function()
		before_each(function()
			ns.ShowOptions()
		end)

		it("offers the client's language first, then the bundled ones, the client's by default", function()
			assert.are.same({
				{ "Español", "CLIENT" },
				{ "Inglés", "enUS" },
				{ "Alemán", "deDE" },
				{ "Español (México)", "esMX" },
				{ "Francés", "frFR" },
				{ "Italiano", "itIT" },
				{ "Portugués", "ptBR" },
			}, LanguageMenu().options)
			assert.is_true(LanguageMenu().isSelected("CLIENT"))
			assert.is_false(LanguageMenu().isSelected("enUS"))
		end)

		it("marks the client's entry when the client's own language is saved by name", function()
			ns.db.language = "esES"
			assert.is_true(LanguageMenu().isSelected("CLIENT"))
		end)

		it("shows Blizzard's names in the client's language by default, lowercased", function()
			local texts = PreviewTexts()
			assert.are.same({ "Sample Item", "Se liga al equiparlo", "+5 aguante" }, { texts[1], texts[2], texts[3] })
			assert.are.same({
				"+4 poder de ataque",
				"+6 poder de ataque contra bestias",
				"+12 poder de ataque a distancia",
				"+30 poder de ataque bajo forma",
				"+1% golpe",
				"+1% golpe crítico",
				"+7 habilidad con espadas",
				"+3 defensa",
				"+1% esquivar",
				"+1% parar",
				"+1% bloquear",
				"+15 valor de bloqueo",
				"+5 HP5",
				"+26 poder con hechizos",
				"+10 daño con hechizos",
				"+30 sanación con hechizos",
				"+20 daño con hechizos contra no-muertos",
				"+1% golpe (hechizo)",
				"+1% golpe crítico (hechizo)",
				"+10 perforación de hechizo",
				"+4 MP5",
				"+12 daño arcano",
				"+12 daño de fuego",
				"+32 daño de escarcha",
				"+12 daño sagrado",
				"+12 daño de naturaleza",
				"+12 daño de las sombras",
			}, { unpack(texts, 4) })
		end)

		it("shows the food's details with Blizzard's words, the Well Fed buff's name lowercased", function()
			LanguageMenu().setSelected("deDE")
			assert.are.same({
				"+530 gesundheit (24 sek.)",
				"+803 mana (24 sek.)",
				"+5% durch siege erhaltene erfahrung",
				"+6 ausdauer (satt, 15 min.)",
			}, { unpack(FoodPreviewTexts(), 2, 5) })
		end)

		it("switches every Blizzard text to the chosen language at once", function()
			LanguageMenu().setSelected("enUS")
			assert.are.equal("enUS", ns.db.language)
			assert.is_true(HasText("Colors"))
			assert.is_true(HasText("Preview"))
			assert.is_false(HasText("Colores"))
			local resets = fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", text = "Reset" })
			assert.are.equal(#ns.COLOR_KINDS, #resets)
			assert.are.same(
				{ { "CTRL key", "CTRL" }, { "ALT key", "ALT" }, { "SHIFT key", "SHIFT" } },
				KeyMenu().options
			)
			for _, label in ipairs({
				"spell power",
				"spell damage",
				"spell healing",
				"MP5",
				"attack power vs …",
				"hit",
			}) do
				assert.is_true(HasText(label))
			end
			local texts = PreviewTexts()
			assert.are.same({ "Sample Item", "Binds when equipped", "+5 Stamina" }, { texts[1], texts[2], texts[3] })
			assert.are.same({
				"+4 attack power",
				"+6 attack power vs beasts",
				"+12 ranged attack power",
				"+30 attack power in forms",
				"+1% hit",
				"+1% critical strike",
				"+7 swords skill",
				"+3 defense",
				"+1% dodge",
				"+1% parry",
				"+1% block",
				"+15 block value",
				"+5 HP5",
				"+26 spell power",
				"+10 spell damage",
				"+30 spell healing",
				"+20 spell damage vs undead",
				"+1% hit (spell)",
				"+1% critical strike (spell)",
				"+10 spell piercing",
				"+4 MP5",
				"+12 arcane damage",
				"+12 fire damage",
				"+32 frost damage",
				"+12 holy damage",
				"+12 nature damage",
				"+12 shadow damage",
			}, { unpack(texts, 4) })
			assert.are.same({
				"Sample Food",
				"+530 health (24 sec)",
				"+803 mana (24 sec)",
				"+5% experience gained from kills",
				"+6 stamina (well fed, 15 min)",
				"+6 intellect (well fed, 15 min)",
				"+6 strength (well fed, 15 min)",
				"+6 agility (well fed, 15 min)",
				"+6 spirit (well fed, 15 min)",
				"+150 armor (well fed, 15 min)",
			}, FoodPreviewTexts())
		end)

		it("rebuilds a shown item tooltip so it switches language right away", function()
			ShowStaff()
			assert.are.same({ "+26 poder con hechizos" }, TooltipTexts(wow.env.GameTooltip))
			LanguageMenu().setSelected("deDE")
			assert.are.same({ "+26 zaubermacht" }, TooltipTexts(wow.env.GameTooltip))
		end)

		it("offers only English besides the client's language on a client without the Latin alphabet", function()
			wow = fakes.NewWoW()
			wow.env.GetLocale = function()
				return "ruRU"
			end
			wow.env.LocaleUtil.GetLocaleDisplayName = function(locale)
				return locale
			end
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.are.same({ { "ruRU", "CLIENT" }, { "enUS", "enUS" } }, LanguageMenu().options)
		end)

		it("marks the client's entry for a saved language the client's font can't show", function()
			-- Saved on another client; the fake client's own strings stay esES
			wow = fakes.NewWoW()
			wow.env.GetLocale = function()
				return "ruRU"
			end
			wow.env.StatsTrimmerDB = { language = "deDE" }
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.is_true(LanguageMenu().isSelected("CLIENT"))
			assert.are.equal("+26 poder con hechizos", PreviewTexts()[3 + KindIndex("spellPower")])
		end)
	end)

	describe("spell power checkbox", function()
		local function Checkbox()
			return fakes.FindFrames(wow, { template = "UICheckButtonTemplate" })[1]
		end

		local function PreviewHas(text)
			for _, shown in ipairs(PreviewTexts()) do
				if shown == text then
					return true
				end
			end
			return false
		end

		it("starts unchecked, with spell power as its own line in the preview", function()
			ns.ShowOptions()
			assert.are.equal(
				"Split spell power into spell damage and spell healing when both values are the same",
				Checkbox().Text.text
			)
			assert.is_false(Checkbox():GetChecked())
			assert.is_true(PreviewHas("+26 poder con hechizos"))
		end)

		it("splits spell power when checked, rebuilding the preview and a shown item tooltip", function()
			ShowStaff()
			ns.ShowOptions()
			fakes.ClickCheckButton(Checkbox())
			assert.is_true(ns.db.splitSpellPower)
			assert.is_false(PreviewHas("+26 poder con hechizos"))
			-- Spell damage takes spell power's place
			assert.are.equal("+10 daño con hechizos", PreviewTexts()[3 + KindIndex("spellPower")])
			assert.are.same(
				{ "+26 daño con hechizos", "+26 sanación con hechizos" },
				TooltipTexts(wow.env.GameTooltip)
			)
		end)

		it("shows spell power as its own line again when unchecked", function()
			ns.ShowOptions()
			fakes.ClickCheckButton(Checkbox())
			fakes.ClickCheckButton(Checkbox())
			assert.is_false(ns.db.splitSpellPower)
			assert.is_true(PreviewHas("+26 poder con hechizos"))
		end)

		it("shows the saved setting when opened", function()
			wow = fakes.NewWoW()
			wow.env.StatsTrimmerDB = { splitSpellPower = true }
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			assert.is_true(Checkbox():GetChecked())
			assert.is_false(PreviewHas("+26 poder con hechizos"))
		end)
	end)

	describe("texts", function()
		it("come from the client where it has them", function()
			ns.ShowOptions()
			assert.is_true(HasText("Colores"))
			assert.is_true(HasText("Vista previa"))
			local resets = fakes.FindFrames(wow, { template = "UIPanelButtonTemplate", text = "Reiniciar" })
			assert.are.equal(#ns.COLOR_KINDS, #resets)
			assert.is_true(resets[1].fitsText)
			assert.is_true(fakes.FindFrames(wow, { text = "Reset these colors" })[1].fitsText)
		end)

		it("label the color rows with Blizzard's names in lowercase, MP5 and HP5 as they are", function()
			ns.ShowOptions()
			for _, label in ipairs({
				"poder con hechizos",
				"daño con hechizos",
				"sanación con hechizos",
				"daño de escarcha",
				"MP5",
				"HP5",
				"poder de ataque",
				"poder de ataque contra …",
				"defensa",
				"bloquear",
				"golpe",
				"poder de ataque a distancia",
				"poder de ataque bajo forma",
				"golpe crítico",
				"habilidades con las armas",
				"esquivar",
				"parar",
				"valor de bloqueo",
				"daño con hechizos contra …",
				"golpe (hechizo)",
				"golpe crítico (hechizo)",
				"perforación de hechizo",
				"salud",
				"maná",
				"experiencia",
				"aguante",
				"intelecto",
				"fuerza",
				"agilidad",
				"espíritu",
				"armadura",
			}) do
				assert.is_true(HasText(label))
			end
		end)

		it("title the color sections with Blizzard's names, in the chosen language", function()
			ns.ShowOptions()
			for _, title in ipairs({ "Ataque", "Defensa", "Hechizos", "Daño extra", "Comida y bebida" }) do
				assert.is_true(HasText(title))
			end
			LanguageMenu().setSelected("enUS")
			for _, title in ipairs({ "Attack", "Defense", "Spells", "Damage extra", "Food & Drink" }) do
				assert.is_true(HasText(title))
			end
		end)

		it("come from Blizzard's English when the client lacks them", function()
			wow = fakes.NewWoW({ locale = "enUS" })
			ns = helpers.StartStatsTrimmer(wow)
			ns.ShowOptions()
			for _, text in ipairs({ "Colors", "Preview", "Reset", "spell damage", "MP5", "hit" }) do
				assert.is_true(HasText(text))
			end
			assert.are.same(
				{ { "CTRL key", "CTRL" }, { "ALT key", "ALT" }, { "SHIFT key", "SHIFT" } },
				KeyMenu().options
			)
			assert.are.same({ "Sample Item", "Binds when equipped", "+5 Stamina" }, { unpack(PreviewTexts(), 1, 3) })
		end)

		it("fall back to the addon's own English when Blizzard lacks them too", function()
			wow = fakes.NewWoW({ locale = "enUS" })
			ns = helpers.StartStatsTrimmer(wow)
			ns.LOCALE_STRINGS.enUS.ITEM_MOD_HIT_RATING_SHORT = nil
			ns.LOCALE_STRINGS.enUS.ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = nil
			ns.ShowOptions()
			assert.is_true(HasText("hit"))
			assert.is_true(HasText("attack power vs type"))
			assert.are.equal("+1% hit rating", PreviewTexts()[3 + KindIndex("hitRating")])
		end)
	end)
end)
