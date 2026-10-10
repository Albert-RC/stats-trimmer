local helpers = {}

-- Loads addon files the way the WoW client does: each file gets (addonName, ns) as its varargs and they
-- share ns. Without `env` only pure files can be loaded (no WoW API); with an environment from
-- fakes.NewWoW() the files run against the fake API and their globals land in that environment.
function helpers.LoadAddon(addonName, files, env)
	local ns = {}
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(("%s/%s"):format(addonName, file)))
		if env then
			setfenv(chunk, env)
		end
		chunk(addonName, ns)
	end
	return ns
end

-- Lua files listed in an addon's .toc, in load order
function helpers.TocFiles(addonName)
	local files = {}
	for line in io.lines(("%s/%s.toc"):format(addonName, addonName)) do
		local file = line:match("^%s*([%w_/]+%.lua)%s*$")
		if file then
			table.insert(files, file)
		end
	end
	return files
end

-- Loads the whole Stats Trimmer addon in .toc order into a fake world (fakes.NewWoW) and sends its
-- ADDON_LOADED, the way the client starts it. Settings saved before can be put in wow.env.StatsTrimmerDB first.
function helpers.StartStatsTrimmer(wow)
	local ns = helpers.LoadAddon("StatsTrimmer", helpers.TocFiles("StatsTrimmer"), wow.env)
	require("spec.fakes").FireEvent(wow, "ADDON_LOADED", "StatsTrimmer")
	return ns
end

return helpers
