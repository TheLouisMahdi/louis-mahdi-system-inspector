@echo off
setlocal
cd /d "%~dp0"
set "LOUISMAHDI_ICON_PATH=%~dp0assets\LouisMahdi_System_Inspector.ico"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Validate-Source.ps1" -SourcePath "%~dp0src\LouisMahdi.SystemInspector.ps1"
if errorlevel 1 goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0src\LouisMahdi.SystemInspector.ps1"
if errorlevel 1 goto :failed
exit /b 0
:failed
echo.
echo The application did not start because validation or execution failed.
pause
exit /b 1
