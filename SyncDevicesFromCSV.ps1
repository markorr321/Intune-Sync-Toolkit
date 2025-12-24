# ============================================================
# Intune Device Retrieval and Sync Script
# ============================================================
#
# SUMMARY:
# This script automates the process of syncing managed devices in Microsoft Intune
# based on device names. It connects to Microsoft Graph, retrieves specific devices
# by device name from a CSV file, and triggers a sync operation on each device.
#
# KEY FEATURES:
# - Supports multiple input methods (direct list, text file, CSV file)
# - Syncs any managed device by exact name match (Windows, iOS, Android, etc.)
# - Works with both PowerShell 5.1 and PowerShell 7+
# - Color-coded console output with minimal verbose messages
# - Comprehensive logging to file for audit purposes
# - Handles authentication automatically with proper permissions
# - Processes multiple devices efficiently with throttling protection
#
# TYPICAL USE CASES:
# - Force sync specific devices by device name (any platform)
# - Bulk sync devices from a list of device names in CSV
# - Troubleshoot specific devices by triggering immediate sync
# - Automate device management tasks for specific devices
#
# REQUIREMENTS:
# - Microsoft.Graph.Intune PowerShell module (PS 5.1) OR
# - Microsoft.Graph.Authentication module (PS 7+)
# - Appropriate Intune permissions in Entra ID
# - DeviceManagementManagedDevices.PrivilegedOperations.All scope
#
# ============================================================

<#
.SYNOPSIS
    Retrieves iOS and iPadOS Intune devices for specified users and triggers device sync

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves iOS and iPadOS managed devices for a subset of users,
    and triggers a sync operation on those devices.

.PARAMETER DeviceList
    Array of device names to process

.PARAMETER DeviceListFile
    Path to a text file containing device names (one per line)

.PARAMETER CsvFile
    Path to a CSV file containing device information

.PARAMETER CsvColumn
    Column name in CSV that contains device names (default: "DeviceName")

.PARAMETER LogPath
    Path for log file output (optional)

.EXAMPLE
    .\SyncDevicesFromCSV.ps1 -DeviceList @("iPhone_ABC123", "iPad_XYZ789")

.EXAMPLE
    .\SyncDevicesFromCSV.ps1 -DeviceListFile "C:\temp\devices.txt"

.EXAMPLE
    .\SyncDevicesFromCSV.ps1 -CsvFile "C:\temp\devices.csv" -CsvColumn "DeviceName"
#>

param(
    [Parameter(ParameterSetName = 'DeviceArray')]
    [string[]]$DeviceList,
    
    [Parameter(ParameterSetName = 'DeviceFile')]
    [string]$DeviceListFile,
    
    [Parameter(ParameterSetName = 'CsvFile')]
    [string]$CsvFile,
    
    [Parameter(ParameterSetName = 'CsvFile')]
    [string]$CsvColumn = "DeviceName",
    
    [string]$LogPath = "C:\temp\IntuneDeviceSync.log"
)

# Required modules check
$RequiredModules = @("Microsoft.Graph.Intune")

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"
    
    # Only show non-INFO messages or important INFO messages on console
    if (-not $NoConsole -and ($Level -ne "INFO" -or $Message -match "(Processing user|Device:|Syncing device|disconnected from Graph)")) {
        $Color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { 
                if ($Message -match "Processing user") { "Cyan" }
                elseif ($Message -match "Device:") { "Magenta" }
                elseif ($Message -match "Syncing device") { "Blue" }
                elseif ($Message -match "disconnected from Graph") { "Red" }
                else { "White" }
            }
            default { "White" }
        }
        Write-Host $LogEntry -ForegroundColor $Color
    }
    
    # Always write to log file if path specified
    if ($LogPath) {
        try {
            $LogDir = Split-Path $LogPath -Parent
            if (-not (Test-Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $LogEntry
        } catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

# Check and install required modules
function Install-RequiredModules {
    Write-Log "Checking required PowerShell modules..."
    
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            Write-Log "Installing module: $Module" -Level "WARNING"
            try {
                Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser
                Write-Log "Successfully installed: $Module" -Level "SUCCESS"
            } catch {
                Write-Log "Failed to install module $Module`: $_" -Level "ERROR"
                return $false
            }
        } else {
            Write-Log "Module already installed: $Module"
        }
    }
    return $true
}

# Connect to Microsoft Graph
function Connect-ToGraph {
    Write-Log "Connecting to Microsoft Graph..."
    
    try {
        # Check PowerShell version and use appropriate method
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Log "PowerShell 7+ detected, using modern Graph modules..."
            # Fallback to newer modules for PS7 compatibility
            Import-Module Microsoft.Graph.Authentication -Force
            Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All" -NoWelcome
        } else {
            Write-Log "Windows PowerShell detected, using Intune module..."
            # Import the Intune module for PS 5.1
            Import-Module -Name Microsoft.Graph.Intune -Force
            
            # Connect using the Intune module method
            if(!(Connect-MSGraph)){
                Connect-MSGraph
            }
        }
        
        Write-Log "Successfully connected to Microsoft Graph" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-Log "Failed to connect to Microsoft Graph: $_" -Level "ERROR"
        return $false
    }
}

