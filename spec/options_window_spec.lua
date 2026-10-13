-- OptionsWindow.lua: opening and closing, live color editing with preview, resets, the dropdowns, the spell
-- power checkbox and the client's own texts. The fake client is esES unless a test says otherwise.
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

	-- The color of a kind's sample line in the preview: one line per kind, after the item's three lines
	local function PreviewColor(key)
		local line = wow.env.StatsTrimmerPreviewTooltip.lines[3 + KindIndex(key)]
		return { r = line.r, g = line.g, b = line.b }
	end

	local function PreviewTexts()
		local texts = {}
		for _, line in ipairs(wow.env.StatsTrimmerPreviewTooltip.lines) do
			table.insert(texts, line.text)
		end
		return texts
	end

	local function HasText(text)
		return fakes.FindFrames(wow, { text = text })[1] ~= nil
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
			ns.db.colors.spellDamage = { r = 1, g = 0, b = 0 }
		end)

		it("resets one kind to its default, leaving the others", function()
			fakes.Fire(ResetButton("frostDamage"), "OnClick")
			assert.are.same(GREEN, ns.db.colors.frostDamage)
			assert.are.same(GREEN, PreviewColor("frostDamage"))
			assert.are.same({ r = 1, g = 0, b = 0 }, ns.db.colors.spellDamage)
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
				"+26 poder con hechizos",
				"+10 daño con hechizos",
				"+30 sanación con hechizos",
				"+12 daño arcano",
				"+12 daño de fuego",
				"+32 daño de escarcha",
				"+12 daño sagrado",
				"+12 daño de naturaleza",
				"+12 daño de las sombras",
				"+4 MP5",
				"+5 HP5",
				"+4 poder de ataque",
				"+6 poder de ataque contra bestias",
				"+3 defensa",
				"+1% bloquear",
				"+1% golpe",
			}, { unpack(texts, 4) })
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
				"+26 spell power",
				"+10 spell damage",
				"+30 spell healing",
				"+12 arcane damage",
				"+12 fire damage",
				"+32 frost damage",
				"+12 holy damage",
				"+12 nature damage",
				"+12 shadow damage",
				"+4 MP5",
				"+5 HP5",
				"+4 attack power",
				"+6 attack power vs beasts",
				"+3 defense",
				"+1% block",
				"+1% hit",
			}, { unpack(texts, 4) })
		end)

		it("rebuilds a shown item tooltip so it switches language right away", function()
			local tooltip = wow.env.GameTooltip
			fakes.ShowItem(wow, tooltip, wow.env.UIParent, "ANCHOR_NONE")
			LanguageMenu().setSelected("deDE")
			assert.are.equal(1, tooltip.refreshCount)
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
			assert.are.equal("+26 poder con hechizos", PreviewTexts()[4])
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
			assert.are.equal("Split spell power into spell damage and spell healing", Checkbox().Text.text)
			assert.is_false(Checkbox():GetChecked())
			assert.is_true(PreviewHas("+26 poder con hechizos"))
		end)

		it("splits spell power when checked, rebuilding the preview and a shown item tooltip", function()
			local tooltip = wow.env.GameTooltip
			fakes.ShowItem(wow, tooltip, wow.env.UIParent, "ANCHOR_NONE")
			ns.ShowOptions()
			fakes.ClickCheckButton(Checkbox())
			assert.is_true(ns.db.splitSpellPower)
			assert.is_false(PreviewHas("+26 poder con hechizos"))
			assert.are.equal("+10 daño con hechizos", PreviewTexts()[4])
			assert.are.equal(1, tooltip.refreshCount)
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
			assert.is_true(fakes.FindFrames(wow, { text = "Reset all colors" })[1].fitsText)
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
			}) do
				assert.is_true(HasText(label))
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
			assert.is_true(HasText("hit rating"))
			assert.is_true(HasText("attack power vs type"))
			assert.are.equal("+1% hit rating", PreviewTexts()[#PreviewTexts()])
		end)
	end)
end)
