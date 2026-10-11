# Builds the release files for the version in StatsTrimmer.toc:
# - .release/StatsTrimmer-v<version>.zip: the committed StatsTrimmer folder (HEAD), with LICENSE inside it;
# - .release/notes.md: the release notes, the CHANGELOG section "## v<version>" plus the installation steps.
# Fails if the version isn't X.Y.Z or the CHANGELOG has no section for it.
# Usage: ./scripts/package.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$addon = "StatsTrimmer"

Push-Location $root
try {
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
	git archive --format=zip --prefix="$addon/" --add-file=LICENSE -o (Join-Path $out $zipName) "HEAD:$addon"
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
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