# Get device by name
function Get-DeviceByName {
    param([string]$DeviceName)
    
    Write-Log "Searching for device: $DeviceName"
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Log "Using modern Graph modules for device retrieval..."
            # Get all managed devices using modern modules
            $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
            
            # Filter for devices with matching name (any platform)
            $MatchedDevice = $AllDevices | Where-Object { 
                $_.DeviceName -eq $DeviceName
            }
        } else {
            Write-Log "Using Intune module for device retrieval..."
            # Get all managed devices using the Intune module approach
            $AllDevices = Get-IntuneManagedDevice | Get-MSGraphAllPages
            
            # Filter devices for this specific device name (any platform)
            $MatchedDevice = $AllDevices | Where-Object { 
                $_.deviceName -eq $DeviceName
            }
        }
        
        if ($MatchedDevice) {
            Write-Log "Found device: $DeviceName" -Level "SUCCESS"
            return $MatchedDevice
        } else {
            Write-Log "Device not found: $DeviceName" -Level "WARNING"
            return $null
        }
    } catch {
        Write-Log "Error searching for device $DeviceName`: $_" -Level "ERROR"
        return $null
    }
}

# Sync device
function Sync-IntuneDevice {
    param(
        [string]$DeviceId,
        [string]$DeviceName
    )
    
    Write-Log "Syncing device: $DeviceName (ID: $DeviceId)"
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # Use REST API for PowerShell 7
            $SyncUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId/syncDevice"
            Invoke-MgGraphRequest -Uri $SyncUri -Method POST -ErrorAction Stop
        } else {
            # Use Intune module cmdlet for PowerShell 5.1
            Invoke-IntuneManagedDeviceSyncDevice -managedDeviceId $DeviceId -ErrorAction Stop
        }
        
        Write-Log "Successfully triggered sync for device: $DeviceName" -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "Failed to sync device $DeviceName`: $_" -Level "ERROR"
        return $false
    }
}

