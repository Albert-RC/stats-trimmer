-- Tooltip.lua: how equip lines are swapped in real tooltips, their colors and the original-text key
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

-- Cosedora, as seen on the esES client
local COSEDORA_LINE = "Equipar: Aumenta hasta 30 p. la sanación realizada y hasta 10 p. el daño infligido "
	.. "con todos los hechizos y efectos mágicos."
local COSEDORA_STATS = {
	ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30,
	ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10,
	ITEM_MOD_STAMINA_SHORT = 3,
}
local CRIT_LINE = "Equipar: Mejora tu probabilidad de conseguir un golpe crítico un 1%."

-- The tooltip glue with settings loaded, as it runs after ADDON_LOADED. Returns the world, the addon
-- namespace and the registered line pre-call. `prepare(wow)` can change the world before the addon loads;
-- `locale` is the client's (esES by default).
local function Setup(prepare, locale)
	local wow = fakes.NewWoW({ locale = locale })
	if prepare then
		prepare(wow)
	end
	local ns = helpers.LoadAddon(
		"StatsTrimmer",
		{ "Util.lua", "Config.lua", "Locales.lua", "FoodData.lua", "Rules.lua", "FoodRules.lua", "Tooltip.lua" },
		wow.env
	)
	ns.db = ns.LoadSettings(nil)
	wow.items["item:cosedora"] = COSEDORA_STATS
	wow.items["item:crit"] = { ITEM_MOD_CRIT_RATING_SHORT = 14 }
	return wow, ns, wow.preCalls[1].handler
end

-- Runs the pre-call on one line of an item tooltip; returns whether the line was consumed and the lines
-- the addon added
local function ProcessLine(wow, preCall, text, data, leftColor)
	local tooltip = fakes.ItemTooltip(wow, data or { hyperlink = "item:cosedora" })
	local consumed = preCall(tooltip, { leftText = text, leftColor = leftColor or fakes.Color(0, 1, 0) })
	return consumed, tooltip.lines
end

