<#
.SCOPE
    Fully portable, Uses $PCToolkit everywhere, Clean and organized, Includes a Cancel button and Ready for production use
    $PCToolkit variable 
    - Portable script paths using Join-Path
    - Remove Device tab
    - Join Device tab
    - Reboot tab
    - External Intune/Entra Validation tab
    - Cancel button (bottom‑right, closes the GUI)

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 06/02/2026
#>

Add-Type -AssemblyName PresentationFramework

# === Toolkit Root Folder ===
$PCToolkit = "C:\temp\PC-Toolkit"

# === Script Paths (Portable) ===
$RemoveScriptPath   = Join-Path $PCToolkit "Remove-Device.ps1"
$JoinScriptPath     = Join-Path $PCToolkit "Join-Device.ps1"
$ValidateScriptPath = Join-Path $PCToolkit "Validate-IntuneEntra.ps1"

# === WPF XAML ===
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Toolkit" Height="480" Width="680" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">

        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TabControl Name="MainTabs" Grid.Row="0">

            <!-- Remove Device Tab -->
            <TabItem Header="Remove Device">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Computer Name:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtRemoveComputer" Width="200"/>
                    </StackPanel>

                    <Button Grid.Row="1" Name="btnRemoveDevice" Content="Run Remove-Device" Width="150" Height="30"/>

                    <TextBox Grid.Row="2" Name="txtRemoveLog" Margin="0,10,0,0" IsReadOnly="True"
                             VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
                </Grid>
            </TabItem>

            <!-- Join Device Tab -->
            <TabItem Header="Join Device">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                        <TextBlock Text="Computer Name:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtJoinComputer" Width="200"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5" Grid.Row="1">
                        <TextBlock Text="Domain Name:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtDomainName" Width="200"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5" Grid.Row="2">
                        <TextBlock Text="Join User:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtJoinUser" Width="200"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,5" Grid.Row="3">
                        <TextBlock Text="OU Path:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtOUPath" Width="350"/>
                    </StackPanel>

                    <Button Grid.Row="4" Name="btnJoinDevice" Content="Run Join-Device" Width="150" Height="30" Margin="0,10,0,0"/>
                </Grid>
            </TabItem>

            <!-- Reboot Tab -->
            <TabItem Header="Reboot">
                <Grid Margin="10">
                    <StackPanel>
                        <TextBlock Text="Reboot the local computer." Margin="0,0,0,10"/>
                        <Button Name="btnReboot" Content="Reboot Now" Width="120" Height="30"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <!-- External Validation Script Tab -->
            <TabItem Header="Intune / Entra Validation">
                <Grid Margin="10">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Computer Name:" VerticalAlignment="Center" Width="110"/>
                        <TextBox Name="txtValidateComputer" Width="200"/>
                        <Button Name="btnValidate" Content="Run Validation Script" Width="160" Height="28" Margin="10,0,0,0"/>
                    </StackPanel>

                    <TextBox Grid.Row="1" Name="txtValidateOutput"
                             IsReadOnly="True"
                             VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap"
                             AcceptsReturn="True"/>
                </Grid>
            </TabItem>

        </TabControl>

        <!-- CANCEL BUTTON -->
        <Button Name="btnCancel"
                Content="Cancel"
                Width="100"
                Height="30"
                HorizontalAlignment="Right"
                VerticalAlignment="Bottom"
                Margin="0,10,10,10"
                Grid.Row="1"/>
    </Grid>
</Window>
"@

# === Load XAML ===
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# === Bind Controls ===
$txtRemoveComputer = $window.FindName("txtRemoveComputer")
$txtRemoveLog      = $window.FindName("txtRemoveLog")
$btnRemoveDevice   = $window.FindName("btnRemoveDevice")

$txtJoinComputer   = $window.FindName("txtJoinComputer")
$txtDomainName     = $window.FindName("txtDomainName")
$txtJoinUser       = $window.FindName("txtJoinUser")
$txtOUPath         = $window.FindName("txtOUPath")
$btnJoinDevice     = $window.FindName("btnJoinDevice")

$btnReboot         = $window.FindName("btnReboot")

$txtValidateComputer = $window.FindName("txtValidateComputer")
$txtValidateOutput   = $window.FindName("txtValidateOutput")
$btnValidate         = $window.FindName("btnValidate")

$btnCancel          = $window.FindName("btnCancel")

# === Remove Device Button ===
$btnRemoveDevice.Add_Click({
    $comp = $txtRemoveComputer.Text.Trim()
    if (-not $comp) {
        [System.Windows.MessageBox]::Show("Enter a computer name.")
        return
    }

    $txtRemoveLog.Text = "Running Remove-Device for $comp..."
    try {
        $output = powershell -NoProfile -ExecutionPolicy Bypass -File $RemoveScriptPath -ComputerName $comp 2>&1
        $txtRemoveLog.Text = $output -join "`r`n"
    }
    catch {
        $txtRemoveLog.Text = "Error: $($_.Exception.Message)"
    }
})

# === Join Device Button ===
$btnJoinDevice.Add_Click({
    $comp  = $txtJoinComputer.Text.Trim()
    $dom   = $txtDomainName.Text.Trim()
    $user  = $txtJoinUser.Text.Trim()
    $ou    = $txtOUPath.Text.Trim()

    if (-not $comp -or -not $dom -or -not $user) {
        [System.Windows.MessageBox]::Show("Computer, Domain, and Join User are required.")
        return
    }

    $args = @(
        "-ComputerName", $comp,
        "-DomainName",   $dom,
        "-JoinUser",     $user
    )
    if ($ou) { $args += @("-OUPath", $ou) }

    Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$JoinScriptPath) + $args -Verb RunAs
})

# === Reboot Button ===
$btnReboot.Add_Click({
    $res = [System.Windows.MessageBox]::Show("Reboot the computer now?","Confirm Reboot","YesNo","Warning")
    if ($res -eq "Yes") {
        Start-Process "shutdown.exe" -ArgumentList "/r /t 0" -Verb RunAs
    }
})

# === Validation Button (External Script) ===
$btnValidate.Add_Click({
    $comp = $txtValidateComputer.Text.Trim()

    if (-not $comp) {
        [System.Windows.MessageBox]::Show("Enter a computer name.")
        return
    }

    $txtValidateOutput.Text = "Running external validation script on $comp ...`r`n"

    try {
        $output = powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScriptPath -ComputerName $comp 2>&1
        $txtValidateOutput.Text = $output -join "`r`n"
    }
    catch {
        $txtValidateOutput.Text = "Error running validation script: $($_.Exception.Message)"
    }
})

# === Cancel Button ===
$btnCancel.Add_Click({
    $window.Close()
})

# === Show Window ===
$window.ShowDialog() | Out-Null
