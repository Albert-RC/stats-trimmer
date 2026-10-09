-- Minimal runner for busted-style specs (describe / it / before_each / assert.*), for machines where
-- busted can't be installed. Specs stay busted-compatible, so they also run unchanged under busted.
-- Supported assertions: assert.are.same/equal/near, assert.is_nil/is_not_nil/is_true/is_false.
-- Usage: luajit spec/runner.lua spec/a_spec.lua [spec/b_spec.lua ...]   (from the repo root)

local passed, failures = 0, {}
local blocks = {} -- open describe blocks: { name, hooks }

local function TestPath(name)
	local parts = {}
	for _, block in ipairs(blocks) do
		table.insert(parts, block.name)
	end
	table.insert(parts, name)
	return table.concat(parts, " > ")
end

function describe(name, body)
	table.insert(blocks, { name = name, hooks = {} })
	body()
	table.remove(blocks)
end

function before_each(hook)
	table.insert(blocks[#blocks].hooks, hook)
end

function it(name, body)
	local ok, err = pcall(function()
		for _, block in ipairs(blocks) do
			for _, hook in ipairs(block.hooks) do
				hook()
			end
		end
		body()
	end)
	if ok then
		passed = passed + 1
	else
		table.insert(failures, { path = TestPath(name), err = tostring(err) })
	end
end

-- Readable form of a value, with table keys sorted so output is stable
local function Format(value)
	if type(value) == "string" then
		return ("%q"):format(value)
	elseif type(value) ~= "table" then
		return tostring(value)
	end
	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, ("[%s] = %s"):format(Format(key), Format(value[key])))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Level 3 points the error at the spec line that called the assertion
local function Check(condition, expected, actual)
	if not condition then
		error(("expected %s, got %s"):format(Format(expected), Format(actual)), 3)
	end
end

local luaAssert = assert
assert = setmetatable({
	are = {
		same = function(expected, actual)
			Check(Same(expected, actual), expected, actual)
		end,
		equal = function(expected, actual)
			Check(expected == actual, expected, actual)
		end,
		near = function(expected, actual, tolerance)
			Check(type(actual) == "number" and math.abs(expected - actual) <= tolerance, expected, actual)
		end,
	},
	is_nil = function(actual)
		Check(actual == nil, nil, actual)
	end,
	is_not_nil = function(actual)
		Check(actual ~= nil, "a value", actual)
	end,
	is_true = function(actual)
		Check(actual == true, true, actual)
	end,
	is_false = function(actual)
		Check(actual == false, false, actual)
	end,
}, {
	-- Plain assert(value, message) keeps working
	__call = function(_, ...)
		return luaAssert(...)
	end,
})

for _, file in ipairs(arg) do
	local ok, err = pcall(dofile, file)
	if not ok then
		table.insert(failures, { path = file, err = "failed to load: " .. tostring(err) })
	end
end

for _, failure in ipairs(failures) do
	print(("FAIL  %s\n      %s"):format(failure.path, failure.err))
end
print(("%d passed, %d failed"):format(passed, #failures))
os.exit(#failures == 0 and 0 or 1)
