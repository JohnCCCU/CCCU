<#
SCOPE: have the ability to update a stand alone server without vCenter (VUM\vLCM). Created this update for online ONLY. if needed an
off-line version can be created

RESOURCE:

CREATOR: John W. Braunsdorf @ Cal Coast Credit Union (CCCU)

DATE: 04/09/2026

REV: 0.0

#>

# Do not participate in VMware CEIP
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false

# Variables
$url = "https://dl.broadcom.com/ONQum5wZwobEOoSCI4Rf8MKqZeffMNkj/PROD/COMP/ESX_HOST/main/vmw-depot-index.xml"
$esxiHost = "ESXI IP"
$esxiUser = "root"
$esxipwd = "password"

#region
# PowewrCLI Module validation
$moduleName = "VMware.VimAutomation.Core"

# Check if module is installed
$installed = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue

if ($installed) {
    Write-Host "$moduleName is already installed. Version: $($installed.Version)" -BackgroundColor White -ForegroundColor Blue
}
else {
    Write-Host "$moduleName is not installed. Installing..." -BackgroundColor White -ForegroundColor Red
    try {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "$moduleName installed successfully." -BackgroundColor White -ForegroundColor Blue
    }
    catch {
        Write-Host "Failed to install $moduleName $($_.Exception.Message)" -BackgroundColor White -ForegroundColor Red
    }
}

# Optional: Import the module
try {
    Import-Module $moduleName -ErrorAction Stop
    Write-Host "$moduleName imported successfully." -BackgroundColor White -ForegroundColor Blue
}
catch {
    Write-Host "Module installed but could not be imported: $($_.Exception.Message)" -BackgroundColor White -ForegroundColor Red
}

#endregion

# Connect to standalone ESXi host
Connect-VIServer -Server $esxiHost -User $esxiUser -Password $esxipwd

# Check Current ESXi Version
Start-Sleep -Seconds 5
Get-VMHost | Select Name, Version, Build

# Place ESXi host into maintenance mode
Start-Sleep -Seconds 5
$vmhost = Get-VMHost -Name $esxiHost

if ($vmhost.ConnectionState -ne "Maintenance") {
    Write-Host "Putting ESXi host into maintenance mode..."
    Set-VMHost -VMHost $vmhost -State Maintenance -Confirm:$false
} else {
    Write-Host "ESXi host is already in maintenance mode."
}

# verify all VMs are powered off or migrated
Start-Sleep -Seconds 5
$poweredOnVMs = Get-VM -Location $vmhost | Where-Object {$_.PowerState -eq "PoweredOn"}

if ($poweredOnVMs.Count -gt 0) {
    Write-Host "Warning: These VMs are still powered on:"
    $poweredOnVMs | Select Name, PowerState
} else {
    Write-Host "All VMs are powered off or migrated."
}

#region - Update with VMware Online Depot

# Checking if the URL is available

try {
    $response = Invoke-WebRequest -Uri $url -Method Head -ErrorAction Stop -UseBasicParsing
    Write-Host "URL is reachable (HTTP $($response.StatusCode))." -BackgroundColor Green -ForegroundColor Blue
}
catch {
    Write-Host "URL is NOT reachable: $($_.Exception.Message)"
    return
}


# NEW Depot 
Add-EsxSoftwareDepot $url

# List Available Image Profiles (example: ESXi 7.0 U3)
Get-EsxImageProfile | Where-Object {$_.Name -like "ESXi-7.0.3-*"}

# Select the desired image
$profile = Get-EsxImageProfile | Where-Object {$_.Name -like "ESXi-7.0.3-0.0.20*"}

# Apply the update
Set-VMHost -VMHost $esxiHost -ImageProfile $profile -Confirm:$false
#endregion

# Rebbot current ESXi Host
Start-Sleep -Seconds 10
Restart-VMHost -VMHost $esxiHost -Confirm:$false

# Verify \ Validate after reboot
Get-VMHost | Select Name, Version, Build

# ESXi host exits maintenance mode
Set-VMHost -VMHost $esxiHost -State Connected



