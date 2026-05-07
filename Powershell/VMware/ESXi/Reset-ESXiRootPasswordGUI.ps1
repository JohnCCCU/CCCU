<#

SCOPE: 
    Opens a Windows GUI - The script creates a small application window where you can type: (This replaces manual PowerShell input)

 - vCenter Server

 - Username

 - Password

 - ESXi Host

 - New root password

CREATED BY: John W. Braunsdorf 

DATE: 05/06/2026

#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# Create Form
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "ESXi Root Password Reset via vCenter"
$form.Size = New-Object System.Drawing.Size(450, 420)
$form.StartPosition = "CenterScreen"

# -----------------------------
# Input Fields
# -----------------------------
$fields = @(
    "vCenter Server",
    "Username",
    "Password",
    "ESXi Host",
    "New Root Password"
)

$controls = @{}
$y = 20

foreach ($field in $fields) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "${field}:"
    $label.Location = New-Object System.Drawing.Point(20, $y)
    $label.Size = New-Object System.Drawing.Size(150, 20)
    $form.Controls.Add($label)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(180, $y)
    $textbox.Size = New-Object System.Drawing.Size(220, 20)

    if ($field -like "*Password*") {
        $textbox.UseSystemPasswordChar = $true
    }

    $form.Controls.Add($textbox)
    $controls[$field] = $textbox

    $y += 40
}

# -----------------------------
# Output Box
# -----------------------------
$output = New-Object System.Windows.Forms.TextBox
$output.Location = New-Object System.Drawing.Point(20, 240)
$output.Size = New-Object System.Drawing.Size(380, 100)
$output.Multiline = $true
$output.ReadOnly = $true
$form.Controls.Add($output)

# -----------------------------
# Reset Button
# -----------------------------
$button = New-Object System.Windows.Forms.Button
$button.Text = "Reset Password"
$button.Location = New-Object System.Drawing.Point(150, 350)
$button.Size = New-Object System.Drawing.Size(140, 30)

$button.Add_Click({
    try {
        # Collect UI values
        $vcenterServer   = $controls["vCenter Server"].Text
        $vcenterUser     = $controls["Username"].Text
        $vcenterPass     = $controls["Password"].Text
        $esxiHost        = $controls["ESXi Host"].Text
        $newRootPassword = $controls["New Root Password"].Text

        $output.Text = "Connecting to vCenter..."

        # Connect to vCenter
        Connect-VIServer -Server $vcenterServer -User $vcenterUser -Password $vcenterPass -ErrorAction Stop

        $output.Text = "Connected. Locating ESXi host..."

        # Get ESXi host object
        $vmhost = Get-VMHost -Name $esxiHost -ErrorAction Stop

        $output.Text = "Preparing ESXCLI..."

        # Prepare ESXCLI
        $esxcli = Get-EsxCli -VMHost $vmhost -V2

        # Build arguments for root password change
        $args = $esxcli.system.account.set.CreateArgs()
        $args.id = "root"
        $args.password = $newRootPassword
        $args.passwordconfirmation = $newRootPassword

        $output.Text = "Applying password change..."

        # Apply password change
        $esxcli.system.account.set.Invoke($args)

        $output.Text = "SUCCESS: Root password updated on $esxiHost"
    }
    catch {
        $output.Text = "ERROR: $($_.Exception.Message)"
    }
})

$form.Controls.Add($button)

# -----------------------------
# Show UI
# -----------------------------
$form.ShowDialog()