# Main execution
function Main {
    Write-Log "=== Intune Device Sync Script Started ==="
    Write-Log "Log file: $LogPath"
    
    # Install required modules
    if (-not (Install-RequiredModules)) {
        Write-Log "Failed to install required modules. Exiting." -Level "ERROR"
        return
    }
    
    # Import modules
    foreach ($Module in $RequiredModules) {
        Import-Module $Module -Force
    }
    
    # Connect to Graph
    if (-not (Connect-ToGraph)) {
        Write-Log "Failed to connect to Microsoft Graph. Exiting." -Level "ERROR"
        return
    }
    
    # Determine device list
    $DevicesToProcess = @()
    
    if ($DeviceList) {
        $DevicesToProcess = $DeviceList
        Write-Log "Processing $($DevicesToProcess.Count) devices from parameter list"
    } elseif ($DeviceListFile) {
        if (Test-Path $DeviceListFile) {
            $DevicesToProcess = Get-Content $DeviceListFile | Where-Object { $_.Trim() -ne "" }
            Write-Log "Processing $($DevicesToProcess.Count) devices from file: $DeviceListFile"
        } else {
            Write-Log "Device list file not found: $DeviceListFile" -Level "ERROR"
            return
        }
    } elseif ($CsvFile) {
        if (Test-Path $CsvFile) {
            try {
                $CsvData = Import-Csv $CsvFile
                Write-Log "Successfully imported CSV file: $CsvFile"
                Write-Log "CSV contains $($CsvData.Count) rows"
                
                # Check if specified column exists
                $FirstRow = $CsvData | Select-Object -First 1
                $AvailableColumns = ($FirstRow | Get-Member -MemberType NoteProperty).Name
                
                Write-Log "Available columns: $($AvailableColumns -join ', ')"
                
                if ($CsvColumn -notin $AvailableColumns) {
                    Write-Log "Column '$CsvColumn' not found in CSV. Available columns: $($AvailableColumns -join ', ')" -Level "ERROR"
                    return
                }
                
                # Extract device list from specified column
                $DevicesToProcess = $CsvData | Where-Object { $_.$CsvColumn -and $_.$CsvColumn.Trim() -ne "" } | ForEach-Object { $_.$CsvColumn.Trim() }
                Write-Log "Processing $($DevicesToProcess.Count) devices from CSV column '$CsvColumn'"
                
                # Show sample of devices being processed
                $SampleDevices = $DevicesToProcess | Select-Object -First 5
                Write-Log "Sample devices: $($SampleDevices -join ', ')$(if ($DevicesToProcess.Count -gt 5) { '...' })"
                
            } catch {
                Write-Log "Failed to import CSV file: $_" -Level "ERROR"
                return
            }
        } else {
            Write-Log "CSV file not found: $CsvFile" -Level "ERROR"
            return
        }
    } else {
        Write-Log "No device list provided. Use -DeviceList, -DeviceListFile, or -CsvFile parameter." -Level "ERROR"
        return
    }
    
    # Process each device
    $TotalDevices = $DevicesToProcess.Count
    $SyncedDevices = 0
    $FailedSyncs = 0
    $NotFoundDevices = 0
    
    foreach ($DeviceName in $DevicesToProcess) {
        Write-Log "--- Processing device: $DeviceName ---"
        
        $Device = Get-DeviceByName -DeviceName $DeviceName
        
        if ($Device) {
            # Handle different property names based on PowerShell version/module
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $ActualDeviceName = $Device.DeviceName
                $DeviceOS = $Device.OperatingSystem
                $LastSync = $Device.LastSyncDateTime
                $DeviceId = $Device.Id
                $UserPrincipalName = $Device.UserPrincipalName
            } else {
                $ActualDeviceName = $Device.deviceName
                $DeviceOS = $Device.operatingSystem
                $LastSync = $Device.lastSyncDateTime
                $DeviceId = $Device.managedDeviceId
                $UserPrincipalName = $Device.userPrincipalName
            }
            
            Write-Log "Device: $ActualDeviceName | OS: $DeviceOS | User: $UserPrincipalName | Last Sync: $LastSync"
            
            if (Sync-IntuneDevice -DeviceId $DeviceId -DeviceName $ActualDeviceName) {
                $SyncedDevices++
            } else {
                $FailedSyncs++
            }
        } else {
            $NotFoundDevices++
        }
        
        # Add small delay to avoid throttling
        Start-Sleep -Milliseconds 500
    }
    
    # Summary
    Write-Log "=== SYNC SUMMARY ==="
    Write-Log "Devices requested: $TotalDevices"
    Write-Log "Devices found: $($TotalDevices - $NotFoundDevices)"
    Write-Log "Devices not found: $NotFoundDevices" -Level $(if ($NotFoundDevices -gt 0) { "WARNING" } else { "INFO" })
    Write-Log "Devices synced successfully: $SyncedDevices" -Level "SUCCESS"
    Write-Log "Failed syncs: $FailedSyncs" -Level $(if ($FailedSyncs -gt 0) { "WARNING" } else { "INFO" })
    Write-Log "=== Script Completed ==="
    
    # Disconnect from Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        Write-Log "You have been disconnected from Graph"
    } catch {
        # Suppress any disconnect errors
    }
}

# Execute main function
Main
