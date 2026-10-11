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

-- A compact line's text, in English or with the client's stat name: "≤10 spell damage", "+1% golpe"
function ns.FormatLine(sign, value, percent, name)
	return ("%s%s%s %s"):format(sign, value, percent and "%" or "", name)
end

-- A compact line. `text` is the English line; `sign`, `value`, `percent` and the stat keys in `stats` let
-- ns.LocalizeLines rebuild it with Blizzard's stat names, and without `stats` it is never translated.
-- `kind` picks its color (ns.COLOR_KINDS); unknown kinds keep the original line color.
function ns.CompactLine(kind, sign, value, name, stats, percent)
	return {
		kind = kind,
		text = ns.FormatLine(sign, value, percent, name),
		sign = sign,
		value = value,
		percent = percent,
		stats = stats,
	}
end
