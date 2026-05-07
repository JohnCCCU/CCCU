#
<#

SCOPE: Create a complete ESXi backup \ restore for v7\8
 - Full GUI login window
ESXi only, no vCenter connection

Username

Password (masked)

######

- Full backup GUI

- Progress bar

- Correct backup filename detection

- ESXi‑name‑based backup folder

  - Checksum generation

- Maintenance‑mode validation for restore

- Clean disconnect after each operation

- Global fail‑safe disconnect at the end

- Direct ESXi connection (no vCenter)

Restore Option
- Full restore GUI
- Validate Maintenance mode is enable, if not restart after enabling "Maintenance Mode"

CREATED BY: John W. Braunsdorf

DATE: 05/06/2026

VERSION:1.2

#>
# 
<# What is actually Backed ups
1. Host networking configuration
vSwitches (vSS)

Port groups

VMkernel adapters (vmk0, vmk1…)

VLAN settings

NIC teaming / failover order

MTU settings

TCP/IP stack settings

2. Host security configuration
Local users and groups

Permissions

Lockdown mode settings

SSH / ESXi Shell settings

Firewall rules

3. Storage configuration
VMFS datastore mappings

iSCSI configuration

NFS mounts

SATP/PSP multipathing settings

4. System configuration
Hostname

DNS servers

NTP servers

Syslog settings

SNMP settings

Advanced host settings

Power management settings

5. Licensing
ESXi license assignment

6. Core system files
/etc directory contents

/bootbank metadata

Host profile–related configuration

#>
# 
Add-Type -AssemblyName System.Windows.Forms

###############################################
### GUI: MAIN MENU (Backup or Restore)
###############################################

$menuForm = New-Object System.Windows.Forms.Form
$menuForm.Text = "ESXi Backup / Restore"
$menuForm.Size = New-Object System.Drawing.Size(300,200)
$menuForm.StartPosition = "CenterScreen"

$backupButton = New-Object System.Windows.Forms.Button
$backupButton.Text = "Backup ESXi Host"
$backupButton.Size = New-Object System.Drawing.Size(200,40)
$backupButton.Location = New-Object System.Drawing.Point(40,30)
$backupButton.Add_Click({
    $menuForm.Tag = "backup"
    $menuForm.Close()
})
$menuForm.Controls.Add($backupButton)

$restoreButton = New-Object System.Windows.Forms.Button
$restoreButton.Text = "Restore ESXi Host"
$restoreButton.Size = New-Object System.Drawing.Size(200,40)
$restoreButton.Location = New-Object System.Drawing.Point(40,90)
$restoreButton.Add_Click({
    $menuForm.Tag = "restore"
    $menuForm.Close()
})
$menuForm.Controls.Add($restoreButton)

$menuForm.ShowDialog()
$mode = $menuForm.Tag

###############################################
### GUI: LOGIN WINDOW
###############################################

$form = New-Object System.Windows.Forms.Form
$form.Text = "ESXi Login"
$form.Size = New-Object System.Drawing.Size(380,240)
$form.StartPosition = "CenterScreen"

# ESXi Host Label
$labelHost = New-Object System.Windows.Forms.Label
$labelHost.Text = "ESXi Host:"
$labelHost.Location = New-Object System.Drawing.Point(20,20)
$labelHost.AutoSize = $true
$form.Controls.Add($labelHost)

# ESXi Host Textbox
$textHost = New-Object System.Windows.Forms.TextBox
$textHost.Location = New-Object System.Drawing.Point(120,18)
$textHost.Width = 220
$form.Controls.Add($textHost)

# Username Label
$labelUser = New-Object System.Windows.Forms.Label
$labelUser.Text = "Username:"
$labelUser.Location = New-Object System.Drawing.Point(20,60)
$labelUser.AutoSize = $true
$form.Controls.Add($labelUser)

# Username Textbox
$textUser = New-Object System.Windows.Forms.TextBox
$textUser.Location = New-Object System.Drawing.Point(120,58)
$textUser.Width = 220
$form.Controls.Add($textUser)

# Password Label
$labelPass = New-Object System.Windows.Forms.Label
$labelPass.Text = "Password:"
$labelPass.Location = New-Object System.Drawing.Point(20,100)
$labelPass.AutoSize = $true
$form.Controls.Add($labelPass)

# Password Textbox
$textPass = New-Object System.Windows.Forms.TextBox
$textPass.Location = New-Object System.Drawing.Point(120,98)
$textPass.Width = 220
$textPass.UseSystemPasswordChar = $true
$form.Controls.Add($textPass)

# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Continue"
$okButton.Location = New-Object System.Drawing.Point(140,140)
$okButton.Add_Click({ $form.Close() })
$form.Controls.Add($okButton)

$form.ShowDialog()

