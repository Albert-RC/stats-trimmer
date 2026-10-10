std = "lua51"
max_line_length = false

-- Globals the addon defines or modifies
globals = {
	"StatsTrimmerDB",
	"HelloForeverDB",
	"SLASH_HELLOFOREVER1",
	"SlashCmdList",
}

-- Read-only WoW API (extend as needed)
read_globals = {
	"C_CreatureInfo",
	"C_Item",
	"ColorPickerFrame",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GameTooltip",
	"GetCursorPosition",
	"IsAltKeyDown",
	"IsControlKeyDown",
	"IsShiftKeyDown",
	"ITEM_SPELL_TRIGGER_ONEQUIP",
	"ItemRefTooltip",
	"MenuUtil",
	"Minimap",
	"NORMAL_FONT_COLOR",
	"PlaySound",
	"Settings",
	"SOUNDKIT",
	"tinsert",
	"TooltipDataProcessor",
	"UIParent",
	"UISpecialFrames",
}

-- Specs use busted's globals; the runner is what defines them when busted isn't available
files["spec"] = { std = "+busted" }
files["spec/runner.lua"] = { globals = { "assert", "before_each", "describe", "it" } }
