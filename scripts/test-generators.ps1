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
	$locales = Join-Path $work "Locales.lua"
	$client = Join-Path $work "ClientStrings-ruRU.lua"
	# The fixtures have a few stat names per language, not the client's hundred
	$localeParameters = @{ Output = $locales; Fixture = $client; MinimumStatNames = 3 }

	Test-Case "update-foods.ps1 writes the fixtures' foods" {
		Assert-Written (Invoke-Generator "update-foods.ps1" @{ From = "spec/fixtures/foods"; Output = $foods })
	}
	Test-Case "update-locales.ps1 writes the fixtures' languages and the ruRU client's strings" {
		Assert-Written (Invoke-Generator "update-locales.ps1" (With $localeParameters @{ From = "spec/fixtures/locales" }))
	}
	# What they wrote
	$env:STATS_TRIMMER_GENERATED = $work
	luajit spec/runner.lua spec/generators/foods_spec.lua spec/generators/locales_spec.lua
	if ($LASTEXITCODE -ne 0) {
		$failures++
	}

	Test-Case "update-foods.ps1 refuses a table without a column it reads" {
		$from = Copy-Fixtures "foods"
		Edit-Csv "$from/SpellEffect.csv" { param($rows) $rows | Select-Object * -ExcludeProperty EffectAura }
		$output = Join-Path $work "NoColumn.lua"
		Assert-Refused (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = $output }) "SpellEffect has no EffectAura column"
		if (Test-Path $output) {
			throw "it wrote $output"
		}
	}
	Test-Case "update-foods.ps1 refuses an empty table" {
		$from = Copy-Fixtures "foods"
		Edit-Csv "$from/Spell.csv" { param($rows) @() }
		Assert-Refused (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = (Join-Path $work "Empty.lua") }) "Spell has no rows"
	}
	Test-Case "update-foods.ps1 refuses tables that don't agree, such as a food spell missing from Spell" {
		$from = Copy-Fixtures "foods"
		Edit-Csv "$from/Spell.csv" { param($rows) $rows | Where-Object { $_.ID -ne "435" } }
		$output = Join-Path $work "Partial.lua"
		Assert-Refused (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = $output }) "Spell lacks food spells 435"
	}
	Test-Case "update-foods.ps1 refuses a result without any food" {
		$from = Copy-Fixtures "foods"
		Edit-Csv "$from/Spell.csv" { param($rows) $rows | ForEach-Object { $_.Description_lang = "Tastes odd."; $_ } }
		Assert-Refused (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = (Join-Path $work "None.lua") }) "No food spell could be converted"
	}
	Test-Case "update-foods.ps1 keeps the file when a food it had would go, unless told it is expected" {
		$from = Copy-Fixtures "foods"
		Edit-Csv "$from/Spell.csv" {
			param($rows) $rows | ForEach-Object { if ($_.ID -eq "432") { $_.Description_lang = "Restores some mana." }; $_ }
		}
		$output = Join-Path $work "Previous.lua"
		Copy-Item $foods $output
		$before = Get-FileHash $output
		Assert-Refused (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = $output }) "1 food spells would be removed"
		if ((Get-FileHash $output).Hash -ne $before.Hash) {
			throw "it changed $output"
		}
		Assert-Written (Invoke-Generator "update-foods.ps1" @{ From = $from; Output = $output; AcceptRemovals = $true })
		if (Select-String -Path $output -Pattern '\[432\]' -Quiet) {
			throw "432 is still there"
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
