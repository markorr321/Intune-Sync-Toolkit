# Quick Device Sync Status Checker
# Just run this script and type device names to check their sync status

# Import required modules
Import-Module Microsoft.Graph.Authentication -Force -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.DeviceManagement -Force -ErrorAction SilentlyContinue

# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome | Out-Null

# Main loop
do {
    Write-Host ""
    $deviceName = Read-Host "Enter device name to check (or 'quit' to exit)"
    
    if ($deviceName -eq 'quit' -or $deviceName -eq 'q' -or $deviceName -eq 'exit') {
        break
    }
    
    if ($deviceName) {
        Write-Host "Searching for: $deviceName..." -ForegroundColor Cyan
        
        $device = Get-MgDeviceManagementManagedDevice -All | Where-Object {$_.DeviceName -eq $deviceName}
        
        if ($device) {
            # Calculate time since sync
            $lastSync = $device.LastSyncDateTime
            if ($lastSync) {
                $timeDiff = (Get-Date) - $lastSync
                $hoursAgo = [math]::Round($timeDiff.TotalHours, 1)
                $syncColor = if ($hoursAgo -lt 24) { "Green" } elseif ($hoursAgo -lt 72) { "Yellow" } else { "Red" }
            } else {
                $hoursAgo = "Never"
                $syncColor = "Red"
            }
            
            Write-Host "`nDevice Found!" -ForegroundColor Green
            Write-Host "Name: " -NoNewline; Write-Host $device.DeviceName -ForegroundColor White
            Write-Host "OS: " -NoNewline; Write-Host "$($device.OperatingSystem) $($device.OsVersion)" -ForegroundColor White
            Write-Host "User: " -NoNewline; Write-Host $device.UserPrincipalName -ForegroundColor White
            Write-Host "Last Sync: " -NoNewline; 
            if ($lastSync) {
                Write-Host "$($lastSync.ToString('yyyy-MM-dd HH:mm:ss')) ($hoursAgo hours ago)" -ForegroundColor $syncColor
            } else {
                Write-Host "Never" -ForegroundColor Red
            }
            Write-Host "Compliance: " -NoNewline; 
            $compColor = if ($device.ComplianceState -eq "Compliant") { "Green" } else { "Red" }
            Write-Host $device.ComplianceState -ForegroundColor $compColor
            
        } else {
            Write-Host "Device '$deviceName' not found!" -ForegroundColor Red
        }
    }
    
} while ($true)

Disconnect-MgGraph | Out-Null
