<#
SCOPE: New UI - Create new CSR using OpenSSL

do not forget to fill out the [ req_distinguished_name ] section

CREATED BY: John W. Braunsdorf

DATE: 04/24/2026

#>


Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "OpenSSL New CSR Generator"
$form.Size = New-Object System.Drawing.Size(500,400)

# --- INPUT FIELDS ---
$labels = "Common Name (FQDN)", "Short Name", "IP Address"
$y = 20
$inputs = @{}

foreach ($label in $labels) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point(10,$y)
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(170,$y)
    $txt.Width = 300
    $form.Controls.Add($txt)

    $inputs[$label] = $txt
    $y += 40
}

# --- SAVE PATH FIELD ---
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Save Output To:"
$lblPath.Location = New-Object System.Drawing.Point(10, $y)
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(170, $y)
$txtPath.Width = 300
$form.Controls.Add($txtPath)

$y += 40

# --- BROWSE BUTTON BELOW PATH ---
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Width = 100
$btnBrowse.Location = New-Object System.Drawing.Point(170, $y)
$form.Controls.Add($btnBrowse)

$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog

$btnBrowse.Add_Click({
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtPath.Text = $folderDialog.SelectedPath
    }
})

$y += 60

# --- GENERATE BUTTON ---
$button = New-Object System.Windows.Forms.Button
$button.Text = "Generate CSR"
$button.Location = New-Object System.Drawing.Point(180, $y)
$form.Controls.Add($button)

$button.Add_Click({
    $CN    = $inputs["Common Name (FQDN)"].Text
    $Short = $inputs["Short Name"].Text
    $IP    = $inputs["IP Address"].Text
    $Path  = $txtPath.Text

    if (-not (Test-Path $Path)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid save path.")
        return
    }

    $Config = @"
[ req ]
default_bits = 2048
default_keyfile = rui.key
distinguished_name = req_distinguished_name
encrypt_key = no
prompt = no
string_mask = nombstr
req_extensions = v3_req

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$Short, IP:$IP, DNS:$CN

[ req_distinguished_name ]
countryName = US
stateOrProvinceName = NY
localityName = New York
0.organizationName = domain.com
organizationalUnitName = IT
commonName = $CN
"@

    $ConfigFile = Join-Path $Path "gui_csr.cnf"
    $KeyFile    = Join-Path $Path "gui.key"
    $CSRFile    = Join-Path $Path "gui.csr"

    $Config | Out-File -Encoding ascii $ConfigFile

    openssl genrsa -out $KeyFile 2048
    openssl req -new -key $KeyFile -out $CSRFile -config $ConfigFile

    [System.Windows.Forms.MessageBox]::Show("CSR and key generated successfully.`nSaved to:`n$Path")
})

$form.ShowDialog()
