# ============================================================
# Intune-Sync-Tool.ps1
# ============================================================
#
# DESCRIPTION:
# A comprehensive terminal GUI tool for managing Intune device sync operations.
# Provides a menu-driven interface to access all sync scripts in one place.
#
# AUTHOR: Mark Orr
# DATE: 12/24/2024
#
# FEATURES:
# - Interactive terminal menu with color-coded options
# - Sync all devices by platform (Windows, macOS, iOS, Android)
# - Quick device sync by name
# - Device sync status checker
# - CSV-based bulk device sync
# - Single authentication for all operations
#
# REQUIREMENTS:
# - Microsoft.Graph.Authentication module (PS 7+) OR
# - Microsoft.Graph.Intune module (PS 5.1)
# - Appropriate Intune permissions in Entra ID
#
# ============================================================

param(
    [string]$LogPath = "C:\temp\IntuneSyncTool.log"
)

# Script root for calling other scripts
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    
    if (-not $NoConsole) {
        $Color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "White" }
            default { "White" }
        }
        Write-Host $LogEntry -ForegroundColor $Color
    }
    
    if ($LogPath) {
        try {
            $LogDir = Split-Path $LogPath -Parent
            if (-not (Test-Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $LogEntry
        } catch {
            # Silently fail logging
        }
    }
}

function Show-Banner {
    Clear-Host
    $banner = @"

    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║      ██╗███╗   ██╗████████╗██╗   ██╗███╗   ██╗███████╗           ║
    ║      ██║████╗  ██║╚══██╔══╝██║   ██║████╗  ██║██╔════╝           ║
    ║      ██║██╔██╗ ██║   ██║   ██║   ██║██╔██╗ ██║█████╗             ║
    ║      ██║██║╚██╗██║   ██║   ██║   ██║██║╚██╗██║██╔══╝             ║
    ║      ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚████║███████╗           ║
    ║      ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝           ║
    ║                                                                  ║
    ║          ███████╗██╗   ██╗███╗   ██╗ ██████╗                     ║
    ║          ██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝                     ║
    ║          ███████╗ ╚████╔╝ ██╔██╗ ██║██║                          ║
    ║          ╚════██║  ╚██╔╝  ██║╚██╗██║██║                          ║
    ║          ███████║   ██║   ██║ ╚████║╚██████╗                     ║
    ║          ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝                     ║
    ║                                                                  ║
    ║                    Device Sync Management Tool                   ║
    ╚══════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-MainMenu {
    Write-Host ""
    Write-Host "  ┌────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │                        " -ForegroundColor DarkGray -NoNewline
    Write-Host "MAIN MENU" -ForegroundColor Yellow -NoNewline
    Write-Host "                             │" -ForegroundColor DarkGray
    Write-Host "  ├────────────────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │  " -ForegroundColor DarkGray -NoNewline
    Write-Host "BULK SYNC BY PLATFORM:" -ForegroundColor White -NoNewline
    Write-Host "                                        │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "1" -ForegroundColor Green -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync All Windows Devices" -ForegroundColor White -NoNewline
    Write-Host "                              │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "2" -ForegroundColor Green -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync All macOS Devices" -ForegroundColor White -NoNewline
    Write-Host "                                │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "3" -ForegroundColor Green -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync All iOS/iPadOS Devices" -ForegroundColor White -NoNewline
    Write-Host "                           │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "4" -ForegroundColor Green -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync All Android Devices" -ForegroundColor White -NoNewline
    Write-Host "                              │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "5" -ForegroundColor Green -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync ALL Devices (All Platforms)" -ForegroundColor Magenta -NoNewline
    Write-Host "                      │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │  " -ForegroundColor DarkGray -NoNewline
    Write-Host "INDIVIDUAL DEVICE OPERATIONS:" -ForegroundColor White -NoNewline
    Write-Host "                                 │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "6" -ForegroundColor Cyan -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Quick Device Sync (by name)" -ForegroundColor White -NoNewline
    Write-Host "                           │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "7" -ForegroundColor Cyan -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Check Device Sync Status" -ForegroundColor White -NoNewline
    Write-Host "                              │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │  " -ForegroundColor DarkGray -NoNewline
    Write-Host "BULK OPERATIONS:" -ForegroundColor White -NoNewline
    Write-Host "                                              │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "8" -ForegroundColor Yellow -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Sync Devices from CSV File" -ForegroundColor White -NoNewline
    Write-Host "                            │" -ForegroundColor DarkGray
    Write-Host "  │                                                                │" -ForegroundColor DarkGray
    Write-Host "  ├────────────────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │    [" -ForegroundColor DarkGray -NoNewline
    Write-Host "Q" -ForegroundColor Red -NoNewline
    Write-Host "]  " -ForegroundColor DarkGray -NoNewline
    Write-Host "Quit" -ForegroundColor Red -NoNewline
    Write-Host "                                                    │" -ForegroundColor DarkGray
    Write-Host "  └────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-ConnectionStatus {
    param([bool]$Connected)
    
    if ($Connected) {
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "●" -NoNewline -ForegroundColor Green
        Write-Host "] Connected to Microsoft Graph" -ForegroundColor Green
    } else {
        Write-Host "  [" -NoNewline -ForegroundColor DarkGray
        Write-Host "○" -NoNewline -ForegroundColor Red
        Write-Host "] Not connected - Will authenticate on first operation" -ForegroundColor Yellow
    }
}

function Confirm-Action {
    param([string]$Message)
    
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "  Press " -NoNewline -ForegroundColor White
    Write-Host "Y" -NoNewline -ForegroundColor Green
    Write-Host " to continue or " -NoNewline -ForegroundColor White
    Write-Host "N" -NoNewline -ForegroundColor Red
    Write-Host " to cancel: " -NoNewline -ForegroundColor White
    
    $response = Read-Host
    return ($response -eq 'Y' -or $response -eq 'y')
}

function Press-AnyKey {
    Write-Host ""
    Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ============================================================
# GRAPH CONNECTION
# ============================================================

$script:GraphConnected = $false

function Connect-ToGraphIfNeeded {
    if ($script:GraphConnected) {
        return $true
    }
    
    Write-Host ""
    Write-Host "  Connecting to Microsoft Graph..." -ForegroundColor Cyan
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Import-Module Microsoft.Graph.Authentication -Force -ErrorAction SilentlyContinue
            Import-Module Microsoft.Graph.DeviceManagement -Force -ErrorAction SilentlyContinue
            Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All", "DeviceManagementManagedDevices.Read.All" -NoWelcome
        } else {
            Import-Module Microsoft.Graph.Intune -Force -ErrorAction SilentlyContinue
            if(!(Connect-MSGraph)){
                Connect-MSGraph
            }
        }
        
        $script:GraphConnected = $true
        Write-Host "  ✓ Successfully connected to Microsoft Graph" -ForegroundColor Green
        Write-Log "Connected to Microsoft Graph" -Level "SUCCESS" -NoConsole
        Start-Sleep -Seconds 1
        return $true
    } catch {
        Write-Host "  ✗ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Failed to connect to Microsoft Graph: $_" -Level "ERROR" -NoConsole
        return $false
    }
}

function Disconnect-FromGraph {
    if ($script:GraphConnected) {
        try {
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            $script:GraphConnected = $false
            Write-Host "  Disconnected from Microsoft Graph" -ForegroundColor Yellow
        } catch {
            # Silently fail
        }
    }
}

# ============================================================
# DEVICE OPERATIONS
# ============================================================

function Get-AllDevicesByOS {
    param([string]$OperatingSystem)
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
            
            if ($OperatingSystem -eq "iOS") {
                return $AllDevices | Where-Object { $_.OperatingSystem -eq "iOS" -or $_.OperatingSystem -eq "iPadOS" }
            } else {
                return $AllDevices | Where-Object { $_.OperatingSystem -eq $OperatingSystem }
            }
        } else {
            if ($OperatingSystem -eq "iOS") {
                return Get-IntuneManagedDevice -Filter "operatingsystem eq 'iOS' or operatingsystem eq 'iPadOS'" | Get-MSGraphAllPages
            } else {
                return Get-IntuneManagedDevice -Filter "operatingsystem eq '$OperatingSystem'" | Get-MSGraphAllPages
            }
        }
    } catch {
        Write-Host "  ✗ Error retrieving devices: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Sync-SingleDevice {
    param(
        [string]$DeviceId,
        [string]$DeviceName
    )
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $SyncUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/syncDevice"
            Invoke-MgGraphRequest -Uri $SyncUri -Method POST -ErrorAction Stop
        } else {
            Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $DeviceId -ErrorAction Stop
        }
        return $true
    } catch {
        return $false
    }
}

