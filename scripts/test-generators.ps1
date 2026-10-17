# Tests the generators on the CSV fixtures in spec/fixtures: what they write, which the specs in spec/generators
# check, and what they refuse to write. Needs LuaJIT, like test.ps1, and no network.
# Usage: ./scripts/test-generators.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([System.IO.Path]::GetTempPath()) "StatsTrimmer-GeneratorTests"
$failures = 0

# A copy of these parameters with others set or replaced
function With([hashtable]$parameters, [hashtable]$others) {
	$merged = $parameters.Clone()
	foreach ($key in $others.Keys) {
		$merged[$key] = $others[$key]
	}
	return $merged
}

# Runs a generator with these parameters; returns the message it stopped with, or $null when it wrote its files
function Invoke-Generator([string]$name, [hashtable]$parameters) {
	try {
		& (Join-Path $PSScriptRoot $name) @parameters | Out-Null
		return $null
	}
	catch {
		return $_.Exception.Message
	}
}

function Test-Case([string]$name, [scriptblock]$body) {
	try {
		& $body
		Write-Output "ok    $name"
	}
	catch {
		$script:failures++
		Write-Output "FAIL  $name"
		Write-Output "      $($_.Exception.Message)"
	}
}

function Assert-Written([string]$refused) {
	if ($refused) {
		throw "it stopped: $refused"
	}
}

# The generator stopped with a message containing `expected`, and wrote nothing new
function Assert-Refused([string]$refused, [string]$expected) {
	if (-not $refused) {
		throw "it wrote its files"
	}
	if (-not $refused.Contains($expected)) {
		throw "it stopped with another message: $refused"
	}
}

# A copy of a fixture folder that a case can change
function Copy-Fixtures([string]$name) {
	$copy = Join-Path $work ([System.IO.Path]::GetRandomFileName())
	Copy-Item -Recurse (Join-Path $root "spec/fixtures/$name") $copy
	return $copy
}

# Changes a CSV of a fixture copy: `change` gets its rows and returns the new ones
function Edit-Csv([string]$file, [scriptblock]$change) {
	$rows = @(Import-Csv $file -Encoding utf8)
	$header = (Get-Content $file -TotalCount 1)
	$changed = @(& $change $rows)
	if ($changed.Count -eq 0) {
		Set-Content -Path $file -Value $header -Encoding utf8
	}
	else {
		$changed | Export-Csv -Path $file -NoTypeInformation -Encoding utf8
	}
}

