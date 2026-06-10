<#
.SCOPE
Created this program to monitor network latency and not have to install wireshark. Light weigth version for me.

 - Built in features    
    - Dual‑graph layout (Latency + Jitter)
    - Smooth Bezier curves
    - Gradient colors
    - Auto‑scaling
    - Packet‑loss overlay
    - Hover tooltips
    - Independent vertical markers (no more WPF errors)
    - Stats panel
    - PowerShell 7 compatibility Only

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 06/10/2026

.SCRIPT
    - Open PowerShell 7 --> cd to folder where the script is stored run the following command
        - pwsh ./PingGraph.ps1
#>

Add-Type -AssemblyName PresentationFramework

# ---------------------------
# XAML UI (PowerShell 7 safe)
# ---------------------------
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Real-Time Ping Dashboard - PowerShell 7 Only!'
        Height='800' Width='950'
        Background='#1e1e1e'
        WindowStartupLocation='CenterScreen'>

    <Grid Margin='10'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='220'/>
            <RowDefinition Height='220'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
        </Grid.RowDefinitions>

        <!-- Input Row -->
        <StackPanel Orientation='Horizontal' Margin='0,0,0,10'>
            <Label Content='Target Host:' Foreground='White' FontSize='14'/>
            <TextBox x:Name='TargetBox' Width='300' Margin='10,0,0,0' FontSize='14'/>
            <Button x:Name='StartBtn' Content='Start' Width='100' Margin='10,0,0,0' FontSize='14'/>
            <Button x:Name='StopBtn' Content='Stop' Width='100' Margin='10,0,0,0' FontSize='14' IsEnabled='False'/>
        </StackPanel>

        <!-- Latency Graph -->
        <Canvas x:Name='LatencyCanvas' Grid.Row='1' Background='#252526'/>

        <!-- Jitter Graph -->
        <Canvas x:Name='JitterCanvas' Grid.Row='2' Background='#202020'/>

        <!-- Stats Panel -->
        <StackPanel Grid.Row='3' Orientation='Horizontal' Margin='0,10,0,10'>
            <TextBlock x:Name='StatsText'
                       Foreground='White'
                       FontFamily='Consolas'
                       FontSize='14'
                       TextWrapping='Wrap'/>
        </StackPanel>

        <!-- Output Log -->
        <ScrollViewer Grid.Row='4' VerticalScrollBarVisibility='Auto'>
            <TextBlock x:Name='OutputBox'
                       Foreground='White'
                       FontFamily='Consolas'
                       FontSize='14'
                       TextWrapping='Wrap'/>
        </ScrollViewer>
    </Grid>
</Window>
"@

# ---------------------------
# Load XAML safely in PS7
# ---------------------------
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# ---------------------------
# Bind controls
# ---------------------------
$TargetBox     = $window.FindName("TargetBox")
$StartBtn      = $window.FindName("StartBtn")
$StopBtn       = $window.FindName("StopBtn")
$LatencyCanvas = $window.FindName("LatencyCanvas")
$JitterCanvas  = $window.FindName("JitterCanvas")
$OutputBox     = $window.FindName("OutputBox")
$StatsText     = $window.FindName("StatsText")

# ---------------------------
# Buffers (100 samples)
# ---------------------------
$latency     = New-Object System.Collections.Generic.List[int]
$jitter      = New-Object System.Collections.Generic.List[int]
$lossHistory = New-Object System.Collections.Generic.List[int]
$timestamps  = New-Object System.Collections.Generic.List[string]

# ---------------------------
# Timer for continuous ping
# ---------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)

