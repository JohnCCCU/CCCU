<#
RESOURCE: 
https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere/7-0/vcenter-upgrade/upgrading-and-updating-the-vcenter-server-appliance/preparing-to-upgrade-vcenter-server-appliance/prepare-esxi-hosts-for-vcenter-server-appliance-upgrade/change-the-certificate-mode.html?utm_source=copilot.com

SCOPE: Change \ manage all ESXi 3rd party certs. removing vCenter (VCSA) from this task, before updating validates PEM files are inplace
vCenter local machine ssl cert

FEATURES: CONNECT, CANCEL, DISCONNECT BUTTONS, Status window and Path Validation

CREATOR: John William Braunsdorf

DATE: 04/13/2026

REV: v1.6

LOCATION: C:\temp\certs\vcenter (PEM files should be located here)

#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- MAIN FORM ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "vCenter Machine SSL Replacement"
$form.Size = New-Object System.Drawing.Size(650,600)
$form.StartPosition = "CenterScreen"

# --- VCENTER INPUT ---
$lblVC = New-Object System.Windows.Forms.Label
$lblVC.Text = "vCenter Server:"
$lblVC.Location = "20,20"
$form.Controls.Add($lblVC)

$txtVC = New-Object System.Windows.Forms.TextBox
$txtVC.Location = "150,18"
$txtVC.Width = 320
$form.Controls.Add($txtVC)

# --- USERNAME ---
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Username:"
$lblUser.Location = "20,55"
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = "150,53"
$txtUser.Width = 320
$form.Controls.Add($txtUser)

# --- PASSWORD ---
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "Password:"
$lblPass.Location = "20,90"
$form.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = "150,88"
$txtPass.Width = 320
$txtPass.UseSystemPasswordChar = $true
$form.Controls.Add($txtPass)

# --- CONNECT BUTTON ---
$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Text = "Connect"
$btnConnect.Location = "490,53"
$form.Controls.Add($btnConnect)

# --- DISCONNECT BUTTON ---
$btnDisconnect = New-Object System.Windows.Forms.Button
$btnDisconnect.Text = "Disconnect"
$btnDisconnect.Location = "490,88"
$form.Controls.Add($btnDisconnect)

# --- STATUS BOX ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status:"
$lblStatus.Location = "20,130"
$form.Controls.Add($lblStatus)

$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = "20,150"
$txtStatus.Multiline = $true
$txtStatus.ScrollBars = "Vertical"
$txtStatus.Width = 600
$txtStatus.Height = 120
$txtStatus.ReadOnly = $true
$form.Controls.Add($txtStatus)

function Write-Status {
    param([string]$Message)
    $txtStatus.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
}

# --- FILE PATH DISPLAY (AUTO-LOADED) ---
$lblCert = New-Object System.Windows.Forms.Label
$lblCert.Text = "cert.pem:"
$lblCert.Location = "20,290"
$form.Controls.Add($lblCert)

$txtCert = New-Object System.Windows.Forms.TextBox
$txtCert.Location = "150,288"
$txtCert.Width = 420
$form.Controls.Add($txtCert)

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = "key.pem:"
$lblKey.Location = "20,325"
$form.Controls.Add($lblKey)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Location = "150,323"
$txtKey.Width = 420
$form.Controls.Add($txtKey)

$lblChain = New-Object System.Windows.Forms.Label
$lblChain.Text = "chain.pem:"
$lblChain.Location = "20,360"
$form.Controls.Add($lblChain)

$txtChain = New-Object System.Windows.Forms.TextBox
$txtChain.Location = "150,358"
$txtChain.Width = 420
$form.Controls.Add($txtChain)

# --- AUTO-LOAD FILES FROM C:\temp ---
$form.Add_Shown({
    $certPath  = "C:\temp\certs\vcenter\cert.pem"
    $keyPath   = "C:\temp\certs\vcenter\key.pem"
    $chainPath = "C:\temp\certs\vcenter\chain.pem"

    Write-Status "Checking C:\temp\certs\vcenter for PEM files..."

    if (Test-Path $certPath)  { $txtCert.Text  = $certPath;  Write-Status "Found cert.pem" }
    else { Write-Status "cert.pem not found in $certPath" }

    if (Test-Path $keyPath)   { $txtKey.Text   = $keyPath;   Write-Status "Found key.pem" }
    else { Write-Status "key.pem not found in $keyPath" }

    if (Test-Path $chainPath) { $txtChain.Text = $chainPath; Write-Status "Found chain.pem" }
    else { Write-Status "chain.pem not found in $chainPath" }
})

