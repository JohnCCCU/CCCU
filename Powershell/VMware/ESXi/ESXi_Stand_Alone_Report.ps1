<#

SCOPE: 
  ESXi Configuration Export Tool
  - GUI for Host/User/Password
  - Checkbox: Disconnect after report
  - Auto-load VMware.PowerCLI + VCF.PowerCLI (only if needed)
  - Collect ESXi configuration including:
       * Host summary
       * CPU / Memory
       * DNS / Network
       * ALL VMkernel interfaces (vmk)
       * vSwitch uplink mappings
       * Port groups
       * Datastores
       * NTP configuration
       * Syslog configuration
  - Export to CSS-styled HTML

CREATED BY: John W. Braunsdorf 

DATE: 05/06/2026

#>

<# Remove Rem only if modules are not installed
# -------------------------------
# 1. Load VMware.PowerCLI (required)
# -------------------------------

Write-Host "Checking VMware.PowerCLI module..."

$vmwareLoaded = Get-Module -Name VMware.PowerCLI -ErrorAction SilentlyContinue
$vmwareAvailable = Get-Module -ListAvailable -Name VMware.PowerCLI -ErrorAction SilentlyContinue

if (-not $vmwareAvailable) {
    Write-Host "VMware.PowerCLI not found. Installing..."
    Install-Module VMware.PowerCLI -Scope CurrentUser -Force -SkipPublisherCheck
}

if (-not $vmwareLoaded) {
    Write-Host "Importing VMware.PowerCLI..."
    Import-Module VMware.PowerCLI -Force
} else {
    Write-Host "VMware.PowerCLI already imported. Skipping import."
}

# -------------------------------
# 2. Load VCF.PowerCLI (optional)
# -------------------------------

Write-Host "Checking VCF.PowerCLI module..."

$vcfLoaded = Get-Module -Name VCF.PowerCLI -ErrorAction SilentlyContinue
$vcfAvailable = Get-Module -ListAvailable -Name VCF.PowerCLI -ErrorAction SilentlyContinue

if (-not $vcfAvailable) {
    Write-Host "VCF.PowerCLI not found. Installing..."
    Install-Module VCF.PowerCLI -Scope CurrentUser -Force -SkipPublisherCheck
}

if (-not $vcfLoaded) {
    Write-Host "Importing VCF.PowerCLI..."
    Import-Module VCF.PowerCLI -Force
} else {
    Write-Host "VCF.PowerCLI already imported. Skipping import."
}
#>

# -------------------------------
# 3. GUI for ESXi Host Credentials
# -------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "ESXi Configuration Export"
$form.Size = New-Object System.Drawing.Size(380,300)
$form.StartPosition = "CenterScreen"

# Hostname
$lblHost = New-Object System.Windows.Forms.Label
$lblHost.Text = "ESXi Host:"
$lblHost.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($lblHost)

$txtHost = New-Object System.Windows.Forms.TextBox
$txtHost.Location = New-Object System.Drawing.Point(150,20)
$txtHost.Width = 200
$form.Controls.Add($txtHost)

# Username
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Username:"
$lblUser.Location = New-Object System.Drawing.Point(10,60)
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point(150,60)
$txtUser.Width = 200
$form.Controls.Add($txtUser)

# Password
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "Password:"
$lblPass.Location = New-Object System.Drawing.Point(10,100)
$form.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = New-Object System.Drawing.Point(150,100)
$txtPass.Width = 200
$txtPass.UseSystemPasswordChar = $true
$form.Controls.Add($txtPass)

# Disconnect checkbox
$chkDisconnect = New-Object System.Windows.Forms.CheckBox
$chkDisconnect.Text = "Disconnect"
$chkDisconnect.Location = New-Object System.Drawing.Point(150,140)
$form.Controls.Add($chkDisconnect)

# Run button
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text = "Enter"
$btnOK.Location = New-Object System.Drawing.Point(150,180)
$btnOK.Add_Click({ $form.Close() })
$form.Controls.Add($btnOK)

$form.ShowDialog()

# Collect values
$ESXiHost = $txtHost.Text
$User = $txtUser.Text
$Password = $txtPass.Text | ConvertTo-SecureString -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($User, $Password)

# Output file
$OutputFile = "C:\temp\Reports\ESXi\$ESXiHost-ESXi_Config_Report.html"
New-Item -ItemType Directory -Force -Path "C:\temp\Reports\ESXi" | Out-Null

# -------------------------------
# 4. Connect to ESXi
# -------------------------------

Write-Host "Connecting to ESXi host $ESXiHost ..."
Connect-VIServer -Server $ESXiHost -Credential $Cred -Force

# -------------------------------
# 5. Collect ESXi Configuration
# -------------------------------

$VMHostObj = Get-VMHost -Name $ESXiHost

# Host summary
$Summary = $VMHostObj | Select-Object Name, Manufacturer, Model, Version, Build, ConnectionState

# CPU
$CPU = $VMHostObj | Select-Object Name,
    @{N="CPU Model";E={$_.ProcessorType}},
    @{N="CPU Cores";E={$_.NumCpu}},
    @{N="CPU Sockets";E={$_.NumCpuPackages}},
    @{N="CPU Threads";E={$_.NumCpuThreads}}

# Memory
$Memory = $VMHostObj | Select-Object Name,
    @{N="Total Memory (GB)";E={[math]::Round($_.MemoryTotalGB,2)}}

# Network summary
$Network = Get-VMHostNetwork -VMHost $VMHostObj |
    Select-Object HostName, DomainName, DnsAddress, VmotionEnabled