function Invoke-BulkSync {
    param(
        [string]$OperatingSystem,
        [string]$DisplayName
    )
    
    if (-not (Connect-ToGraphIfNeeded)) { return }
    
    Write-Host ""
    Write-Host "  Retrieving $DisplayName devices..." -ForegroundColor Cyan
    
    $Devices = Get-AllDevicesByOS -OperatingSystem $OperatingSystem
    
    if ($Devices.Count -eq 0) {
        Write-Host "  No $DisplayName devices found in tenant." -ForegroundColor Yellow
        return
    }
    
    Write-Host "  Found " -NoNewline -ForegroundColor White
    Write-Host "$($Devices.Count)" -NoNewline -ForegroundColor Green
    Write-Host " $DisplayName devices" -ForegroundColor White
    
    if (-not (Confirm-Action "This will sync all $($Devices.Count) $DisplayName devices.")) {
        Write-Host "  Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "  Starting sync operation..." -ForegroundColor Cyan
    Write-Host ""
    
    $Synced = 0
    $Failed = 0
    $Counter = 0
    $Total = $Devices.Count
    
    foreach ($Device in $Devices) {
        $Counter++
        
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $DeviceName = $Device.DeviceName
            $DeviceId = $Device.Id
            $User = $Device.UserPrincipalName
        } else {
            $DeviceName = $Device.deviceName
            $DeviceId = $Device.managedDeviceId
            $User = $Device.userPrincipalName
        }
        
        # Progress bar
        $PercentComplete = [math]::Round(($Counter / $Total) * 100)
        $ProgressBar = "█" * [math]::Floor($PercentComplete / 5) + "░" * (20 - [math]::Floor($PercentComplete / 5))
        Write-Host "`r  [$ProgressBar] $PercentComplete% - Syncing: $DeviceName                    " -NoNewline -ForegroundColor Cyan
        
        if (Sync-SingleDevice -DeviceId $DeviceId -DeviceName $DeviceName) {
            $Synced++
            Write-Log "Synced: $DeviceName (User: $User)" -Level "SUCCESS" -NoConsole
        } else {
            $Failed++
            Write-Log "Failed to sync: $DeviceName" -Level "ERROR" -NoConsole
        }
        
        Start-Sleep -Milliseconds 300
    }
    
    Write-Host ""
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host "  ║           " -ForegroundColor DarkGray -NoNewline
    Write-Host "SYNC COMPLETE" -ForegroundColor Green -NoNewline
    Write-Host "              ║" -ForegroundColor DarkGray
    Write-Host "  ╠════════════════════════════════════════╣" -ForegroundColor DarkGray
    Write-Host "  ║  Total Devices:    " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-18}" -f $Total) -ForegroundColor White -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Synced:           " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-18}" -f $Synced) -ForegroundColor Green -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Failed:           " -ForegroundColor DarkGray -NoNewline
    $FailedColor = if ($Failed -gt 0) { "Red" } else { "Green" }
    Write-Host ("{0,-18}" -f $Failed) -ForegroundColor $FailedColor -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor DarkGray
}

