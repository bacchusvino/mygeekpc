@echo off
:: ============================================================================
:: MyGeekMac Remote Support Setup v2.1
:: ============================================================================
:: Double-click this file to configure your PC for remote support.
:: No typing required - just click Yes when Windows asks for permission.
:: ============================================================================

:: Request admin elevation silently
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Check if .ps1 file exists
if not exist "%~dp0MyGeekMac_Setup.ps1" (
    echo.
    echo ERROR: MyGeekMac_Setup.ps1 not found!
    echo Please download both files from mygeekpc.com/support.html
    echo.
    pause
    exit /b 1
)

:: Run the setup
powershell -ExecutionPolicy Bypass -File "%~dp0MyGeekMac_Setup.ps1"
pause
