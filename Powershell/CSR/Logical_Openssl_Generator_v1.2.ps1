<#
SCOPE: created script with UI, openssl integration and three options for Windows, vCenter and ESXi Host csr. Output to a 
        - windows-openssl.cnf, vcenter-openssl.cnf and esxi-openssl.cnf

 - A single exported command

 - All UI logic isolated

 - No global variables

 - No global functions

 - Easy to import and update

 - Safe to distribute inside your environment

 go to line 169 - make sure to update these fields
 #############################################
 # [ req_distinguished_name ]
 # countryName                 = US
 # stateOrProvinceName         = CA
 # localityName                = San Diego
 # 0.organizationName          = Domain
 # organizationalUnitName      = IT
 # commonName                  = $FQDN
 #############################################

CREATED BY: John W. Braunsdorf

DATE:05/08/2026
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore
Add-Type -AssemblyName System.Windows.Forms

# XAML for WPF Window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OpenSSL Config Generator" Height="540" Width="700"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>   <!-- Cert type -->
            <RowDefinition Height="Auto"/>   <!-- FQDN -->
            <RowDefinition Height="Auto"/>   <!-- Hostname -->
            <RowDefinition Height="Auto"/>   <!-- IP -->
            <RowDefinition Height="Auto"/>   <!-- DNS3 -->
            <RowDefinition Height="Auto"/>   <!-- DNS4 -->
            <RowDefinition Height="Auto"/>   <!-- Windows Localhost -->
            <RowDefinition Height="Auto"/>   <!-- Output folder -->
            <RowDefinition Height="Auto"/>   <!-- Buttons -->
            <RowDefinition Height="*"/>      <!-- Output text -->
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="180"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="110"/>
        </Grid.ColumnDefinitions>

        <!-- Certificate Type -->
        <TextBlock Grid.Row="0" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">Choose Certificate Type:</TextBlock>
        <ComboBox x:Name="CertTypeCombo" Grid.Row="0" Grid.Column="1" Margin="0,0,0,10" SelectedIndex="0">
            <ComboBoxItem>Microsoft Windows Server</ComboBoxItem>
            <ComboBoxItem>VMware vCenter Machine SSL</ComboBoxItem>
            <ComboBoxItem>VMware ESXi Host SSL</ComboBoxItem>
        </ComboBox>

        <!-- FQDN -->
        <TextBlock Grid.Row="1" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">FQDN:</TextBlock>
        <TextBox x:Name="FqdnBox" Grid.Row="1" Grid.Column="1" Margin="0,0,0,10"
                 Text="server.domain.local"
                 ToolTip="Fully Qualified Domain Name (e.g. server.domain.local)"/>

        <!-- Hostname -->
        <TextBlock Grid.Row="2" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">Hostname:</TextBlock>
        <TextBox x:Name="HostBox" Grid.Row="2" Grid.Column="1" Margin="0,0,0,10"
                 Text="server"
                 ToolTip="Short hostname without domain (e.g. server)"/>

        <!-- IP Address -->
        <TextBlock Grid.Row="3" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">IP Address:</TextBlock>
        <TextBox x:Name="IpBox" Grid.Row="3" Grid.Column="1" Margin="0,0,0,10"
                 Text="192.168.1.10"
                 ToolTip="Primary IP address for the certificate"/>

        <!-- DNS.3 -->
        <TextBlock Grid.Row="4" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">DNS.3 (optional):</TextBlock>
        <TextBox x:Name="Dns3Box" Grid.Row="4" Grid.Column="1" Margin="0,0,0,10"
                 Text="Enter optional-alt1.domain.local - leave blank if not used"
                 ToolTip="Optional additional DNS SAN entry"/>

        <!-- DNS.4 -->
        <TextBlock Grid.Row="5" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">DNS.4 (optional):</TextBlock>
        <TextBox x:Name="Dns4Box" Grid.Row="5" Grid.Column="1" Margin="0,0,0,10"
                 Text="Enter optional-alt2.domain.local - leave blank if not used"
                 ToolTip="Optional additional DNS SAN entry"/>

        <!-- Windows Localhost -->
        <TextBlock Grid.Row="6" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">Windows Localhost:</TextBlock>
        <TextBox x:Name="WinLocalBox" Grid.Row="6" Grid.Column="1" Margin="0,0,0,10"
                 Text="Enter Windows localhost - leave blank if not used"
                 ToolTip="Value to use for Windows localhost SAN (e.g. localhost or 127.0.0.1)"/>

        <!-- Output Folder -->
        <TextBlock Grid.Row="7" Grid.Column="0" Margin="0,0,5,10" VerticalAlignment="Center">Output Folder:</TextBlock>
        <TextBox x:Name="OutFolderBox" Grid.Row="7" Grid.Column="1" Margin="0,0,5,10"
                 Text="C:\Temp"
                 ToolTip="Folder where the .cnf file will be saved"/>
        <Button x:Name="BrowseBtn" Grid.Row="7" Grid.Column="2" Margin="0,0,0,10" Width="90" Content="Browse..."/>

        <!-- Buttons (Generate centered) -->
        <Grid Grid.Row="8" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,10,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Button x:Name="GenerateBtn" Grid.Column="1" Margin="10,0" Height="30" Width="260"
                    HorizontalAlignment="Center"
                    Content="Generate Selected OpenSSL Config"/>

            <Button x:Name="CancelBtn" Grid.Column="2" Margin="10,0" Height="30" Width="90"
                    HorizontalAlignment="Left"
                    Content="Cancel"/>
        </Grid>

        <!-- Output Text -->
        <TextBlock x:Name="OutputText" Grid.Row="9" Grid.Column="0" Grid.ColumnSpan="3"
                   TextWrapping="Wrap" Foreground="DarkGreen"/>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$CertTypeCombo = $window.FindName("CertTypeCombo")
