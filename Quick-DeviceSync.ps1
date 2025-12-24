# Quick Device Sync
# Just run this script and type device names to sync them immediately

# Import required modules
Import-Module Microsoft.Graph.Authentication -Force -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.DeviceManagement -Force -ErrorAction SilentlyContinue

# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All" -NoWelcome | Out-Null

# Main loop
do {
    Write-Host ""
    $deviceName = Read-Host "Enter device name to sync (or 'quit' to exit)"
    
    if ($deviceName -eq 'quit' -or $deviceName -eq 'q' -or $deviceName -eq 'exit') {
        break
    }
    
    if ($deviceName) {
        Write-Host "Searching for: $deviceName..." -ForegroundColor Cyan
        
        $device = Get-MgDeviceManagementManagedDevice -All | Where-Object {$_.DeviceName -eq $deviceName}
        
        if ($device) {
            Write-Host "Device found! Triggering sync..." -ForegroundColor Yellow
            
            try {
                # Trigger sync using REST API
                $SyncUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($device.Id)/syncDevice"
                Invoke-MgGraphRequest -Uri $SyncUri -Method POST -ErrorAction Stop
                
                Write-Host "✓ Sync triggered successfully for: $deviceName" -ForegroundColor Green
                Write-Host "  Device: $($device.DeviceName)" -ForegroundColor White
                Write-Host "  OS: $($device.OperatingSystem)" -ForegroundColor White
                Write-Host "  User: $($device.UserPrincipalName)" -ForegroundColor White
                
            } catch {
                Write-Host "✗ Failed to sync device: $($_.Exception.Message)" -ForegroundColor Red
            }
            
        } else {
            Write-Host "Device '$deviceName' not found!" -ForegroundColor Red
        }
    }
    
} while ($true)

Disconnect-MgGraph | Out-Null
