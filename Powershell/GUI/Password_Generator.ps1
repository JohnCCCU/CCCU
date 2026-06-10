<#
SCOPE: Created this simple password generator app. this allowes me to not rely on other apps

CREATED BY: John W. Braunsdorf

DATE: 05/08/2026

VERSION: 1.0
#>

# hides any outputs to powershell terminal window
$Host.UI.RawUI.WindowTitle = ""
$Host.PrivateData.ErrorForegroundColor = "Black"
$Host.PrivateData.WarningForegroundColor = "Black"
$Host.PrivateData.DebugForegroundColor = "Black"

#  UI password interface
Add-Type -AssemblyName PresentationFramework

function New-ComplexPassword {
    param ([int]$Length = 32)

    $Lower   = 'abcdefghijklmnopqrstuvwxyz'
    $Upper   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $Digits  = '0123456789'
    $Symbols = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    $AllChars = $Lower + $Upper + $Digits + $Symbols

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    function Get-RandomChar([string]$chars) {
        $byte = New-Object 'System.Byte[]' 1
        $rng.GetBytes($byte)
        return $chars[$byte[0] % $chars.Length]
    }

    $PasswordChars = @(
        Get-RandomChar $Lower
        Get-RandomChar $Upper
        Get-RandomChar $Digits
        Get-RandomChar $Symbols
    )

    for ($i = $PasswordChars.Count; $i -lt $Length; $i++) {
        $PasswordChars += Get-RandomChar $AllChars
    }

    ($PasswordChars | Sort-Object { Get-Random }) -join ''
}

# ---------------- Password Strength Function ----------------

function Get-PasswordStrength {
    param([string]$Password)

    $score = 0

    if ($Password.Length -ge 12) { $score += 1 }
    if ($Password.Length -ge 20) { $score += 1 }
    if ($Password -match '[A-Z]') { $score += 1 }
    if ($Password -match '[a-z]') { $score += 1 }
    if ($Password -match '\d')   { $score += 1 }
    if ($Password -match '[^a-zA-Z0-9]') { $score += 1 }

    return $score
}

# ---------------- GUI XAML ----------------

$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Password Generator"
        Height="330" Width="500"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Label Content="Password Length:" FontSize="14"/>
            <ComboBox Name="LengthBox" Width="80" Margin="10,0,0,0" FontSize="14">
                <ComboBoxItem Content="16"/>
                <ComboBoxItem Content="24"/>
                <ComboBoxItem Content="32" IsSelected="True"/>
                <ComboBoxItem Content="48"/>
                <ComboBoxItem Content="64"/>
            </ComboBox>
        </StackPanel>

        <Button Grid.Row="1" Name="GenerateBtn" Content="Generate Password"
                Height="35" FontSize="16" Margin="0,0,0,10"/>

        <TextBox Grid.Row="2" Name="PasswordBox" Height="35" FontSize="18"
                 IsReadOnly="True" Margin="0,0,0,10"/>

        <StackPanel Grid.Row="3" Margin="0,0,0,10">
            <Label Content="Strength:" FontSize="14"/>
            <ProgressBar Name="StrengthBar" Height="20" Minimum="0" Maximum="6"/>
            <Label Name="StrengthLabel" FontSize="14" HorizontalAlignment="Center"/>
        </StackPanel>

        <Button Grid.Row="4" Name="CopyBtn" Content="Copy to Clipboard"
                Height="35" FontSize="16"/>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

$LengthBox     = $Window.FindName("LengthBox")
$GenerateBtn   = $Window.FindName("GenerateBtn")
$PasswordBox   = $Window.FindName("PasswordBox")
$StrengthBar   = $Window.FindName("StrengthBar")
$StrengthLabel = $Window.FindName("StrengthLabel")
$CopyBtn       = $Window.FindName("CopyBtn")

# ---------------- Update Strength Meter ----------------

function Update-StrengthMeter {
    param([string]$pw)

    $score = Get-PasswordStrength $pw
    $StrengthBar.Value = $score

    switch ($score) {
        0 { $StrengthLabel.Content = "Very Weak"; $StrengthLabel.Foreground = "Red" }
        1 { $StrengthLabel.Content = "Weak";       $StrengthLabel.Foreground = "OrangeRed" }
        2 { $StrengthLabel.Content = "Fair";       $StrengthLabel.Foreground = "Orange" }
        3 { $StrengthLabel.Content = "Good";       $StrengthLabel.Foreground = "Goldenrod" }
        4 { $StrengthLabel.Content = "Strong";     $StrengthLabel.Foreground = "Green" }
        5 { $StrengthLabel.Content = "Very Strong";$StrengthLabel.Foreground = "DarkGreen" }
        6 { $StrengthLabel.Content = "Excellent";  $StrengthLabel.Foreground = "DarkGreen" }
    }
}

# ---------------- Generate Button Action ----------------

$GenerateAction = {
    $length = [int]$LengthBox.SelectedItem.Content
    $pw = New-ComplexPassword -Length $length
    $PasswordBox.Text = $pw
    Update-StrengthMeter $pw
}

$GenerateBtn.Add_Click($GenerateAction)
$CopyBtn.Add_Click({ Set-Clipboard $PasswordBox.Text })

# Generate one on startup
& $GenerateAction

# Show window
$Window.ShowDialog() | Out-Null
