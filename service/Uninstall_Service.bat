@echo off
REM Hesett Print Bridge - Windows Service Uninstaller
REM Requires Administrator privileges

echo ============================================================
echo  Hesett Print Bridge - Windows Service Uninstaller
echo ============================================================
echo.

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

cd /d "%~dp0"

if not exist "hesett-print-bridge-service.exe" (
    echo ERROR: hesett-print-bridge-service.exe not found.
    echo.
    pause
    exit /b 1
)

echo Stopping Hesett Print Bridge service...
"%~dp0hesett-print-bridge-service.exe" stop 2>nul

echo Uninstalling Hesett Print Bridge service...
"%~dp0hesett-print-bridge-service.exe" uninstall

echo.
echo ============================================================
echo  Uninstallation Complete
echo ============================================================
echo.
echo The Hesett Print Bridge service has been removed.
echo Log files in the logs\ folder have been preserved.
echo.
pause