# ---------------------------
# Helper: Draw Bezier Curve Graph
# ---------------------------
function Draw-BezierGraph {
    param(
        [System.Windows.Controls.Canvas]$Canvas,
        [System.Collections.Generic.List[int]]$Values,
        [string]$LabelText
    )

    $Canvas.Children.Clear()
    if ($Values.Count -lt 3) { return }

    $width  = $Canvas.ActualWidth
    $height = $Canvas.ActualHeight

    # Auto-scale
    $maxVal = ($Values | Measure-Object -Maximum).Maximum
    if ($maxVal -lt 10) { $maxVal = 10 }
    $maxVal = [Math]::Ceiling($maxVal / 10) * 10

    # Draw Bezier segments
    for ($i = 1; $i -lt $Values.Count - 1; $i++) {

        $x0 = (($i - 1) / 100.0) * $width
        $y0 = $height - (($Values[$i - 1] / $maxVal) * $height)

        $x1 = ($i / 100.0) * $width
        $y1 = $height - (($Values[$i] / $maxVal) * $height)

        $x2 = (($i + 1) / 100.0) * $width
        $y2 = $height - (($Values[$i + 1] / $maxVal) * $height)

        # Control point
        $cx = ($x0 + $x2) / 2
        $cy = ($y0 + $y2) / 2

        # Color gradient
        $value = $Values[$i]
        if     ($value -lt 50)  { $color = "Lime" }
        elseif ($value -lt 100) { $color = "Yellow" }
        elseif ($value -lt 200) { $color = "Orange" }
        else                    { $color = "Red" }

        $segment = New-Object System.Windows.Shapes.Path
        $segment.Stroke = $color
        $segment.StrokeThickness = 2

        $geometry = New-Object System.Windows.Media.PathGeometry
        $figure = New-Object System.Windows.Media.PathFigure
        $figure.StartPoint = [Windows.Point]::new($x0, $y0)

        $bezier = New-Object System.Windows.Media.QuadraticBezierSegment
        $bezier.Point1 = [Windows.Point]::new($cx, $cy)
        $bezier.Point2 = [Windows.Point]::new($x2, $y2)

        $figure.Segments.Add($bezier)
        $geometry.Figures.Add($figure)
        $segment.Data = $geometry

        $Canvas.Children.Add($segment)
    }

    # Label
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = "$LabelText (Max: $maxVal)"
    $label.Foreground = "White"
    $label.FontSize = 12
    $label.Margin = "5,5,0,0"
    $Canvas.Children.Add($label)
}

# ---------------------------
# Hover tooltip + vertical markers (fixed)
# ---------------------------
$tooltip = New-Object System.Windows.Controls.ToolTip
$LatencyCanvas.ToolTip = $tooltip
$JitterCanvas.ToolTip  = $tooltip

# Separate markers for each graph
$latencyMarker = New-Object System.Windows.Shapes.Line
$latencyMarker.Stroke = "#50FFFFFF"
$latencyMarker.StrokeThickness = 1
$latencyMarker.Visibility = "Collapsed"
$LatencyCanvas.Children.Add($latencyMarker)

$jitterMarker = New-Object System.Windows.Shapes.Line
$jitterMarker.Stroke = "#50FFFFFF"
$jitterMarker.StrokeThickness = 1
$jitterMarker.Visibility = "Collapsed"
$JitterCanvas.Children.Add($jitterMarker)

function Handle-Hover {
    param($Canvas, $Marker, $eventArgs)

    if ($latency.Count -lt 2) { return }

    $pos = $eventArgs.GetPosition($Canvas)
    $width = $Canvas.ActualWidth

    $index = [math]::Floor(($pos.X / $width) * 100)
    if ($index -lt 0 -or $index -ge $latency.Count) { return }

    $ms = $latency[$index]
    $jit = $jitter[$index]
    $ts = $timestamps[$index]
    $lossPct = [int](($lossHistory | Measure-Object -Average).Average * 100)

    $tooltip.Content = "$ts`nLatency: $ms ms`nJitter: $jit ms`nLoss: $lossPct%"
    $tooltip.IsOpen = $true

    # Move the correct marker
    $Marker.X1 = $pos.X
    $Marker.X2 = $pos.X
    $Marker.Y1 = 0
    $Marker.Y2 = $Canvas.ActualHeight
    $Marker.Visibility = "Visible"
}