$FqdnBox       = $window.FindName("FqdnBox")
$HostBox       = $window.FindName("HostBox")
$IpBox         = $window.FindName("IpBox")
$Dns3Box       = $window.FindName("Dns3Box")
$Dns4Box       = $window.FindName("Dns4Box")
$WinLocalBox   = $window.FindName("WinLocalBox")
$OutFolderBox  = $window.FindName("OutFolderBox")
$BrowseBtn     = $window.FindName("BrowseBtn")
$GenerateBtn   = $window.FindName("GenerateBtn")
$CancelBtn     = $window.FindName("CancelBtn")
$OutputText    = $window.FindName("OutputText")

# Browse button logic
$BrowseBtn.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $OutFolderBox.Text
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $OutFolderBox.Text = $dialog.SelectedPath
    }
})

# Cancel button logic
$CancelBtn.Add_Click({
    $window.Close()
})

# Helper: DN block - DO NOT FORGET TO UP THE FIELDS BELOW
function Get-DistinguishedNameBlock {
    param([string]$FQDN)
@"
[ req_distinguished_name ]
countryName                 = US
stateOrProvinceName         = CA
localityName                = San Diego
0.organizationName          = Domain
organizationalUnitName      = IT
commonName                  = $FQDN
"@
}

# Helper: SAN block
function Get-SanBlock {
    param(
        [string]$Hostname,
        [string]$FQDN,
        [string]$DNS3,
        [string]$DNS4,
        [string]$IP1,
        [bool]  $IncludeLocalhost,
        [string]$LocalhostValue = "localhost"
    )

    $sanList = @()
    $sanList += "DNS.1 = $Hostname"
    $sanList += "DNS.2 = $FQDN"

    $counter = 3
    if (-not [string]::IsNullOrWhiteSpace($DNS3)) {
        $sanList += "DNS.$counter = $DNS3"
        $counter++
    }
    if (-not [string]::IsNullOrWhiteSpace($DNS4)) {
        $sanList += "DNS.$counter = $DNS4"
        $counter++
    }

    if ($IncludeLocalhost -and -not [string]::IsNullOrWhiteSpace($LocalhostValue)) {
        $sanList += "DNS.$counter = $LocalhostValue"
        $counter++
    }

    if (-not [string]::IsNullOrWhiteSpace($IP1)) {
        $sanList += "IP.1  = $IP1"
    }

    return "[ alt_names ]`r`n" + ($sanList -join "`r`n")
}

