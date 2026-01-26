@echo off
:: MyGeekMac QuickConnect - ONE CLICK SETUP
:: Downloads and runs the full setup script

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_QuickConnect.ps1 | iex"
