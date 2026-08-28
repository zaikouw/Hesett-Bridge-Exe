@echo off
REM Hesett Print Bridge - Windows Service Installer
REM Requires Administrator privileges

echo ============================================================
echo  Hesett Print Bridge - Windows Service Installer
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

REM Check required files exist
if not exist "hesett-print-bridge-service.exe" (
    echo ERROR: hesett-print-bridge-service.exe not found.
    echo Please ensure the WinSW service wrapper is in this folder.
    echo.
    pause
    exit /b 1
)

if not exist "hesett_print_bridge.exe" (
    echo ERROR: hesett_print_bridge.exe not found.
    echo Please ensure the print bridge executable is in this folder.
    echo.
    pause
    exit /b 1
)

if not exist "hesett-print-bridge-service.xml" (
    echo ERROR: hesett-print-bridge-service.xml not found.
    echo Please ensure the service configuration is in this folder.
    echo.
    pause
    exit /b 1
)

REM Create logs directory
if not exist "logs" mkdir logs

echo Installing Hesett Print Bridge service...
echo.

REM Install the service
"%~dp0hesett-print-bridge-service.exe" install
if %errorLevel% neq 0 (
    echo.
    echo ERROR: Service installation failed.
    echo Check if the service is already installed (use Uninstall_Service.bat first).
    echo.
    pause
    exit /b 1
)

echo.
echo Starting the service...
"%~dp0hesett-print-bridge-service.exe" start

echo.
echo ============================================================
echo  Installation Complete!
echo ============================================================
echo.
echo The Hesett Print Bridge is now running as a Windows service.
echo.
echo  - Service Name: Hesett Print Bridge
echo  - Bind Address: 0.0.0.0:7171 (accessible on LAN)
echo  - Auto-start:   Enabled (starts on boot)
echo  - Crash restart: Enabled
echo.
echo You can manage the service via:
echo  - Windows Services (services.msc)
echo  - "sc query HesettPrintBridge" / "sc stop HesettPrintBridge"
echo  - Or use Start_Service.bat / Stop_Service.bat
echo.
pause
