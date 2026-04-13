
<#
SCOPE:

Can we automate (create a script) the below steps so a list of Laptops can be enrolled MS Intune. I will be working on the list of laptops with the users attached.

1. obtain the laps netadmin password

2. disable trellix

3. Unjoin the domain and reboot \ remove it from the domain

4. delete the device in Entra

5. On the laptop, Sysprep.exe [/oobe [/generalize]/reboot /unattend:answerfile [Whatever else we need]

6. Join the domain

7. move the computer object into the correct OU

8. laptop pull all GPOs, etc. (may need a reboot)

wait for device to be hybrid joined in Entra

have the user sign into the computer for the first time with an O365/Intune license

Let the device create new profile

Force GPUpdate

Reboot the device

9. Confirmation the device is in Entra and Intune

RESOURCE:
https://learn.microsoft.com/en-us/powershell/module/microsoft.entra.directorymanagement/remove-entradevice?view=entra-powershell&utm_source=copilot.com

CREATOR: John W. Braunsdorf

DATE: 04/13/2026

v1.1

#>

# Variables
$computerName = hostname

#region - Disables any active Trellix
# Author: Michael Silva
# Created: 7/30/2024
# About: Bypasses Trellix FDE preboot authentication a specified number of times

$toolPath = "EpeTemporaryAutoboot.exe"
$rebootCount = 10

$toolProc = Start-Process $toolPath -ArgumentList "--number-of-reboots $rebootCount" -PassThru -Wait
# Wait-Process -InputObject $toolProc
# $exitHex = ($toolProc.ExitCode).ToString("X")
if ($toolProc.ExitCode -eq 0) {
    "Success: Temporary Autoboot Set"
    "Rebooting system"
    shutdown -r -f -t 0
} else {
    "Error: Exception Setting Temporary Autoboot"
}
exit $toolProc.ExitCode

#endregion

#Start-Process "https://portal.azure.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/Devices/menuId~/null"

#region - Required Powershell modules - only use the module if the test module check fails
# Powershell modules needed
# Install-Module -Name Microsoft.Graph -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
# Install-Module -Name Microsoft.Entra -Repository PSGallery -Scope CurrentUser -Force -AllowClobber

Start-Sleep -Seconds 5

# Validating Powershell modules are installed
$modules = @("Microsoft.Graph","Microsoft.Entra")

foreach ($m in $modules) {

    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "Module '$m' is NOT installed. Installing..." -ForegroundColor Yellow

        try {
            Install-Module -Name $m -Force -Scope CurrentUser
            Write-Host "Successfully installed: $m" -ForegroundColor Green
            $status = "Installed"
        }
        catch {
            Write-Host "Failed to install: $m" -ForegroundColor Red
            $status = "Install Failed"
            continue
        }
    }
    else {
        Write-Host "Module '$m' already installed." -ForegroundColor Cyan
        $status = "Already Installed"
    }

    try {
        Import-Module $m -ErrorAction Stop
        Write-Host "Imported: $m" -ForegroundColor Green
        $imported = $true
    }
    catch {
        Write-Host "Failed to import or import of module not needed: $m" -ForegroundColor Red
        $imported = $false
    }

    # Optional: output structured result
    [pscustomobject]@{
        Module   = $m
        Status   = $status
        Imported = $imported
    }
}

#only use this function if important -module fails
# $MaximumFunctionCount = 8192
# $MaximumVariableCount = 8192
# important these modules if not they do not exist
Import-Module Microsoft.Graph
Import-Module Microsoft.Entra

#endregion

#region - Pre-deployment OU validation

Get-ADComputer -Identity $computerName | Select-Object DistinguishedName

#endregion

#region - Remove computer from domain
if ((Read-Host "Proceed with domain pc removal? (y/n)") -ne 'y') { return }

$domainCred = Get-Credential -Message "Enter domain admin credentials"

Remove-Computer
    -UnjoinDomainCredential $domainCred `
    -WorkgroupName "WORKGROUP" `
    -PassThru `
    -Verbose `
    -Restart

#endregion

#region - post-reboot, Validating machine is no longer in Active Directory:

if (Get-ADComputer -Identity $computerName -ErrorAction SilentlyContinue) {
    Write-Host "Computer object still exists in AD." -BackgroundColor White -ForegroundColor Blue
} else {
    Write-Host "Computer object successfully removed from AD." -BackgroundColor White -ForegroundColor Red
}

#endregion

#region - Connecting to Entra, delete the device in Entra - This will prompt admin running the script to login
if ((Read-Host "Proceed with Entra pc removal? (y/n)") -ne 'y') { return }

Connect-Entra -Scopes 'Device.ReadWrite.All'
$device = Get-EntraDevice -Filter "DisplayName eq '$computerName'"
Remove-EntraDevice -DeviceId $device.Id

#endregion
           
#region - Running Sysprep Locally via PowerShell
if ((Read-Host "Start sysprep, are you ready to proceed? (y/n)") -ne 'y') { return }

Start-Process "C:\Windows\System32\Sysprep\Sysprep.exe" `
    -ArgumentList "/generalize /oobe /shutdown /quiet"

#endregion

#region - adding coputer to domain
if ((Read-Host "Add $computerName to domain, are you ready to proceed? (y/n)") -ne 'y') { return }

Add-Computer -DomainName "yourdomain.local" `
    -OUPath "OU=PCs,OU=Network Services,OU=Departments,DC=cccu,DC=local" `
    -Credential (Get-Credential) -Restart

#endregion

#region - Get All GPO Links in the Entire Domain
if ((Read-Host "Acquire all GPOs for $computerName, are you ready to proceed? (y/n)") -ne 'y') { return }

Get-GPOLink -Domain "cccu.local"

#endregion
