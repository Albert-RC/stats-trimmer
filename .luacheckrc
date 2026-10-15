std = "lua51"
max_line_length = false

-- Globals the addon defines or modifies
globals = {
	"StatsTrimmerDB",
}

-- Read-only WoW API (extend as needed)
read_globals = {
	"C_ClassColor",
	"C_CreatureInfo",
	"C_Intl",
	"C_Item",
	"C_Spell",
	"CLASS_SORT_ORDER",
	"ColorPickerFrame",
	"CreateFrame",
	"Enum",
	"ExecuteFrameScript",
	"GameTooltip",
	"GetCursorPosition",
	"GetLocale",
	"hooksecurefunc",
	"issecretvalue",
	"issecurevariable",
	"IsAltKeyDown",
	"IsControlKeyDown",
	"IsShiftKeyDown",
	"ITEM_SPELL_TRIGGER_ONEQUIP",
	"ITEM_SPELL_TRIGGER_ONUSE",
	"ItemRefTooltip",
	"LocaleUtil",
	"LocalizedClassList",
	"MenuUtil",
	"Minimap",
	"NORMAL_FONT_COLOR",
	"PanelTemplates_SetNumTabs",
	"PanelTemplates_SetTab",
	"PanelTemplates_TabResize",
	"PlaySound",
	"Settings",
	"SOUNDKIT",
	"tinsert",
	"TooltipDataProcessor",
	"UIParent",
	"UISpecialFrames",
	"WorldFrame",
}

-- Specs use busted's globals; the runner is what defines them when busted isn't available
files["spec"] = { std = "+busted" }
files["spec/runner.lua"] = { globals = { "assert", "before_each", "describe", "it" } }
