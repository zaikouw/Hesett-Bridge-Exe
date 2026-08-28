# Hesett Print Bridge (Windows .exe)

This repo builds the **Hesett Print Bridge** Windows executable so you can send it to clients who need printing from [business.hesett.com](https://business.hesett.com).

## Get the package

1. Go to the **Actions** tab on GitHub.
2. Open **"Build Windows .exe"** in the left sidebar.
3. Click **"Run workflow"** (or use the latest run from a push).
4. When the job finishes, download the **Artifact** `hesett-print-bridge-windows` (zip containing all files).

## Installation Options

### Option A: Windows Service (Recommended for Production)

The Windows service runs in the background, starts automatically on boot, and restarts on crash.

1. **Download and extract** the artifact zip to a permanent location (e.g., `C:\HesettPrintBridge\`).
2. **Right-click `Install_Service.bat`** → **Run as administrator**.
3. The service is now running and will auto-start on boot.

**Service details:**
- **Bind address:** `0.0.0.0:7171` (accessible from LAN devices like iPads)
- **Auto-start:** Yes (starts when Windows boots)
- **Crash recovery:** Yes (restarts automatically on failure)
- **Origin allowlist:** Restricts access to `business.hesett.com` and localhost dev servers

**Managing the service:**
- Use `Check_Service_Status.bat` to see if it's running
- Use `Stop_Service.bat` / `Start_Service.bat` to control it
- Or use Windows Services (`services.msc`) → look for "Hesett Print Bridge"
- Or use command line: `sc query HesettPrintBridge`

**Uninstalling:**
- Run `Uninstall_Service.bat` as administrator

### Option B: Manual Launch (Quick Testing)

For quick testing without installing a service:

1. **Download and extract** the artifact zip.
2. **Double-click `Run_Print_Bridge.bat`** and leave the window open.
3. The bridge runs until you close the window.

**Note:** This binds to `0.0.0.0:7171` (LAN-accessible). For localhost-only debugging, use `Run_Print_Bridge_Debug.bat` instead.

## Network Configuration

The bridge binds to `0.0.0.0:7171` by default, making it accessible from any device on the local network (iPads, other computers, etc.).

**Origin allowlist:** Only these origins can connect:
- `https://business.hesett.com` (production dashboard)
- `http://localhost:8080`, `http://localhost:3000`, `http://localhost:5000` (local development)

The allowlist protects against unauthorized access from other websites.

## Test Restaurant

For testing, use **Hesett Restaurant** as the test restaurant. Do not configure production client IDs in test builds.

## Build locally (on Windows)

```powershell
dart pub get
dart compile exe bin/server.dart -o hesett_print_bridge.exe
```

## Package Contents

After downloading the artifact:

| File | Purpose |
|------|---------|
| `hesett_print_bridge.exe` | Main print bridge executable |
| `Run_Print_Bridge.bat` | Manual launcher (LAN-accessible) |
| `Run_Print_Bridge_Debug.bat` | Debug launcher (localhost-only) |
| `hesett-print-bridge-service.exe` | WinSW service wrapper |
| `hesett-print-bridge-service.xml` | Service configuration |
| `Install_Service.bat` | Install as Windows service |
| `Uninstall_Service.bat` | Remove Windows service |
| `Start_Service.bat` | Start the service |
| `Stop_Service.bat` | Stop the service |
| `Check_Service_Status.bat` | Check if service is running |

## License

Part of Hesett. Use for Hesett printing only.
