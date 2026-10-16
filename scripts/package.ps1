# Builds the release files for the version in StatsTrimmer.toc:
# - .release/StatsTrimmer-v<version>.zip: the committed StatsTrimmer folder (HEAD), with LICENSE inside it;
# - .release/notes.md: the release notes, the CHANGELOG section "## v<version>" plus the installation steps.
# Fails if the version isn't X.Y.Z, the CHANGELOG has no section for it, or StatsTrimmer/, CHANGELOG.md or LICENSE
# have changes that aren't committed: the zip is the committed code, so the version, the notes and the zip would
# come from different states. The finished zip is checked too: the version of its .toc, every file the .toc
# loads, and LICENSE.
# Usage: ./scripts/package.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$addon = "StatsTrimmer"

Push-Location $root
try {
	$pending = @(git status --porcelain -- $addon CHANGELOG.md LICENSE)
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
	if ($pending.Count -gt 0) {
		throw "Commit these first, the zip is the committed code:`n$($pending -join "`n")"
	}

	$versionLine = Select-String -Path "$addon/$addon.toc" -Pattern '^## Version:\s*(\d+\.\d+\.\d+)\s*$' |
		Select-Object -First 1
	if (-not $versionLine) {
		throw "$addon.toc needs a '## Version: X.Y.Z' line"
	}
	$version = $versionLine.Matches[0].Groups[1].Value
	$tag = "v$version"
	$zipName = "$addon-$tag.zip"

	# The section runs from its "## v<version>" heading to the next "## " heading
	$changelog = @(Get-Content CHANGELOG.md)
	$heading = "^## $([regex]::Escape($tag))(\s|$)"
	$start = -1
	for ($i = 0; $i -lt $changelog.Count; $i++) {
		if ($changelog[$i] -match $heading) {
			$start = $i
			break
		}
	}
	if ($start -lt 0) {
		throw "CHANGELOG.md has no '## $tag' section: rename '## Unreleased' to '## $tag (<date>)'"
	}
	$end = $changelog.Count
	for ($i = $start + 1; $i -lt $changelog.Count; $i++) {
		if ($changelog[$i] -match '^## ') {
			$end = $i
			break
		}
	}
	$section = ""
	if ($end -gt $start + 1) {
		$section = ($changelog[($start + 1)..($end - 1)] -join "`n").Trim()
	}
	if (-not $section) {
		throw "The '## $tag' section of CHANGELOG.md is empty"
	}

	$notes = @"
$section

## Installation

1. Download ``$zipName`` below.
2. Extract it into the Forever client's ``Interface\AddOns`` folder. You should end up with ``World of Warcraft\_classic_beta_\Interface\AddOns\$addon\$addon.toc``.
3. Restart the game.
"@

	$out = Join-Path $root ".release"
	New-Item -ItemType Directory -Force $out | Out-Null
	[IO.File]::WriteAllText((Join-Path $out "notes.md"), "$notes`n")

	# git archive only takes committed files, with the LF line endings of .gitattributes
	$zipPath = Join-Path $out $zipName
	git archive --format=zip --prefix="$addon/" --add-file=LICENSE -o $zipPath "HEAD:$addon"
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	# What the player extracts: the addon's folder, whose .toc has this version and loads files that are there
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
	try {
		$names = @($zip.Entries | ForEach-Object { $_.FullName })
		$outside = @($names | Where-Object { -not $_.StartsWith("$addon/") })
		$toc = $zip.GetEntry("$addon/$addon.toc")
		if ($outside.Count -gt 0 -or -not $toc) {
			throw "$zipName needs $addon/$addon.toc and nothing outside $addon/: it has $($names -join ', ')"
		}
		$reader = [IO.StreamReader]::new($toc.Open())
		$tocLines = $reader.ReadToEnd() -split "`r?`n"
		$reader.Dispose()
		$zipVersion = ($tocLines | Where-Object { $_ -match '^## Version:\s*(\S+)' } | Select-Object -First 1) -replace '^## Version:\s*', ''
		if ($zipVersion -ne $version) {
			throw "$zipName's .toc says version '$zipVersion', not $version"
		}
		$missing = @($tocLines | Where-Object { $_ -match '^[^#\s].*\.(lua|xml)\s*$' } | ForEach-Object { $_.Trim() } |
				Where-Object { $names -notcontains "$addon/$_" })
		if (-not ($names -contains "$addon/LICENSE")) {
			$missing += "LICENSE"
		}
		if ($missing.Count -gt 0) {
			throw "$zipName lacks $($missing -join ', ')"
		}
	}
	finally {
		$zip.Dispose()
	}

	if ($env:GITHUB_OUTPUT) {
		"version=$version" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
	}
	Write-Output "Built .release/$zipName and .release/notes.md"
	exit 0
}
finally {
	Pop-Location
}
