# Intune Device Sync Toolkit

PowerShell tools for managing Microsoft Intune device synchronization. Includes an interactive terminal GUI menu plus individual scripts for bulk syncing Windows, macOS, iOS/iPadOS, and Android devices. Supports CSV imports, quick device lookup, and sync status checking.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

## 🚀 Quick Start

```powershell
# Run the interactive menu tool
.\Intune-Sync-Tool.ps1
```

## 📋 Features

- **Interactive Terminal GUI** - Color-coded menu with ASCII art banner
- **Bulk Platform Sync** - Sync all devices by OS (Windows, macOS, iOS, Android)
- **Quick Device Operations** - Sync or check status of individual devices by name
- **CSV File Import** - Bulk sync devices from a CSV file
- **Cross-Version Support** - Works with PowerShell 5.1 and 7+
- **Comprehensive Logging** - All operations logged to file

## 📁 Scripts Included

| Script | Description |
|--------|-------------|
| `Intune-Sync-Tool.ps1` | **Main tool** - Interactive terminal GUI with all options |
| `Sync-AllWindowsDevices.ps1` | Sync all Windows devices in tenant |
| `Sync-AllMacOSDevices.ps1` | Sync all macOS devices in tenant |
| `Sync-AlliOSDevices.ps1` | Sync all iOS and iPadOS devices in tenant |
| `Sync-AllAndroidDevices.ps1` | Sync all Android devices in tenant |
| `SyncDevicesFromCSV.ps1` | Sync specific devices from CSV file |
| `Quick-DeviceSync.ps1` | Interactive quick sync by device name |
| `Quick-DeviceSync-Check.ps1` | Check sync status of specific devices |

## 🖥️ Interactive Menu

```
╔══════════════════════════════════════════════════════════════════╗
║      ██╗███╗   ██╗████████╗██╗   ██╗███╗   ██╗███████╗           ║
║      ██║████╗  ██║╚══██╔══╝██║   ██║████╗  ██║██╔════╝           ║
║      ██║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║█████╗             ║
║      ██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██╔══╝             ║
║      ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║███████╗           ║
║      ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝           ║
║          ███████╗██╗   ██╗███╗   ██╗ ██████╗                     ║
║          ██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝                     ║
║          ███████╗ ╚████╔╝ ██╔██╗ ██║██║                          ║
║          ╚════██║  ╚██╔╝  ██║╚██╗██║██║                          ║
║          ███████║   ██║   ██║ ╚████║╚██████╗                     ║
║          ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝                     ║
║                    Device Sync Management Tool                   ║
╚══════════════════════════════════════════════════════════════════╝

  BULK SYNC BY PLATFORM:
    [1]  Sync All Windows Devices
    [2]  Sync All macOS Devices
    [3]  Sync All iOS/iPadOS Devices
    [4]  Sync All Android Devices
    [5]  Sync ALL Devices (All Platforms)

  INDIVIDUAL DEVICE OPERATIONS:
    [6]  Quick Device Sync (by name)
    [7]  Check Device Sync Status

  BULK OPERATIONS:
    [8]  Sync Devices from CSV File

    [Q]  Quit
```

## ⚙️ Requirements

### PowerShell Modules
- **PowerShell 7+**: `Microsoft.Graph.Authentication`, `Microsoft.Graph.DeviceManagement`
- **PowerShell 5.1**: `Microsoft.Graph.Intune`

### Microsoft Entra ID Permissions
- `DeviceManagementManagedDevices.PrivilegedOperations.All`
- `DeviceManagementManagedDevices.Read.All`

## 📖 Usage Examples

### Interactive Menu Tool
```powershell
# Launch the interactive menu
.\Intune-Sync-Tool.ps1

# With custom log path
.\Intune-Sync-Tool.ps1 -LogPath "C:\Logs\SyncTool.log"
```

### Individual Scripts
```powershell
# Sync all Windows devices
.\Sync-AllWindowsDevices.ps1

# Sync all macOS devices with custom log
.\Sync-AllMacOSDevices.ps1 -LogPath "C:\Logs\MacSync.log"

# Sync devices from CSV file
.\SyncDevicesFromCSV.ps1 -CsvFile "C:\devices.csv" -CsvColumn "DeviceName"
```

## 📝 CSV File Format

Your CSV file should have a column containing device names:

```csv
DeviceName,Department,User
PC-WIN-001,IT,john.doe@company.com
PC-WIN-002,HR,jane.smith@company.com
IPHONE-001,Sales,bob.wilson@company.com
```

Then run:
```powershell
.\SyncDevicesFromCSV.ps1 -CsvFile "devices.csv" -CsvColumn "DeviceName"
```

## 📄 Log Files

Default log locations:
- Main Tool: `C:\temp\IntuneSyncTool.log`
- Windows Sync: `C:\temp\WindowsDeviceSync.log`
- macOS Sync: `C:\temp\MacOSDeviceSync.log`
- iOS Sync: `C:\temp\iOSDeviceSync.log`
- Android Sync: `C:\temp\AndroidDeviceSync.log`
- CSV Sync: `C:\temp\IntuneDeviceSync.log`

## 🔐 Authentication

All scripts use Microsoft Graph authentication. On first run, you'll be prompted to sign in with an account that has the required Intune permissions. The interactive tool maintains the connection across all operations.

## 📜 License

MIT License - Feel free to use and modify as needed.

## 🤝 Contributing

Contributions welcome! Feel free to submit issues and pull requests.

---

**Author:** Mark Orr