# VMkernel interfaces (vmk)
$VMKInterfaces = Get-VMHostNetworkAdapter -VMHost $VMHostObj -VMKernel |
    Select-Object Name,
                  IP,
                  SubnetMask,
                  Mac,
                  MTU,
                  PortGroupName,
                  @{N="vMotion";E={$_.VmotionEnabled}},
                  @{N="FaultTolerance";E={$_.FaultToleranceLoggingEnabled}},
                  @{N="Management";E={$_.ManagementTrafficEnabled}},
                  @{N="vSAN";E={$_.VsanTrafficEnabled}},
                  @{N="Provisioning";E={$_.ProvisioningEnabled}}

# Standard vSwitches
$StdSwitches = Get-VirtualSwitch -VMHost $VMHostObj | Where-Object { $_.GetType().Name -eq "VirtualSwitchImpl" }

# Distributed vSwitches
$VDSwitches = Get-VDSwitch -VMHost $VMHostObj

# Combined uplink table
$VSwitchUplinks = @()

# Standard vSwitch uplinks
foreach ($vs in $StdSwitches) {
    $policy = Get-NicTeamingPolicy -VirtualSwitch $vs

    $VSwitchUplinks += [PSCustomObject]@{
        SwitchType     = "Standard vSwitch"
        SwitchName     = $vs.Name
        ActiveUplinks  = ($policy.ActiveNic -join ", ")
        StandbyUplinks = ($policy.StandbyNic -join ", ")
    }
}

# Distributed vSwitch uplinks (per host)
$VDSwitches = Get-VDSwitch -VMHost $VMHostObj

foreach ($vds in $VDSwitches) {
    # Physical NICs on this host that are attached to this vDS
    $uplinkNics = Get-VMHostNetworkAdapter -VMHost $VMHostObj -Physical |
                  Where-Object { $_.DistributedSwitch -and $_.DistributedSwitch.Name -eq $vds.Name }

    $VSwitchUplinks += [PSCustomObject]@{
        SwitchType     = "Distributed vSwitch"
        SwitchName     = $vds.Name
        ActiveUplinks  = ($uplinkNics.Name -join ", ")
        StandbyUplinks = "N/A (handled per portgroup/policy)"
    }
}

# Port Groups
$PortGroups = Get-VirtualPortGroup -VMHost $VMHostObj |
    Select-Object Name, VirtualSwitchName, VLanId

# Datastores
$Datastores = Get-Datastore -VMHost $VMHostObj |
    Select-Object Name, Type,
        @{N="CapacityGB";E={[math]::Round($_.CapacityGB,2)}},
        @{N="FreeGB";E={[math]::Round($_.FreeSpaceGB,2)}}

# NTP configuration
$NTP = Get-VMHostNtpServer -VMHost $VMHostObj |
    Select-Object @{N="NTP Servers";E={$_}}

$NTPService = Get-VMHostService -VMHost $VMHostObj |
    Where-Object {$_.Key -eq "ntpd"} |
    Select-Object Key, Label, Running, Policy

# Syslog configuration
$Syslog = Get-VMHostSysLogServer -VMHost $VMHostObj |
    Select-Object Host, Port, Protocol

# -------------------------------
# 6. Build CSS-styled HTML Report
# -------------------------------

$HTML = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>ESXi Host Configuration Report - $($VMHostObj.Name)</title>
<style>
    body {
        font-family: Segoe UI, Tahoma, Arial, sans-serif;
        background-color: #f5f5f5;
        color: #333;
        margin: 0;
        padding: 20px;
    }
    h1 {
        background-color: #0078d4;
        color: #fff;
        padding: 15px 20px;
        border-radius: 4px;
    }
    h2 {
        margin-top: 30px;
        color: #0078d4;
        border-bottom: 2px solid #0078d4;
        padding-bottom: 5px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin-top: 10px;
        margin-bottom: 20px;
        background-color: #fff;
    }
    th, td {
        border: 1px solid #ddd;
        padding: 6px 8px;
        font-size: 12px;
    }
    th {
        background-color: #f0f0f0;
        font-weight: 600;
        text-align: left;
    }
    tr:nth-child(even) {
        background-color: #fafafa;
    }
    tr:hover {
        background-color: #f1f7ff;
    }
    .section {
        margin-bottom: 30px;
    }
</style>
</head>
<body>

<h1>ESXi Host Configuration Report - $($VMHostObj.Name)</h1>

<div class="section">
<h2>Host Summary</h2>
$( $Summary | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>CPU Information</h2>
$( $CPU | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>Memory Information</h2>
$( $Memory | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>Network Configuration</h2>
$( $Network | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>VMkernel Interfaces (vmk)</h2>
$( $VMKInterfaces | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>vSwitch Uplink Mappings (Standard + Distributed)</h2>
$( $VSwitchUplinks | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>Port Groups</h2>
$( $PortGroups | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>Datastores</h2>
$( $Datastores | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>NTP Configuration</h2>
$( $NTP | ConvertTo-Html -Fragment )
$( $NTPService | ConvertTo-Html -Fragment )
</div>

<div class="section">
<h2>Syslog Configuration</h2>
$( $Syslog | ConvertTo-Html -Fragment )
</div>

</body>
</html>
"@

$HTML | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "Report generated successfully:"
Write-Host $OutputFile

# -------------------------------
# 7. Optional Disconnect
# -------------------------------

if ($chkDisconnect.Checked) {
    Write-Host "Disconnecting from ESXi host..."
    Disconnect-VIServer -Server $ESXiHost -Confirm:$false
}
