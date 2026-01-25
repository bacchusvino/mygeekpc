# MyGeekMac Remote Support Setup

## One-Liner Install (Paste in PowerShell as Admin)

```powershell
irm https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_Setup.ps1 | iex
```

Or the longer version:
```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_Setup.ps1' -OutFile "$env:TEMP\MyGeekMac_Setup.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\MyGeekMac_Setup.ps1"
```

## To Remove Access Later

```powershell
irm https://raw.githubusercontent.com/bacchusvino/mygeekpc/main/MyGeekMac_Remove.ps1 | iex
```

## Files

- `MyGeekMac_Setup.ps1` - Main setup script
- `MyGeekMac_Setup.bat` - Launcher for double-click install  
- `MyGeekMac_Remove.bat` - Revoke access script
- `install.bat` - One-click installer that downloads from GitHub
