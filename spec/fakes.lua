-- A small fake of the WoW API pieces Stats Trimmer uses. It records what the addon does (scripts, events,
-- tooltip lines, colors, positions, registrations) so specs can assert on observable behavior.
-- fakes.NewWoW() returns a fresh, independent world; load addon files into `wow.env` with helpers.LoadAddon.
local fakes = {}

local Frame = {}

-- Methods specs don't care about (layout, strata, textures...) exist but do nothing. Only names that look
-- like WoW methods (capitalized) get one, so missing data fields still read as nil.
local function NoOp() end
local FrameMeta = {
	__index = function(_, key)
		local method = Frame[key]
		if method ~= nil then
			return method
		end
		if type(key) == "string" and key:find("^%u") then
			return NoOp
		end
	end,
}

-- Runs a frame's script handler, like the client does; returns what the handler returns
function fakes.Fire(frame, scriptName, ...)
	local handler = frame.scripts[scriptName]
	if handler then
		return handler(frame, ...)
	end
end

-- Sends an event to every frame registered for it
function fakes.FireEvent(wow, event, ...)
	for _, frame in ipairs(wow.frames) do
		if frame.events[event] then
			fakes.Fire(frame, "OnEvent", event, ...)
		end
	end
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

function Frame:SetScript(name, handler)
	self.scripts[name] = handler
end

function Frame:GetScript(name)
	return self.scripts[name]
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

function Frame:GetName()
	return self.name
end

function Frame:GetParent()
	return self.parent
end

function Frame:SetParent(parent)
	self.parent = parent
end

function Frame:SetText(text)
	self.text = text
	if self.lines then
		self.lines = { { text = text } }
	end
end

function Frame:GetText()
	return self.text
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

function Frame:GetWidth()
	return self.width
end

function Frame:GetCenter()
	return self.centerX, self.centerY
end

function Frame:GetEffectiveScale()
	return self.scale
end

function Frame:CreateFontString()
	return fakes.NewFrame(self.wow, "FontString", nil, self)
end

function Frame:CreateTexture()
	return fakes.NewFrame(self.wow, "Texture", nil, self)
end

-- GameTooltip methods: lines are recorded as { text, r, g, b }
function Frame:SetOwner(owner)
	self.owner = owner
	self.lines = {}
end

function Frame:GetOwner()
	return self.owner
end

function Frame:ClearLines()
	self.lines = {}
end

function Frame:AddLine(text, r, g, b)
	table.insert(self.lines, { text = text, r = r, g = g, b = b })
end

function Frame:GetProcessingTooltipInfo()
	return self.processingInfo
end

function Frame:IsTooltipType(tooltipType)
	local data = self.processingInfo and self.processingInfo.tooltipData
	return data ~= nil and data.type == tooltipType
end

function Frame:RefreshData()
	self.refreshCount = self.refreshCount + 1
end

-- Like CreateFrame: named frames also become globals of the world's environment
function fakes.NewFrame(wow, frameType, name, parent, template)
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
	end
	table.insert(wow.frames, frame)
	if name then
		wow.env[name] = frame
	end
	return frame
end

-- A shown tooltip whose data is being processed, as the line pre-calls see it. `data` is the tooltip
-- data: { type, hyperlink, guid, lines }; type defaults to an item.
function fakes.ItemTooltip(wow, data)
	local tooltip = fakes.NewFrame(wow, "GameTooltip")
	data.type = data.type or wow.env.Enum.TooltipDataType.Item
	data.lines = data.lines or {}
	tooltip.processingInfo = { tooltipData = data }
	tooltip.shown = true
	return tooltip
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

-- A fresh fake world.
-- options.locale: "esES" (default) or "enUS", for the "Equip:" prefix and creature type names.
function fakes.NewWoW(options)
	options = options or {}
	local env = setmetatable({}, { __index = _G })
	local wow = {
		env = env,
		frames = {},
		items = {}, -- link -> GetItemStats result
		guids = {}, -- guid -> link
		keysDown = {}, -- "CTRL" / "ALT" / "SHIFT" -> true
		cursor = { 0, 0 },
		preCalls = {}, -- { lineType, handler }
		categories = {}, -- Options categories
		sounds = {},
		colorPicker = { rgb = { 1, 1, 1 } },
	}

	local english = options.locale == "enUS"
	env.ITEM_SPELL_TRIGGER_ONEQUIP = english and "Equip:" or "Equipar:"
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
		TooltipDataLineType = { None = 0 },
	}
	env.NORMAL_FONT_COLOR = fakes.Color(1, 0.82, 0)
	env.SOUNDKIT = { IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840 }
	env.UISpecialFrames = {}
	env.tinsert = table.insert

	env.CreateFrame = function(frameType, name, parent, template)
		return fakes.NewFrame(wow, frameType, name, parent, template)
	end
	env.UIParent = fakes.NewFrame(wow, "Frame", "UIParent")
	env.Minimap = fakes.NewFrame(wow, "Frame", "Minimap", env.UIParent)
	env.Minimap.width, env.Minimap.centerX, env.Minimap.centerY, env.Minimap.scale = 140, 500, 400, 1
	env.GameTooltip = fakes.NewFrame(wow, "GameTooltip", "GameTooltip", env.UIParent)
	env.ItemRefTooltip = fakes.NewFrame(wow, "GameTooltip", "ItemRefTooltip", env.UIParent)

	env.TooltipDataProcessor = {
		AddLinePreCall = function(lineType, handler)
			table.insert(wow.preCalls, { lineType = lineType, handler = handler })
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

	env.ColorPickerFrame = {
		SetupColorPickerAndShow = function(_, info)
			wow.colorPicker.info = info
		end,
		GetColorRGB = function()
			return unpack(wow.colorPicker.rgb)
		end,
	}
	env.MenuUtil = {
		CreateRadioMenu = function(dropdown, isSelected, setSelected, ...)
			wow.radioMenu =
				{ dropdown = dropdown, isSelected = isSelected, setSelected = setSelected, options = { ... } }
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