# Generate button logic
$GenerateBtn.Add_Click({
    $typeItem = $CertTypeCombo.SelectedItem
    if (-not $typeItem) {
        $OutputText.Text = "Please select a certificate type."
        return
    }

    $type     = $typeItem.Content
    $FQDN     = $FqdnBox.Text.Trim()
    $Hostname = $HostBox.Text.Trim()
    $IP1      = $IpBox.Text.Trim()
    $DNS3     = $Dns3Box.Text.Trim()
    $DNS4     = $Dns4Box.Text.Trim()
    $WinLocal = $WinLocalBox.Text.Trim()
    $outFolder = $OutFolderBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($FQDN) -or [string]::IsNullOrWhiteSpace($Hostname)) {
        $OutputText.Text = "FQDN and Hostname are required."
        return
    }

    if (-not (Test-Path $outFolder)) {
        try {
            New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
        } catch {
            $OutputText.Text = "Cannot create or access output folder: $outFolder"
            return
        }
    }

    $dnBlock = Get-DistinguishedNameBlock -FQDN $FQDN

    switch ($type) {

        "Windows Server" {
            $sanBlock = Get-SanBlock `
                -Hostname $Hostname `
                -FQDN $FQDN `
                -DNS3 $DNS3 `
                -DNS4 $DNS4 `
                -IP1 $IP1 `
                -IncludeLocalhost $true `
                -LocalhostValue $WinLocal

            $config = @"
[ req ]
default_bits        = 2048
default_keyfile     = rui.key
distinguished_name  = req_distinguished_name
encrypt_key         = no
prompt              = no
string_mask         = nombstr
req_extensions      = v3_req

[ v3_req ]
basicConstraints    = CA:FALSE
keyUsage            = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage    = serverAuth, clientAuth
subjectAltName      = @alt_names

$dnBlock

$sanBlock
"@

            $fileName = "windows-openssl.cnf"
        }

        "vCenter Machine SSL" {
            $sanBlock = Get-SanBlock `
                -Hostname $Hostname `
                -FQDN $FQDN `
                -DNS3 $DNS3 `
                -DNS4 $DNS4 `
                -IP1 $IP1 `
                -IncludeLocalhost $false

            $config = @"
[ req ]
default_bits        = 2048
default_keyfile     = machine_ssl.key
distinguished_name  = req_distinguished_name
encrypt_key         = no
prompt              = no
string_mask         = nombstr
req_extensions      = v3_req

[ v3_req ]
basicConstraints    = CA:FALSE
keyUsage            = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage    = serverAuth, clientAuth
subjectAltName      = @alt_names

$dnBlock

$sanBlock
"@

            $fileName = "vcenter-openssl.cnf"
        }

        "ESXi Host SSL" {
            $sanBlock = Get-SanBlock `
                -Hostname $Hostname `
                -FQDN $FQDN `
                -DNS3 $DNS3 `
                -DNS4 $DNS4 `
                -IP1 $IP1 `
                -IncludeLocalhost $false

            $config = @"
[ req ]
default_bits        = 2048
default_keyfile     = rui.key
distinguished_name  = req_distinguished_name
encrypt_key         = no
prompt              = no
string_mask         = nombstr
req_extensions      = v3_req

[ v3_req ]
basicConstraints    = CA:FALSE
keyUsage            = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage    = serverAuth, clientAuth
subjectAltName      = @alt_names

$dnBlock

$sanBlock
"@

            $fileName = "esxi-openssl.cnf"
        }
    }

    $outPath = Join-Path $outFolder $fileName
    $config | Out-File -Encoding ascii $outPath
    $OutputText.Text = "Saved OpenSSL config to: $outPath"
})

# Show window
$window.ShowDialog() | Out-Null
