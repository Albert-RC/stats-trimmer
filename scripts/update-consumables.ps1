# Generates StatsTrimmer/FoodData.lua and StatsTrimmer/AlchemyData.lua: what the Use line of each food and drink,
# and of each potion, elixir and flask, shows, taken from Forever's item and spell tables on wago.tools. Run it
# again when the client build changes.
# Usage: ./scripts/update-consumables.ps1 [-Build 1.60.1.70425] [-From <folder>] [-FoodOutput <file>]
#        [-AlchemyOutput <file>] [-AcceptRemovals]
#
# A consumable's Use line is its spell's description, whose numbers the client fills in from the spell data:
# "Restores $o1 health over $d." The wording and the order of those numbers vary per language, so the addon matches
# the line by its numbers, like equip lines. This script reads the English description to learn which numbers the
# line shows and what each one is. The health or mana a food restores over time is the one number the client
# computes in its own way, so the line itself gives it.
#
# It works in three steps:
# 1. Reads the tables: downloads them for -Build, or reads them from -From, a folder with one <Table>.csv each
#    (spec/fixtures/consumables for the specs). Every table must have rows and the columns the script reads, and
#    every consumable's effects and spells must be in their tables, or the script stops: a partial download would
#    otherwise leave consumables out silently.
# 2. Converts every Use spell, or lists why it keeps its original text.
# 3. Compares each result with the file it replaces (-FoodOutput, FoodData.lua, and -AlchemyOutput, AlchemyData.lua,
#    by default) and writes both. Nothing is written when a result is empty, or lacks spells its file had, unless
#    -AcceptRemovals says that is expected.
param(
	[string]$Build = "1.60.1.70425",
	[string]$From,
	[string]$FoodOutput = (Join-Path (Split-Path -Parent $PSScriptRoot) "StatsTrimmer/FoodData.lua"),
	[string]$AlchemyOutput = (Join-Path (Split-Path -Parent $PSScriptRoot) "StatsTrimmer/AlchemyData.lua"),
	[switch]$AcceptRemovals
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$downloads = Join-Path ([System.IO.Path]::GetTempPath()) "StatsTrimmer-ConsumableData"

# The tables the script reads, with the columns it reads from each
$tableColumns = [ordered]@{
	Item = @("ID", "ClassID", "SubclassID")
	ItemSparse = @("ID", "Display_lang")
	ItemEffect = @("ID", "TriggerType", "SpellID")
	ItemXItemEffect = @("ItemID", "ItemEffectID")
	Spell = @("ID", "Description_lang")
	SpellEffect = @("SpellID", "EffectIndex", "DifficultyID", "EffectBasePointsF", "EffectAura", "EffectAuraPeriod", "EffectMiscValue_0")
	SpellMisc = @("SpellID", "DifficultyID", "DurationIndex")
	SpellDuration = @("ID", "Duration")
}

# Consumables (Item class 0) by subclass -> the file their Use spells go to: food and drink, or potions, elixirs
# and flasks
$groups = @{ "5" = "food"; "1" = "alchemy"; "2" = "alchemy"; "3" = "alchemy" }

# Forever's well fed foods end with this spell's description, "Additionally, experience gained from kills is
# increased by 5%.", which the client only shows to some players
$experienceSpell = "1243969"
$experienceMark = "<experience>"

# Words of a food's English description -> the stat key of Blizzard's name for them
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

# Words of a potion's, elixir's or flask's English description -> the stat key of Blizzard's name for them, and the
# aura that adds it (with its misc value, when it tells stats apart). The spell must have an effect with that aura
# and the base points the line shows, so words that say something else aren't taken for the stat.
$alchemyStats = @{
	"strength" = @{ stat = "ITEM_MOD_STRENGTH_SHORT"; aura = "29"; misc = "0" }
	"agility" = @{ stat = "ITEM_MOD_AGILITY_SHORT"; aura = "29"; misc = "1" }
	"stamina" = @{ stat = "ITEM_MOD_STAMINA_SHORT"; aura = "29"; misc = "2" }
	"intellect" = @{ stat = "ITEM_MOD_INTELLECT_SHORT"; aura = "29"; misc = "3" }
	"spirit" = @{ stat = "ITEM_MOD_SPIRIT_SHORT"; aura = "29"; misc = "4" }
	"armor" = @{ stat = "ARMOR"; aura = "674"; misc = "1" }
	"maximum health" = @{ stat = "HEALTH"; aura = "34" }
	"maximum mana" = @{ stat = "MANA"; aura = "418" }
	"resistance to all schools of magic" = @{ stat = "ITEM_MOD_SPELL_RESISTANCE_ALL_SCHOOLS_SHORT"; aura = "22"; misc = "126" }
	"attack power" = @{ stat = "ITEM_MOD_ATTACK_POWER_SHORT"; aura = "99" }
	"spell damage" = @{ stat = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"; aura = "13"; misc = "126" }
	"damage done by magical spells and effects" = @{ stat = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"; aura = "13"; misc = "126" }
	"spell healing" = @{ stat = "ITEM_MOD_SPELL_HEALING_DONE_SHORT"; aura = "135"; misc = "126" }
	"healing done by spells and effects" = @{ stat = "ITEM_MOD_SPELL_HEALING_DONE_SHORT"; aura = "135"; misc = "126" }
	"chance to get a critical hit" = @{ stat = "ITEM_MOD_CRIT_RATING_SHORT"; aura = "290"; percent = $true }
	"chance to critically hit" = @{ stat = "ITEM_MOD_CRIT_RATING_SHORT"; aura = "290"; percent = $true }
}
# One school's spell damage ("spell fire damage", "nature spell damage"): aura 13 with the school's mask
$schools = @{ arcane = "64"; fire = "4"; frost = "16"; holy = "2"; nature = "8"; shadow = "32" }
foreach ($school in $schools.Keys) {
	$entry = @{ stat = "ITEM_MOD_$($school.ToUpper())_DAMAGE_DONE_SHORT"; aura = "13"; misc = $schools[$school] }
	$alchemyStats["spell $school damage"] = $entry
	$alchemyStats["$school spell damage"] = $entry
}
# Regeneration every 5 seconds, which the addon shows as HP5 and MP5
$regenerations = @{
	"health" = @{ stat = "HP5"; aura = "161" }
	"mana" = @{ stat = "MP5"; aura = "85" }
}
# Stats against a creature type ("Attack Power by $s1 against Beasts"): the stat words -> the stat in the key and the
# aura, and the type's plural -> its key and its bit in the aura's misc value (1 << (type ID - 1))
$vsStats = @{
	"attack power" = @{ stat = "ATTACK_POWER"; aura = "102" }
	"spell damage" = @{ stat = "SPELL_DAMAGE"; aura = "180" }
}
$vsTypes = @{
	"beasts" = @{ key = "BEAST"; misc = "1" }
	"dragonkin" = @{ key = "DRAGONKIN"; misc = "2" }
	"demons" = @{ key = "DEMON"; misc = "4" }
	"elementals" = @{ key = "ELEMENTAL"; misc = "8" }
	"giants" = @{ key = "GIANT"; misc = "16" }
	"undead" = @{ key = "UNDEAD"; misc = "32" }
	"humanoids" = @{ key = "HUMANOID"; misc = "64" }
	"mechanicals" = @{ key = "MECHANICAL"; misc = "256" }
}

# A number in a description: a formula the client works out (${($430s1/5)*$430d}), a spell variable ($435o1,
# $1249519d) or a literal one
$formula = '\$\{[^{}]*\}'
$value = "(?:$formula|\$\d+[sodt]\d*|\d+)"

class SkipSpell : System.Exception {
	SkipSpell([string]$message) : base($message) {}
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
	$itemGroups = @{} # item -> food or alchemy
	$itemNames = @{}
	foreach ($row in Read-Table "Item") {
		if ($row.ClassID -eq "0" -and $groups.ContainsKey($row.SubclassID)) {
			$itemGroups[$row.ID] = $groups[$row.SubclassID]
		}
	}
	foreach ($row in Read-Table "ItemSparse") {
		if ($itemGroups.ContainsKey($row.ID)) {
			$itemNames[$row.ID] = $row.Display_lang
		}
	}
	$itemEffects = @{}
	foreach ($row in Read-Table "ItemEffect") {
		$itemEffects[$row.ID] = $row
	}
	# Group -> Use spell -> the names of the consumables that use it
	$spells = @{ food = @{}; alchemy = @{} }
	$missingEffects = [System.Collections.Generic.List[string]]::new()
	foreach ($row in Read-Table "ItemXItemEffect") {
		$group = $itemGroups[$row.ItemID]
		if (-not $group) {
			continue
		}
		$effect = $itemEffects[$row.ItemEffectID]
		if (-not $effect) {
			$missingEffects.Add("item $($row.ItemID): effect $($row.ItemEffectID)")
			continue
		}
		# TriggerType 0 is "Use:"
		if ($effect.TriggerType -eq "0") {
			if (-not $spells[$group].ContainsKey($effect.SpellID)) {
				$spells[$group][$effect.SpellID] = [System.Collections.Generic.List[string]]::new()
			}
			if ($itemNames[$row.ItemID]) {
				$spells[$group][$effect.SpellID].Add($itemNames[$row.ItemID])
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

$problems = @()
foreach ($group in "food", "alchemy") {
	if ($spells[$group].Count -eq 0) {
		$problems += "no $group item has a Use spell"
	}
	# A spell in neither Spell nor SpellEffect doesn't exist in this build (Rage Potion's 6614): its item keeps its
	# text. One with effects but no Spell row is a partial download.
	$missingSpells = @($spells[$group].Keys | Where-Object { -not $descriptions.ContainsKey($_) -and $spellEffects.ContainsKey($_) } | Sort-Object { [int]$_ })
	if ($missingSpells.Count -gt 0) {
		$problems += "Spell lacks $group spells $($missingSpells -join ', ')"
	}
}
if ($missingEffects.Count -gt 0) {
	$problems += "ItemEffect lacks $($missingEffects -join '; ')"
}
if ($problems.Count -gt 0) {
	throw "The tables don't agree, so FoodData.lua and AlchemyData.lua are left as they are: $($problems -join '. ')"
}

function Get-Effect([string]$spell, [string]$index) {
	$effects = $spellEffects[$spell]
	$effect = if ($effects -and $index) { $effects[[string]([int]$index - 1)] }
	if (-not $effect) {
		throw [SkipSpell]::new("spell $spell has no effect $index")
	}
	return $effect
}

function Get-BasePoints($effect) {
	$points = [double]$effect.EffectBasePointsF
	if ($points -ne [math]::Floor($points)) {
		throw [SkipSpell]::new("spell $($effect.SpellID) has fractional base points")
	}
	return [int]$points
}

# A spell's description with the descriptions it includes ($@spelldesc435) written out, and every variable
# naming its spell: "$o1" in spell 435 becomes "$435o1"
function Expand-Description([string]$spell) {
	if (-not ($descriptions.ContainsKey($spell) -or $spellEffects.ContainsKey($spell))) {
		throw [SkipSpell]::new("spell $spell doesn't exist in this build")
	}
	$text = $descriptions[$spell]
	if (-not $text) {
		throw [SkipSpell]::new("spell $spell has no description")
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
		throw [SkipSpell]::new("formula $token")
	}
	$effect = Get-Effect $points[0].Groups[1].Value $points[0].Groups[3].Value
	if (-not $pointAuras.ContainsKey($effect.EffectAura)) {
		throw [SkipSpell]::new("formula $token on aura $($effect.EffectAura)")
	}
	return @{ amount = Get-BasePoints $effect; stat = $pointAuras[$effect.EffectAura] }
}

# A duration ($435d) as the client writes it: @{ number, unit }, in seconds under a minute, in minutes under an
# hour and in hours from there. One that isn't a whole number of its unit (90 seconds) isn't known.
function Resolve-Duration([string]$token) {
	if ($token -notmatch '^\$(\d+)d\d*$') {
		throw [SkipSpell]::new("duration $token")
	}
	$spell = $Matches[1]
	$milliseconds = $durations[$spell]
	if (-not $milliseconds -or $milliseconds -le 0) {
		throw [SkipSpell]::new("spell $spell has no duration")
	}
	foreach ($unit in @(@("seconds", 1000, 60000), @("minutes", 60000, 3600000), @("hours", 3600000, [int]::MaxValue))) {
		$name, $length, $limit = $unit
		if ($milliseconds -lt $limit) {
			if ($milliseconds % $length -ne 0) {
				break
			}
			return @{ number = $milliseconds / $length; unit = $name }
		}
	}
	throw [SkipSpell]::new("spell $spell lasts $milliseconds ms")
}

# What a number in the description shows: @{ number } for a number the line shows as it is, or @{ amount, stat }
# for a restore whose total the client computes (amount is its base points, for telling health and mana apart).
# A duration must be in `unit`.
function Resolve-Value([string]$token, [string]$unit = "") {
	if ($token -match '^\d+$') {
		return @{ number = [int]$token }
	}
	if ($token -match "^$formula$") {
		return Resolve-Formula $token
	}
	if ($token -notmatch '^\$(\d+)([sodt])(\d*)$') {
		throw [SkipSpell]::new("unknown number $token")
	}
	$spell, $letter, $index = $Matches[1], $Matches[2], $Matches[3]
	switch ($letter) {
		"d" {
			$duration = Resolve-Duration $token
			if ($duration.unit -ne $unit) {
				throw [SkipSpell]::new("spell $spell lasts $($duration.number) $($duration.unit), not in $unit")
			}
			return @{ number = $duration.number }
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
			throw [SkipSpell]::new("spell $spell effect $index has aura $($effect.EffectAura)")
		}
	}
}

# A description with its whitespace collapsed, after checking it has no conditional or unknown text
function Get-PlainText([string]$text) {
	$text = ($text -replace '\s+', ' ').Trim()
	if (($text -replace $formula, '') -match '\$[^\d]') {
		throw [SkipSpell]::new("conditional or unknown text: $text")
	}
	return $text
}

# What a food's Use line shows: the numbers it has besides the amounts the client computes, and its compact
# lines. Throws SkipSpell for a description this script doesn't understand: that food keeps its original text.
function Convert-Food([string]$spell) {
	$text = Expand-Description $spell
	$experience = $null
	if ($text.Contains($experienceMark)) {
		$experience = Get-BasePoints (Get-Effect $experienceSpell 1)
		$text = $text.Replace($experienceMark, "")
	}
	$text = Get-PlainText $text

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
			throw [SkipSpell]::new("$word is restored by a $($resolved.stat) aura")
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
			throw [SkipSpell]::new("well fed value $valueToken")
		}
		Add-Number $resolved
		$stats = if ($words -eq "stamina and spirit") { @("stamina", "spirit") } else { @($words) }
		foreach ($word in $stats) {
			if (-not $statKeys.ContainsKey($word) -or $word -in @("health", "mana")) {
				throw [SkipSpell]::new("well fed stat $word")
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
				throw [SkipSpell]::new("rate $($all[1])")
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
				throw [SkipSpell]::new("well fed gain: $gain")
			}
			$numbers.Add($minutes)
		}
		else {
			throw [SkipSpell]::new("unknown text: $text")
		}
		$text = $text.Substring($all[0].Length)
	}
	if ($lines.Count -eq 0) {
		throw [SkipSpell]::new("nothing to show")
	}
	return [ordered]@{ numbers = $numbers; lines = $lines; experience = $experience }
}

# The stats some words of a potion's, elixir's or flask's description name ("your Strength", "Intellect and
# Spirit"), as $alchemyStats entries. Throws for words that name anything else.
function Get-AlchemyStats([string]$words) {
	$words = ($words.ToLower() -replace "^(?:your|the player's) ", "")
	if ($alchemyStats.ContainsKey($words)) {
		return , @($alchemyStats[$words])
	}
	$parts = @($words -split " and ")
	if ($parts.Count -gt 1 -and @($parts | Where-Object { -not $alchemyStats.ContainsKey($_) }).Count -eq 0) {
		return , @($parts | ForEach-Object { $alchemyStats[$_] })
	}
	throw [SkipSpell]::new("unknown stat: $words")
}

# The effect of a spell that adds a stat ($alchemyStats entry) with these base points, or a throw: the words
# would otherwise name something the spell doesn't do
function Assert-Effect([string]$spell, $entry, [int]$points) {
	foreach ($effect in $spellEffects[$spell].Values) {
		if ($effect.EffectAura -eq $entry.aura -and (-not $entry.misc -or $effect.EffectMiscValue_0 -eq $entry.misc) -and (Get-BasePoints $effect) -eq $points) {
			return
		}
	}
	throw [SkipSpell]::new("spell $spell has no aura $($entry.aura) of $points for $($entry.stat)")
}

# What a potion's, elixir's or flask's Use line shows: the numbers it has and its compact lines, each with how
# long it lasts. Throws SkipSpell for a description this script doesn't understand: that one keeps its original
# text.
function Convert-Alchemy([string]$spell) {
	$text = Expand-Description $spell
	if ($text.Contains($experienceMark)) {
		throw [SkipSpell]::new("experience bonus")
	}
	$text = Get-PlainText $text

	$numbers = [System.Collections.Generic.List[int]]::new()
	$gains = [System.Collections.Generic.List[object]]::new() # { entry, value, percent }
	$found = @{ duration = $null }
	function Add-Gain($entry, [string]$valueToken, [string]$percent) {
		$resolved = Resolve-Value $valueToken
		if ($null -eq $resolved.number) {
			throw [SkipSpell]::new("value $valueToken")
		}
		if ([bool]$entry.percent -ne ($percent -eq "%")) {
			throw [SkipSpell]::new("$($entry.stat) with$(if (-not $percent) { 'out' }) a percentage")
		}
		Assert-Effect $spell $entry $resolved.number
		$gains.Add(@{ entry = $entry; value = $resolved.number; percent = $percent -eq "%" })
	}
	# The stats a value adds: one ("Strength by $s1"), or several with the same value ("Intellect and Spirit by $s1")
	function Add-Gains([string]$words, [string]$valueToken, [string]$percent) {
		foreach ($entry in (Get-AlchemyStats $words)) {
			Add-Gain $entry $valueToken $percent
		}
		$numbers.Add((Resolve-Value $valueToken).number)
	}
	function Set-Duration([string]$token) {
		if ($found.duration) {
			throw [SkipSpell]::new("two durations")
		}
		$found.duration = Resolve-Duration $token
		$numbers.Add($found.duration.number)
	}

	# Each sentence is consumed as it is understood; $all is its match, as -match inside a branch overwrites $Matches.
	# The duration ends a sentence ("for $d.") or makes one ("Lasts for $d.").
	$until = "(?: for ($value)\.|\. Lasts(?: for)? ($value)\.)\s*"
	while ($text) {
		if ($text -match "^(?:Increases|Drink to increase) ([^.]+?)$until") {
			$all = $Matches
			$gain = $all[1]
			if ($gain -match "^([a-zA-Z' ]+?) by ($value) against ([a-zA-Z]+)$") {
				# A stat against a creature type
				$parts = $Matches
				$vs, $type = $vsStats[$parts[1].ToLower()], $vsTypes[$parts[3].ToLower()]
				if (-not ($vs -and $type)) {
					throw [SkipSpell]::new("unknown stat: $gain")
				}
				$entry = @{ stat = "ITEM_MOD_$($vs.stat)_VS_$($type.key)_SHORT"; aura = $vs.aura; misc = $type.misc }
				Add-Gain $entry $parts[2] ""
				$numbers.Add((Resolve-Value $parts[2]).number)
			}
			elseif ($gain -match "^([a-zA-Z' ]+?) by (?:up to )?($value)(%?)(?: and ([a-zA-Z' ]+?) by (?:up to )?($value)(%?))?$") {
				$parts = $Matches
				Add-Gains $parts[1] $parts[2] $parts[3]
				if ($parts[4]) {
					Add-Gains $parts[4] $parts[5] $parts[6]
				}
			}
			else {
				throw [SkipSpell]::new("unknown gain: $gain")
			}
			Set-Duration ($all[2] + $all[3])
		}
		elseif ($text -match "^Drink to gain ([^.]+?)\. Lasts(?: for)? ($value)\.\s*") {
			$all = $Matches
			if ($all[1] -match "^($value)(%?) ([a-zA-Z ]+?)(?: and ($value)(%?) ([a-zA-Z ]+))?$") {
				$parts = $Matches
				Add-Gains $parts[3] $parts[1] $parts[2]
				if ($parts[4]) {
					Add-Gains $parts[6] $parts[4] $parts[5]
				}
			}
			else {
				throw [SkipSpell]::new("unknown gain: $($all[1])")
			}
			Set-Duration $all[2]
		}
		elseif ($text -match "^(?:Regenerate|Drink to regenerate|Drink to restore) ($value) (health|mana)(?: and ($value) (mana))? (?:every|per) 5 sec$until") {
			$all = $Matches
			Add-Gain $regenerations[$all[2]] $all[1] ""
			$numbers.Add((Resolve-Value $all[1]).number)
			if ($all[3]) {
				Add-Gain $regenerations[$all[4]] $all[3] ""
				$numbers.Add((Resolve-Value $all[3]).number)
			}
			$numbers.Add(5)
			Set-Duration ($all[5] + $all[6])
		}
		elseif ($text -match '^You can only have the effect of one flask at a time\.\s*') {
			# Every flask says it
			$all = $Matches
		}
		elseif ($text -match '^This effect persists through death(?: and stacks with all other resistance spells and items)?\.\s*') {
			$all = $Matches
		}
		else {
			throw [SkipSpell]::new("unknown text: $text")
		}
		$text = $text.Substring($all[0].Length)
	}
	if ($gains.Count -eq 0 -or -not $found.duration) {
		throw [SkipSpell]::new("nothing to show")
	}
	$lines = foreach ($gain in $gains) {
		$line = [ordered]@{ stat = $gain.entry.stat; value = $gain.value; percent = $gain.percent }
		$line[$found.duration.unit] = $found.duration.number
		$line
	}
	return [ordered]@{ numbers = $numbers; lines = @($lines) }
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

# 2. Every Use spell, converted or with why it keeps its text
function Convert-Group([string]$group, [scriptblock]$Convert) {
	$converted = [System.Collections.Generic.List[object]]::new()
	$skipped = [ordered]@{} # spell -> "names: reason"
	foreach ($spell in ($spells[$group].Keys | Sort-Object { [int]$_ })) {
		$names = @($spells[$group][$spell] | Sort-Object -Unique)
		try {
			$converted.Add([ordered]@{ spell = $spell; names = $names; data = & $Convert $spell })
		}
		catch [SkipSpell] {
			$skipped[$spell] = "($($names -join ', ')): $($_.Exception.Message)"
		}
	}
	return @{ group = $group; converted = $converted; skipped = $skipped }
}

$results = @(
	(Convert-Group "food" { param($spell) Convert-Food $spell }) + @{
		output = $FoodOutput
		table = "FOODS"
		description = @(
			"-- Food spell (the spellID of its Use line) -> what that line shows:"
			"--   numbers     the numbers the line shows, besides the amounts the client computes and the experience"
			"--   lines       the compact lines, in order. A line with an amount shows the number read from the line;"
			"--               the amount is its base points, which the larger number goes to."
			"--   experience  the bonus some players see at the end of the line, or nil"
		)
	}
	(Convert-Group "alchemy" { param($spell) Convert-Alchemy $spell }) + @{
		output = $AlchemyOutput
		table = "ALCHEMY"
		description = @(
			"-- Potion, elixir and flask spell (the spellID of its Use line) -> what that line shows:"
			"--   numbers  the numbers the line shows"
			"--   lines    the compact lines, in order, each with how long it lasts (seconds, minutes or hours)"
		)
	}
)

# 3. Compared with the files they replace, then written: neither unless both can be
foreach ($result in $results) {
	$converted = $result.converted
	if ($converted.Count -eq 0) {
		throw "No $($result.group) spell could be converted, so $($result.output) and the other file are left as they are"
	}
	$previous = @()
	if (Test-Path $result.output) {
		$previous = @(Select-String -Path $result.output -Pattern '^\s*\[(\d+)\] = \{' | ForEach-Object { $_.Matches[0].Groups[1].Value })
	}
	$current = @($converted | ForEach-Object { $_.spell })
	$removed = @($previous | Where-Object { $current -notcontains $_ })
	foreach ($spell in @($current | Where-Object { $previous -notcontains $_ })) {
		Write-Output "  added $($result.group) $spell"
	}
	foreach ($spell in $removed) {
		$reason = if ($result.skipped.Contains($spell)) { $result.skipped[$spell] } else { "(no longer a $($result.group) Use spell)" }
		Write-Output "  removed $($result.group) $spell $reason"
	}
	if ($removed.Count -gt 0 -and -not $AcceptRemovals) {
		throw "$($removed.Count) $($result.group) spells would be removed, so $($result.output) and the other file are left as they are. Run again with -AcceptRemovals if that is expected."
	}
}

foreach ($result in $results) {
	$lines = [System.Collections.Generic.List[string]]::new()
	$lines.Add("-- Generated by scripts/update-consumables.ps1 from the item and spell tables of build $Build")
	$lines.Add("-- (https://wago.tools/db2). Don't edit it by hand: run the script again.")
	$lines.Add("local _, ns = ...")
	$lines.Add("")
	foreach ($line in $result.description) {
		$lines.Add($line)
	}
	$lines.Add("ns.$($result.table) = {")
	foreach ($entry in $result.converted) {
		$names, $data = $entry.names, $entry.data
		$shown = if ($names.Count -gt 3) { ($names[0..2] -join ", ") + ", …" } else { $names -join ", " }
		if ($shown) {
			$lines.Add("`t-- $shown")
		}
		$fields = [System.Collections.Generic.List[string]]::new()
		$fields.Add("numbers = { " + ($data.numbers -join ", ") + " }")
		$fields.Add("lines = { " + (($data.lines | ForEach-Object { ConvertTo-LuaTable $_ }) -join ", ") + " }")
		if ($null -ne $data.experience) {
			$fields.Add("experience = $($data.experience)")
		}
		$lines.Add("`t[$($entry.spell)] = { " + ($fields -join ", ") + " },")
	}
	$lines.Add("}")

	[System.IO.File]::WriteAllText($result.output, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
	if (Get-Command stylua -ErrorAction SilentlyContinue) {
		stylua --config-path (Join-Path $root "stylua.toml") $result.output
	}
	Write-Output ("{0} {1} spells, {2} left with their original text:" -f $result.converted.Count, $result.group, $result.skipped.Count)
	foreach ($spell in $result.skipped.Keys) {
		Write-Output "  $spell $($result.skipped[$spell])"
	}
	Write-Output "Wrote $($result.output)"
}
