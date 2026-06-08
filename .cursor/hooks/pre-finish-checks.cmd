@echo off
setlocal
set "HOOK_DIR=%~dp0"
set "ROOT=%HOOK_DIR%..\.."
cd /d "%ROOT%"
python "%HOOK_DIR%pre-finish-checks.py"
