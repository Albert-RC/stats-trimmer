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
-- namespace and the registered line pre-call. `prepare(wow)` can change the world before the addon loads.
local function Setup(prepare)
	local wow = fakes.NewWoW()
	if prepare then
		prepare(wow)
	end
	local ns = helpers.LoadAddon(
		"StatsTrimmer",
		{ "Util.lua", "Config.lua", "Locales.lua", "Rules.lua", "Tooltip.lua" },
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

	it("is registered for None lines, which is how Forever sends equip lines", function()
		assert.are.equal(1, #wow.preCalls)
		assert.are.equal(wow.env.Enum.TooltipDataLineType.None, wow.preCalls[1].lineType)
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
