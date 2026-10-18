# Generates StatsTrimmer/Locales.lua: the client strings Stats Trimmer shows, in every language it offers,
# taken from Forever's GlobalStrings, ChrClasses, SpellName and Spell on wago.tools. Run it again when the client
# build changes.
# It also generates spec/fixtures/ClientStrings-ruRU.lua, the strings of a client whose language Stats Trimmer
# doesn't bundle, for the fake ruRU client of the specs (with CreatureType too).
# Usage: ./scripts/update-locales.ps1 [-Build 1.60.1.70425] [-LocaleBuilds @{ itIT = "1.60.1.70338" }]
#        [-From <folder>] [-Output <file>] [-Fixture <file>] [-MinimumStatNames 100] [-AcceptRemovals]
#
# The tables are downloaded for -Build, or for a language's build in -LocaleBuilds, or read from -From, a folder
# with one <Table>-<locale>.csv each (spec/fixtures/locales for the specs). Every table must have rows and the
# columns the script reads. Each language must have at least -MinimumStatNames stat names and every other string,
# not all of them the same as English, and keep every string the file it replaces (-Output, Locales.lua by
# default) had for it, unless -AcceptRemovals says that is expected. Nothing is written otherwise.
#
# Since build 1.60.1.70374, wago.tools gives the English texts for itIT: its texts come from 1.60.1.70338, the
# last build with Italian ones, through -LocaleBuilds.
param(
	[string]$Build = "1.60.1.70425",
	[hashtable]$LocaleBuilds = @{ itIT = "1.60.1.70338" },
	[string]$From,
	[string]$Output = (Join-Path (Split-Path -Parent $PSScriptRoot) "StatsTrimmer/Locales.lua"),
	[string]$Fixture = (Join-Path (Split-Path -Parent $PSScriptRoot) "spec/fixtures/ClientStrings-ruRU.lua"),
	[int]$MinimumStatNames = 100,
	[switch]$AcceptRemovals
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$downloads = Join-Path ([System.IO.Path]::GetTempPath()) "StatsTrimmer-Locales"

# Languages with the Latin alphabet, which every client's font can show. Other clients get their own
# language from the game itself.
$locales = @("enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR")
# Interface texts and the words of consumable lines, besides every ITEM_MOD_*_SHORT stat name
$uiKeys = @(
	"CTRL_KEY", "ALT_KEY", "SHIFT_KEY", "RESET", "PREVIEW", "COLORS", "ITEM_BIND_ON_EQUIP",
	"STAT_CATEGORY_ATTACK", "STAT_CATEGORY_DEFENSE", "SPELLS", "STAT_CATEGORY_WEAPON_SKILLS", "DAMAGE", "COMBAT",
	"MINIMAP_TRACKING_VENDOR_FOOD", "HEALTH", "MANA", "COMBAT_XP_GAIN", "ARMOR",
	"ALCHEMY", "STAT_CATEGORY_ATTRIBUTES",
	"INT_SPELL_DURATION_SEC", "INT_SPELL_DURATION_MIN", "INT_SPELL_DURATION_HOURS"
)
# The Well Fed buff's name isn't a GlobalString: it is bundled as WELL_FED, from this spell's name (the same
# spell Tooltip.lua asks the client for)
$wellFedSpell = "19705"
# Nor is the experience Forever's Well Fed buffs add, which only counts for kills. It is bundled as
# KILL_EXPERIENCE, from this spell's aura description without its number and the two words before it:
# "Experience gained from kills increased by $w1%." -> "Experience gained from kills", "Durch Siege erhaltene
# Erfahrung um $w1% erhöht." -> "Durch Siege erhaltene Erfahrung".
$experienceSpell = "1243969"
# Forever's classes (CLASS_SORT_ORDER in the game): their male names, as LocalizedClassList(false) gives them
$classes = @("WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER")

# The fixture's language, and the strings its client has that the bundled languages don't need: the prefixes and
# cooldown texts recognition uses, and the language names of the language menu (LocaleUtil.GetLocaleDisplayName)
$fixtureLocale = "ruRU"
$clientKeys = @("ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_COOLDOWN_TOTAL", "SECONDS_ABBR", "MINUTES_ABBR")
$languageKeys = @($locales + $fixtureLocale | ForEach-Object { "LFG_LIST_LANGUAGE_" + $_.ToUpper() })
# Creature types the rules know (Rules.lua's VS_CREATURE_TYPES), by ID
$creatureTypes = @(1, 2, 3, 4, 5, 6, 7, 9)

# The tables the script reads, with the columns it reads from each
$tableColumns = @{
	GlobalStrings = @("BaseTag", "TagText_lang")
	ChrClasses = @("Filename", "Name_male_lang")
	SpellName = @("ID", "Name_lang")
	Spell = @("ID", "AuraDescription_lang")
	CreatureType = @("ID", "Name_lang")
}

# The build a language's texts come from
function Get-LocaleBuild([string]$locale) {
	if ($LocaleBuilds.ContainsKey($locale)) {
		return $LocaleBuilds[$locale]
	}
	return $Build
}

# A table's rows in a language, downloaded or from -From. Stops when it has no rows or lacks a column the script
# reads.
function Read-Table([string]$name, [string]$locale) {
	if ($From) {
		$file = Join-Path $From "$name-$locale.csv"
	}
	else {
		$file = Join-Path $downloads "$name-$locale.csv"
		$url = "https://wago.tools/db2/$name/csv?build=$(Get-LocaleBuild $locale)&locale=$locale"
		Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
	}
	$rows = @(Import-Csv -Path $file -Encoding utf8)
	if ($rows.Count -eq 0) {
		throw "$name ($locale) has no rows"
	}
	$columns = $rows[0].PSObject.Properties.Name
	$missing = @($tableColumns[$name] | Where-Object { $columns -notcontains $_ })
	if ($missing.Count -gt 0) {
		throw "$name ($locale) has no $($missing -join ', ') column"
	}
	return $rows
}

function ConvertTo-LuaString([string]$text) {
	$escaped = $text.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
	return '"' + $escaped + '"'
}

# A language's male class names (WARRIOR -> "Guerrero"), of the classes that have one
function Get-ClassNames([string]$locale) {
	$names = [ordered]@{}
	$rows = Read-Table "ChrClasses" $locale
	foreach ($class in $classes) {
		$row = $rows | Where-Object { $_.Filename -eq $class } | Select-Object -First 1
		if ($row -and $row.Name_male_lang) {
			$names[$class] = $row.Name_male_lang
		}
	}
	return $names
}

# A language's GlobalStrings with one of these names (or an ITEM_MOD_*_SHORT stat name, with -Stats)
function Get-GlobalStrings([string]$locale, [string[]]$keys, [switch]$Stats) {
	$strings = @{}
	foreach ($row in Read-Table "GlobalStrings" $locale) {
		if (($Stats -and $row.BaseTag -match '^ITEM_MOD_.+_SHORT$') -or $keys -contains $row.BaseTag) {
			$strings[$row.BaseTag] = $row.TagText_lang
		}
	}
	return $strings
}

# A spell's name in a language, or nil
function Get-SpellName([string]$locale, [string]$spell) {
	$row = Read-Table "SpellName" $locale | Where-Object { $_.ID -eq $spell } | Select-Object -First 1
	if ($row -and $row.Name_lang) {
		return $row.Name_lang
	}
}

# The strings each language had in the file this run replaces: locale -> names
function Get-PreviousStrings([string]$file) {
	$previous = @{}
	if (-not (Test-Path $file)) {
		return $previous
	}
	$locale = $null
	foreach ($line in Get-Content $file -Encoding utf8) {
		if ($line -match '^ns\.LOCALE_CLASS_NAMES') {
			break
		}
		if ($line -match '^\t(\w+) = \{$') {
			$locale = $Matches[1]
			$previous[$locale] = [System.Collections.Generic.List[string]]::new()
		}
		elseif ($locale -and $line -match '^\t\t(\w+) = ') {
			$previous[$locale].Add($Matches[1])
		}
	}
	return $previous
}

# Lua table lines for strings: `<indent><name> = "<text>",`, sorted by name
function ConvertTo-LuaFields($strings, [string]$indent) {
	foreach ($key in ($strings.Keys | Sort-Object -CaseSensitive)) {
		"$indent$key = $(ConvertTo-LuaString $strings[$key]),"
	}
}

if (-not $From) {
	New-Item -ItemType Directory -Force -Path $downloads | Out-Null
}
try {
	$stringsByLocale = [ordered]@{}
	$classesByLocale = [ordered]@{}
	foreach ($locale in $locales) {
		$names = Get-ClassNames $locale
		# Forever's itIT data has no class names: that language shows the English ones
		$missingClasses = @($classes | Where-Object { -not $names.Contains($_) })
		if ($missingClasses.Count -gt 0) {
			if ($locale -eq "enUS") {
				throw "enUS is missing class names: $($missingClasses -join ', ')"
			}
			Write-Warning "$locale has no class names for $($missingClasses -join ', '); it will show the English ones"
		}
		if ($names.Count -gt 0) {
			$classesByLocale[$locale] = $names
		}

		$strings = Get-GlobalStrings $locale $uiKeys -Stats
		$wellFed = Get-SpellName $locale $wellFedSpell
		if ($wellFed) {
			$strings["WELL_FED"] = $wellFed
		}
		$experience = Read-Table "Spell" $locale | Where-Object { $_.ID -eq $experienceSpell } | Select-Object -First 1
		$aura = if ($experience) { $experience.AuraDescription_lang -replace '\$w1\s*%', '' -replace '\s+', ' ' }
		if ($aura -and $aura.Trim().TrimEnd('.').Trim() -match '^(.+\S) \S+ \S+$') {
			$strings["KILL_EXPERIENCE"] = $Matches[1]
		}

		$statCount = @($strings.Keys | Where-Object { $_ -like "ITEM_MOD_*" }).Count
		$missing = @(($uiKeys + "WELL_FED", "KILL_EXPERIENCE") | Where-Object { -not $strings.ContainsKey($_) })
		if ($statCount -lt $MinimumStatNames -or $missing.Count -gt 0) {
			throw "$locale looks incomplete: $statCount stat names, missing $($missing -join ', ')"
		}
		# A language whose every text is the English one isn't that language: wago.tools gave English instead
		$english = $stringsByLocale["enUS"]
		if ($english -and $locale -ne "enUS") {
			$own = @($strings.Keys | Where-Object { $strings[$_] -cne $english[$_] })
			if ($own.Count -eq 0) {
				$source = if ($From) { $From } else { "build $(Get-LocaleBuild $locale)" }
				throw ("$locale's texts are all the English ones in $source`: take them from an earlier build with " +
					"-LocaleBuilds @{ $locale = '<build>' }")
			}
		}
		Write-Output ("{0}: {1} stat names" -f $locale, $statCount)
		$stringsByLocale[$locale] = $strings
	}

	$fixtureStrings = $null
	if ($Fixture) {
		$fixtureStrings = Get-GlobalStrings $fixtureLocale ($uiKeys + $clientKeys + $languageKeys) -Stats
		$missing = @(($uiKeys + $clientKeys) | Where-Object { -not $fixtureStrings.ContainsKey($_) })
		if ($missing.Count -gt 0) {
			throw "$fixtureLocale looks incomplete: missing $($missing -join ', ')"
		}
		$fixtureClasses = Get-ClassNames $fixtureLocale
		$fixtureWellFed = Get-SpellName $fixtureLocale $wellFedSpell
		# String keys: an ordered dictionary takes an integer as a position
		$fixtureTypes = [ordered]@{}
		$typeRows = Read-Table "CreatureType" $fixtureLocale
		foreach ($id in $creatureTypes) {
			$row = $typeRows | Where-Object { $_.ID -eq [string]$id } | Select-Object -First 1
			if ($row -and $row.Name_lang) {
				$fixtureTypes["$id"] = $row.Name_lang
			}
		}
	}
}
finally {
	if (-not $From) {
		Remove-Item -Recurse -Force $downloads -ErrorAction SilentlyContinue
	}
}

# Strings each language had before and lost
$previous = Get-PreviousStrings $Output
$removed = foreach ($locale in $previous.Keys) {
	$strings = $stringsByLocale[$locale]
	foreach ($key in $previous[$locale]) {
		if (-not ($strings -and $strings.ContainsKey($key))) {
			"$locale $key"
		}
	}
}
$removed = @($removed)
foreach ($entry in $removed) {
	Write-Output "  removed $entry"
}
if ($removed.Count -gt 0 -and -not $AcceptRemovals) {
	throw "$($removed.Count) strings would be removed, so $Output is left as it is. Run again with -AcceptRemovals if that is expected."
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- Generated by scripts/update-locales.ps1 from the GlobalStrings, ChrClasses, SpellName and Spell of build")
$lines.Add("-- $Build (https://wago.tools/db2). Don't edit it by hand: run the script again.")
foreach ($locale in ($locales | Where-Object { $LocaleBuilds.ContainsKey($_) })) {
	$lines.Add("-- $locale's texts are those of build $($LocaleBuilds[$locale]).")
}
$lines.Add("-- These are Blizzard's texts, not covered by the addon's license.")
$lines.Add("local _, ns = ...")
$lines.Add("")
$lines.Add("-- Languages in menu order")
$lines.Add("ns.LOCALES = { " + (($locales | ForEach-Object { '"' + $_ + '"' }) -join ", ") + " }")
$lines.Add("")
$lines.Add("ns.LOCALE_STRINGS = {")
foreach ($locale in $stringsByLocale.Keys) {
	$lines.Add("`t$locale = {")
	$lines.AddRange([string[]]@(ConvertTo-LuaFields $stringsByLocale[$locale] "`t`t"))
	$lines.Add("`t},")
}
$lines.Add("}")
$lines.Add("")
$lines.Add("-- Class file name (WARRIOR) -> male class name")
$lines.Add("ns.LOCALE_CLASS_NAMES = {")
foreach ($locale in $classesByLocale.Keys) {
	$lines.Add("`t$locale = {")
	foreach ($class in $classesByLocale[$locale].Keys) {
		$lines.Add("`t`t$class = $(ConvertTo-LuaString $classesByLocale[$locale][$class]),")
	}
	$lines.Add("`t},")
}
$lines.Add("}")
[System.IO.File]::WriteAllText($Output, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
$written = @($Output)

if ($Fixture) {
	$lines = [System.Collections.Generic.List[string]]::new()
	$lines.Add("-- Generated by scripts/update-locales.ps1 from the GlobalStrings, ChrClasses, SpellName and CreatureType of")
	$lines.Add("-- build $Build (https://wago.tools/db2). Don't edit it by hand: run the script again.")
	$lines.Add("-- The strings of a $fixtureLocale client, whose language Stats Trimmer doesn't bundle: spec/fakes.lua's fake")
	$lines.Add("-- $fixtureLocale client has them. These are Blizzard's texts, not covered by the addon's license.")
	$lines.Add("return {")
	$lines.Add("`t-- GlobalStrings")
	$lines.Add("`tstrings = {")
	$lines.AddRange([string[]]@(ConvertTo-LuaFields $fixtureStrings "`t`t"))
	$lines.Add("`t},")
	$lines.Add("`t-- LocalizedClassList(false)")
	$lines.Add("`tclassNames = {")
	foreach ($class in $fixtureClasses.Keys) {
		$lines.Add("`t`t$class = $(ConvertTo-LuaString $fixtureClasses[$class]),")
	}
	$lines.Add("`t},")
	$lines.Add("`t-- C_CreatureInfo.GetCreatureTypeInfo(id).name")
	$lines.Add("`tcreatureTypes = {")
	foreach ($id in $fixtureTypes.Keys) {
		$lines.Add("`t`t[$id] = $(ConvertTo-LuaString $fixtureTypes[$id]),")
	}
	$lines.Add("`t},")
	$lines.Add("`t-- C_Spell.GetSpellName($wellFedSpell), the Well Fed buff's name")
	$lines.Add("`twellFed = $(ConvertTo-LuaString $fixtureWellFed),")
	$lines.Add("}")
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Fixture) | Out-Null
	[System.IO.File]::WriteAllText($Fixture, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
	$written += $Fixture
}

if (Get-Command stylua -ErrorAction SilentlyContinue) {
	stylua --config-path (Join-Path $root "stylua.toml") @written
}
$written | ForEach-Object { Write-Output "Wrote $_" }
