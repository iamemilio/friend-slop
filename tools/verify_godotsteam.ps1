# Verifies GodotSteam GDExtension layout.
# Run from repo root: powershell -ExecutionPolicy Bypass -File tools/verify_godotsteam.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AddonsDir = Join-Path $Root "addons\godotsteam"
$Gde = Join-Path $AddonsDir "godotsteam.gdextension"
$LinuxLib = Join-Path $AddonsDir "linux64\libgodotsteam.linux.template_debug.x86_64.so"
$WindowsLib = Join-Path $AddonsDir "win64\libgodotsteam.windows.template_debug.x86_64.dll"
$AppId = Join-Path $Root "steam_appid.txt"

if (-not (Test-Path $Gde)) {
	Write-Error "GodotSteam not installed. Run make setup-steam first."
}
if (-not (Test-Path $LinuxLib)) {
	Write-Error "GodotSteam Linux libraries missing. Re-run make setup-steam."
}
if (-not (Test-Path $WindowsLib)) {
	Write-Error "GodotSteam Windows libraries missing. Re-run make setup-steam."
}
if (-not (Test-Path $AppId)) {
	Write-Error "steam_appid.txt missing at repo root."
}

$VersionsFile = Join-Path $Root "tools\versions.env"
$Version = ""
$ReleaseTag = ""
foreach ($line in Get-Content $VersionsFile) {
	$trimmed = $line.Trim()
	if ($trimmed -match "^GODOTSTEAM_VERSION=(.+)$") { $Version = $Matches[1] }
	if ($trimmed -match "^GODOTSTEAM_GDE_RELEASE_TAG=(.+)$") { $ReleaseTag = $Matches[1] }
}

Write-Host "GodotSteam OK ($Version, $ReleaseTag)"