$esxiHost = $textHost.Text
$username = $textUser.Text
$password = $textPass.Text

###############################################
### GUI: RESTORE FILE PICKER (Restore Mode Only)
###############################################

if ($mode -eq "restore") {

    $restoreForm = New-Object System.Windows.Forms.Form
    $restoreForm.Text = "Select Backup File"
    $restoreForm.Size = New-Object System.Drawing.Size(420,200)
    $restoreForm.StartPosition = "CenterScreen"

    $labelFile = New-Object System.Windows.Forms.Label
    $labelFile.Text = "Backup File:"
    $labelFile.Location = New-Object System.Drawing.Point(20,20)
    $labelFile.AutoSize = $true
    $restoreForm.Controls.Add($labelFile)

    $textFile = New-Object System.Windows.Forms.TextBox
    $textFile.Location = New-Object System.Drawing.Point(120,18)
    $textFile.Width = 200
    $restoreForm.Controls.Add($textFile)

    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Text = "Browse"
    $browseButton.Location = New-Object System.Drawing.Point(330,16)
    $browseButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "TGZ Files (*.tgz)|*.tgz"
        if ($dialog.ShowDialog() -eq "OK") {
            $textFile.Text = $dialog.FileName
        }
    })
    $restoreForm.Controls.Add($browseButton)

    $restoreOK = New-Object System.Windows.Forms.Button
    $restoreOK.Text = "Restore"
    $restoreOK.Location = New-Object System.Drawing.Point(150,70)
    $restoreOK.Add_Click({ $restoreForm.Close() })
    $restoreForm.Controls.Add($restoreOK)

    $restoreForm.ShowDialog()
    $backupFile = $textFile.Text
}

###############################################
### PROGRESS BAR WINDOW
###############################################

$progressForm = New-Object System.Windows.Forms.Form
$progressForm.Text = "Processing..."
$progressForm.Size = New-Object System.Drawing.Size(400,120)
$progressForm.StartPosition = "CenterScreen"

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,20)
$progressBar.Size = New-Object System.Drawing.Size(340,30)
$progressBar.Style = "Marquee"
$progressBar.MarqueeAnimationSpeed = 30
$progressForm.Controls.Add($progressBar)

###############################################
### BACKUP MODE
###############################################

if ($mode -eq "backup") {

    $backupRoot = "C:\temp\VMware\ESXi_backups"

    # Create folder based on ESXi name
    $hostFolder = Join-Path $backupRoot $esxiHost
    if (-not (Test-Path $hostFolder)) {
        New-Item -ItemType Directory -Path $hostFolder | Out-Null
    }

    $progressForm.Show()

    Connect-VIServer -Server $esxiHost -User $username -Password $password

    # Perform backup
    Get-VMHostFirmware -VMHost $esxiHost -BackupConfiguration -DestinationPath $hostFolder

    # Detect actual backup file
    $backupFile = Get-ChildItem -Path $hostFolder -Filter "configBundle*.tgz" |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if (-not $backupFile) {
        $progressForm.Close()
        [System.Windows.Forms.MessageBox]::Show("Backup failed — no backup file created.","Error")
        Disconnect-VIServer -Server $esxiHost -Confirm:$false
        return
    }

    # Generate checksum
    $hash = Get-FileHash -Path $backupFile.FullName -Algorithm SHA256
    $hash.Hash | Out-File "$($backupFile.FullName).sha256"

    Disconnect-VIServer -Server $esxiHost -Confirm:$false
    $progressForm.Close()

    [System.Windows.Forms.MessageBox]::Show("Backup completed successfully.","Done")
}

###############################################
### RESTORE MODE (with Maintenance‑Mode Validation)
###############################################

if ($mode -eq "restore") {

    $progressForm.Show()

    Connect-VIServer -Server $esxiHost -User $username -Password $password

    # Validate maintenance mode
    $hostObj = Get-VMHost -Name $esxiHost
    if ($hostObj.ConnectionState -ne "Maintenance") {

        $progressForm.Close()
        Disconnect-VIServer -Server $esxiHost -Confirm:$false

        [System.Windows.Forms.MessageBox]::Show(
            "Rerun restore when ESXi host is in maintenance mode.",
            "Host Not In Maintenance Mode"
        )

        return
    }

    # Perform restore
    Get-VMHostFirmware -VMHost $esxiHost -Restore -SourcePath $backupFile -HostUser $username -HostPassword $password

    Disconnect-VIServer -Server $esxiHost -Confirm:$false
    $progressForm.Close()

    [System.Windows.Forms.MessageBox]::Show("Restore completed. Host will reboot.","Done")
}

###############################################
### GLOBAL FAIL‑SAFE DISCONNECT (Always Runs)
###############################################

try {
    Disconnect-VIServer -Server $esxiHost -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

