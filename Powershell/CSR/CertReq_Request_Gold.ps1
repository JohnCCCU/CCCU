<#
SCOPE: GUI interface - CSR‑Only Script (Corrected + Web Server Fields) and in this script is using PKCS10 only
Certreq requires run as administrator as part of this program

CREATED BY: John W. Braunsdorf

DATE: 04/23/2026

#>

# --- AUTO‑ELEVATE TO ADMINISTRATOR ---
$currUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currUser)
$admin = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $principal.IsInRole($admin)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- GUI FORM ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Certreq CSR Generator"
$form.Size = New-Object System.Drawing.Size(420,260)
$form.StartPosition = "CenterScreen"

# Labels + Textboxes
$labels = @("FQDN (CN)", "IP Address")
$y = 20
$textboxes = @{}

foreach ($label in $labels) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point(10,$y)
    $lbl.Size = New-Object System.Drawing.Size(120,20)
    $form.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point(150,$y)
    $tb.Size = New-Object System.Drawing.Size(230,20)
    $form.Controls.Add($tb)

    $textboxes[$label] = $tb
    $y += 40
}

# Button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Generate CSR"
$button.Location = New-Object System.Drawing.Point(150,150)
$button.Size = New-Object System.Drawing.Size(120,30)
$form.Controls.Add($button)

# --- BUTTON ACTION ---
$button.Add_Click({
    $fqdn = $textboxes["FQDN (CN)"].Text
    $ip   = $textboxes["IP Address"].Text

    if (-not $fqdn) {
        [System.Windows.Forms.MessageBox]::Show("FQDN is required.")
        return
    }

    $csrPath = "C:\Temp\CSR"
    if (-not (Test-Path $csrPath)) {
        New-Item -ItemType Directory -Path $csrPath | Out-Null
    }

    $infFile = "$csrPath\$fqdn.inf"
    $csrFile = "$csrPath\$fqdn.csr"

$infContent = @"
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=$fqdn, O=Company Name, OU=IT, L=San Diego, S=California, C=US"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "DNS=$fqdn&"
_continue_ = "IP Address=$ip"
"@

    $infContent | Out-File -FilePath $infFile -Encoding ascii

    certreq.exe -new $infFile $csrFile

    [System.Windows.Forms.MessageBox]::Show("CSR created:`n$csrFile")
})

$form.ShowDialog()
