@echo off
:: ============================================================================
:: MyGeekMac Remote Support - One-Click Installer
:: ============================================================================
:: This downloads and runs the setup scripts from GitHub
:: ============================================================================

:: Request admin elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Create temp directory
set "MYGEEK=%TEMP%\MyGeekMac"
if not exist "%MYGEEK%" mkdir "%MYGEEK%"

echo.
echo Downloading MyGeekMac Setup...
echo.

:: Download both files from GitHub raw
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_Setup.ps1' -OutFile '%MYGEEK%\MyGeekMac_Setup.ps1'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_Remove.bat' -OutFile '%MYGEEK%\MyGeekMac_Remove.bat'"

:: Run the setup
powershell -ExecutionPolicy Bypass -File "%MYGEEK%\MyGeekMac_Setup.ps1"

echo.
echo Removal script saved to: %MYGEEK%\MyGeekMac_Remove.bat
echo.
pause
