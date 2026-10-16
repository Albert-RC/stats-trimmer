-- scripts/update-locales.ps1 on spec/fixtures/locales, a few rows of Forever's tables in each language (build
-- 1.60.1.70425, and 1.60.1.70338 for itIT). scripts/test-generators.ps1 runs it, then this spec reads what it
-- wrote. The expected texts are Blizzard's, written out here.
local dir = assert(os.getenv("STATS_TRIMMER_GENERATED"), "run scripts/test-generators.ps1")
local ns = {}
assert(loadfile(dir .. "/Locales.lua"))("StatsTrimmer", ns)
local client = assert(loadfile(dir .. "/ClientStrings-ruRU.lua"))()

-- One string in every bundled language
local function InEveryLanguage(name)
	local texts = {}
	for locale, strings in pairs(ns.LOCALE_STRINGS) do
		texts[locale] = strings[name]
	end
	return texts
end

describe("update-locales.ps1", function()
	it("bundles the languages with the Latin alphabet, in menu order", function()
		assert.are.same({ "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }, ns.LOCALES)
	end)

	it("names the experience from kills with the bonus buff's words, without its number", function()
		assert.are.same({
			enUS = "Experience gained from kills",
			deDE = "Durch Siege erhaltene Erfahrung",
			esES = "Experiencia obtenida al matar enemigos",
			esMX = "La experiencia que ganas por eliminar enemigos",
			frFR = "Expérience gagnée en tuant des adversaires",
			-- Forever's Italian description isn't translated
			itIT = "Experience gained from kills",
			ptBR = "Experiência obtida com abates",
		}, InEveryLanguage("KILL_EXPERIENCE"))
	end)

	it("names the Well Fed buff with its spell's name", function()
		assert.are.same({
			enUS = "Well Fed",
			deDE = "Satt",
			esES = "Bien alimentado",
			esMX = "Bien alimentado",
			frFR = "Bien nourri",
			itIT = "Ben Nutrito",
			ptBR = "Bem Alimentado",
		}, InEveryLanguage("WELL_FED"))
	end)

	it("bundles stat names and the window's strings, not the client's others", function()
		assert.are.same({ "Stamina", "Hit", "Reset" }, {
			ns.LOCALE_STRINGS.enUS.ITEM_MOD_STAMINA_SHORT,
			ns.LOCALE_STRINGS.enUS.ITEM_MOD_HIT_RATING_SHORT,
			ns.LOCALE_STRINGS.enUS.RESET,
		})
		assert.are.equal("Colori", ns.LOCALE_STRINGS.itIT.COLORS)
		assert.is_nil(ns.LOCALE_STRINGS.enUS.ITEM_SPELL_TRIGGER_ONEQUIP)
		assert.is_nil(ns.LOCALE_STRINGS.enUS.SECONDS_ABBR)
	end)

	it("bundles the classes' male names, with none for Italian, which Forever has no names for", function()
		assert.are.same({
			WARRIOR = "Guerrero",
			PALADIN = "Paladín",
			PRIEST = "Sacerdote",
			SHAMAN = "Chamán",
			DRUID = "Druida",
			ROGUE = "Pícaro",
			MAGE = "Mago",
			WARLOCK = "Brujo",
			HUNTER = "Cazador",
		}, ns.LOCALE_CLASS_NAMES.esES)
		assert.is_nil(ns.LOCALE_CLASS_NAMES.itIT)
	end)

	describe("for the fake ruRU client", function()
		it("writes the strings the client recognizes lines with, and the language names", function()
			local strings = client.strings
			assert.are.equal("Если на персонаже:", strings.ITEM_SPELL_TRIGGER_ONEQUIP)
			assert.are.equal("Использование:", strings.ITEM_SPELL_TRIGGER_ONUSE)
			assert.are.equal("(Восстановление: %s)", strings.ITEM_COOLDOWN_TOTAL)
			assert.are.equal("%d с.", strings.SECONDS_ABBR)
			assert.are.equal("Русский", strings.LFG_LIST_LANGUAGE_RURU)
			assert.are.equal("Урон от заклинаний", strings.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT)
			-- The client has no such text of its own
			assert.is_nil(client.strings.KILL_EXPERIENCE)
		end)

		it("writes the class names, the creature types and the Well Fed buff's name", function()
			assert.are.equal("Маг", client.classNames.MAGE)
			assert.are.same({ "Животное", "Нежить", "Механизм" }, {
				client.creatureTypes[1],
				client.creatureTypes[6],
				client.creatureTypes[9],
			})
			assert.are.equal("Сытость", client.wellFed)
		end)
	end)
end)
