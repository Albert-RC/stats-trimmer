# Runs the unit tests in spec/ with LuaJIT (Lua 5.1 compatible) and the busted-style runner.
# Usage: ./scripts/test.ps1
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	$specs = Get-ChildItem spec -Filter *_spec.lua | ForEach-Object { "spec/$($_.Name)" }
	luajit spec/runner.lua @specs
	exit $LASTEXITCODE
}
finally {
	Pop-Location
}
