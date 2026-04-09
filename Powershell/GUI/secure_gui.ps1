# GUI interface


# Load required .NET assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Login"
$form.Size = New-Object System.Drawing.Size(300, 180)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Username label and textbox
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Username:"
$lblUser.Location = New-Object System.Drawing.Point(10, 20)
$lblUser.AutoSize = $true
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point(100, 18)
$txtUser.Width = 150
$form.Controls.Add($txtUser)

# Password label and textbox (masked)
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "Password:"
$lblPass.Location = New-Object System.Drawing.Point(10, 60)
$lblPass.AutoSize = $true
$form.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = New-Object System.Drawing.Point(100, 58)
$txtPass.Width = 150
$txtPass.UseSystemPasswordChar = $true
$form.Controls.Add($txtPass)

# OK button
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text = "OK"
$btnOK.Location = New-Object System.Drawing.Point(60, 100)
$btnOK.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtUser.Text) -or [string]::IsNullOrWhiteSpace($txtPass.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter both username and password.","Error","OK","Error")
    } else {
        $form.Tag = "OK"
        $form.Close()
    }
})
$form.Controls.Add($btnOK)

# Cancel button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(150, 100)
$btnCancel.Add_Click({
    $form.Tag = "Cancel"
    $form.Close()
})
$form.Controls.Add($btnCancel)

# Show the form
$form.Topmost = $true
$form.Add_Shown({ $txtUser.Focus() })
$form.ShowDialog() | Out-Null

# Process results # user and password are connection points
if ($form.Tag -eq "OK") {
    $username = $txtUser.Text
    # Convert password to SecureString
    $securePassword = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force

    Write-Host "Username entered: $username"
    Write-Host "Secure password object created (not displayed for security)."
} else {
    Write-Host "User cancelled input."
}

