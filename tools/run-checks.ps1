$ErrorActionPreference = "Stop"

$PythonScript = Join-Path $PSScriptRoot "run_checks.py"
python $PythonScript
exit $LASTEXITCODE
