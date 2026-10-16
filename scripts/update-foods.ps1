# Generates StatsTrimmer/FoodData.lua: what the Use line of each food and drink shows, taken from Forever's item
# and spell tables on wago.tools. Run it again when the client build changes.
# Usage: ./scripts/update-foods.ps1 [-Build 1.60.1.70425] [-From <folder>] [-Output <file>] [-AcceptRemovals]
#
# A food's Use line is its spell's description, whose numbers the client fills in from the spell data: "Restores
# $o1 health over $d." The wording and the order of those numbers vary per language, so the addon matches the
# line by its numbers, like equip lines. This script reads the English description to learn which numbers the
# line shows and what each one is. The health or mana a food restores over time is the one number the client
# computes in its own way, so the line itself gives it.
#
# It works in three steps:
# 1. Reads the tables: downloads them for -Build, or reads them from -From, a folder with one <Table>.csv each
#    (spec/fixtures/foods for the specs). Every table must have rows and the columns the script reads, and every
#    food's effects and spells must be in their tables, or the script stops: a partial download would otherwise
#    leave foods out silently.
# 2. Converts every food spell, or lists why it keeps its original text.
# 3. Compares the result with the file it replaces (-Output, FoodData.lua by default) and writes it. An empty
#    result is never written, and neither is one without food spells the file had, unless -AcceptRemovals says
#    that is expected.
param(
	[string]$Build = "1.60.1.70425",
	[string]$From,
	[string]$Output = (Join-Path (Split-Path -Parent $PSScriptRoot) "StatsTrimmer/FoodData.lua"),
	[switch]$AcceptRemovals
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$downloads = Join-Path ([System.IO.Path]::GetTempPath()) "StatsTrimmer-FoodData"

# The tables the script reads, with the columns it reads from each
$tableColumns = [ordered]@{
	Item = @("ID", "ClassID", "SubclassID")
	ItemSparse = @("ID", "Display_lang")
	ItemEffect = @("ID", "TriggerType", "SpellID")
	ItemXItemEffect = @("ItemID", "ItemEffectID")
	Spell = @("ID", "Description_lang")
	SpellEffect = @("SpellID", "EffectIndex", "DifficultyID", "EffectBasePointsF", "EffectAura", "EffectAuraPeriod")
	SpellMisc = @("SpellID", "DifficultyID", "DurationIndex")
	SpellDuration = @("ID", "Duration")
}

# Forever's well fed foods end with this spell's description, "Additionally, experience gained from kills is
# increased by 5%.", which the client only shows to some players
$experienceSpell = "1243969"
$experienceMark = "<experience>"

# Words of the English description -> the stat key of Blizzard's name for them
$statKeys = @{
	"stamina" = "ITEM_MOD_STAMINA_SHORT"
	"intellect" = "ITEM_MOD_INTELLECT_SHORT"
	"strength" = "ITEM_MOD_STRENGTH_SHORT"
	"agility" = "ITEM_MOD_AGILITY_SHORT"
	"spirit" = "ITEM_MOD_SPIRIT_SHORT"
	"armor" = "ARMOR"
	"attack power" = "ITEM_MOD_ATTACK_POWER_SHORT"
	"spell damage" = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
	"healing power" = "ITEM_MOD_SPELL_HEALING_DONE_SHORT"
	"critical strike chance" = "ITEM_MOD_CRIT_RATING_SHORT"
	"health" = "HEALTH"
	"mana" = "MANA"
}
# Auras whose total ($o) is the health or mana a food restores: points the client computes, or a percentage
$pointAuras = @{ "84" = "HEALTH"; "85" = "MANA" }
$percentAuras = @{ "20" = "HEALTH"; "21" = "MANA" }

# A number in a description: a formula the client works out (${($430s1/5)*$430d}), a spell variable ($435o1,
# $1249519d) or a literal one
$formula = '\$\{[^{}]*\}'
$value = "(?:$formula|\$\d+[sodt]\d*|\d+)"

class SkipFood : System.Exception {
	SkipFood([string]$message) : base($message) {}
}

# A table's rows, downloaded or from -From. Stops when it has no rows or lacks a column the script reads.
function Read-Table([string]$name) {
	if ($From) {
		$file = Join-Path $From "$name.csv"
	}
	else {
		$file = Join-Path $downloads "$name.csv"
		$url = "https://wago.tools/db2/$name/csv?build=$Build&locale=enUS"
		Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
	}
	$rows = @(Import-Csv -Path $file -Encoding utf8)
	if ($rows.Count -eq 0) {
		throw "$name has no rows"
	}
	$columns = $rows[0].PSObject.Properties.Name
	$missing = @($tableColumns[$name] | Where-Object { $columns -notcontains $_ })
	if ($missing.Count -gt 0) {
		throw "$name has no $($missing -join ', ') column"
	}
	return $rows
}

function ConvertTo-LuaString([string]$text) {
	$escaped = $text.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
	return '"' + $escaped + '"'
}

# 1. The tables
if (-not $From) {
	New-Item -ItemType Directory -Force -Path $downloads | Out-Null
}
try {
	$foodNames = @{}
	foreach ($row in Read-Table "Item") {
		if ($row.ClassID -eq "0" -and $row.SubclassID -eq "5") {
			$foodNames[$row.ID] = $null
		}
	}
	foreach ($row in Read-Table "ItemSparse") {
		if ($foodNames.ContainsKey($row.ID)) {
			$foodNames[$row.ID] = $row.Display_lang
		}
	}
	$itemEffects = @{}
	foreach ($row in Read-Table "ItemEffect") {
		$itemEffects[$row.ID] = $row
	}
	# Food spell -> the names of the foods that use it
	$foods = @{}
	$missingEffects = [System.Collections.Generic.List[string]]::new()
	foreach ($row in Read-Table "ItemXItemEffect") {
		if (-not $foodNames.ContainsKey($row.ItemID)) {
			continue
		}
		$effect = $itemEffects[$row.ItemEffectID]
		if (-not $effect) {
			$missingEffects.Add("item $($row.ItemID): effect $($row.ItemEffectID)")
			continue
		}
		# TriggerType 0 is "Use:"
		if ($effect.TriggerType -eq "0") {
			if (-not $foods.ContainsKey($effect.SpellID)) {
				$foods[$effect.SpellID] = [System.Collections.Generic.List[string]]::new()
			}
			if ($foodNames[$row.ItemID]) {
				$foods[$effect.SpellID].Add($foodNames[$row.ItemID])
			}
		}
	}

	$descriptions = @{}
	foreach ($row in Read-Table "Spell") {
		$descriptions[$row.ID] = $row.Description_lang
	}
	$spellEffects = @{} # spell -> effect index -> row
	foreach ($row in Read-Table "SpellEffect") {
		if ($row.DifficultyID -eq "0") {
			if (-not $spellEffects.ContainsKey($row.SpellID)) {
				$spellEffects[$row.SpellID] = @{}
			}
			$spellEffects[$row.SpellID][$row.EffectIndex] = $row
		}
	}
	$durationsByIndex = @{}
	foreach ($row in Read-Table "SpellDuration") {
		$durationsByIndex[$row.ID] = [int]$row.Duration
	}
	$durations = @{} # spell -> milliseconds
	foreach ($row in Read-Table "SpellMisc") {
		if ($row.DifficultyID -eq "0" -and $durationsByIndex.ContainsKey($row.DurationIndex)) {
			$durations[$row.SpellID] = $durationsByIndex[$row.DurationIndex]
		}
	}
}
finally {
	if (-not $From) {
		Remove-Item -Recurse -Force $downloads -ErrorAction SilentlyContinue
	}
}

$missingSpells = @($foods.Keys | Where-Object { -not $descriptions.ContainsKey($_) } | Sort-Object { [int]$_ })
if ($foods.Count -eq 0 -or $missingEffects.Count -gt 0 -or $missingSpells.Count -gt 0) {
	$problems = @()
	if ($foods.Count -eq 0) {
		$problems += "no food has a Use spell"
	}
	if ($missingEffects.Count -gt 0) {
		$problems += "ItemEffect lacks $($missingEffects -join '; ')"
	}
	if ($missingSpells.Count -gt 0) {
		$problems += "Spell lacks food spells $($missingSpells -join ', ')"
	}
	throw "The tables don't agree, so FoodData.lua is left as it is: $($problems -join '. ')"
}

function Get-Effect([string]$spell, [string]$index) {
	$effects = $spellEffects[$spell]
	$effect = if ($effects -and $index) { $effects[[string]([int]$index - 1)] }
	if (-not $effect) {
		throw [SkipFood]::new("spell $spell has no effect $index")
	}
	return $effect
}

function Get-BasePoints($effect) {
	$points = [double]$effect.EffectBasePointsF
	if ($points -ne [math]::Floor($points)) {
		throw [SkipFood]::new("spell $($effect.SpellID) has fractional base points")
	}
	return [int]$points
}

# A spell's description with the descriptions it includes ($@spelldesc435) written out, and every variable
# naming its spell: "$o1" in spell 435 becomes "$435o1"
function Expand-Description([string]$spell) {
	$text = $descriptions[$spell]
	if (-not $text) {
		throw [SkipFood]::new("spell $spell has no description")
	}
	$text = [regex]::Replace($text, '\$(?=[sodt]\d*)', '$' + $spell)
	# The experience bonus is conditional: Convert-Food takes it out wherever it is
	$text = $text.Replace("`$@spelldesc$experienceSpell", $experienceMark)
	while ($text -match '\$@spelldesc(\d+)') {
		$included, $includedSpell = $Matches[0], $Matches[1]
		$text = $text.Replace($included, (Expand-Description $includedSpell))
	}
	return $text
}

# A formula the client works out, as the total of a health or mana regeneration: since build 1.60.1.70425 drinks
# say "Restores ${($430s1/5)*$430d} mana", their base points every 5 seconds for their duration. Like $o1, the line
# shows the result, which the addon reads from it: the formula only says which effect it is, by its one base
# points variable.
function Resolve-Formula([string]$token) {
	$variables = @([regex]::Matches($token, '\$(\d+)([sodt])(\d*)'))
	$points = @($variables | Where-Object { $_.Groups[2].Value -in @("s", "o") })
	$others = @($variables | Where-Object { $_.Groups[2].Value -notin @("s", "o", "d") })
	if ($points.Count -ne 1 -or $others.Count -gt 0) {
		throw [SkipFood]::new("formula $token")
	}
	$effect = Get-Effect $points[0].Groups[1].Value $points[0].Groups[3].Value
	if (-not $pointAuras.ContainsKey($effect.EffectAura)) {
		throw [SkipFood]::new("formula $token on aura $($effect.EffectAura)")
	}
	return @{ amount = Get-BasePoints $effect; stat = $pointAuras[$effect.EffectAura] }
}

# What a number in the description shows: @{ number } for a number the line shows as it is, or @{ amount, stat }
# for a restore whose total the client computes (amount is its base points, for telling health and mana apart)
function Resolve-Value([string]$token, [string]$unit = "") {
	if ($token -match '^\d+$') {
		return @{ number = [int]$token }
	}
	if ($token -match "^$formula$") {
		return Resolve-Formula $token
	}
	if ($token -notmatch '^\$(\d+)([sodt])(\d*)$') {
		throw [SkipFood]::new("unknown number $token")
	}
	$spell, $letter, $index = $Matches[1], $Matches[2], $Matches[3]
	switch ($letter) {
		"d" {
			$milliseconds = $durations[$spell]
			if (-not $milliseconds -or $milliseconds -le 0) {
				throw [SkipFood]::new("spell $spell has no duration")
			}
			# The client shows durations under a minute in seconds, the rest in minutes
			if ($unit -eq "seconds" -and $milliseconds -lt 60000 -and $milliseconds % 1000 -eq 0) {
				return @{ number = $milliseconds / 1000 }
			}
			if ($unit -eq "minutes" -and $milliseconds -lt 3600000 -and $milliseconds % 60000 -eq 0) {
				return @{ number = $milliseconds / 60000 }
			}
			throw [SkipFood]::new("spell $spell lasts $milliseconds ms, not in $unit")
		}
		"s" {
			return @{ number = Get-BasePoints (Get-Effect $spell $index) }
		}
		"t" {
			return @{ number = [int](Get-Effect $spell $index).EffectAuraPeriod / 1000 }
		}
		"o" {
			$effect = Get-Effect $spell $index
			if ($pointAuras.ContainsKey($effect.EffectAura)) {
				return @{ amount = Get-BasePoints $effect; stat = $pointAuras[$effect.EffectAura] }
			}
			if ($percentAuras.ContainsKey($effect.EffectAura) -and [int]$effect.EffectAuraPeriod -gt 0) {
				$ticks = $durations[$spell] / [int]$effect.EffectAuraPeriod
				return @{ number = (Get-BasePoints $effect) * $ticks; stat = $percentAuras[$effect.EffectAura] }
			}
			throw [SkipFood]::new("spell $spell effect $index has aura $($effect.EffectAura)")
		}
	}
}

# What a food's Use line shows: the numbers it has besides the amounts the client computes, and its compact
# lines. Throws SkipFood for a description this script doesn't understand: that food keeps its original text.
function Convert-Food([string]$spell) {
	$text = Expand-Description $spell
	$experience = $null
	if ($text.Contains($experienceMark)) {
		$experience = Get-BasePoints (Get-Effect $experienceSpell 1)
		$text = $text.Replace($experienceMark, "")
	}
	$text = ($text -replace '\s+', ' ').Trim()
	if (($text -replace $formula, '') -match '\$[^\d]') {
		throw [SkipFood]::new("conditional or unknown text: $text")
	}

	$numbers = [System.Collections.Generic.List[int]]::new()
	$lines = [System.Collections.Generic.List[object]]::new()
	function Add-Number($resolved) {
		if ($null -ne $resolved.number) {
			$numbers.Add($resolved.number)
		}
	}
	function Add-Restore($resolved, [string]$word, [bool]$percent, [bool]$perSecond, [int]$seconds) {
		$stat = $statKeys[$word.ToLower()]
		if ($resolved.stat -and $resolved.stat -ne $stat) {
			throw [SkipFood]::new("$word is restored by a $($resolved.stat) aura")
		}
		if ($null -ne $resolved.amount) {
			$lines.Add([ordered]@{ stat = $stat; amount = $resolved.amount; seconds = $seconds })
		}
		else {
			$lines.Add([ordered]@{ stat = $stat; value = $resolved.number; percent = $percent; perSecond = $perSecond; seconds = $seconds })
		}
	}
	function Add-WellFed([string]$valueToken, [string]$percent, [string]$words, [int]$minutes) {
		$resolved = Resolve-Value $valueToken
		if ($null -eq $resolved.number) {
			throw [SkipFood]::new("well fed value $valueToken")
		}
		Add-Number $resolved
		$stats = if ($words -eq "stamina and spirit") { @("stamina", "spirit") } else { @($words) }
		foreach ($word in $stats) {
			if (-not $statKeys.ContainsKey($word) -or $word -in @("health", "mana")) {
				throw [SkipFood]::new("well fed stat $word")
			}
			$lines.Add([ordered]@{ stat = $statKeys[$word]; value = $resolved.number; percent = $percent -eq "%"; wellFedMinutes = $minutes })
		}
	}

	# Each sentence is consumed as it is understood; $all is its match, as -match inside a branch overwrites $Matches
	while ($text) {
		if ($text -match "^Restores ($value)(%?) (health|mana)(?: and ($value)(%?) (mana))? over ($value)\.\s*") {
			$all = $Matches
			$seconds = Resolve-Value $all[7] "seconds"
			$first = Resolve-Value $all[1]
			Add-Number $first
			Add-Restore $first $all[3] ($all[2] -eq "%") $false $seconds.number
			if ($all[4]) {
				$second = Resolve-Value $all[4]
				Add-Number $second
				Add-Restore $second $all[6] ($all[5] -eq "%") $false $seconds.number
			}
			Add-Number $seconds
		}
		elseif ($text -match "^Restores ($value)% of your (health|health and mana) per second for ($value)\.\s*") {
			$all = $Matches
			$rate = Resolve-Value $all[1]
			$seconds = Resolve-Value $all[3] "seconds"
			if ($null -eq $rate.number) {
				throw [SkipFood]::new("rate $($all[1])")
			}
			Add-Number $rate
			foreach ($word in ($all[2] -split " and ")) {
				Add-Restore @{ number = $rate.number } $word $true $true $seconds.number
			}
			Add-Number $seconds
		}
		elseif ($text -match '^Must remain seated while (?:eating|drinking)\.\s*') {
			$all = $Matches
		}
		elseif ($text -match "^If you spend at least ($value) (?:sec|seconds) (?:eating|drinking),? you will become well fed and gain (.+?) for ($value)\.\s*") {
			$all = $Matches
			Add-Number (Resolve-Value $all[1])
			$minutes = (Resolve-Value $all[3] "minutes").number
			$gain = $all[2].ToLower()
			if ($gain -match "^($value)(%?) ([a-z ]+?) and ($value)(%?) ([a-z ]+)$") {
				$parts = $Matches
				Add-WellFed $parts[1] $parts[2] $parts[3] $minutes
				Add-WellFed $parts[4] $parts[5] $parts[6] $minutes
			}
			elseif ($gain -match "^($value)(%?) ([a-z ]+)$") {
				Add-WellFed $Matches[1] $Matches[2] $Matches[3] $minutes
			}
			else {
				throw [SkipFood]::new("well fed gain: $gain")
			}
			$numbers.Add($minutes)
		}
		else {
			throw [SkipFood]::new("unknown text: $text")
		}
		$text = $text.Substring($all[0].Length)
	}
	if ($lines.Count -eq 0) {
		throw [SkipFood]::new("nothing to show")
	}
	return [ordered]@{ numbers = $numbers; lines = $lines; experience = $experience }
}

function ConvertTo-LuaValue($value) {
	if ($value -is [bool]) {
		return $value.ToString().ToLower()
	}
	if ($value -is [string]) {
		return ConvertTo-LuaString $value
	}
	return [string]$value
}

function ConvertTo-LuaTable($entries) {
	# Unset and false fields are left out
	$fields = foreach ($key in $entries.Keys) {
		$field = $entries[$key]
		if ($null -ne $field -and -not ($field -is [bool] -and -not $field)) {
			"$key = $(ConvertTo-LuaValue $field)"
		}
	}
	return "{ " + ($fields -join ", ") + " }"
}

# 2. Every food spell, converted or with why it keeps its text
$converted = [System.Collections.Generic.List[object]]::new()
$skipped = [ordered]@{} # spell -> "names: reason"
foreach ($spell in ($foods.Keys | Sort-Object { [int]$_ })) {
	$names = @($foods[$spell] | Sort-Object -Unique)
	try {
		$converted.Add([ordered]@{ spell = $spell; names = $names; food = Convert-Food $spell })
	}
	catch [SkipFood] {
		$skipped[$spell] = "($($names -join ', ')): $($_.Exception.Message)"
	}
}

# 3. Compared with the file it replaces, then written
if ($converted.Count -eq 0) {
	throw "No food spell could be converted, so $Output is left as it is"
}
$previous = @()
if (Test-Path $Output) {
	$previous = @(Select-String -Path $Output -Pattern '^\s*\[(\d+)\] = \{' | ForEach-Object { $_.Matches[0].Groups[1].Value })
}
$current = @($converted | ForEach-Object { $_.spell })
$added = @($current | Where-Object { $previous -notcontains $_ })
$removed = @($previous | Where-Object { $current -notcontains $_ })
foreach ($spell in $added) {
	Write-Output "  added $spell"
}
foreach ($spell in $removed) {
	$reason = if ($skipped.Contains($spell)) { $skipped[$spell] } else { "(no longer a food's Use spell)" }
	Write-Output "  removed $spell $reason"
}
if ($removed.Count -gt 0 -and -not $AcceptRemovals) {
	throw "$($removed.Count) food spells would be removed, so $Output is left as it is. Run again with -AcceptRemovals if that is expected."
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- Generated by scripts/update-foods.ps1 from the item and spell tables of build $Build")
$lines.Add("-- (https://wago.tools/db2). Don't edit it by hand: run the script again.")
$lines.Add("local _, ns = ...")
$lines.Add("")
$lines.Add("-- Food spell (the spellID of its Use line) -> what that line shows:")
$lines.Add("--   numbers     the numbers the line shows, besides the amounts the client computes and the experience")
$lines.Add("--   lines       the compact lines, in order. A line with an amount shows the number read from the line;")
$lines.Add("--               the amount is its base points, which the larger number goes to.")
$lines.Add("--   experience  the bonus some players see at the end of the line, or nil")
$lines.Add("ns.FOODS = {")
foreach ($entry in $converted) {
	$names, $food = $entry.names, $entry.food
	$shown = if ($names.Count -gt 3) { ($names[0..2] -join ", ") + ", …" } else { $names -join ", " }
	if ($shown) {
		$lines.Add("`t-- $shown")
	}
	$fields = [System.Collections.Generic.List[string]]::new()
	$fields.Add("numbers = { " + ($food.numbers -join ", ") + " }")
	$fields.Add("lines = { " + (($food.lines | ForEach-Object { ConvertTo-LuaTable $_ }) -join ", ") + " }")
	if ($null -ne $food.experience) {
		$fields.Add("experience = $($food.experience)")
	}
	$lines.Add("`t[$($entry.spell)] = { " + ($fields -join ", ") + " },")
}
$lines.Add("}")

[System.IO.File]::WriteAllText($Output, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
if (Get-Command stylua -ErrorAction SilentlyContinue) {
	stylua --config-path (Join-Path $root "stylua.toml") $Output
}
Write-Output ("{0} food spells, {1} left with their original text:" -f $converted.Count, $skipped.Count)
foreach ($spell in $skipped.Keys) {
	Write-Output "  $spell $($skipped[$spell])"
}
Write-Output "Wrote $Output"