function Invoke-SyncAllPlatforms {
    if (-not (Connect-ToGraphIfNeeded)) { return }
    
    if (-not (Confirm-Action "This will sync ALL devices across ALL platforms. This may take a while.")) {
        Write-Host "  Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "                    SYNCING ALL PLATFORMS" -ForegroundColor Magenta
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    
    $Platforms = @(
        @{ OS = "Windows"; Name = "Windows" },
        @{ OS = "macOS"; Name = "macOS" },
        @{ OS = "iOS"; Name = "iOS/iPadOS" },
        @{ OS = "Android"; Name = "Android" }
    )
    
    $GrandTotal = 0
    $GrandSynced = 0
    $GrandFailed = 0
    
    foreach ($Platform in $Platforms) {
        Write-Host ""
        Write-Host "  ─── $($Platform.Name) ───" -ForegroundColor Yellow
        
        $Devices = Get-AllDevicesByOS -OperatingSystem $Platform.OS
        
        if ($Devices.Count -eq 0) {
            Write-Host "  No devices found" -ForegroundColor DarkGray
            continue
        }
        
        Write-Host "  Found $($Devices.Count) devices" -ForegroundColor White
        
        $Counter = 0
        $Total = $Devices.Count
        $Synced = 0
        $Failed = 0
        
        foreach ($Device in $Devices) {
            $Counter++
            
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $DeviceName = $Device.DeviceName
                $DeviceId = $Device.Id
            } else {
                $DeviceName = $Device.deviceName
                $DeviceId = $Device.managedDeviceId
            }
            
            $PercentComplete = [math]::Round(($Counter / $Total) * 100)
            Write-Host "`r  Progress: $Counter/$Total ($PercentComplete%)          " -NoNewline -ForegroundColor Cyan
            
            if (Sync-SingleDevice -DeviceId $DeviceId -DeviceName $DeviceName) {
                $Synced++
            } else {
                $Failed++
            }
            
            Start-Sleep -Milliseconds 200
        }
        
        Write-Host "`r  ✓ Synced: $Synced | Failed: $Failed                    " -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Yellow" })
        
        $GrandTotal += $Total
        $GrandSynced += $Synced
        $GrandFailed += $Failed
    }
    
    Write-Host ""
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  GRAND TOTAL: $GrandTotal devices | Synced: $GrandSynced | Failed: $GrandFailed" -ForegroundColor White
    Write-Host "  ═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
}

