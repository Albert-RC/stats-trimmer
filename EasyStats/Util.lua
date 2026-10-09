-- Pure text/stat helpers. No WoW API here, so this file can be unit tested outside the game.
local _, ns = ...

-- The tooltip wording varies per locale and per item, so a line is identified by its numbers:
-- they must be exactly the expected values (a and/or b), nothing more and nothing less.
function ns.NumbersMatch(text, a, b)
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

-- True when the item has a rating stat other than the given one. Skill ratings (e.g. defense) are
-- shown as plain points, not percentages, so they don't count.
function ns.HasOtherRating(stats, ratingKey)
	for key in pairs(stats) do
		if key ~= ratingKey and key:find("_RATING_SHORT$") and not key:find("_SKILL_RATING_SHORT$") then
			return true
		end
	end
	return false
end

-- True when any tooltip data line contains lowerName (plain, case-insensitive search)
function ns.AnyLineMentions(lines, lowerName)
	for _, line in ipairs(lines) do
		if line.leftText and line.leftText:lower():find(lowerName, 1, true) then
			return true
		end
	end
	return false
end
