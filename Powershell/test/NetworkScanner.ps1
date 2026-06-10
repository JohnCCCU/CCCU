<#
.SCOPE
Created this program to monitor network latency and not have to install wireshark. Light weigth version for me.

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 04/17/2026

.SCRIPT
    - Open PowerShell 7 --> cd to folder where the script is stored run the following command
        - pwsh ./NetworkScanner.ps1
#>

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms

# XAML for WPF GUI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Network Scanner" Height="500" Width="800"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- Subnet -->
        <TextBlock Grid.Row="0" Grid.Column="0" Margin="0,0,5,5" VerticalAlignment="Center">Subnet (/24):</TextBlock>
        <TextBox x:Name="txtSubnet" Grid.Row="0" Grid.Column="1" Margin="0,0,5,5" Text="192.168.1.0"/>
        <TextBlock Grid.Row="0" Grid.Column="2" Margin="5,0,0,5" VerticalAlignment="Center" Foreground="Gray">
            e.g. 192.168.1.0
        </TextBlock>

        <!-- Port range -->
        <TextBlock Grid.Row="1" Grid.Column="0" Margin="0,0,5,5" VerticalAlignment="Center">Port range:</TextBlock>
        <TextBox x:Name="txtPorts" Grid.Row="1" Grid.Column="1" Margin="0,0,5,5" Text="1-1024"/>
        <TextBlock Grid.Row="1" Grid.Column="2" Margin="5,0,0,5" VerticalAlignment="Center" Foreground="Gray">
            e.g. 1-1024 or 22,80,443
        </TextBlock>

        <!-- Buttons -->
        <StackPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,5,0,5">
            <Button x:Name="btnScan" Width="100" Margin="0,0,5,0">Scan</Button>
            <Button x:Name="btnCancel" Width="100" Margin="0,0,5,0" IsEnabled="False">Cancel</Button>
            <TextBlock x:Name="lblStatus" VerticalAlignment="Center" Margin="10,0,0,0" Foreground="DarkBlue"/>
        </StackPanel>

        <!-- Results -->
        <DataGrid x:Name="dgResults"
          Grid.Row="3"
          Grid.Column="0"
          Grid.ColumnSpan="3"
          AutoGenerateColumns="False"
          IsReadOnly="True"
          Margin="0,5,0,5">

    <DataGrid.RowStyle>
        <Style TargetType="DataGridRow">

            <!-- Alive host -->
            <Style.Triggers>
                <DataTrigger Binding="{Binding Status}" Value="Host Alive (ICMP)">
                    <Setter Property="Background" Value="#D6FFD6"/>   <!-- light green -->
                </DataTrigger>

                <!-- No response -->
                <DataTrigger Binding="{Binding Status}" Value="No Response">
                    <Setter Property="Background" Value="#FFD6D6"/>   <!-- light red -->
                </DataTrigger>

                <!-- Open port -->
                <DataTrigger Binding="{Binding Status}" Value="Open">
                    <Setter Property="Background" Value="#FFF7C2"/>   <!-- light yellow -->
                </DataTrigger>

                <!-- Closed port -->
                <DataTrigger Binding="{Binding Status}" Value="Closed">
                    <Setter Property="Background" Value="#F0F0F0"/>   <!-- light gray -->
                </DataTrigger>

                <!-- Error -->
                <DataTrigger Binding="{Binding Status}" Value="Error">
                    <Setter Property="Background" Value="#FFCCCC"/>   <!-- darker red -->
                </DataTrigger>
            </Style.Triggers>

        </Style>
    </DataGrid.RowStyle>

    <DataGrid.Columns>
        <DataGridTextColumn Header="Host" Binding="{Binding Host}" Width="*"/>
        <DataGridTextColumn Header="IP" Binding="{Binding IP}" Width="*"/>
        <DataGridTextColumn Header="Port" Binding="{Binding Port}" Width="*"/>
        <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="*"/>
    </DataGrid.Columns>
</DataGrid>


        <!-- Progress -->
        <StackPanel Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal">
            <ProgressBar x:Name="pbProgress" Height="18" Width="300" Minimum="0" Maximum="100"/>
            <TextBlock x:Name="lblProgress" Margin="10,0,0,0" VerticalAlignment="Center"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$txtSubnet  = $window.FindName("txtSubnet")
$txtPorts   = $window.FindName("txtPorts")
$btnScan    = $window.FindName("btnScan")
$btnCancel  = $window.FindName("btnCancel")
$dgResults  = $window.FindName("dgResults")
$lblStatus  = $window.FindName("lblStatus")
$pbProgress = $window.FindName("pbProgress")
$lblProgress= $window.FindName("lblProgress")

# Observable collection for results
$resultsType = @"
using System.Collections.ObjectModel;
public class ScanResult {
    public string Host {get;set;}
    public string IP {get;set;}
    public int Port {get;set;}
    public string Status {get;set;}
}
"@
Add-Type -TypeDefinition $resultsType -Language CSharp

$collection = New-Object System.Collections.ObjectModel.ObservableCollection[ScanResult]
$dgResults.ItemsSource = $collection

# Global job variable
$script:scanJob = $null