# --- REPLACE BUTTON ---
$btnReplace = New-Object System.Windows.Forms.Button
$btnReplace.Text = "Replace Machine SSL"
$btnReplace.Location = "20,410"
$btnReplace.Width = 200
$form.Controls.Add($btnReplace)

# --- CANCEL BUTTON ---
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = "240,410"
$btnCancel.Width = 200
$form.Controls.Add($btnCancel)

# --- EVENTS ---

# CONNECT TO VCENTER
$btnConnect.Add_Click({
    try {
        Write-Status "Connecting to vCenter $($txtVC.Text)..."

        $secPass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($txtUser.Text, $secPass)

        Connect-VIServer -Server $txtVC.Text -Credential $cred -ErrorAction Stop | Out-Null

        Write-Status "Connected to vCenter."
    }
    catch {
        Write-Status "ERROR connecting: $($_.Exception.Message)"
    }
})

# DISCONNECT BUTTON
$btnDisconnect.Add_Click({
    try {
        if ($global:DefaultVIServer) {
            Write-Status "Disconnecting from vCenter..."
            Disconnect-VIServer -Server $global:DefaultVIServer -Confirm:$false
            Write-Status "Disconnected."
        }
        else {
            Write-Status "No active vCenter session."
        }
    }
    catch {
        Write-Status "ERROR disconnecting: $($_.Exception.Message)"
    }
})

# CANCEL BUTTON
$btnCancel.Add_Click({
    try {
        if ($global:DefaultVIServer) {
            Write-Status "Disconnecting from vCenter..."
            Disconnect-VIServer -Server $global:DefaultVIServer -Confirm:$false
            Write-Status "Disconnected."
        }
    }
    catch {}

    Write-Status "Closing UI..."
    $form.Close()
})

# REPLACE MACHINE SSL
$btnReplace.Add_Click({
    $certPath  = $txtCert.Text
    $keyPath   = $txtKey.Text
    $chainPath = $txtChain.Text

    Write-Status "Validating PEM file paths..."

    if (-not (Test-Path $certPath))  { Write-Status "Missing cert.pem"; return }
    if (-not (Test-Path $keyPath))   { Write-Status "Missing key.pem"; return }
    if (-not (Test-Path $chainPath)) { Write-Status "Missing chain.pem"; return }

    try {
        Write-Status "Loading PEM files..."
        $cert  = Get-Content $certPath  -Raw
        $key   = Get-Content $keyPath   -Raw
        $chain = Get-Content $chainPath -Raw

        Write-Status "Building PEM bundle..."
        $bundle = $cert + "`n" + $key + "`n" + $chain

        Write-Status "Replacing Machine SSL certificate..."
        Set-VIMachineCertificate -PemCertificateOrChain $bundle -ErrorAction Stop | Out-Null

        Write-Status "SUCCESS: Machine SSL replaced."

        # --- RESTART VCENTER SERVICES ---
        Write-Status "Restarting vCenter services (this may take several minutes)..."

        $secPass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($txtUser.Text, $secPass)

        # Stop all services
        Write-Status "Stopping all services..."
        ssh $txtUser.Text@$txtVC.Text "service-control --stop --all" | Out-Null

        # Start all services
        Write-Status "Starting all services..."
        ssh $txtUser.Text@$txtVC.Text "service-control --start --all" | Out-Null

        Write-Status "vCenter services restarted successfully."
    }
    catch {
        Write-Status "ERROR replacing certificate or restarting services: $($_.Exception.Message)"
    }
})
$form.ShowDialog()

#region - closing \ disconnecting VI-Server session
$form.Add_FormClosing({
    if ($global:DefaultVIServer) {
        Write-Status "Disconnecting from vCenter..."
        Disconnect-VIServer -Server $global:DefaultVIServer -Confirm:$false
    }
})
#endregion