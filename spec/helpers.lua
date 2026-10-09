local helpers = {}

-- Loads addon files the way the WoW client does: each file gets (addonName, ns) as its varargs and they
-- share ns. Only load files that don't touch the WoW API (e.g. Util.lua, Rules.lua).
function helpers.LoadAddon(addonName, files)
	local ns = {}
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(("%s/%s"):format(addonName, file)))
		chunk(addonName, ns)
	end
	return ns
end

return helpers
