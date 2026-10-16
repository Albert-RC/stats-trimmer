-- Blizzard's texts in the language chosen in the settings: the client's own strings, or a bundled language's
-- (Locales.lua), then English. The tooltips, the settings window and the class palette all show texts through
-- these.
local _, ns = ...

-- A spell named Well Fed, whose name is Blizzard's for that buff. update-locales.ps1 bundles the same name.
local WELL_FED_SPELL = 19705

-- Unicode-aware lowercase, so type names like "Élémentaire" or "Нежить" are found whatever their case.
-- C_Intl.FoldCase may return nothing.
local IntlFoldCase = C_Intl and C_Intl.FoldCase
function ns.FoldCase(text)
	return IntlFoldCase and IntlFoldCase(text) or text:lower()
end

local function NonEmpty(value)
	if type(value) == "string" and value ~= "" then
		return value
	end
end

-- Blizzard's texts that aren't GlobalStrings, by the name the bundled languages give them. The client gives the
-- Well Fed buff's name through its API. The experience from kills comes from a buff's description, which no API
-- gives: the client's language has the bundled one, if any.
local CLIENT_TEXTS = {
	WELL_FED = function()
		return C_Spell.GetSpellName(WELL_FED_SPELL)
	end,
	KILL_EXPERIENCE = function()
		local strings = ns.LOCALE_STRINGS[GetLocale()]
		return strings and strings.KILL_EXPERIENCE
	end,
}

-- A Blizzard string in the client's own language (an ITEM_MOD_*_SHORT stat name, RESET...), or nil. Equip
-- lines are always recognized with these: the tooltip is in the client's language.
function ns.GetClientText(name)
	local GetText = CLIENT_TEXTS[name]
	if GetText then
		return NonEmpty(GetText())
	end
	return NonEmpty(_G[name])
end

-- The language Blizzard's texts are shown in: "CLIENT" or a bundled language (ns.ResolveLanguage)
function ns.GetLanguage()
	return ns.ResolveLanguage(ns.db and ns.db.language, GetLocale())
end

-- A Blizzard string in a language ("CLIENT" or a bundled one), or nil
function ns.GetTextIn(language, name)
	if language == "CLIENT" then
		return ns.GetClientText(name)
	end
	local strings = ns.LOCALE_STRINGS[language]
	return strings and NonEmpty(strings[name]) or nil
end

-- A Blizzard string in English, the fallback when the chosen language lacks it or names it wrongly
function ns.GetEnglishText(name)
	return GetLocale() == "enUS" and ns.GetClientText(name) or ns.GetTextIn("enUS", name)
end

-- The client's class names (WARRIOR -> "Guerrero"), read once
local clientClassNames

-- A class's name in a language ("CLIENT" or a bundled one), or nil
local function ClassNameIn(language, classFile)
	local names
	if language == "CLIENT" then
		clientClassNames = clientClassNames or LocalizedClassList(false) or {}
		names = clientClassNames
	else
		names = ns.LOCALE_CLASS_NAMES[language]
	end
	return names and NonEmpty(names[classFile])
end

-- A class's name (WARRIOR) in the language chosen in the settings, then in English, or nil
function ns.GetClassName(classFile)
	return ClassNameIn(ns.GetLanguage(), classFile)
		or ClassNameIn(GetLocale() == "enUS" and "CLIENT" or "enUS", classFile)
end

-- Lowercase for display, following the client's language rules. C_Intl.ToLower may return nothing.
local IntlToLower = C_Intl and C_Intl.ToLower
function ns.ToLower(text)
	return IntlToLower and IntlToLower(text) or text:lower()
end

-- The client's stat names, as the rules recognize equip lines with them
ns.GetClientStatName = ns.TrustedNames(ns.GetClientText, ns.FoldCase)

-- Stat name getters for the compact lines: Blizzard's names lowercased like the rest of the line (Blizzard's
-- own capitalization is uneven: "Daño Arcano", "golpe"). Made once per language, since ns.TrustedNames
-- reads every creature type's name.
local namesIn = {} -- language -> getter
local englishNames

local function LowercasedNames(GetName)
	return ns.TrustedNames(function(key)
		local name = GetName(key)
		return name and ns.ToLower(name)
	end, ns.FoldCase)
end

-- The compact lines with Blizzard's stat names in the chosen language (or `language`, "CLIENT" or a bundled
-- one), then in English for any line that language can't name. MP5 and HP5 have no names and stay as they are.
function ns.InLanguage(lines, language)
	language = language or ns.GetLanguage()
	namesIn[language] = namesIn[language] or LowercasedNames(function(key)
		return ns.GetTextIn(language, key)
	end)
	englishNames = englishNames or LowercasedNames(ns.GetEnglishText)
	return ns.LocalizeLines(ns.LocalizeLines(lines, namesIn[language]), englishNames)
end