function Invoke-QuickDeviceSync {
    if (-not (Connect-ToGraphIfNeeded)) { return }
    
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         QUICK DEVICE SYNC              ║" -ForegroundColor Cyan
    Write-Host "  ║  Type device names to sync them        ║" -ForegroundColor Cyan
    Write-Host "  ╠════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  " -ForegroundColor Cyan -NoNewline
    Write-Host "[Q]" -ForegroundColor Yellow -NoNewline
    Write-Host " or " -ForegroundColor Cyan -NoNewline
    Write-Host "[done]" -ForegroundColor Yellow -NoNewline
    Write-Host " to return to menu      ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
    
    do {
        Write-Host ""
        Write-Host "  Enter device name: " -NoNewline -ForegroundColor White
        $deviceName = Read-Host
        
        if ($deviceName -eq 'done' -or $deviceName -eq 'quit' -or $deviceName -eq 'exit' -or $deviceName -eq 'q') {
            break
        }
        
        if ([string]::IsNullOrWhiteSpace($deviceName)) {
            continue
        }
        
        Write-Host "  Searching for: $deviceName..." -ForegroundColor Cyan
        
        try {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
                $device = $AllDevices | Where-Object { $_.DeviceName -eq $deviceName }
                
                if ($device) {
                    $DeviceId = $device.Id
                    $OS = $device.OperatingSystem
                    $User = $device.UserPrincipalName
                }
            } else {
                $AllDevices = Get-IntuneManagedDevice | Get-MSGraphAllPages
                $device = $AllDevices | Where-Object { $_.deviceName -eq $deviceName }
                
                if ($device) {
                    $DeviceId = $device.managedDeviceId
                    $OS = $device.operatingSystem
                    $User = $device.userPrincipalName
                }
            }
            
            if ($device) {
                # Get last sync time
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $LastSync = $device.LastSyncDateTime
                } else {
                    $LastSync = $device.lastSyncDateTime
                }
                
                # Format last sync display
                if ($LastSync) {
                    $timeDiff = (Get-Date) - $LastSync
                    $hoursAgo = [math]::Round($timeDiff.TotalHours, 1)
                    $LastSyncDisplay = "$($LastSync.ToString('yyyy-MM-dd HH:mm:ss')) ($hoursAgo hrs ago)"
                    $syncColor = if ($hoursAgo -lt 24) { "Green" } elseif ($hoursAgo -lt 72) { "Yellow" } else { "Red" }
                } else {
                    $LastSyncDisplay = "Never"
                    $syncColor = "Red"
                }
                
                Write-Host "  Found: $deviceName | OS: $OS | User: $User" -ForegroundColor White
                Write-Host "  Last Sync: " -NoNewline -ForegroundColor White
                Write-Host $LastSyncDisplay -ForegroundColor $syncColor
                
                if (Sync-SingleDevice -DeviceId $DeviceId -DeviceName $deviceName) {
                    Write-Host "  ✓ Sync triggered successfully!" -ForegroundColor Green
                } else {
                    Write-Host "  ✗ Sync failed!" -ForegroundColor Red
                }
            } else {
                Write-Host "  ✗ Device '$deviceName' not found!" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    } while ($true)
}

