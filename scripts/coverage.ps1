# Runs the unit tests under LuaCov and checks the line coverage of EasyStats/.
# Needs LuaJIT and LuaCov 0.17.0 in %LOCALAPPDATA%\Programs\luacov (see README).
# Usage: ./scripts/coverage.ps1 [-Minimum 85]
param([double]$Minimum = 85)

$root = Split-Path -Parent $PSScriptRoot
$luacov = (Join-Path $env:LOCALAPPDATA "Programs\luacov") -replace '\\', '/'
$setPath = "package.path='$luacov/?.lua;'..package.path"

Push-Location $root
try {
	Remove-Item luacov.stats.out, luacov.report.out -ErrorAction SilentlyContinue
	$specs = Get-ChildItem spec -Filter *_spec.lua | ForEach-Object { "spec/$($_.Name)" }

	# -joff: LuaJIT's compiled code doesn't fire the line hooks LuaCov counts with
	luajit -joff -e $setPath -lluacov spec/runner.lua @specs
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
	luajit -e $setPath "$luacov/bin/luacov"

	# The report ends with a Summary table: "<file> <hits> <missed> <coverage>%" rows and a Total row
	$summary = ((Get-Content luacov.report.out -Raw) -split '(?m)^Summary\s*$')[-1]
	$rows = $summary -split "`r?`n" | Where-Object { $_ -match '^(EasyStats[\\/]\S+|Total)\s+\d+\s+\d+\s+[\d.]+%' }
	$rows | ForEach-Object { $_ }

	$total = [double](($rows | Where-Object { $_ -like 'Total*' }) -replace '.*\s([\d.]+)%.*', '$1')
	if ($total -lt $Minimum) {
		Write-Output ("Coverage {0}% is below the {1}% minimum" -f $total, $Minimum)
		exit 1
	}
	Write-Output ("Coverage {0}% (minimum {1}%)" -f $total, $Minimum)
	exit 0
}
finally {
	Pop-Location
}
