# ============================================================
# Sync-AlliOSDevices.ps1
# ============================================================
#
# DESCRIPTION:
# This script automates the process of syncing ALL iOS and iPadOS devices in Microsoft Intune.
# It connects to Microsoft Graph, retrieves all iOS/iPadOS managed devices in the tenant,
# and triggers a sync operation on each device. Perfect for bulk policy updates
# or maintenance operations across all Apple mobile devices.
#
# AUTHOR: Mark Orr
# COMPANY: Sompo International
# DATE: 11/10/2025
#
# KEY FEATURES:
# - Automatically finds all iOS and iPadOS devices in Intune
# - Triggers sync on all discovered Apple mobile devices
# - Works with both PowerShell 5.1 and PowerShell 7+
# - Color-coded console output with minimal verbose messages
# - Comprehensive logging to file for audit purposes
# - Progress indication for bulk processing
# - Handles authentication automatically with proper permissions
#
# TYPICAL USE CASES:
# - Force sync all iOS/iPad devices after policy changes
# - Bulk maintenance operations on Apple mobile fleet
# - Ensure all iOS devices get latest security updates
# - Troubleshoot iOS device compliance across tenant
#
# REQUIREMENTS:
# - Microsoft.Graph.Intune PowerShell module (PS 5.1) OR
# - Microsoft.Graph.Authentication module (PS 7+)
# - Appropriate Intune permissions in Entra ID
# - DeviceManagementManagedDevices.PrivilegedOperations.All scope
#
# USAGE EXAMPLES:
# 
# # Sync all iOS and iPadOS devices in tenant
# .\Sync-AlliOSDevices.ps1
# 
# # Custom log file location
# .\Sync-AlliOSDevices.ps1 -LogPath "C:\Logs\iOSSync.log"
#
# ============================================================

<#
.SYNOPSIS
    Syncs all iOS and iPadOS devices in Microsoft Intune

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all iOS and iPadOS managed devices,
    and triggers a sync operation on each device.

.PARAMETER LogPath
    Path for log file output (optional)

.EXAMPLE
    .\Sync-AlliOSDevices.ps1

.EXAMPLE
    .\Sync-AlliOSDevices.ps1 -LogPath "C:\Logs\iOSSync.log"
#>

param(
    [string]$LogPath = "C:\temp\iOSDeviceSync.log"
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
    if (-not $NoConsole -and ($Level -ne "INFO" -or $Message -match "(Processing device|Device:|Syncing device|disconnected from Graph)")) {
        $Color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { 
                if ($Message -match "Processing device") { "Cyan" }
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

# Get all iOS and iPadOS devices
function Get-AlliOSDevices {
    Write-Log "Retrieving all iOS and iPadOS devices from Intune..."
    
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Write-Log "Using modern Graph modules for device retrieval..."
            # Get all managed devices using modern modules
            $AllDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
            
            # Filter for iOS and iPadOS devices
            $iOSDevices = $AllDevices | Where-Object { 
                $_.OperatingSystem -eq "iOS" -or $_.OperatingSystem -eq "iPadOS"
            }
        } else {
            Write-Log "Using Intune module for device retrieval..."
            # Get all iOS and iPadOS devices using the Intune module approach
            $iOSDevices = Get-IntuneManagedDevice -Filter "operatingsystem eq 'iOS' or operatingsystem eq 'iPadOS'" | Get-MSGraphAllPages
        }
        
        Write-Log "Found $($iOSDevices.Count) iOS/iPadOS devices in tenant"
        
        return $iOSDevices
    } catch {
        Write-Log "Error retrieving iOS/iPadOS devices: $_" -Level "ERROR"
        return @()
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
    Write-Log "=== iOS/iPadOS Device Sync Script Started ==="
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
    
    # Get all iOS/iPadOS devices
    $iOSDevices = Get-AlliOSDevices
    
    if ($iOSDevices.Count -eq 0) {
        Write-Log "No iOS/iPadOS devices found in tenant." -Level "WARNING"
        return
    }
    
    # Process each device
    $TotalDevices = $iOSDevices.Count
    $SyncedDevices = 0
    $FailedSyncs = 0
    $Counter = 0
    
    foreach ($Device in $iOSDevices) {
        $Counter++
        Write-Progress -Activity "Syncing iOS/iPadOS Devices" -Status "Processing device $Counter of $TotalDevices" -PercentComplete (($Counter / $TotalDevices) * 100)
        
        # Handle different property names based on PowerShell version/module
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $DeviceName = $Device.DeviceName
            $DeviceOS = $Device.OperatingSystem
            $LastSync = $Device.LastSyncDateTime
            $DeviceId = $Device.Id
            $UserPrincipalName = $Device.UserPrincipalName
        } else {
            $DeviceName = $Device.deviceName
            $DeviceOS = $Device.operatingSystem
            $LastSync = $Device.lastSyncDateTime
            $DeviceId = $Device.managedDeviceId
            $UserPrincipalName = $Device.userPrincipalName
        }
        
        Write-Log "Device: $DeviceName | OS: $DeviceOS | User: $UserPrincipalName | Last Sync: $LastSync"
        
        if (Sync-IntuneDevice -DeviceId $DeviceId -DeviceName $DeviceName) {
            $SyncedDevices++
        } else {
            $FailedSyncs++
        }
        
        # Add small delay to avoid throttling
        Start-Sleep -Milliseconds 500
    }
    
    Write-Progress -Activity "Syncing iOS/iPadOS Devices" -Completed
    
    # Summary
    Write-Log "=== SYNC SUMMARY ==="
    Write-Log "Total iOS/iPadOS devices found: $TotalDevices"
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