Push-Location $root
try {
	Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
	New-Item -ItemType Directory -Force -Path $work | Out-Null
	$foods = Join-Path $work "FoodData.lua"
	$alchemy = Join-Path $work "AlchemyData.lua"
	$locales = Join-Path $work "Locales.lua"
	$client = Join-Path $work "ClientStrings-ruRU.lua"
	# The fixtures have a few stat names per language, not the client's hundred
	$localeParameters = @{ Output = $locales; Fixture = $client; MinimumStatNames = 3 }
	# update-consumables.ps1's two files for a case, in the work folder
	function Outputs([string]$name) {
		return @{ FoodOutput = (Join-Path $work "$name-Food.lua"); AlchemyOutput = (Join-Path $work "$name-Alchemy.lua") }
	}
	# The potions', elixirs' and flasks' spells in the fixtures
	$alchemySpells = @("4941", "6612", "6615", "17535", "17538", "17626", "24361", "1251940", "1252559")

	Test-Case "update-consumables.ps1 writes the fixtures' foods, and their potions, elixirs and flasks" {
		Assert-Written (Invoke-Generator "update-consumables.ps1" @{ From = "spec/fixtures/consumables"; FoodOutput = $foods; AlchemyOutput = $alchemy })
	}
	Test-Case "update-locales.ps1 writes the fixtures' languages and the ruRU client's strings" {
		Assert-Written (Invoke-Generator "update-locales.ps1" (With $localeParameters @{ From = "spec/fixtures/locales" }))
	}
	# What they wrote
	$env:STATS_TRIMMER_GENERATED = $work
	luajit spec/runner.lua spec/generators/consumables_spec.lua spec/generators/locales_spec.lua
	if ($LASTEXITCODE -ne 0) {
		$failures++
	}

	Test-Case "update-consumables.ps1 refuses a table without a column it reads" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/SpellEffect.csv" { param($rows) $rows | Select-Object * -ExcludeProperty EffectAura }
		$outputs = Outputs "NoColumn"
		Assert-Refused (Invoke-Generator "update-consumables.ps1" (With $outputs @{ From = $from })) "SpellEffect has no EffectAura column"
		foreach ($output in $outputs.Values) {
			if (Test-Path $output) {
				throw "it wrote $output"
			}
		}
	}
	Test-Case "update-consumables.ps1 refuses an empty table" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/Spell.csv" { param($rows) @() }
		Assert-Refused (Invoke-Generator "update-consumables.ps1" (With (Outputs "Empty") @{ From = $from })) "Spell has no rows"
	}
	Test-Case "update-consumables.ps1 refuses tables that don't agree, such as a food spell missing from Spell" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/Spell.csv" { param($rows) $rows | Where-Object { $_.ID -ne "435" } }
		Assert-Refused (Invoke-Generator "update-consumables.ps1" (With (Outputs "Partial") @{ From = $from })) "Spell lacks food spells 435"
	}
	Test-Case "update-consumables.ps1 leaves out a Use spell missing from both Spell and SpellEffect, as not in the build" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/Spell.csv" { param($rows) $rows | Where-Object { $_.ID -ne "17626" } }
		Edit-Csv "$from/SpellEffect.csv" { param($rows) $rows | Where-Object { $_.SpellID -ne "17626" } }
		$outputs = Outputs "NotInBuild"
		Assert-Written (Invoke-Generator "update-consumables.ps1" (With $outputs @{ From = $from }))
		if (Select-String -Path $outputs.AlchemyOutput -Pattern '\[17626\]' -Quiet) {
			throw "17626 is there"
		}
	}
	Test-Case "update-consumables.ps1 refuses a result without any food" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/Spell.csv" { param($rows) $rows | ForEach-Object { $_.Description_lang = "Tastes odd."; $_ } }
		Assert-Refused (Invoke-Generator "update-consumables.ps1" (With (Outputs "None") @{ From = $from })) "No food spell could be converted"
	}
	Test-Case "update-consumables.ps1 refuses a result without any potion, elixir or flask" {
		$from = Copy-Fixtures "consumables"
		Edit-Csv "$from/Spell.csv" {
			param($rows) $rows | ForEach-Object { if ($alchemySpells -contains $_.ID) { $_.Description_lang = "Tastes odd." }; $_ }
		}
		$outputs = Outputs "NoAlchemy"
		Assert-Refused (Invoke-Generator "update-consumables.ps1" (With $outputs @{ From = $from })) "No alchemy spell could be converted"
		if (Test-Path $outputs.FoodOutput) {
			throw "it wrote $($outputs.FoodOutput)"
		}
	}
	# Spell 432 is a food's, 17626 a flask's
	foreach ($removal in @(@{ spell = "432"; group = "food"; label = "a food" }, @{ spell = "17626"; group = "alchemy"; label = "an alchemy" })) {
		Test-Case "update-consumables.ps1 keeps both files when $($removal.label) spell they had would go, unless told it is expected" {
			$from = Copy-Fixtures "consumables"
			Edit-Csv "$from/Spell.csv" {
				param($rows) $rows | ForEach-Object { if ($_.ID -eq $removal.spell) { $_.Description_lang = "Does something else." }; $_ }
			}
			$outputs = Outputs "Previous"
			Copy-Item $foods $outputs.FoodOutput
			Copy-Item $alchemy $outputs.AlchemyOutput
			$before = @($outputs.FoodOutput, $outputs.AlchemyOutput | ForEach-Object { (Get-FileHash $_).Hash })
			Assert-Refused (Invoke-Generator "update-consumables.ps1" (With $outputs @{ From = $from })) "1 $($removal.group) spells would be removed"
			$after = @($outputs.FoodOutput, $outputs.AlchemyOutput | ForEach-Object { (Get-FileHash $_).Hash })
			if (($before -join " ") -ne ($after -join " ")) {
				throw "it changed a file"
			}
			Assert-Written (Invoke-Generator "update-consumables.ps1" (With $outputs @{ From = $from; AcceptRemovals = $true }))
			if (Select-String -Path $outputs.FoodOutput, $outputs.AlchemyOutput -Pattern "\[$($removal.spell)\]" -Quiet) {
				throw "$($removal.spell) is still there"
			}
		}
	}

	Test-Case "update-locales.ps1 refuses a table without a column it reads" {
		$from = Copy-Fixtures "locales"
		Edit-Csv "$from/ChrClasses-enUS.csv" { param($rows) $rows | Select-Object * -ExcludeProperty Name_male_lang }
		$parameters = With $localeParameters @{ From = $from; Output = (Join-Path $work "NoColumn.lua") }
		Assert-Refused (Invoke-Generator "update-locales.ps1" $parameters) "ChrClasses (enUS) has no Name_male_lang column"
	}
	Test-Case "update-locales.ps1 refuses a language without a string the addon shows" {
		$from = Copy-Fixtures "locales"
		Edit-Csv "$from/GlobalStrings-deDE.csv" { param($rows) $rows | Where-Object { $_.BaseTag -ne "RESET" } }
		$parameters = With $localeParameters @{ From = $from; Output = (Join-Path $work "Incomplete.lua") }
		Assert-Refused (Invoke-Generator "update-locales.ps1" $parameters) "deDE looks incomplete"
	}
	Test-Case "update-locales.ps1 refuses a language whose texts are all English (wago.tools' itIT since 70374)" {
		$from = Copy-Fixtures "locales"
		foreach ($table in "GlobalStrings", "ChrClasses", "SpellName", "Spell") {
			Copy-Item -Force "$from/$table-enUS.csv" "$from/$table-itIT.csv"
		}
		$parameters = With $localeParameters @{ From = $from; Output = (Join-Path $work "English.lua") }
		Assert-Refused (Invoke-Generator "update-locales.ps1" $parameters) "itIT's texts are all the English ones"
	}
	Test-Case "update-locales.ps1 keeps the file when a string it had would go, unless told it is expected" {
		$from = Copy-Fixtures "locales"
		Edit-Csv "$from/GlobalStrings-frFR.csv" { param($rows) $rows | Where-Object { $_.BaseTag -ne "ITEM_MOD_HIT_RATING_SHORT" } }
		$output = Join-Path $work "PreviousLocales.lua"
		Copy-Item $locales $output
		$before = Get-FileHash $output
		$parameters = With $localeParameters @{ From = $from; Output = $output; MinimumStatNames = 2 }
		Assert-Refused (Invoke-Generator "update-locales.ps1" $parameters) "1 strings would be removed"
		if ((Get-FileHash $output).Hash -ne $before.Hash) {
			throw "it changed $output"
		}
		Assert-Written (Invoke-Generator "update-locales.ps1" (With $parameters @{ AcceptRemovals = $true }))
	}
}
finally {
	Pop-Location
	Remove-Item Env:STATS_TRIMMER_GENERATED -ErrorAction SilentlyContinue
	Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

if ($failures -gt 0) {
	Write-Output "$failures generator check(s) failed"
	exit 1
}
Write-Output "Generator checks passed"
exit 0
