-- Pure text helpers. No WoW API here, so this file can be unit tested outside the game.
local _, ns = ...

-- The tooltip wording varies per locale and per item, so a line is identified by its numbers:
-- they must be exactly the expected values (a and/or b), nothing more and nothing less. A line with a
-- percentage never matches: these values are points, and a "10%" next to a 10-point stat is something else.
function ns.NumbersMatch(text, a, b)
	if text:find("%", 1, true) then
		return false
	end

	local expected = {}
	if a then
		expected[a] = true
	end
	if b then
		expected[b] = true
	end

	local found = {}
	for number in text:gmatch("%d+") do
		local value = tonumber(number)
		if not expected[value] then
			return false
		end
		found[value] = true
	end
	for value in pairs(expected) do
		if not found[value] then
			return false
		end
	end
	return true
end

-- The percentage in a line ("1.0%", "1,0 %") as a short string ("1", "1.5").
-- nil unless it is the only number in the line.
local PERCENT_PATTERN = "%d+[%.,]?%d*%s*%%"

function ns.GetOnlyPercent(text)
	local percent = text:match(PERCENT_PATTERN)
	if not percent or text:gsub(PERCENT_PATTERN, ""):find("%d") then
		return nil
	end
	local value = tonumber((percent:match("[%d%.,]+"):gsub(",", ".")))
	return value and tostring(value)
end

-- A compact line's text, in English or with the client's stat name: "+10 spell damage", "+1% golpe".
-- Always "+": the line shows what the item adds to the stat, like Blizzard's item comparison. The "up to"
-- of the original wording is how much of it each spell gets, not the stat itself.
function ns.FormatLine(value, percent, name)
	return ("+%s%s %s"):format(value, percent and "%" or "", name)
end

-- The words of a food line's details in the addon's own English, by the name of Blizzard's (see FormatDetails).
-- They are the last resort, when a language lacks Blizzard's.
local ENGLISH_DETAILS = {
	INT_SPELL_DURATION_SEC = "%d sec",
	INT_SPELL_DURATION_MIN = "%d min",
	WELL_FED = "well fed",
}

local function EnglishDetail(name)
	return ENGLISH_DETAILS[name]
end

-- A duration in Blizzard's format for it ("%d sec")
local function FormatDuration(format, amount)
	return (format:gsub("%%d", tostring(amount), 1))
end

-- What follows a food line's stat name: "/s" for a rate (`perSecond`), then how long a restore takes
-- (`seconds`), " (24 sec)", or how long a Well Fed buff lasts (`wellFedMinutes`), " (well fed, 15 min)".
-- GetText(name) gives the words: Blizzard's INT_SPELL_DURATION_SEC, INT_SPELL_DURATION_MIN and WELL_FED, the
-- buff's name. "" without details, nil when GetText lacks a word they need. "/s" reads the same in every
-- language, like MP5.
function ns.FormatDetails(details, GetText)
	if not details then
		return ""
	end
	local text = details.perSecond and "/s" or ""
	if details.seconds then
		local seconds = GetText("INT_SPELL_DURATION_SEC")
		if not seconds then
			return nil
		end
		text = text .. (" (%s)"):format(FormatDuration(seconds, details.seconds))
	elseif details.wellFedMinutes then
		local name, minutes = GetText("WELL_FED"), GetText("INT_SPELL_DURATION_MIN")
		if not (name and minutes) then
			return nil
		end
		text = text .. (" (%s, %s)"):format(name, FormatDuration(minutes, details.wellFedMinutes))
	end
	return text
end

-- A compact line. `text` is the English line; `value`, `percent`, `details` and the stat keys in `stats` let
-- ns.LocalizeLines rebuild it with Blizzard's names, and without `stats` it is never translated. `details`
-- are a food line's (see FormatDetails). `kind` picks its color (ns.COLOR_KINDS); unknown kinds keep the
-- original line color.
function ns.CompactLine(kind, value, name, stats, percent, details)
	return {
		kind = kind,
		text = ns.FormatLine(value, percent, name) .. ns.FormatDetails(details, EnglishDetail),
		value = value,
		percent = percent,
		stats = stats,
		details = details,
	}
end
