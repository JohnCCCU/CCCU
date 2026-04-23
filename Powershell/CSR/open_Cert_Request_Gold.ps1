<#
SCOPE: GUI interface - Create New CSR request for ESXi Hosts, using OpenSSL format. 
    - Output is set for C:\temp\CSR\OpenSSL, but create a browse feature to place certs were ever.
    - Req, v3_Req and Req_distinguished_name are all accounted for 

CREATED BY: John W. Braunsdorf

DATE: 04/23/2026

#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Default output directory
$defaultOut = "C:\temp\CSR\OpenSSL"

# Ensure directory exists
if (-not (Test-Path $defaultOut)) {
    New-Item -ItemType Directory -Path $defaultOut -Force | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "OpenSSL CSR Generator"
$form.Size = New-Object System.Drawing.Size(420,300)
$form.StartPosition = "CenterScreen"

# Labels and Textboxes
$labelCN = New-Object System.Windows.Forms.Label
$labelCN.Text = "FQDN (Common Name):"
$labelCN.Location = "10,20"
$form.Controls.Add($labelCN)

$textCN = New-Object System.Windows.Forms.TextBox
$textCN.Location = "160,20"
$textCN.Width = 220
$form.Controls.Add($textCN)

$labelIP = New-Object System.Windows.Forms.Label
$labelIP.Text = "IP Address:"
$labelIP.Location = "10,60"
$form.Controls.Add($labelIP)

$textIP = New-Object System.Windows.Forms.TextBox
$textIP.Location = "160,60"
$textIP.Width = 220
$form.Controls.Add($textIP)

$labelOut = New-Object System.Windows.Forms.Label
$labelOut.Text = "Output Folder:"
$labelOut.Location = "10,100"
$form.Controls.Add($labelOut)

$textOut = New-Object System.Windows.Forms.TextBox
$textOut.Location = "160,100"
$textOut.Width = 180
$textOut.Text = $defaultOut
$form.Controls.Add($textOut)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = "350,100"
$btnBrowse.Add_Click({
    $folder = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folder.ShowDialog() -eq "OK") {
        $textOut.Text = $folder.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# Generate Button
$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "Generate CSR"
$btnGenerate.Location = "160,150"
$btnGenerate.Add_Click({

    $CN = $textCN.Text
    $IP = $textIP.Text
    $OUT = $textOut.Text

    if (-not $CN -or -not $IP -or -not $OUT) {
        [System.Windows.Forms.MessageBox]::Show("All fields are required.")
        return
    }

    # Ensure output directory exists
    if (-not (Test-Path $OUT)) {
        New-Item -ItemType Directory -Path $OUT -Force | Out-Null
    }

    # Extract short hostname from CN
    $ShortName = $CN.Split(".")[0]

    $keyFile = Join-Path $OUT "rui.key"
    $csrFile = Join-Path $OUT "rui.csr"
    $cfgFile = Join-Path $OUT "openssl_temp.cnf"

@"
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
subjectAltName = DNS:$ShortName, IP:$IP, DNS:$CN

[ req_distinguished_name ]
countryName = US
stateOrProvinceName = NY
localityName = New York
0.organizationName = domain.com
organizationalUnitName = IT
commonName = $CN
"@ | Out-File -Encoding ascii $cfgFile

    # Generate key
    openssl genrsa -out $keyFile 2048

    # Generate CSR
    openssl req -new -key $keyFile -out $csrFile -config $cfgFile

    [System.Windows.Forms.MessageBox]::Show("CSR and key generated successfully.`nOutput: $OUT")
})
$form.Controls.Add($btnGenerate)

$form.ShowDialog()