function Invoke-DeviceSyncCheck {
    if (-not (Connect-ToGraphIfNeeded)) { return }
    
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       DEVICE SYNC STATUS CHECK         ║" -ForegroundColor Cyan
    Write-Host "  ║  Type device names to check status     ║" -ForegroundColor Cyan
    Write-Host "  ╠════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  " -ForegroundColor Cyan -NoNewline
    Write-Host "[Q]" -ForegroundColor Yellow -NoNewline
    Write-Host " or " -ForegroundColor Cyan -NoNewline
    Write-Host "[done]" -ForegroundColor Yellow -NoNewline
    Write-Host " to return to menu      ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Cyan
    
    do {
        Write-Host ""
        Write-Host "  Enter device name: " -NoNewline -ForegroundColor White
        $deviceName = Read-Host
        
        if ($deviceName -eq 'done' -or $deviceName -eq 'quit' -or $deviceName -eq 'exit' -or $deviceName -eq 'q') {
            break
        }
        
        if ([string]::IsNullOrWhiteSpace($deviceName)) {
            continue
        }
        
        Write-Host "  Searching for: $deviceName..." -ForegroundColor Cyan
        
        try {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
                $device = $AllDevices | Where-Object { $_.DeviceName -eq $deviceName }
            } else {
                $AllDevices = Get-IntuneManagedDevice | Get-MSGraphAllPages
                $device = $AllDevices | Where-Object { $_.deviceName -eq $deviceName }
            }
            
            if ($device) {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $LastSync = $device.LastSyncDateTime
                    $OS = "$($device.OperatingSystem) $($device.OsVersion)"
                    $User = $device.UserPrincipalName
                    $Compliance = $device.ComplianceState
                } else {
                    $LastSync = $device.lastSyncDateTime
                    $OS = "$($device.operatingSystem) $($device.osVersion)"
                    $User = $device.userPrincipalName
                    $Compliance = $device.complianceState
                }
                
                # Calculate time since sync
                if ($LastSync) {
                    $timeDiff = (Get-Date) - $LastSync
                    $hoursAgo = [math]::Round($timeDiff.TotalHours, 1)
                    $syncColor = if ($hoursAgo -lt 24) { "Green" } elseif ($hoursAgo -lt 72) { "Yellow" } else { "Red" }
                } else {
                    $hoursAgo = "Never"
                    $syncColor = "Red"
                }
                
                Write-Host ""
                Write-Host "  ┌────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
                Write-Host "  │ " -ForegroundColor DarkGray -NoNewline
                Write-Host "Device Found!" -ForegroundColor Green -NoNewline
                Write-Host "                                             │" -ForegroundColor DarkGray
                Write-Host "  ├────────────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
                Write-Host "  │ Name:       " -ForegroundColor DarkGray -NoNewline
                Write-Host ("{0,-46}" -f $deviceName) -ForegroundColor White -NoNewline
                Write-Host "│" -ForegroundColor DarkGray
                Write-Host "  │ OS:         " -ForegroundColor DarkGray -NoNewline
                $osDisplay = if ($OS.Length -gt 46) { $OS.Substring(0, 46) } else { $OS }
                Write-Host ("{0,-46}" -f $osDisplay) -ForegroundColor White -NoNewline
                Write-Host "│" -ForegroundColor DarkGray
                Write-Host "  │ User:       " -ForegroundColor DarkGray -NoNewline
                Write-Host ("{0,-46}" -f $User) -ForegroundColor White -NoNewline
                Write-Host "│" -ForegroundColor DarkGray
                Write-Host "  │ Last Sync:  " -ForegroundColor DarkGray -NoNewline
                $syncDisplay = if ($LastSync) { "$($LastSync.ToString('yyyy-MM-dd HH:mm:ss')) ($hoursAgo hrs ago)" } else { "Never" }
                Write-Host ("{0,-46}" -f $syncDisplay) -ForegroundColor $syncColor -NoNewline
                Write-Host "│" -ForegroundColor DarkGray
                Write-Host "  │ Compliance: " -ForegroundColor DarkGray -NoNewline
                $compColor = if ($Compliance -eq "compliant" -or $Compliance -eq "Compliant") { "Green" } else { "Red" }
                Write-Host ("{0,-46}" -f $Compliance) -ForegroundColor $compColor -NoNewline
                Write-Host "│" -ForegroundColor DarkGray
                Write-Host "  └────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
                
            } else {
                Write-Host "  ✗ Device '$deviceName' not found!" -ForegroundColor Red
            }
        } catch {
            Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    } while ($true)
}

