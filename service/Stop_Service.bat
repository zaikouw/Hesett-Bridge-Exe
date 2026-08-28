@echo off
REM Hesett Print Bridge - Stop Service
REM Requires Administrator privileges

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

cd /d "%~dp0"
echo Stopping Hesett Print Bridge service...
"%~dp0hesett-print-bridge-service.exe" stop
echo.
echo Service stopped.
pause