describe("Tooltip line pre-call", function()
	local wow, ns, preCall

	before_each(function()
		wow, ns, preCall = Setup()
	end)

	it("is registered for None lines, which is how Forever sends equip lines, and Use lines", function()
		assert.are.equal(2, #wow.preCalls)
		assert.are.equal(wow.env.Enum.TooltipDataLineType.None, wow.preCalls[1].lineType)
		assert.are.equal(wow.env.Enum.TooltipDataLineType.ItemSpellTriggerOnUse, wow.preCalls[2].lineType)
	end)

	it("replaces an equip line with compact lines in the saved colors", function()
		ns.db.colors.spellDamage = { r = 1, g = 0.5, b = 0 }
		ns.db.colors.spellHealing = { r = 0, g = 0.5, b = 1 }
		local consumed, lines = ProcessLine(wow, preCall, COSEDORA_LINE)
		assert.is_true(consumed)
		assert.are.same({
			{ text = "+10 daño con hechizos", r = 1, g = 0.5, b = 0 },
			{ text = "+30 sanación con hechizos", r = 0, g = 0.5, b = 1 },
		}, lines)
	end)

	describe("combined spell power (Bastón nudoso de nigromancia)", function()
		local text = "Equipar: Aumenta hasta 26 p. el daño infligido y la sanación realizada "
			.. "con hechizos y efectos mágicos."

		before_each(function()
			wow.items["item:baston"] = { ITEM_MOD_SPELL_POWER_SHORT = 26, ITEM_MOD_SPIRIT_SHORT = 10 }
			ns.db.colors.spellPower = { r = 1, g = 0, b = 1 }
			ns.db.colors.spellDamage = { r = 1, g = 0.5, b = 0 }
			ns.db.colors.spellHealing = { r = 0, g = 0.5, b = 1 }
		end)

		it("shows as one line in its own color by default", function()
			local _, lines = ProcessLine(wow, preCall, text, { hyperlink = "item:baston" })
			assert.are.same({ { text = "+26 poder con hechizos", r = 1, g = 0, b = 1 } }, lines)
		end)

		it("shows as spell damage and healing lines in their colors when the setting splits it", function()
			ns.db.splitSpellPower = true
			local _, lines = ProcessLine(wow, preCall, text, { hyperlink = "item:baston" })
			assert.are.same({
				{ text = "+26 daño con hechizos", r = 1, g = 0.5, b = 0 },
				{ text = "+26 sanación con hechizos", r = 0, g = 0.5, b = 1 },
			}, lines)
		end)
	end)

	describe("language", function()
		local function Texts(text, data)
			local _, lines = ProcessLine(wow, preCall, text, data)
			local texts = {}
			for _, line in ipairs(lines) do
				table.insert(texts, line.text)
			end
			return texts
		end

		it("is the client's by default, with Blizzard's names in lowercase", function()
			assert.are.equal("CLIENT", ns.db.language)
			assert.are.same({ "+10 daño con hechizos", "+30 sanación con hechizos" }, Texts(COSEDORA_LINE))
		end)

		it("can be another one, without the client's", function()
			ns.db.language = "enUS"
			assert.are.same({ "+10 spell damage", "+30 spell healing" }, Texts(COSEDORA_LINE))
			ns.db.language = "deDE"
			assert.are.same({ "+10 zauberschaden", "+30 zauberheilung" }, Texts(COSEDORA_LINE))
		end)

		it("uses the client's strings when it is saved as the client's own language", function()
			ns.db.language = "esES"
			assert.are.same({ "+10 daño con hechizos", "+30 sanación con hechizos" }, Texts(COSEDORA_LINE))
		end)

		it("uses the client's strings for a saved language the client's font can't show", function()
			-- Saved on another client; the fake client's own strings stay esES
			wow.env.GetLocale = function()
				return "ruRU"
			end
			ns.db.language = "deDE"
			assert.are.same({ "+10 daño con hechizos", "+30 sanación con hechizos" }, Texts(COSEDORA_LINE))
			assert.are.equal("deDE", ns.db.language)
		end)

		it("leaves MP5 as it is in every language", function()
			wow.items["item:mp5"] = { ITEM_MOD_MANA_REGENERATION_SHORT = 4 }
			local mp5 = "Equipar: Restaura 4 p. de maná cada 5 s."
			assert.are.same({ "+4 MP5" }, Texts(mp5, { hyperlink = "item:mp5" }))
			ns.db.language = "frFR"
			assert.are.same({ "+4 MP5" }, Texts(mp5, { hyperlink = "item:mp5" }))
		end)

		it("falls back to Blizzard's English, not the addon's, for a name the client lacks", function()
			wow.env.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = nil
			assert.are.same({ "+10 spell damage", "+30 sanación con hechizos" }, Texts(COSEDORA_LINE))
		end)

		it("falls back to Blizzard's English for a name the language gets wrong", function()
			-- The esES client calls spell damage vs beasts "Daño con hechizos contra mecánicos"
			wow.items["item:vsbeasts"] = { ITEM_MOD_SPELL_DAMAGE_VS_BEAST_SHORT = 15 }
			local text = "Equipar: Aumenta hasta 15 p. el daño infligido a bestias con hechizos y efectos mágicos."
			assert.are.same({ "+15 spell damage vs beasts" }, Texts(text, { hyperlink = "item:vsbeasts" }))
		end)
	end)

	it("lowercases the stat names itself when the client's lowercase returns nothing", function()
		wow, ns, preCall = Setup(function(world)
			world.env.C_Intl.ToLower = function() end
		end)
		local _, lines = ProcessLine(wow, preCall, COSEDORA_LINE)
		assert.are.equal("+10 daño con hechizos", lines[1].text)
	end)

	it("folds the case itself when the client's case folding returns nothing", function()
		wow, ns, preCall = Setup(function(world)
			world.env.C_Intl.FoldCase = function() end
		end)
		wow.items["item:nudillos"] = { ITEM_MOD_ATTACK_POWER_SHORT = 6, ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6 }
		local lines = {
			{ leftText = "Equipar: +6 p. de poder de ataque." },
			{ leftText = "Equipar: +6 p. de poder de ataque contra Bestias." },
		}
		local data = { hyperlink = "item:nudillos", lines = lines }
		local _, plain = ProcessLine(wow, preCall, lines[1].leftText, data)
		local _, vsBeasts = ProcessLine(wow, preCall, lines[2].leftText, data)
		assert.are.equal("+6 poder de ataque", plain[1].text)
		assert.are.equal("+6 poder de ataque contra bestias", vsBeasts[1].text)
	end)

	it("colors crit lines with their own saved color", function()
		ns.db.colors.critRating = { r = 1, g = 0.5, b = 0 }
		local _, lines = ProcessLine(wow, preCall, CRIT_LINE, { hyperlink = "item:crit" }, fakes.Color(0.1, 0.9, 0.2))
		assert.are.same({ { text = "+1% golpe crítico", r = 1, g = 0.5, b = 0 } }, lines)
	end)

	it("uses the normal font color before the saved settings are loaded, when the line has none", function()
		ns.db = nil
		local tooltip = fakes.ItemTooltip(wow, { hyperlink = "item:crit" })
		preCall(tooltip, { leftText = CRIT_LINE })
		assert.are.same({ { text = "+1% golpe crítico", r = 1, g = 0.82, b = 0 } }, tooltip.lines)
	end)

	it("finds the item through its GUID when there is one", function()
		wow.guids["Item-1"] = "item:cosedora"
		local consumed = ProcessLine(wow, preCall, COSEDORA_LINE, { guid = "Item-1" })
		assert.is_true(consumed)
	end)

	it("tells attack power vs beasts apart with the client's creature type names (Nudillos de hueso)", function()
		wow.items["item:nudillos"] = { ITEM_MOD_ATTACK_POWER_SHORT = 6, ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6 }
		local lines = {
			{ leftText = "Equipar: +6 p. de poder de ataque." },
			{ leftText = "Equipar: +6 p. de poder de ataque contra bestias." },
		}
		local data = { hyperlink = "item:nudillos", lines = lines }
		local _, plain = ProcessLine(wow, preCall, lines[1].leftText, data)
		local _, vsBeasts = ProcessLine(wow, preCall, lines[2].leftText, data)
		assert.are.equal("+6 poder de ataque", plain[1].text)
		assert.are.equal("+6 poder de ataque contra bestias", vsBeasts[1].text)
	end)

	it("doesn't read the item's lines whose text is a secret", function()
		-- Without the vs line, nothing tells the plain line apart from it
		wow.items["item:nudillos"] = { ITEM_MOD_ATTACK_POWER_SHORT = 6, ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6 }
		local lines = {
			{ leftText = "Equipar: +6 p. de poder de ataque." },
			{ leftText = "Equipar: +6 p. de poder de ataque contra bestias." },
		}
		wow.secretTexts[lines[2].leftText] = true
		local consumed = ProcessLine(wow, preCall, lines[1].leftText, { hyperlink = "item:nudillos", lines = lines })
		assert.is_false(consumed)
	end)

	it("removes the extra lines of weapon skills that share a number", function()
		wow.items["item:edgemaster"] =
			{ ITEM_MOD_AXES_SHORT = 7, ITEM_MOD_DAGGERS_SHORT = 7, ITEM_MOD_SWORDS_SHORT = 7 }
		local lines = {
			{ leftText = "Equipar: Habilidad con hachas aumentada +7." },
			{ leftText = "Equipar: Habilidad con dagas aumentada +7." },
			{ leftText = "Equipar: Habilidad con espadas aumentada +7." },
		}
		local data = { hyperlink = "item:edgemaster", lines = lines }
		local consumed, added = ProcessLine(wow, preCall, lines[2].leftText, data)
		assert.is_true(consumed)
		assert.are.same({}, added)
	end)

	it("already works before the saved settings are loaded, in the line's own color", function()
		ns.db = nil
		local _, lines = ProcessLine(wow, preCall, COSEDORA_LINE, nil, fakes.Color(0, 1, 0))
		assert.are.same({ text = "+10 daño con hechizos", r = 0, g = 1, b = 0 }, lines[1])
	end)

	describe("leaves the line alone", function()
		local function AssertUntouched(consumed, lines)
			assert.is_false(consumed)
			assert.are.same({}, lines)
		end

		it("when it isn't an equip line", function()
			AssertUntouched(ProcessLine(wow, preCall, "+3 aguante"))
		end)

		it("when the tooltip isn't an item's", function()
			AssertUntouched(ProcessLine(wow, preCall, COSEDORA_LINE, { type = wow.env.Enum.TooltipDataType.Unit }))
		end)

		it("when the item has no stats", function()
			AssertUntouched(ProcessLine(wow, preCall, COSEDORA_LINE, { hyperlink = "item:unknown" }))
		end)

		it("when no rule recognizes it", function()
			AssertUntouched(ProcessLine(wow, preCall, "Equipar: Permite respirar bajo el agua."))
		end)

		it("when its text is a secret", function()
			wow.secretTexts[COSEDORA_LINE] = true
			AssertUntouched(ProcessLine(wow, preCall, COSEDORA_LINE))
		end)

		it("when it shows more than one percentage", function()
			local text = "Equipar: Mejora tu probabilidad de conseguir un golpe crítico un 1% y tu velocidad de "
				.. "movimiento un 8%."
			AssertUntouched(ProcessLine(wow, preCall, text, { hyperlink = "item:crit" }))
		end)

		it("when more than one stat could own it", function()
			wow.items["item:regen"] = { ITEM_MOD_MANA_REGENERATION_SHORT = 4, ITEM_MOD_HEALTH_REGEN_SHORT = 4 }
			local lines = {
				{ leftText = "Equipar: Restaura 4 p. de maná cada 5 s." },
				{ leftText = "Equipar: Restaura 4 p. de salud cada 5 s." },
			}
			local data = { hyperlink = "item:regen", lines = lines }
			AssertUntouched(ProcessLine(wow, preCall, lines[1].leftText, data))
		end)
	end)

	describe("original text key", function()
		it("shows the original line while the chosen key is held", function()
			wow.keysDown.CTRL = true
			local consumed, lines = ProcessLine(wow, preCall, COSEDORA_LINE)
			assert.is_false(consumed)
			assert.are.same({}, lines)
		end)

		it("keeps replacing while another modifier is held", function()
			wow.keysDown.SHIFT = true
			assert.is_true((ProcessLine(wow, preCall, COSEDORA_LINE)))
		end)

		it("follows the key chosen in the settings", function()
			ns.db.originalTextKey = "ALT"
			wow.keysDown.CTRL = true
			assert.is_true((ProcessLine(wow, preCall, COSEDORA_LINE)))
			wow.keysDown.ALT = true
			assert.is_false((ProcessLine(wow, preCall, COSEDORA_LINE)))
		end)
	end)
end)

describe("Food Use lines", function()
	-- Spongy Morel and Longjaw Mud Snapper on the esES client, from their spells' esES descriptions. Longjaw's well
	-- fed part isn't translated.
	local MOREL_LINE = "Usar: Restaura 530 p. de salud durante 24 s. Debes permanecer sentado mientras comes."
	local SNAPPER_LINE = "Usar: Restaura 530 p. de salud durante 24 s. Debes permanecer sentado mientras comes. If you "
		.. "spend at least 10 sec eating, you will become well fed and gain 10 Attack Power for 15 min. Además, la "
		.. "experiencia obtenida al matar enemigos aumenta un 5%. (1 |4s:s; de tiempo de reutilización)."
	local MOREL_SPELL, SNAPPER_SPELL = 435, 1249506
	local wow, ns, preCall

	local function UseLine(text, spellID)
		return {
			leftText = text,
			leftColor = fakes.Color(0, 1, 0),
			type = wow.env.Enum.TooltipDataLineType.ItemSpellTriggerOnUse,
			spellID = spellID,
		}
	end

	-- Runs the Use line pre-call on a food's line; returns whether it was consumed and the lines the addon added
	local function ProcessUseLine(text, spellID, tooltip)
		tooltip = tooltip or fakes.ItemTooltip(wow, { hyperlink = "item:food" })
		local consumed = preCall(tooltip, UseLine(text, spellID))
		return consumed, tooltip.lines
	end

	local function Texts(text, spellID)
		local texts = {}
		for _, line in ipairs(select(2, ProcessUseLine(text, spellID))) do
			table.insert(texts, line.text)
		end
		return texts
	end

	before_each(function()
		wow, ns = Setup()
		preCall = wow.preCalls[2].handler
	end)

	it("replaces a food's Use line with compact lines in the saved colors", function()
		ns.db.colors.health = { r = 1, g = 0, b = 0 }
		ns.db.colors.attackPower = { r = 0, g = 0, b = 1 }
		ns.db.colors.experience = { r = 1, g = 1, b = 0 }
		local consumed, lines = ProcessUseLine(SNAPPER_LINE, SNAPPER_SPELL)
		assert.is_true(consumed)
		assert.are.same({
			{ text = "+530 salud (24 s)", r = 1, g = 0, b = 0 },
			{ text = "+10 poder de ataque (bien alimentado, 15 min)", r = 0, g = 0, b = 1 },
			{ text = "+5% experiencia obtenida al matar enemigos", r = 1, g = 1, b = 0 },
		}, lines)
	end)

	it("follows the language setting", function()
		ns.db.language = "enUS"
		assert.are.same(
			{ "+530 health (24 sec)", "+10 attack power (well fed, 15 min)", "+5% experience gained from kills" },
			Texts(SNAPPER_LINE, SNAPPER_SPELL)
		)
	end)

	it("names the Well Fed buff as the client does", function()
		wow.spellNames[19705] = "Bien Nutrido"
		assert.are.equal("+10 poder de ataque (bien nutrido, 15 min)", Texts(SNAPPER_LINE, SNAPPER_SPELL)[2])
	end)

	it("shows a line in Blizzard's English when the client lacks the Well Fed buff's name", function()
		wow.spellNames[19705] = nil
		assert.are.same(
			{ "+530 salud (24 s)", "+10 attack power (well fed, 15 min)", "+5% experiencia obtenida al matar enemigos" },
			Texts(SNAPPER_LINE, SNAPPER_SPELL)
		)
	end)

	it("is replaced in the item tooltips the client builds, by the Use line pre-call only", function()
		fakes.ShowItem(wow, wow.env.GameTooltip, wow.env.UIParent, "ANCHOR_NONE", {
			lines = { { leftText = "Colmenilla esponjosa" }, UseLine(MOREL_LINE, MOREL_SPELL) },
		})
		local texts = {}
		for _, line in ipairs(wow.env.GameTooltip.lines) do
			table.insert(texts, line.text)
		end
		assert.are.same({ "Colmenilla esponjosa", "+530 salud (24 s)" }, texts)
	end)

	describe("leaves the line alone", function()
		local function AssertUntouched(consumed, lines)
			assert.is_false(consumed)
			assert.are.same({}, lines)
		end

		it("when its spell isn't a food's", function()
			AssertUntouched(ProcessUseLine("Usar: Te devuelve a Molino Tarren.", 8690))
		end)

		it("when it doesn't show what its food's spell does", function()
			AssertUntouched(ProcessUseLine(MOREL_LINE, SNAPPER_SPELL))
		end)

		it("when its spell ID is a secret", function()
			wow.secretTexts[MOREL_SPELL] = true
			AssertUntouched(ProcessUseLine(MOREL_LINE, MOREL_SPELL))
		end)

		it("when its text is a secret", function()
			wow.secretTexts[MOREL_LINE] = true
			AssertUntouched(ProcessUseLine(MOREL_LINE, MOREL_SPELL))
		end)

		it("when another addon only reads it", function()
			local tooltip = fakes.ItemTooltip(wow, { hyperlink = "item:food" })
			tooltip:SetOwner(wow.env.UIParent, "ANCHOR_NONE")
			AssertUntouched(ProcessUseLine(MOREL_LINE, MOREL_SPELL, tooltip))
		end)

		it("while the original text key is held", function()
			wow.keysDown.CTRL = true
			AssertUntouched(ProcessUseLine(MOREL_LINE, MOREL_SPELL))
		end)

		it("when its cooldown is a minute, not the second foods share", function()
			AssertUntouched(ProcessUseLine(MOREL_LINE .. " (1 |4min:min; de tiempo de reutilización).", MOREL_SPELL))
		end)

		it("when it has a cooldown and the client has no text for seconds", function()
			wow.env.SECONDS_ABBR = nil
			AssertUntouched(ProcessUseLine(SNAPPER_LINE, SNAPPER_SPELL))
		end)
	end)

	it("rebuilds another addon's own tooltip with a food line through its owner when the key changes", function()
		local ownTooltip =
			wow.env.CreateFrame("GameTooltip", "AtlasLootTooltip", wow.env.UIParent, "GameTooltipTemplate")
		local button = wow.env.CreateFrame("Button")
		button.mouseOver = true
		button:SetScript("OnEnter", function(self)
			fakes.ShowItem(wow, ownTooltip, self, "ANCHOR_RIGHT", { lines = { UseLine(MOREL_LINE, MOREL_SPELL) } })
		end)
		fakes.Fire(button, "OnEnter")
		assert.are.equal("+530 salud (24 s)", ownTooltip.lines[1].text)
		wow.keysDown.CTRL = true
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		assert.are.equal(MOREL_LINE, ownTooltip.lines[1].text)
	end)
end)

describe("On a client whose language isn't bundled (ruRU)", function()
	local wow, preCall

	local function Texts(lines)
		local texts = {}
		for _, line in ipairs(lines) do
			table.insert(texts, line.text)
		end
		return texts
	end

	before_each(function()
		local _
		wow, _, preCall = Setup(nil, "ruRU")
	end)

	it("recognizes equip lines and names their stats with the client's own names", function()
		local text =
			"Если на персонаже: Увеличивает исцеление от заклинаний на 30 ед. и урон от них на 10 ед."
		local consumed, lines = ProcessLine(wow, preCall, text)
		assert.is_true(consumed)
		assert.are.same(
			{ "+10 урон от заклинаний", "+30 магическое лечение" },
			Texts(lines)
		)
	end)

	it("tells attack power vs beasts apart with the client's creature type names", function()
		wow.items["item:nudillos"] = { ITEM_MOD_ATTACK_POWER_SHORT = 6, ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = 6 }
		local lines = {
			{ leftText = "Если на персонаже: +6 к силе атаки." },
			{
				leftText = "Если на персонаже: +6 к силе атаки в бою с животными.",
			},
		}
		local data = { hyperlink = "item:nudillos", lines = lines }
		assert.are.same(
			{ "+6 к силе атаки" },
			Texts(select(2, ProcessLine(wow, preCall, lines[1].leftText, data)))
		)
		assert.are.same(
			{ "+6 сила атаки в бою с животными" },
			Texts(select(2, ProcessLine(wow, preCall, lines[2].leftText, data)))
		)
	end)

	describe("food", function()
		-- Longjaw Mud Snapper, from its spell's ruRU description, with the client's cooldown text
		local SNAPPER = "Использование: Восполняет 530 ед. здоровья за 24 сек. Действие прерывается, если встать с "
			.. "места. По истечении 10 секунд персонаж насыщается, и его сила атаки увеличивается на 10 на 15 мин. "
			.. "Кроме того, количество опыта, получаемого за убийство противников, увеличивается на 5%."

		local function ProcessUseLine(text)
			local tooltip = fakes.ItemTooltip(wow, { hyperlink = "item:food" })
			local consumed = wow.preCalls[2].handler(tooltip, {
				leftText = text,
				leftColor = fakes.Color(0, 1, 0),
				type = wow.env.Enum.TooltipDataLineType.ItemSpellTriggerOnUse,
				spellID = 1249506,
			})
			return consumed, Texts(tooltip.lines)
		end

		it("drops the shared cooldown, written without a plural escape, and uses the client's words", function()
			local consumed, texts = ProcessUseLine(SNAPPER .. " (Восстановление: 1 с.)")
			assert.is_true(consumed)
			-- The client has no words of its own for the experience from kills: Blizzard's English names it
			assert.are.same({
				"+530 здоровье (24 сек)",
				"+10 к силе атаки (сытость, 15 мин)",
				"+5% experience gained from kills",
			}, texts)
		end)

		it("keeps a line whose cooldown is a minute", function()
			assert.is_false((ProcessUseLine(SNAPPER .. " (Восстановление: 1 мин.)")))
		end)
	end)
end)

describe("Tooltips other addons fill", function()
	local COMPACT = { "+10 daño con hechizos", "+30 sanación con hechizos" }
	local wow

	-- Fills a tooltip with Cosedora the way addons do (SetOwner, then SetHyperlink); returns the texts shown
	local function ShowCosedora(tooltip, owner, anchorType)
		fakes.ShowItem(wow, tooltip, owner, anchorType, {
			hyperlink = "item:cosedora",
			lines = { { leftText = COSEDORA_LINE } },
		})
		local texts = {}
		for _, line in ipairs(tooltip.lines) do
			table.insert(texts, line.text)
		end
		return texts
	end

	local function NewTooltip(name)
		return wow.env.CreateFrame("GameTooltip", name, wow.env.UIParent, "GameTooltipTemplate")
	end

	before_each(function()
		wow = Setup()
	end)

	it("get compact lines when shown next to the hovered button (AtlasLoot)", function()
		local button = wow.env.CreateFrame("Button")
		assert.are.same(COMPACT, ShowCosedora(NewTooltip("AtlasLootTooltip"), button, "ANCHOR_RIGHT"))
	end)

	it("get compact lines when the addon places them itself (the Dungeon Journal's comparisons)", function()
		local row = wow.env.CreateFrame("Button")
		local tooltip = NewTooltip("ForeverDungeonJournalCompareTooltip1")
		assert.are.same(COMPACT, ShowCosedora(tooltip, row, "ANCHOR_NONE"))
	end)

	it("get compact lines when they follow the cursor", function()
		assert.are.same(COMPACT, ShowCosedora(NewTooltip(), wow.env.UIParent, "ANCHOR_CURSOR"))
	end)

	it("keep the original text when they are only filled to read the item", function()
		assert.are.same({ COSEDORA_LINE }, ShowCosedora(NewTooltip(), wow.env.UIParent, "ANCHOR_NONE"))
		assert.are.same({ COSEDORA_LINE }, ShowCosedora(NewTooltip(), wow.env.WorldFrame, "ANCHOR_NONE"))
		assert.are.same({ COSEDORA_LINE }, ShowCosedora(NewTooltip(), nil, nil))
	end)

	it("get compact lines in Blizzard's item tooltips, whatever their owner and anchor", function()
		-- The Dungeon Journal shows items in GameTooltip; default-anchored tooltips are owned by UIParent
		for _, name in ipairs({
			"GameTooltip",
			"ItemRefTooltip",
			"ShoppingTooltip1",
			"ShoppingTooltip2",
			"ItemRefShoppingTooltip1",
			"ItemRefShoppingTooltip2",
		}) do
			assert.are.same(COMPACT, ShowCosedora(wow.env[name], wow.env.UIParent, "ANCHOR_NONE"))
		end
	end)
end)

describe("Tooltip refresh on modifier changes", function()
	local wow, ns

	-- Shows a tooltip of the given data type, built from its data like the client does
	local function ShowTooltip(tooltip, dataType)
		fakes.ShowItem(wow, tooltip, wow.env.UIParent, "ANCHOR_NONE", { type = dataType })
	end

	before_each(function()
		wow, ns = Setup()
		ShowTooltip(wow.env.GameTooltip, wow.env.Enum.TooltipDataType.Item)
		ShowTooltip(wow.env.ItemRefTooltip, wow.env.Enum.TooltipDataType.Item)
	end)

	it("rebuilds shown item tooltips when either side of the chosen key changes", function()
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "RCTRL", 0)
		assert.are.equal(2, wow.env.GameTooltip.refreshCount)
		assert.are.equal(2, wow.env.ItemRefTooltip.refreshCount)
	end)

	it("leaves hidden tooltips and tooltips that aren't an item's alone", function()
		wow.env.GameTooltip.shown = false
		ShowTooltip(wow.env.ItemRefTooltip, wow.env.Enum.TooltipDataType.Unit)
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		assert.are.equal(0, wow.env.GameTooltip.refreshCount)
		assert.are.equal(0, wow.env.ItemRefTooltip.refreshCount)
	end)

	it("rebuilds Blizzard's tooltips once, though they showed equip lines too", function()
		fakes.ShowItem(wow, wow.env.ItemRefTooltip, wow.env.UIParent, "ANCHOR_PRESERVE", {
			hyperlink = "item:cosedora",
			lines = { { leftText = COSEDORA_LINE } },
		})
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		assert.are.equal(1, wow.env.ItemRefTooltip.refreshCount)
	end)

	it("doesn't run the owner of Blizzard's other item tooltips, which would taint it", function()
		-- A Blizzard UI widget shows its item in EmbeddedItemTooltip from OnEnter
		local widget = wow.env.CreateFrame("Frame")
		widget.mouseOver = true
		widget:SetScript("OnEnter", function(self)
			fakes.ShowItem(wow, wow.env.EmbeddedItemTooltip, self, "ANCHOR_RIGHT", {
				hyperlink = "item:cosedora",
				lines = { { leftText = COSEDORA_LINE } },
			})
		end)
		fakes.Fire(widget, "OnEnter")
		wow.keysDown.CTRL = true
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		assert.are.same({}, wow.executedScripts)
	end)

	describe("in another addon's own tooltip", function()
		local button, ownTooltip, compareTooltip

		local function Texts(tooltip)
			local texts = {}
			for _, line in ipairs(tooltip.lines) do
				table.insert(texts, line.text)
			end
			return texts
		end

		local function ShowCosedora(tooltip, owner)
			fakes.ShowItem(wow, tooltip, owner, "ANCHOR_RIGHT", {
				hyperlink = "item:cosedora",
				lines = { { leftText = COSEDORA_LINE } },
			})
		end

		-- Like AtlasLoot with its useGameTooltip setting off: OnEnter fills its own tooltip, adds a line of
		-- its own, and can show its own comparison tooltip too
		before_each(function()
			local function NewTooltip(name)
				return wow.env.CreateFrame("GameTooltip", name, wow.env.UIParent, "GameTooltipTemplate")
			end
			ownTooltip = NewTooltip("AtlasLootTooltip")
			compareTooltip = NewTooltip("AtlasLootCompareTooltip")
			button = wow.env.CreateFrame("Button")
			button.enterCount = 0
			button:SetScript("OnEnter", function(self)
				self.enterCount = self.enterCount + 1
				ShowCosedora(ownTooltip, self)
				ownTooltip:AddLine("Probabilidad de botín: 5%")
				if self.compares then
					ShowCosedora(compareTooltip, self)
				end
			end)
			button.mouseOver = true
		end)

		it("rebuilds it through its owner too", function()
			fakes.Fire(button, "OnEnter")
			wow.keysDown.CTRL = true
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.same({ COSEDORA_LINE, "Probabilidad de botín: 5%" }, Texts(ownTooltip))
			assert.are.equal(2, button.enterCount)
		end)

		it("runs an owner once when it shows several of those tooltips", function()
			button.compares = true
			fakes.Fire(button, "OnEnter")
			wow.keysDown.CTRL = true
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.same({ COSEDORA_LINE }, Texts(compareTooltip))
			assert.are.equal(2, button.enterCount)
		end)
	end)

	describe("with lines another addon added after the item's data", function()
		local button

		local function Texts()
			local texts = {}
			for _, line in ipairs(wow.env.GameTooltip.lines) do
				table.insert(texts, line.text)
			end
			return texts
		end

		-- Like AtlasLoot's item buttons: OnEnter fills GameTooltip, then adds a line of its own
		before_each(function()
			button = wow.env.CreateFrame("Button")
			button.enterCount = 0
			button:SetScript("OnEnter", function(self)
				self.enterCount = self.enterCount + 1
				fakes.ShowItem(wow, wow.env.GameTooltip, self, "ANCHOR_RIGHT", {
					hyperlink = "item:cosedora",
					lines = { { leftText = COSEDORA_LINE } },
				})
				wow.env.GameTooltip:AddLine("Probabilidad de botín: 5%")
			end)
			button.mouseOver = true
			fakes.Fire(button, "OnEnter")
		end)

		it("rebuilds it through its owner, as when the mouse enters it again, keeping those lines", function()
			wow.keysDown.CTRL = true
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.same({ COSEDORA_LINE, "Probabilidad de botín: 5%" }, Texts())

			wow.keysDown.CTRL = nil
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 0)
			assert.are.same(
				{ "+10 daño con hechizos", "+30 sanación con hechizos", "Probabilidad de botín: 5%" },
				Texts()
			)
			assert.are.equal(3, button.enterCount)
			assert.are.equal(0, wow.env.GameTooltip.refreshCount)
		end)

		it("leaves it alone when the mouse has left its owner", function()
			button.mouseOver = false
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.equal(1, button.enterCount)
			assert.are.equal(0, wow.env.GameTooltip.refreshCount)
		end)

		it("leaves it alone when its owner rebuilds it by itself, like Blizzard's item buttons", function()
			button.UpdateTooltip = function() end
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.equal(1, button.enterCount)
		end)

		it("leaves it alone when its owner is protected", function()
			button.protected = true
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.equal(1, button.enterCount)
		end)

		it("leaves it alone when its owner doesn't show it from OnEnter", function()
			button:SetScript("OnEnter", nil)
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.same({}, wow.executedScripts)
			assert.are.equal(0, wow.env.GameTooltip.refreshCount)
		end)

		it("rebuilds it from its data again once nothing is added after it", function()
			ShowTooltip(wow.env.GameTooltip, wow.env.Enum.TooltipDataType.Item)
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.equal(1, button.enterCount)
			assert.are.equal(1, wow.env.GameTooltip.refreshCount)
		end)
	end)

	describe("built only from the item's data", function()
		local COMPACT = { "+10 daño con hechizos", "+30 sanación con hechizos" }

		local function Texts()
			local texts = {}
			for _, line in ipairs(wow.env.GameTooltip.lines) do
				table.insert(texts, line.text)
			end
			return texts
		end

		local function ShowCosedora()
			fakes.ShowItem(wow, wow.env.GameTooltip, wow.env.UIParent, "ANCHOR_NONE", {
				hyperlink = "item:cosedora",
				lines = { { leftText = COSEDORA_LINE } },
			})
		end

		-- Holds the chosen key, then releases it, checking the texts shown at each step
		local function AssertSwitches(compact, original)
			assert.are.same(compact, Texts())
			wow.keysDown.CTRL = true
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
			assert.are.same(original, Texts())
			wow.keysDown.CTRL = nil
			fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 0)
			assert.are.same(compact, Texts())
		end

		it("shows the original text while the key is held, and the compact lines again once released", function()
			ShowCosedora()
			AssertSwitches(COMPACT, { COSEDORA_LINE })
		end)

		it("switches the item data appended after it too", function()
			ShowCosedora()
			fakes.AppendItem(
				wow,
				wow.env.GameTooltip,
				{ hyperlink = "item:crit", lines = { { leftText = CRIT_LINE } } }
			)
			AssertSwitches({ COMPACT[1], COMPACT[2], "+1% golpe crítico" }, { COSEDORA_LINE, CRIT_LINE })
		end)

		it("keeps the lines another addon's tooltip post-call adds (GearQuest's score)", function()
			wow.env.TooltipDataProcessor.AddTooltipPostCall(wow.env.Enum.TooltipDataType.Item, function(tooltip)
				tooltip:AddLine("Puntuación de GearQuest: 42")
			end)
			ShowCosedora()
			AssertSwitches(
				{ COMPACT[1], COMPACT[2], "Puntuación de GearQuest: 42" },
				{ COSEDORA_LINE, "Puntuación de GearQuest: 42" }
			)
			assert.are.same({}, wow.executedScripts)
		end)
	end)

	it("ignores other modifiers", function()
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		assert.are.equal(0, wow.env.GameTooltip.refreshCount)
	end)

	it("does nothing before the saved settings are loaded", function()
		ns.db = nil
		fakes.FireEvent(wow, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
		assert.are.equal(0, wow.env.GameTooltip.refreshCount)
	end)
end)