function Invoke-SyncFromCSV {
    if (-not (Connect-ToGraphIfNeeded)) { return }
    
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║         SYNC FROM CSV FILE             ║" -ForegroundColor Yellow
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Enter CSV file path: " -NoNewline -ForegroundColor White
    $csvPath = Read-Host
    
    if (-not (Test-Path $csvPath)) {
        Write-Host "  ✗ File not found: $csvPath" -ForegroundColor Red
        return
    }
    
    try {
        $CsvData = Import-Csv $csvPath
        $Columns = ($CsvData | Select-Object -First 1 | Get-Member -MemberType NoteProperty).Name
        
        Write-Host "  Available columns: " -NoNewline -ForegroundColor White
        Write-Host ($Columns -join ", ") -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Enter column name containing device names [DeviceName]: " -NoNewline -ForegroundColor White
        $columnName = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($columnName)) {
            $columnName = "DeviceName"
        }
        
        if ($columnName -notin $Columns) {
            Write-Host "  ✗ Column '$columnName' not found in CSV" -ForegroundColor Red
            return
        }
        
        $DeviceNames = $CsvData | Where-Object { $_.$columnName -and $_.$columnName.Trim() -ne "" } | ForEach-Object { $_.$columnName.Trim() }
        
        Write-Host "  Found $($DeviceNames.Count) device names in CSV" -ForegroundColor White
        
        if (-not (Confirm-Action "Sync $($DeviceNames.Count) devices from CSV?")) {
            Write-Host "  Operation cancelled." -ForegroundColor Yellow
            return
        }
        
        Invoke-SyncDeviceList -DeviceNames $DeviceNames
        
    } catch {
        Write-Host "  ✗ Error reading CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-SyncDeviceList {
    param([string[]]$DeviceNames)
    
    Write-Host ""
    Write-Host "  Retrieving device information..." -ForegroundColor Cyan
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
        } else {
            $AllDevices = Get-IntuneManagedDevice | Get-MSGraphAllPages
        }
    } catch {
        Write-Host "  ✗ Failed to retrieve devices: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    $Total = $DeviceNames.Count
    $Synced = 0
    $Failed = 0
    $NotFound = 0
    $Counter = 0
    
    foreach ($DeviceName in $DeviceNames) {
        $Counter++
        
        $PercentComplete = [math]::Round(($Counter / $Total) * 100)
        Write-Host "`r  Progress: $Counter/$Total ($PercentComplete%) - $DeviceName                    " -NoNewline -ForegroundColor Cyan
        
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $Device = $AllDevices | Where-Object { $_.DeviceName -eq $DeviceName }
            if ($Device) { $DeviceId = $Device.Id }
        } else {
            $Device = $AllDevices | Where-Object { $_.deviceName -eq $DeviceName }
            if ($Device) { $DeviceId = $Device.managedDeviceId }
        }
        
        if ($Device) {
            if (Sync-SingleDevice -DeviceId $DeviceId -DeviceName $DeviceName) {
                $Synced++
            } else {
                $Failed++
            }
        } else {
            $NotFound++
            Write-Log "Device not found: $DeviceName" -Level "WARNING" -NoConsole
        }
        
        Start-Sleep -Milliseconds 300
    }
    
    Write-Host ""
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════╗" -ForegroundColor DarkGray
    Write-Host "  ║           " -ForegroundColor DarkGray -NoNewline
    Write-Host "SYNC COMPLETE" -ForegroundColor Green -NoNewline
    Write-Host "              ║" -ForegroundColor DarkGray
    Write-Host "  ╠════════════════════════════════════════╣" -ForegroundColor DarkGray
    Write-Host "  ║  Total Requested:  " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-18}" -f $Total) -ForegroundColor White -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Devices Found:    " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-18}" -f ($Total - $NotFound)) -ForegroundColor White -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Not Found:        " -ForegroundColor DarkGray -NoNewline
    $NotFoundColor = if ($NotFound -gt 0) { "Yellow" } else { "Green" }
    Write-Host ("{0,-18}" -f $NotFound) -ForegroundColor $NotFoundColor -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Synced:           " -ForegroundColor DarkGray -NoNewline
    Write-Host ("{0,-18}" -f $Synced) -ForegroundColor Green -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ║  Failed:           " -ForegroundColor DarkGray -NoNewline
    $FailedColor = if ($Failed -gt 0) { "Red" } else { "Green" }
    Write-Host ("{0,-18}" -f $Failed) -ForegroundColor $FailedColor -NoNewline
    Write-Host "║" -ForegroundColor DarkGray
    Write-Host "  ╚════════════════════════════════════════╝" -ForegroundColor DarkGray
}

