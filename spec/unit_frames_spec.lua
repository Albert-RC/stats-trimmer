-- UnitFrames.lua: unit frames' names that don't fit, abbreviated after Blizzard sets them
local helpers = require("spec.helpers")
local fakes = require("spec.fakes")

describe("Unit frame names", function()
	local wow, ns

	-- A unit frame, as Blizzard's update functions take it, whose name is `width` wide: 6 per character
	local function UnitFrame(unit, width)
		local name = wow.env.UIParent:CreateFontString()
		name:SetWidth(width)
		return { unit = unit, name = name }
	end

	-- Blizzard sets the target frame's name; returns what it shows
	local function ShowTarget(name, width)
		wow.unitNames.target = name
		local frame = UnitFrame("target", width or 60)
		wow.env.UnitFrame_Update(frame)
		return frame.name:GetText()
	end

	before_each(function()
		wow = fakes.NewWoW()
		ns = helpers.StartStatsTrimmer(wow)
	end)

	it("abbreviate a two-word name that doesn't fit", function()
		assert.are.equal("Ladrón De.", ShowTarget("Ladrón Defias"))
	end)

	it("keep a name that fits", function()
		assert.are.equal("Ladrón Defias", ShowTarget("Ladrón Defias", 78))
	end)

	it("keep names of one word or more than two, which the game cuts off", function()
		assert.are.equal("Señor de la Guerra Thrall", ShowTarget("Señor de la Guerra Thrall"))
		assert.are.equal("Eldrathorianel", ShowTarget("Eldrathorianel"))
	end)

	it("keep a name that is a secret value", function()
		wow.secretTexts["Ladrón Defias"] = true
		assert.are.equal("Ladrón Defias", ShowTarget("Ladrón Defias"))
	end)

	it("keep a name when the frame only reports a secret truncation", function()
		local secret = {}
		wow.secretTexts[secret] = true
		wow.unitNames.target = "Ladrón Defias"
		local frame = UnitFrame("target", 60)
		function frame.name.IsTruncated()
			return secret
		end
		wow.env.UnitFrame_Update(frame)
		assert.are.equal("Ladrón Defias", frame.name:GetText())
	end)

	it("abbreviate raid frames' names, not nameplates'", function()
		wow.unitNames.raid3 = "Ladrón Defias"
		wow.unitNames.nameplate1 = "Ladrón Defias"
		local raid, nameplate = UnitFrame("raid3", 60), UnitFrame("nameplate1", 60)
		wow.env.CompactUnitFrame_UpdateName(raid)
		wow.env.CompactUnitFrame_UpdateName(nameplate)
		assert.are.equal("Ladrón De.", raid.name:GetText())
		assert.are.equal("Ladrón Defias", nameplate.name:GetText())
	end)

	it("let frames without a name be", function()
		wow.env.UnitFrame_Update({ unit = "pet" })
	end)

	it("keep a name with the misc tab cleared, and abbreviate it once checked again", function()
		ns.db.disabledTabs.misc = true
		wow.unitNames.target = "Ladrón Defias"
		local frame = UnitFrame("target", 60)
		wow.env.UnitFrame_Update(frame)
		assert.are.equal("Ladrón Defias", frame.name:GetText())

		ns.db.disabledTabs.misc = nil
		ns.RefreshUnitNames()
		assert.are.equal("Ladrón De.", frame.name:GetText())
		ns.db.disabledTabs.misc = true
		ns.RefreshUnitNames()
		assert.are.equal("Ladrón Defias", frame.name:GetText())
	end)

	it("leave a name something else changed since", function()
		wow.unitNames.target = "Ladrón Defias"
		local frame = UnitFrame("target", 60)
		wow.env.UnitFrame_Update(frame)
		frame.name:SetText("Otro")
		ns.db.disabledTabs.misc = true
		ns.RefreshUnitNames()
		assert.are.equal("Otro", frame.name:GetText())
		ns.db.disabledTabs.misc = nil
		ns.RefreshUnitNames()
		assert.are.equal("Otro", frame.name:GetText())
	end)

	it("forget a frame whose name became a secret value", function()
		wow.unitNames.target = "Ladrón Defias"
		local frame = UnitFrame("target", 60)
		wow.env.UnitFrame_Update(frame)
		wow.secretTexts["Gnomo Leproso"] = true
		wow.unitNames.target = "Gnomo Leproso"
		wow.env.UnitFrame_Update(frame)
		ns.db.disabledTabs.misc = true
		ns.RefreshUnitNames()
		assert.are.equal("Gnomo Leproso", frame.name:GetText())
	end)

	it("abbreviate names the frames showed before the settings were loaded", function()
		wow = fakes.NewWoW()
		wow.unitNames.player = "Ladrón Defias"
		ns = helpers.LoadAddon("StatsTrimmer", helpers.TocFiles("StatsTrimmer"), wow.env)
		local frame = UnitFrame("player", 60)
		wow.env.UnitFrame_Update(frame)
		assert.are.equal("Ladrón Defias", frame.name:GetText())
		fakes.FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
		assert.are.equal("Ladrón De.", frame.name:GetText())
	end)
end)
