$ErrorActionPreference = "Stop"

$scriptsDir = & python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
$gdlint = Join-Path $scriptsDir "gdlint.exe"

if (-not (Test-Path $gdlint)) {
	Write-Error "gdlint not found. Install with: python -m pip install -r requirements-dev.txt"
	exit 1
}

& $gdlint @args
exit $LASTEXITCODE