# ============================================================
# MAIN LOOP
# ============================================================

function Main {
    Write-Log "Intune Sync Tool started" -NoConsole
    
    do {
        Show-Banner
        Show-ConnectionStatus -Connected $script:GraphConnected
        Show-MainMenu
        
        Write-Host "  Select option: " -NoNewline -ForegroundColor White
        $choice = Read-Host
        
        switch ($choice.ToUpper()) {
            "1" {
                Invoke-BulkSync -OperatingSystem "Windows" -DisplayName "Windows"
                Press-AnyKey
            }
            "2" {
                Invoke-BulkSync -OperatingSystem "macOS" -DisplayName "macOS"
                Press-AnyKey
            }
            "3" {
                Invoke-BulkSync -OperatingSystem "iOS" -DisplayName "iOS/iPadOS"
                Press-AnyKey
            }
            "4" {
                Invoke-BulkSync -OperatingSystem "Android" -DisplayName "Android"
                Press-AnyKey
            }
            "5" {
                Invoke-SyncAllPlatforms
                Press-AnyKey
            }
            "6" {
                Invoke-QuickDeviceSync
            }
            "7" {
                Invoke-DeviceSyncCheck
            }
            "8" {
                Invoke-SyncFromCSV
                Press-AnyKey
            }
            "Q" {
                Write-Host ""
                Write-Host "  Exiting..." -ForegroundColor Yellow
                Disconnect-FromGraph
                Write-Host "  Goodbye!" -ForegroundColor Cyan
                Write-Log "Intune Sync Tool exited" -NoConsole
                return
            }
            default {
                Write-Host "  Invalid option. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        
    } while ($true)
}

# Execute
Main
