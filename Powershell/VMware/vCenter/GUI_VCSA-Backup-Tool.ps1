<#
SCOPE: Retore VMware vCenter from a Disaster Recovery (DR). using a combination of vCenter (SMB) and powershell to complete task. 
    # Validate vCenter has a central location for back ups and recovery.

    Location: go to line 203 and down for location. however, you have an option to add server and path in the UI\backup path
    - # Backup Path - Make sure to add exact server name and path

    Backup:
    - create back up from vCenter Management console
    - create back up from Powershell
    Restore:
    - Restore vCenter from back (SMB) location
    - Restore vCenter from powershell using stated saved location

CREATED BY: John W. Braunsdorf

DATE: 05/15/2026

VERSION: 1.1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#========================
# Helper: Start VCSA backup
#========================
function Start-VCSABackup {
    param(
        [string]$Server,
        [string]$User,
        [string]$Password,
        [string]$Protocol,
        [string]$Path,
        [string]$LocationUser,
        [string]$LocationPassword,
        [string]$Piece,
        [string]$EncryptPassword,
        [string]$Comment
    )

    $logPrefix = "[{0}] " -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    try {
        $uri = "https://$Server`:5480/rest/appliance/recovery/backup/job"

        # Build location string
        if ($Protocol -eq "smb") {
            if ($Path -like "smb://*") {
                $location = $Path
            } else {
                $clean = $Path.TrimStart("\","/")
                $location = "smb://$clean"
            }
        } else {
            $location = "$Protocol`:$Path"
        }

        $body = @{
            piece            = $Piece
            location         = $location
            locationUser     = $LocationUser
            locationPassword = $LocationPassword
            comment          = $Comment
        }

        if ($EncryptPassword) {
            $body.encryptPassword = $EncryptPassword
        }

        $jsonBody = $body | ConvertTo-Json -Depth 5

        $secPass = ConvertTo-SecureString $Password -AsPlainText -Force
        $cred    = New-Object System.Management.Automation.PSCredential($User, $secPass)

        # Ignore self-signed certs
        add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

        $result = Invoke-RestMethod -Method POST -Uri $uri -Credential $cred -Body $jsonBody -ContentType "application/json" -ErrorAction Stop

        return "$logPrefix Backup job triggered successfully.`r`n$result"
    }
    catch {
        return "$logPrefix ERROR: $($_.Exception.Message)"
    }
}

#========================
# SMB Path Validation
#========================
function Test-BackupPath {
    param(
        [string]$UNCPath,
        [string]$User,
        [string]$Password
    )

    try {
        if ($UNCPath -notmatch "^smb://") {
            return "ERROR: Path must start with smb://"
        }

        # Convert smb://server/share → \\server\share
        $clean = $UNCPath.Replace("smb://", "")
        $unc = "\\" + $clean.Replace("/", "\")

        # Extract server name
        $serverName = ($clean.Split("/"))[0]

        # Kill existing SMB sessions to avoid credential conflict
        cmd.exe /c "net use \\$serverName /delete /y" | Out-Null

        # Map temporary drive
        $sec = ConvertTo-SecureString $Password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($User, $sec)

        New-PSDrive -Name Z -PSProvider FileSystem -Root $unc -Credential $cred -ErrorAction Stop | Out-Null

        if (-not (Test-Path "Z:\")) {
            Remove-PSDrive Z -Force -ErrorAction SilentlyContinue
            return "ERROR: Path not accessible."
        }

        Remove-PSDrive Z -Force -ErrorAction SilentlyContinue
        return "OK"
    }
    catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#========================
# UI Setup
#========================
$form = New-Object System.Windows.Forms.Form
$form.Text = "VCSA Backup Tool v1.2"
$form.Size = New-Object System.Drawing.Size(600,700)
$form.StartPosition = "CenterScreen"

$y = 15
$leftLabel = 10
$leftInput = 150
$inputWidth = 180

function New-Label {
    param($text, $yPos)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.Location = New-Object System.Drawing.Point($leftLabel, $yPos)
    $lbl.AutoSize = $true
    return $lbl
}

function New-Textbox {
    param($yPos, [bool]$isPassword = $false, [int]$width = $inputWidth)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point($leftInput, $yPos)
    $txt.Width = $width
    if ($isPassword) { $txt.UseSystemPasswordChar = $true }
    return $txt
}

# VCSA Server
$form.Controls.Add((New-Label "VCSA Address (FQDN/IP):" $y))
$txtServer = New-Textbox $y
$form.Controls.Add($txtServer)
$y += 30

# Username
$form.Controls.Add((New-Label "VCSA Username:" $y))
$txtUser = New-Textbox $y
$txtUser.Text = "root"
$form.Controls.Add($txtUser)
$y += 30

# Password
$form.Controls.Add((New-Label "VCSA Password:" $y))
$txtPass = New-Textbox $y $true
$form.Controls.Add($txtPass)
$y += 30

# Protocol
$form.Controls.Add((New-Label "Backup Protocol:" $y))
$cmbProtocol = New-Object System.Windows.Forms.ComboBox
$cmbProtocol.Location = New-Object System.Drawing.Point($leftInput, $y)
$cmbProtocol.Width = $inputWidth
$cmbProtocol.DropDownStyle = "DropDownList"
[void]$cmbProtocol.Items.AddRange(@("smb","ftp","ftps","http","https"))
$cmbProtocol.SelectedIndex = 0
$form.Controls.Add($cmbProtocol)
$y += 30

# Backup Path - Make sure to add exact server name and path
$form.Controls.Add((New-Label "Backup Path:" $y))
$txtPath = New-Textbox $y
$txtPath.Text = "smb://servername/folder"
$form.Controls.Add($txtPath)
$y += 30

# Location Username
$form.Controls.Add((New-Label "Location Username:" $y))
$txtLocUser = New-Textbox $y
$form.Controls.Add($txtLocUser)
$y += 30

# Location Password
$form.Controls.Add((New-Label "Location Password:" $y))
$txtLocPass = New-Textbox $y $true
$form.Controls.Add($txtLocPass)
$y += 30

# Piece
$form.Controls.Add((New-Label "Backup Piece:" $y))
$cmbPiece = New-Object System.Windows.Forms.ComboBox
$cmbPiece.Location = New-Object System.Drawing.Point($leftInput, $y)
$cmbPiece.Width = $inputWidth
$cmbPiece.DropDownStyle = "DropDownList"
[void]$cmbPiece.Items.AddRange(@("common","seat","all"))
$cmbPiece.SelectedIndex = 2
$form.Controls.Add($cmbPiece)
$y += 30

# Encrypt Password
$form.Controls.Add((New-Label "Encrypt PW (optional):" $y))
$txtEncPass = New-Textbox $y $true
$form.Controls.Add($txtEncPass)
$y += 30

# Comment
$form.Controls.Add((New-Label "Comment:" $y))
$txtComment = New-Textbox $y $false 250
$txtComment.Text = "Automated backup"
$form.Controls.Add($txtComment)
$y += 40

# Run Backup Button
$btnBackup = New-Object System.Windows.Forms.Button
$btnBackup.Text = "Run Backup"
$btnBackup.Location = New-Object System.Drawing.Point($leftInput, $y)
$btnBackup.Width = 120
$form.Controls.Add($btnBackup)

# Close Button (fixed coordinate to avoid array math bug)
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(290, $y)
$btnClose.Width = 80
$form.Controls.Add($btnClose)
$y += 50

# Log label
$form.Controls.Add((New-Label "Log:" $y))
$y += 20

# Log TextBox
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(10, $y)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Width = 550
$txtLog.Height = 180
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)
$y += 200

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, $y)
$progressBar.Size = New-Object System.Drawing.Size(550, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$form.Controls.Add($progressBar)

#========================
# Events
#========================
$btnBackup.Add_Click({
    $btnBackup.Enabled = $false
    $progressBar.Value = 0
    $txtLog.AppendText("Starting backup..." + [Environment]::NewLine)

    $server   = $txtServer.Text.Trim()
    $user     = $txtUser.Text.Trim()
    $pass     = $txtPass.Text
    $protocol = $cmbProtocol.SelectedItem
    $path     = $txtPath.Text.Trim()
    $locUser  = $txtLocUser.Text.Trim()
    $locPass  = $txtLocPass.Text
    $piece    = $cmbPiece.SelectedItem
    $encPass  = $txtEncPass.Text
    $comment  = $txtComment.Text

    # Validate Path
    $progressBar.Value = 10
    $txtLog.AppendText("Validating backup path..." + [Environment]::NewLine)

    $validation = Test-BackupPath -UNCPath $path -User $locUser -Password $locPass

    if ($validation -ne "OK") {
        $txtLog.AppendText("$validation`r`n")
        $progressBar.Value = 0
        $btnBackup.Enabled = $true
        return
    }

    $txtLog.AppendText("Backup path validated successfully.`r`n")
    $progressBar.Value = 40

    # Trigger Backup
    $txtLog.AppendText("Triggering VCSA backup job..." + [Environment]::NewLine)

    $result = Start-VCSABackup -Server $server `
                               -User $user `
                               -Password $pass `
                               -Protocol $protocol `
                               -Path $path `
                               -LocationUser $locUser `
                               -LocationPassword $locPass `
                               -Piece $piece `
                               -EncryptPassword $encPass `
                               -Comment $comment

    $progressBar.Value = 80

    # Log Result
    $txtLog.AppendText($result + [Environment]::NewLine)
    $txtLog.AppendText("------------------------" + [Environment]::NewLine)

    $progressBar.Value = 100
    Start-Sleep -Milliseconds 500
    $progressBar.Value = 0

    $btnBackup.Enabled = $true
})

$btnClose.Add_Click({
    $form.Close()
})

$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
