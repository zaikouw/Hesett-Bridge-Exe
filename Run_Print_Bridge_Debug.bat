@echo off
title Hesett Print Bridge (Debug - localhost only)
cd /d "%~dp0"

if not exist "hesett_print_bridge.exe" (
    echo hesett_print_bridge.exe not found in this folder.
    echo Please put the .exe in the same folder as this .bat file.
    echo.
    pause
    exit /b 1
)

echo ============================================================
echo DEBUG MODE - Binding to localhost only (127.0.0.1)
echo LAN devices will NOT be able to connect.
echo Use Run_Print_Bridge.bat for production/LAN access.
echo ============================================================
echo.

"%~dp0hesett_print_bridge.exe" --host 127.0.0.1 --port 7171 --allowed-origins "https://business.hesett.com,http://localhost:8080,http://localhost:3000,http://localhost:5000" --verbose

echo.
echo Press any key to close...
pause >nul
