-- A small fake of the WoW API pieces Stats Trimmer uses. It records what the addon does (scripts, events,
-- tooltip lines, colors, positions, registrations) so specs can assert on observable behavior.
-- fakes.NewWoW() returns a fresh, independent world; load addon files into `wow.env` with helpers.LoadAddon.
local fakes = {}

local Frame = {}
local FrameMeta = { __index = Frame }

-- Methods specs don't care about (layout, strata, textures...) exist but do nothing. The list is explicit,
-- so a misspelled WoW method fails the specs instead of being silently ignored.
local function NoOp() end
for _, name in ipairs({
	"EnableMouse",
	"Raise",
	"RegisterForClicks",
	"RegisterForDrag",
	"SetClampedToScreen",
	"SetFontObject",
	"SetFrameLevel",
	"SetHighlightTexture",
	"SetJustifyH",
	"SetMovable",
	"SetPortraitToAsset",
	"SetTexCoord",
	"SetTexture",
	"SetTitle",
	"SetToplevel",
	"SetWordWrap",
	"StartMoving",
	"StopMovingOrSizing",
}) do
	Frame[name] = NoOp
end

-- Text metrics: every character is this wide, every tooltip line this tall, and a tooltip has this padding.
-- A world can change them in wow.textMetrics.
fakes.TEXT_METRICS = { charWidth = 6, lineHeight = 14, tooltipPadding = 20 }

-- Characters in a UTF-8 text, not bytes
local function Length(text)
	return select(2, tostring(text or ""):gsub("[^\128-\191]", ""))
end

-- Runs a frame's script handler, like the client does; returns what the handler returns
function fakes.Fire(frame, scriptName, ...)
	local handler = frame.scripts[scriptName]
	if handler then
		return handler(frame, ...)
	end
end

-- Clicks a check button like the user does: the client toggles it before running OnClick
function fakes.ClickCheckButton(button)
	button:SetChecked(not button:GetChecked())
	return fakes.Fire(button, "OnClick", "LeftButton", true)
end

-- Sends an event to every frame registered for it
function fakes.FireEvent(wow, event, ...)
	for _, frame in ipairs(wow.frames) do
		if frame.events[event] then
			fakes.Fire(frame, "OnEvent", event, ...)
		end
	end
end

-- Blizzard's strings for a language, as the generated Locales.lua bundles them. For esES they match the
-- client exactly (checked against an in-game dump), so the fake esES client uses them as its globals.
function fakes.LocaleStrings(locale)
	local ns = {}
	assert(loadfile("StatsTrimmer/Locales.lua"))("StatsTrimmer", ns)
	return ns.LOCALE_STRINGS[locale]
end

-- Folded capitals besides ASCII that the specs use; string.lower leaves them as they are
local FOLDED_CAPITALS = { ["É"] = "é", ["Ж"] = "ж", ["Н"] = "н", ["С"] = "с" }

-- Like C_Intl.FoldCase for the letters the specs use
function fakes.FoldCase(text)
	local folded = text:lower()
	for capital, small in pairs(FOLDED_CAPITALS) do
		folded = folded:gsub(capital, small)
	end
	return folded
end

-- A color object with the ColorMixin method the addon uses
function fakes.Color(r, g, b)
	return {
		r = r,
		g = g,
		b = b,
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
	}
end

