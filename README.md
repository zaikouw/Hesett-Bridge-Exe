# Hesett Print Bridge (Windows .exe)

This repo builds the **Hesett Print Bridge** Windows executable so you can send it to clients who need printing from [business.hesett.com](https://business.hesett.com).

## Get the .exe

1. Go to the **Actions** tab on GitHub.
2. Open **"Build Windows .exe"** in the left sidebar.
3. Click **"Run workflow"** (or use the latest run from a push).
4. When the job finishes, download the **Artifact** `hesett-print-bridge-windows` (zip containing `hesett_print_bridge.exe`).

## Send to a client

1. Download the artifact and unzip it to get **hesett_print_bridge.exe**.
2. Send the client:
   - **hesett_print_bridge.exe**
   - **Run_Print_Bridge.bat** (from this repo)
3. Tell the client: put both files in the same folder, then double-click **Run_Print_Bridge.bat** and leave the window open. Then open business.hesett.com → Printing settings → Check bridge.

## Build locally (on Windows)

```powershell
dart pub get
dart compile exe bin/server.dart -o hesett_print_bridge.exe
```

## License

Part of Hesett. Use for Hesett printing only.
