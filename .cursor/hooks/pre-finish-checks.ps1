# Legacy wrapper — prefer pre-finish-checks.cmd via hooks.json.
$ErrorActionPreference = "Stop"
& "$PSScriptRoot\pre-finish-checks.cmd"
exit $LASTEXITCODE