function Get-IPRangeFromSubnet {
    param([string]$Subnet)

    try { $ip = [System.Net.IPAddress]::Parse($Subnet) }
    catch { throw "Invalid subnet IP." }

    $bytes = $ip.GetAddressBytes()
    if ($bytes[3] -ne 0) { throw "Use a /24 base address ending in .0 (e.g. 192.168.1.0)." }

    $list = @()
    for ($i = 1; $i -le 254; $i++) {
        $bytes[3] = [byte]$i
        $list += ([System.Net.IPAddress]::new($bytes)).ToString()
    }
    return $list
}

function Parse-PortList {
    param([string]$PortText)

    $ports = New-Object System.Collections.Generic.List[int]
    $parts = $PortText.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    foreach ($p in $parts) {
        if ($p -match "^\d+-\d+$") {
            $range = $p.Split("-")
            $start = [int]$range[0]
            $end   = [int]$range[1]
            for ($i=$start; $i -le $end; $i++) { $ports.Add($i) }
        }
        elseif ($p -match "^\d+$") {
            $ports.Add([int]$p)
        }
        else {
            throw "Invalid port expression: $p"
        }
    }

    return ($ports | Sort-Object -Unique)
}

$scanScript = {
    param($IPs, $Ports)

    $results = New-Object System.Collections.Generic.List[object]
    $total = $IPs.Count * $Ports.Count
    $count = 0

    $pinger = New-Object System.Net.NetworkInformation.Ping

    foreach ($ip in $IPs) {

        # --- ICMP Ping Test ---
        $alive = $false
        try {
            $reply = $pinger.Send($ip, 300)
            if ($reply.Status -eq "Success") { $alive = $true }
        }
        catch { }

        # Add ICMP result row
        $results.Add([pscustomobject]@{
            Host   = $ip
            IP     = $ip
            Port   = "-"
            Status = if ($alive) { "Host Alive (ICMP)" } else { "No Response" }
        })

        # If host is dead, skip port scan
        if (-not $alive) {
            continue
        }

        # --- Port Scan ---
        foreach ($port in $Ports) {
            $count++

            $status = "Closed"
            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $iar = $client.BeginConnect($ip, $port, $null, $null)
                $success = $iar.AsyncWaitHandle.WaitOne(300)
                if ($success -and $client.Connected) { $status = "Open" }
                $client.Close()
            }
            catch { $status = "Error" }

            $results.Add([pscustomobject]@{
                Host   = $ip
                IP     = $ip
                Port   = $port
                Status = $status
            })

            $percent = [int](($count / [double]$total) * 100)
            Write-Progress -Activity "Scanning" -Status ("{0}:{1}" -f $ip, $port) -PercentComplete $percent
        }
    }

    return $results
}


# Update UI from job results
function Update-UIFromJob {
    if (-not $script:scanJob) { return }

    if ($script:scanJob.State -eq 'Completed') {
        $output = Receive-Job -Job $script:scanJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:scanJob -Force
        $script:scanJob = $null

        $collection.Clear()
        foreach ($item in $output) {
            $res = New-Object ScanResult
            $res.Host   = $item.Host
            $res.IP     = $item.IP
            $res.Port   = $item.Port
            $res.Status = $item.Status
            $collection.Add($res)
        }

        $pbProgress.Value = 100
        $lblProgress.Text = "100 %"
        $lblStatus.Text   = "Scan complete."
        $btnScan.IsEnabled   = $true
        $btnCancel.IsEnabled = $false
    }
    elseif ($script:scanJob.State -eq 'Running') {
        $pbProgress.IsIndeterminate = $true
        $lblProgress.Text = "Scanning..."
    }
    else {
        Remove-Job -Job $script:scanJob -Force
        $script:scanJob = $null
        $lblStatus.Text = "Scan cancelled or failed."
        $btnScan.IsEnabled   = $true
        $btnCancel.IsEnabled = $false
        $pbProgress.IsIndeterminate = $false
        $pbProgress.Value = 0
        $lblProgress.Text = ""
    }
}

# Timer to poll job state
$dispatcherTimer = New-Object System.Windows.Threading.DispatcherTimer
$dispatcherTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$dispatcherTimer.Add_Tick({ Update-UIFromJob })

# Scan button click
$btnScan.Add_Click({
    try {
        $collection.Clear()
        $lblStatus.Text = ""
        $pbProgress.IsIndeterminate = $false
        $pbProgress.Value = 0
        $lblProgress.Text = ""

        $subnet = $txtSubnet.Text.Trim()
        $portsText = $txtPorts.Text.Trim()

        $ips   = Get-IPRangeFromSubnet -Subnet $subnet
        $ports = Parse-PortList -PortText $portsText

        $lblStatus.Text = "Starting scan..."
        $btnScan.IsEnabled   = $false
        $btnCancel.IsEnabled = $true

        if ($script:scanJob) {
            Remove-Job -Job $script:scanJob -Force
            $script:scanJob = $null
        }

        $script:scanJob = Start-Job -ScriptBlock $scanScript -ArgumentList @($ips, $ports)
        $dispatcherTimer.Start()
    }
    catch {
        [System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)")
    }
})

# Cancel button
$btnCancel.Add_Click({
    if ($script:scanJob) { Stop-Job -Job $script:scanJob -ErrorAction SilentlyContinue }
})

# Cleanup
$window.Add_Closing({
    if ($script:scanJob) {
        Stop-Job -Job $script:scanJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:scanJob -Force
    }
})

# Show window
$window.ShowDialog() | Out-Null