-- Class colors chosen to be exact in hex (the game's own are close to these)
fakes.CLASS_COLORS = {
	WARRIOR = { 0.8, 0.6, 0.4 },
	PALADIN = { 1, 0.6, 0.8 },
	PRIEST = { 1, 1, 1 },
	SHAMAN = { 0, 0.4, 0.8 },
	DRUID = { 1, 0.4, 0 },
	ROGUE = { 1, 1, 0.4 },
	MAGE = { 0.2, 0.8, 1 },
	WARLOCK = { 0.6, 0.6, 1 },
	HUNTER = { 0.6, 0.8, 0.4 },
}

function Frame:SetScript(name, handler)
	self.scripts[name] = handler
end

function Frame:GetScript(name)
	return self.scripts[name]
end

-- Like the client: the hook runs after the frame's own handler, if it has one
function Frame:HookScript(name, hook)
	local handler = self.scripts[name]
	self.scripts[name] = function(...)
		if handler then
			handler(...)
		end
		hook(...)
	end
end

function Frame:RegisterEvent(event)
	self.events[event] = true
end

function Frame:UnregisterEvent(event)
	self.events[event] = nil
end

function Frame:Show()
	if not self.shown then
		self.shown = true
		fakes.Fire(self, "OnShow")
	end
end

function Frame:Hide()
	if self.shown then
		self.shown = false
		fakes.Fire(self, "OnHide")
	end
end

function Frame:IsShown()
	return self.shown
end

function Frame:SetShown(shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end

-- Set frame.protected or frame.mouseOver to change these
function Frame:IsProtected()
	return self.protected == true, false
end

function Frame:IsMouseOver()
	return self.mouseOver == true
end

function Frame:GetName()
	return self.name
end

function Frame:SetID(id)
	self.id = id
end

function Frame:GetID()
	return self.id or 0
end

function Frame:GetParent()
	return self.parent
end

function Frame:SetParent(parent)
	self.parent = parent
end

-- On a tooltip, SetText starts it again with one line, in the given color
function Frame:SetText(text, r, g, b)
	self.text = text
	if self.lines then
		self.lines = { { text = text, r = r, g = g, b = b } }
	end
end

function Frame:GetText()
	return self.text
end

-- CheckButton methods
function Frame:SetChecked(checked)
	self.checked = checked == true
end

function Frame:GetChecked()
	return self.checked == true
end

-- UIButtonFitToTextBehaviorMixin: sizes the button to its text and padding. It only widens it unless
-- fitTextCanWidthDecrease is set, as UIPanelButtonTemplate does.
function Frame:SetTextToFit(text)
	self:SetText(text)
	self.fitsText = true
	local minWidth = self.fitTextCanWidthDecrease and 0 or (self.width or 0)
	local textWidth = Length(text) * self.wow.textMetrics.charWidth + (self.fitTextWidthPadding or 0)
	self.width = math.max(minWidth, textWidth)
end

-- FontString: the text's width without truncation
function Frame:GetUnboundedStringWidth()
	return Length(self.text) * self.wow.textMetrics.charWidth
end

function Frame:SetColorRGB(r, g, b)
	self.color = { r = r, g = g, b = b }
end

function Frame:SetPoint(...)
	table.insert(self.points, { ... })
end

function Frame:ClearAllPoints()
	self.points = {}
end

function Frame:SetFrameStrata(strata)
	self.strata = strata
end

function Frame:GetFrameStrata()
	return self.strata
end

function Frame.GetFrameLevel()
	return 1
end

function Frame:SetSize(width, height)
	self.width, self.height = width, height
end

function Frame:SetWidth(width)
	self.width = width
end

function Frame:SetHeight(height)
	self.height = height
end

-- A tooltip is as wide as its longest line and as tall as its lines, plus padding
function Frame:GetWidth()
	if self.frameType == "GameTooltip" then
		local longest = 0
		for _, line in ipairs(self.lines) do
			longest = math.max(longest, Length(line.text))
		end
		return longest * self.wow.textMetrics.charWidth + self.wow.textMetrics.tooltipPadding
	end
	return self.width
end

function Frame:GetHeight()
	if self.frameType == "GameTooltip" then
		return #self.lines * self.wow.textMetrics.lineHeight + self.wow.textMetrics.tooltipPadding
	end
	return self.height
end

-- ListHeaderThreeSliceTemplate: a click runs the handler, like ListHeaderMixin:OnClick
function Frame:SetClickHandler(handler)
	self.scripts.OnClick = handler
end

function Frame:UpdateCollapsedState(collapsed)
	self.collapsed = collapsed
end

function Frame:GetCenter()
	return self.centerX, self.centerY
end

function Frame:GetEffectiveScale()
	return self.scale
end

function Frame:SetScale(scale)
	self.scale = scale
end

function Frame:GetScale()
	return self.scale or 1
end

function Frame:SetClampRectInsets(left, right, top, bottom)
	self.clampRectInsets = { left, right, top, bottom }
end

function Frame:GetClampRectInsets()
	return unpack(self.clampRectInsets or { 0, 0, 0, 0 })
end

-- ScrollFrame
function Frame:SetScrollChild(child)
	self.scrollChild = child
end

function Frame:CreateFontString()
	return fakes.NewFrame(self.wow, "FontString", nil, self)
end

function Frame:CreateTexture()
	return fakes.NewFrame(self.wow, "Texture", nil, self)
end

-- GameTooltip methods: lines are recorded as { text, r, g, b }
function Frame:SetOwner(owner, anchorType)
	self.owner = owner
	self.anchorType = anchorType
	self.lines = {}
end

function Frame:GetOwner()
	return self.owner
end

function Frame:GetAnchorType()
	return self.anchorType
end

function Frame:ClearLines()
	self.lines = {}
end

function Frame:AddLine(text, r, g, b)
	table.insert(self.lines, { text = text, r = r, g = g, b = b })
end

function Frame:NumLines()
	return #self.lines
end

-- Like TooltipDataHandlerMixin:ProcessInfo, which every SetX method (SetHyperlink, SetBagItem...) calls:
-- builds the tooltip from the info's data, where the line pre-calls for each line's type can consume it, then
-- runs the tooltip post-calls for the data's type and shows it. Lines without a type are None lines. An info
-- starts the tooltip again, unless it is appended (info.append, as Blizzard's comparison tooltips do): its
-- lines then follow the ones there. Either way it joins the tooltip's infos, which RefreshData processes again.
function Frame:ProcessInfo(info)
	if not info.append then
		self.infoList = {}
		self.lines = {}
	elseif not self.infoList then
		self.infoList = {}
	end
	table.insert(self.infoList, info)
	self.processingInfo = info
	for _, lineData in ipairs(info.tooltipData.lines or {}) do
		local consumed = false
		local lineType = lineData.type or self.wow.env.Enum.TooltipDataLineType.None
		for _, preCall in ipairs(self.wow.preCalls) do
			consumed = preCall.lineType == lineType and preCall.handler(self, lineData)
			if consumed then
				break
			end
		end
		if not consumed then
			local color = lineData.leftColor or self.wow.env.NORMAL_FONT_COLOR
			self:AddLine(lineData.leftText, color:GetRGB())
		end
	end
	for _, postCall in ipairs(self.wow.postCalls) do
		if postCall.tooltipType == info.tooltipData.type then
			postCall.handler(self, info.tooltipData)
		end
	end
	self:Show()
	return true
end

function Frame:GetProcessingTooltipInfo()
	return self.processingInfo
end

-- Like TooltipDataHandlerMixin:IsTooltipType, it checks the primary info, the first one, not the one being
-- processed
function Frame:IsTooltipType(tooltipType)
	local primary = self.infoList and self.infoList[1]
	local data = primary and primary.tooltipData
	return data ~= nil and data.type == tooltipType
end

-- Like GameTooltipDataMixin:RefreshData (TooltipDataHandlerMixin:RebuildFromTooltipInfo): processes the tooltip's
-- infos again, in order, the first one starting it over. Lines added with AddLine after them are lost; the
-- post-calls' run again. Counts the rebuilds in refreshCount.
function Frame:RefreshData()
	self.refreshCount = self.refreshCount + 1
	local infoList = self.infoList
	if not (infoList and infoList[1]) then
		return
	end
	self.infoList = {}
	for index, info in ipairs(infoList) do
		if index == 1 then
			info.append = false
		end
		self:ProcessInfo(info)
	end
end

-- Like CreateFrame: named frames also become globals of the world's environment, and "$parent" in a name is the
-- parent's name
function fakes.NewFrame(wow, frameType, name, parent, template)
	if name and parent and parent.name then
		name = name:gsub("%$parent", parent.name)
	end
	local frame = setmetatable({
		wow = wow,
		frameType = frameType,
		name = name,
		parent = parent,
		template = template,
		scripts = {},
		events = {},
		points = {},
		shown = frameType ~= "GameTooltip",
		refreshCount = 0,
	}, FrameMeta)
	if frameType == "GameTooltip" then
		frame.lines = {}
	end
	if template == "PortraitFrameTemplate" then
		frame.CloseButton = fakes.NewFrame(wow, "Button", nil, frame, "UIPanelCloseButton")
	elseif template == "UICheckButtonTemplate" then
		frame.Text = fakes.NewFrame(wow, "FontString", nil, frame)
	elseif template == "ListHeaderThreeSliceTemplate" then
		frame.Name = fakes.NewFrame(wow, "FontString", nil, frame)
	elseif template == "UIPanelButtonTemplate" then
		-- From UIPanelButtonNoTooltipTemplate's KeyValues
		frame.fitTextCanWidthDecrease = true
	elseif template == "PanelTabButtonTemplate" then
		-- The template's height and parentArray
		frame.height = 32
		parent.Tabs = parent.Tabs or {}
		table.insert(parent.Tabs, frame)
	end
	table.insert(wow.frames, frame)
	if name then
		wow.env[name] = frame
	end
	return frame
end

-- A shown tooltip whose data is being processed, as the line pre-calls see it: another addon's tooltip
-- next to the hovered button. `data` is the tooltip data: { type, hyperlink, guid, lines }; type defaults
-- to an item.
function fakes.ItemTooltip(wow, data)
	local tooltip = fakes.NewFrame(wow, "GameTooltip")
	tooltip:SetOwner(fakes.NewFrame(wow, "Button"), "ANCHOR_RIGHT")
	data.type = data.type or wow.env.Enum.TooltipDataType.Item
	data.lines = data.lines or {}
	tooltip.processingInfo = { tooltipData = data }
	tooltip.infoList = { tooltip.processingInfo }
	tooltip.shown = true
	return tooltip
end

-- Fills a tooltip from item data the way the client does: an owner and anchor first, then SetHyperlink
-- (ProcessInfo). `data` defaults to an item without lines.
function fakes.ShowItem(wow, tooltip, owner, anchorType, data)
	data = data or {}
	data.type = data.type or wow.env.Enum.TooltipDataType.Item
	tooltip:SetOwner(owner, anchorType)
	tooltip:ProcessInfo({ tooltipData = data })
end

-- Appends item data to a shown tooltip, after its lines, like Blizzard's comparison tooltips and AppendInfo
function fakes.AppendItem(wow, tooltip, data)
	data.type = data.type or wow.env.Enum.TooltipDataType.Item
	tooltip:ProcessInfo({ tooltipData = data, append = true })
end

-- Frames created by the addon with a given template or text, in creation order
function fakes.FindFrames(wow, filter)
	local found = {}
	for _, frame in ipairs(wow.frames) do
		if
			(filter.template == nil or frame.template == filter.template)
			and (filter.text == nil or frame.text == filter.text)
			and (filter.parent == nil or frame.parent == filter.parent)
		then
			table.insert(found, frame)
		end
	end
	return found
end

-- Strings of the esES client that Locales.lua doesn't bundle, as the client has them
fakes.ES_CLIENT_STRINGS = {
	ITEM_SPELL_TRIGGER_ONEQUIP = "Equipar:",
	ITEM_SPELL_TRIGGER_ONUSE = "Usar:",
	ITEM_COOLDOWN_TOTAL = "(%s de tiempo de reutilización).",
	SECONDS_ABBR = "%d |4s:s;",
}

-- A fresh fake world.
-- options.locale: "esES" (default) or "enUS", for the "Equip:" and "Use:" prefixes, creature type names and the
-- Well Fed buff's name. Only the esES client has Blizzard's strings as globals (fakes.LocaleStrings and
-- fakes.ES_CLIENT_STRINGS); the enUS one has only the prefixes, which exercises the fallbacks.
function fakes.NewWoW(options)
	options = options or {}
	local env = setmetatable({}, { __index = _G })
	local wow = {
		env = env,
		frames = {},
		items = {}, -- link -> GetItemStats result
		guids = {}, -- guid -> link
		keysDown = {}, -- "CTRL" / "ALT" / "SHIFT" -> true
		secretTexts = {}, -- text -> true: issecretvalue reports it as a secret
		cursor = { 0, 0 },
		preCalls = {}, -- { lineType, handler }
		postCalls = {}, -- { tooltipType, handler }: other addons' tooltip post-calls
		executedScripts = {}, -- ExecuteFrameScript calls: { frame, scriptName }
		categories = {}, -- Options categories
		sounds = {},
		colorPicker = { rgb = { 1, 1, 1 } },
		radioMenus = {}, -- MenuUtil.CreateRadioMenu calls, in creation order
		textMetrics = setmetatable({}, { __index = fakes.TEXT_METRICS }),
	}

	local english = options.locale == "enUS"
	-- Addon code reads client strings through _G, which must be this world
	env._G = env
	if not english then
		for name, value in pairs(fakes.LocaleStrings("esES")) do
			env[name] = value
		end
		for name, value in pairs(fakes.ES_CLIENT_STRINGS) do
			env[name] = value
		end
		-- Not GlobalStrings: the client gives the first as the Well Fed spell's name, and has no text of its own
		-- for the second
		env.WELL_FED = nil
		env.KILL_EXPERIENCE = nil
	end
	env.GetLocale = function()
		return english and "enUS" or "esES"
	end
	-- The esES client's names are its real LFG_LIST_LANGUAGE_* strings; the enUS ones are made up
	local localeNames = english
			and {
				enUS = "English",
				deDE = "German",
				esES = "Spanish",
				esMX = "Spanish (Mexico)",
				frFR = "French",
				itIT = "Italian",
				ptBR = "Portuguese",
			}
		or {
			enUS = "Inglés",
			deDE = "Alemán",
			esES = "Español",
			esMX = "Español (México)",
			frFR = "Francés",
			itIT = "Italiano",
			ptBR = "Portugués",
		}
	env.LocaleUtil = {
		GetLocaleDisplayName = function(locale)
			return localeNames[locale]
		end,
	}
	-- The specs only use letters for which lowercase and case folding agree
	env.C_Intl = { FoldCase = fakes.FoldCase, ToLower = fakes.FoldCase }
	if english then
		env.ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
		env.ITEM_SPELL_TRIGGER_ONUSE = "Use:"
	end
	-- Spell names: wow.spellNames[spellID]. 19705 is a Well Fed buff.
	wow.spellNames = { [19705] = english and "Well Fed" or "Bien alimentado" }
	env.C_Spell = {
		GetSpellName = function(spellID)
			return wow.spellNames[spellID]
		end,
	}
	local creatureTypes = english
			and {
				[1] = "Beast",
				[2] = "Dragonkin",
				[3] = "Demon",
				[4] = "Elemental",
				[5] = "Giant",
				[6] = "Undead",
				[7] = "Humanoid",
				[9] = "Mechanical",
			}
		or {
			[1] = "Bestia",
			[2] = "Dragonante",
			[3] = "Demonio",
			[4] = "Elemental",
			[5] = "Gigante",
			[6] = "No-muerto",
			[7] = "Humanoide",
			[9] = "Mecánico",
		}

	env.Enum = {
		TooltipDataType = { Item = 0, Unit = 2 },
		TooltipDataLineType = { None = 0, ItemSpellTriggerOnUse = 44 },
	}
	env.NORMAL_FONT_COLOR = fakes.Color(1, 0.82, 0)
	env.SOUNDKIT = { IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840, IG_CHARACTER_INFO_TAB = 841 }

	-- Blizzard's helpers for PanelTabButtonTemplate tabs: the selected one is marked `selected`, and a tab is as
	-- wide as its text and 20 of padding
	env.PanelTemplates_SetNumTabs = function(frame, numTabs)
		frame.numTabs = numTabs
	end
	env.PanelTemplates_SetTab = function(frame, id)
		frame.selectedTab = id
		for index, tab in ipairs(frame.Tabs) do
			tab.selected = index == id
		end
	end
	env.PanelTemplates_TabResize = function(tab)
		tab.width = Length(tab.text) * wow.textMetrics.charWidth + 20
	end
	env.UISpecialFrames = {}
	env.tinsert = table.insert

	env.CreateFrame = function(frameType, name, parent, template)
		return fakes.NewFrame(wow, frameType, name, parent, template)
	end
	-- A 1920×1080 screen with the UI scale off: the UI is 768 high
	env.UIParent = fakes.NewFrame(wow, "Frame", "UIParent")
	env.UIParent.width, env.UIParent.height = 1365, 768
	env.WorldFrame = fakes.NewFrame(wow, "Frame", "WorldFrame")
	env.Minimap = fakes.NewFrame(wow, "Frame", "Minimap", env.UIParent)
	env.Minimap.width, env.Minimap.centerX, env.Minimap.centerY, env.Minimap.scale = 140, 500, 400, 1
	-- Blizzard's item tooltips, whose global names Blizzard's secure code set
	wow.secureGlobals = {}
	for _, name in ipairs({
		"GameTooltip",
		"ItemRefTooltip",
		"ShoppingTooltip1",
		"ShoppingTooltip2",
		"ItemRefShoppingTooltip1",
		"ItemRefShoppingTooltip2",
		"EmbeddedItemTooltip",
	}) do
		fakes.NewFrame(wow, "GameTooltip", name, env.UIParent)
		wow.secureGlobals[name] = true
	end
	-- Only Blizzard's globals are secure, not those addon code set. The client also says so for unset names,
	-- which the addon never asks about.
	env.issecurevariable = function(name)
		return wow.secureGlobals[name] == true
	end
	env.ExecuteFrameScript = function(frame, scriptName, ...)
		table.insert(wow.executedScripts, { frame = frame, scriptName = scriptName })
		fakes.Fire(frame, scriptName, ...)
	end
	-- Like the client: the hook runs after the method, which returns what it returned
	env.hooksecurefunc = function(object, method, hook)
		local original = object[method]
		object[method] = function(...)
			local results = { original(...) }
			hook(...)
			return unpack(results)
		end
	end

	-- Forever's classes, in the game's order (CLASS_SORT_ORDER), with their names on this client
	env.CLASS_SORT_ORDER = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
	local classNames = english
			and {
				WARRIOR = "Warrior",
				PALADIN = "Paladin",
				PRIEST = "Priest",
				SHAMAN = "Shaman",
				DRUID = "Druid",
				ROGUE = "Rogue",
				MAGE = "Mage",
				WARLOCK = "Warlock",
				HUNTER = "Hunter",
			}
		or {
			WARRIOR = "Guerrero",
			PALADIN = "Paladín",
			PRIEST = "Sacerdote",
			SHAMAN = "Chamán",
			DRUID = "Druida",
			ROGUE = "Pícaro",
			MAGE = "Mago",
			WARLOCK = "Brujo",
			HUNTER = "Cazador",
		}
	env.LocalizedClassList = function()
		return classNames
	end
	env.C_ClassColor = {
		GetClassColor = function(classFile)
			local color = fakes.CLASS_COLORS[classFile]
			return color and fakes.Color(unpack(color))
		end,
	}

	env.TooltipDataProcessor = {
		AddLinePreCall = function(lineType, handler)
			table.insert(wow.preCalls, { lineType = lineType, handler = handler })
		end,
		-- Stats Trimmer adds none: specs add other addons' (GearQuest's score line)
		AddTooltipPostCall = function(tooltipType, handler)
			table.insert(wow.postCalls, { tooltipType = tooltipType, handler = handler })
		end,
	}
	env.C_Item = {
		GetItemStats = function(link)
			return wow.items[link]
		end,
		GetItemLinkByGUID = function(guid)
			return wow.guids[guid]
		end,
	}
	env.C_CreatureInfo = {
		GetCreatureTypeInfo = function(id)
			return creatureTypes[id] and { id = id, name = creatureTypes[id] }
		end,
	}
	env.issecretvalue = function(value)
		return wow.secretTexts[value] == true
	end
	env.IsControlKeyDown = function()
		return wow.keysDown.CTRL == true
	end
	env.IsAltKeyDown = function()
		return wow.keysDown.ALT == true
	end
	env.IsShiftKeyDown = function()
		return wow.keysDown.SHIFT == true
	end
	env.GetCursorPosition = function()
		return wow.cursor[1], wow.cursor[2]
	end
	env.PlaySound = function(soundKitID)
		table.insert(wow.sounds, soundKitID)
	end

	-- Like Blizzard's: setting it up selects the color, which runs swatchFunc, and so does any later color
	-- change. It hides with its own OnHide, which addons can hook.
	local colorPicker = fakes.NewFrame(wow, "Frame", "ColorPickerFrame", env.UIParent)
	colorPicker.shown = false
	colorPicker.height = 210
	colorPicker.Content = {
		ColorPicker = {
			SetColorRGB = function(_, r, g, b)
				wow.colorPicker.rgb = { r, g, b }
				wow.colorPicker.info.swatchFunc()
			end,
		},
	}
	function colorPicker:SetupColorPickerAndShow(info)
		wow.colorPicker.info = info
		self.Content.ColorPicker:SetColorRGB(info.r, info.g, info.b)
		self:Show()
	end
	function colorPicker.GetColorRGB()
		return unpack(wow.colorPicker.rgb)
	end
	env.ColorPickerFrame = colorPicker
	env.MenuUtil = {
		CreateRadioMenu = function(dropdown, isSelected, setSelected, ...)
			table.insert(
				wow.radioMenus,
				{ dropdown = dropdown, isSelected = isSelected, setSelected = setSelected, options = { ... } }
			)
		end,
	}
	env.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name)
			local category = { frame = frame, name = name }
			table.insert(wow.categories, category)
			return category
		end,
		RegisterAddOnCategory = function(category)
			category.isAddOn = true
		end,
	}

	return wow
end

return fakes