# Bind hover events
$LatencyCanvas.Add_MouseMove({ Handle-Hover $LatencyCanvas $latencyMarker $_ })
$JitterCanvas.Add_MouseMove({ Handle-Hover $JitterCanvas $jitterMarker $_ })

$LatencyCanvas.Add_MouseLeave({
    $tooltip.IsOpen = $false
    $latencyMarker.Visibility = "Collapsed"
})
$JitterCanvas.Add_MouseLeave({
    $tooltip.IsOpen = $false
    $jitterMarker.Visibility = "Collapsed"
})

# ---------------------------
# Timer tick: perform ping
# ---------------------------
$timer.Add_Tick({
    $target = $TargetBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($target)) { return }

    $success = $true
    try {
        $result = Test-Connection -TargetName $target -Count 1 -ErrorAction Stop
        $ms = $result.Latency
    }
    catch {
        $ms = 0
        $success = $false
    }

    # Latency buffer
    if ($latency.Count -ge 100) { $latency.RemoveAt(0) }
    $latency.Add($ms)

    # Jitter buffer
    $jit = 0
    if ($latency.Count -gt 1) {
        $jit = [math]::Abs($latency[$latency.Count - 1] - $latency[$latency.Count - 2])
    }
    if ($jitter.Count -ge 100) { $jitter.RemoveAt(0) }
    $jitter.Add($jit)

    # Packet loss
    if ($lossHistory.Count -ge 100) { $lossHistory.RemoveAt(0) }
    $lossHistory.Add( $success ? 0 : 1 )

    # Timestamp
    $timestamp = (Get-Date).ToString("HH:mm:ss.fff")
    if ($timestamps.Count -ge 100) { $timestamps.RemoveAt(0) }
    $timestamps.Add($timestamp)

    # Stats panel
    $avg  = [math]::Round(($latency | Measure-Object -Average).Average, 1)
    $min  = ($latency | Measure-Object -Minimum).Minimum
    $max  = ($latency | Measure-Object -Maximum).Maximum

    $javg = [math]::Round(($jitter | Measure-Object -Average).Average, 1)
    $jmin = ($jitter | Measure-Object -Minimum).Minimum
    $jmax = ($jitter | Measure-Object -Maximum).Maximum

    $lossPctDisplay = [int](($lossHistory | Measure-Object -Average).Average * 100)

    $StatsText.Text =
        "Latency → Avg: $avg ms   Min: $min ms   Max: $max ms    " +
        "Jitter → Avg: $javg ms   Min: $jmin ms   Max: $jmax ms    " +
        "Loss: $lossPctDisplay%"

    # Log
    $OutputBox.Text += "$timestamp  -  $ms ms  (jitter: $jit ms, loss: $lossPctDisplay%)`n"

    # Draw graphs
    Draw-BezierGraph -Canvas $LatencyCanvas -Values $latency -LabelText "Latency"
    Draw-BezierGraph -Canvas $JitterCanvas  -Values $jitter  -LabelText "Jitter"
})

# ---------------------------
# Start button
# ---------------------------
$StartBtn.Add_Click({
    $target = $TargetBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($target)) {
        [System.Windows.MessageBox]::Show("Enter a host first.")
        return
    }

    $latency.Clear()
    $jitter.Clear()
    $lossHistory.Clear()
    $timestamps.Clear()
    $OutputBox.Text = ""
    $StatsText.Text = ""
    $timer.Start()

    $StartBtn.IsEnabled = $false
    $StopBtn.IsEnabled  = $true
})

# ---------------------------
# Stop button
# ---------------------------
$StopBtn.Add_Click({
    $timer.Stop()
    $StartBtn.IsEnabled = $true
    $StopBtn.IsEnabled  = $false
})

# ---------------------------
# Launch GUI
# ---------------------------
$window.ShowDialog() | Out-Null
