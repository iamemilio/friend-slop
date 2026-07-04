@echo off
setlocal
set "HOOK_DIR=%~dp0"
set "ROOT=%HOOK_DIR%..\.."
cd /d "%ROOT%"
if exist "%ROOT%\.venv\Scripts\python.exe" (
  "%ROOT%\.venv\Scripts\python.exe" "%HOOK_DIR%pre-finish-checks.py"
) else (
  python "%HOOK_DIR%pre-finish-checks.py"
)
