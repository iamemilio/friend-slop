$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$PythonScript = Join-Path $PSScriptRoot "run_checks.py"
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (Test-Path $VenvPython) {
	& $VenvPython $PythonScript
} else {
	python $PythonScript
}
exit $LASTEXITCODE
