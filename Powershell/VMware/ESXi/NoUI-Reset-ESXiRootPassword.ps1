<#

SCOPE: 
    None UI - Changing local ESXi host password via the vCenter

CREATED BY: John W. Braunsdorf 

DATE: 05/06/2026

#>


# -----------------------------
# User Input Section
# -----------------------------

# vCenter connection info
$vcenterServer = "lvdcvcenter01.cccu.local"
$vcenterUser   = "adminjb@cccu.local"
$vcenterPass   = "Cl0udForm@tionLambda#2000026"

# ESXi host to update
$esxiHost = "vsphere-lvdc-01.cccu.local"

# New root password
$newRootPassword = "Their!Wood-Vain"

# -----------------------------
# Script Logic
# -----------------------------

# Connect to vCenter
Connect-VIServer -Server $vcenterServer -User $vcenterUser -Password $vcenterPass

# Get ESXi host object
$vmhost = Get-VMHost -Name $esxiHost

# Prepare ESXCLI
$esxcli = Get-EsxCli -VMHost $vmhost -V2

# Build arguments for root password change
$args = $esxcli.system.account.set.CreateArgs()
$args.id = "root"
$args.password = $newRootPassword
$args.passwordconfirmation = $newRootPassword

# Apply password change
$esxcli.system.account.set.Invoke($args)

Write-Host "Root password updated successfully on $esxiHost"
