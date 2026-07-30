@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Validate-Source.ps1" -SourcePath "%~dp0src\LouisMahdi.SystemInspector.ps1"
if errorlevel 1 goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Validate-Launcher.ps1" -LauncherPath "%~dp0docs\LouisMahdiHost.cs" -BuilderPath "%~dp0Build_LouisMahdi_System_Inspector_ONE_FILE.bat"
if errorlevel 1 goto :failed
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Run-MockTests.ps1"
if errorlevel 1 goto :failed
echo.
echo All validation stages passed.
pause
exit /b 0
:failed
echo.
echo Validation failed. No build should be distributed.
pause
exit /b 1
