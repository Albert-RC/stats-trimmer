std = "lua51"
max_line_length = false

-- Globals the addon defines or modifies
globals = {
	"HelloForeverDB",
	"SLASH_HELLOFOREVER1",
	"SlashCmdList",
}

-- Read-only WoW API (extend as needed)
read_globals = {
	"C_CreatureInfo",
	"C_Item",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"ITEM_SPELL_TRIGGER_ONEQUIP",
	"NORMAL_FONT_COLOR",
	"TooltipDataProcessor",
	"UIParent",
}

-- Specs use busted's globals; the runner is what defines them when busted isn't available
files["spec"] = { std = "+busted" }
files["spec/runner.lua"] = { globals = { "assert", "before_each", "describe", "it" } }
