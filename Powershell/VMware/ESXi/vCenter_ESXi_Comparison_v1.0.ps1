<#
RESOURCE: 
https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere/7-0/vcenter-upgrade/upgrading-and-updating-the-vcenter-server-appliance/preparing-to-upgrade-vcenter-server-appliance/prepare-esxi-hosts-for-vcenter-server-appliance-upgrade/change-the-certificate-mode.html?utm_source=copilot.com

SCOPE: GUI input

 - Folder picker

 - Progress bar

 - Per‑host progress messages

 - Multi‑vCenter support

 - One HTML file with separate sections per vCenter

 - Version mismatch highlighting

 - Sorted output

 - Timestamped filename
 
 - Browse to save location

CREATOR: John William Braunsdorf

DATE: 05/07/2026

REV: v1.0

LOCATION: C:\temp\certs\vcenter (PEM files should be located here)

#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------- GUI DEFINITION ----------------
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "ESXi Host Comparison"
$form.Size          = New-Object System.Drawing.Size(450,350)
$form.StartPosition = "CenterScreen"

# vCenter label + textbox
$lblVC = New-Object System.Windows.Forms.Label
$lblVC.Text = "vCenter(s) (comma-separated):"
$lblVC.Location = New-Object System.Drawing.Point(10,20)
$lblVC.AutoSize = $true
$form.Controls.Add($lblVC)

$txtVC = New-Object System.Windows.Forms.TextBox
$txtVC.Location = New-Object System.Drawing.Point(10,40)
$txtVC.Size = New-Object System.Drawing.Size(410,20)
$form.Controls.Add($txtVC)

# Username label + textbox
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Username:"
$lblUser.Location = New-Object System.Drawing.Point(10,70)
$lblUser.AutoSize = $true
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point(10,90)
$txtUser.Size = New-Object System.Drawing.Size(410,20)
$form.Controls.Add($txtUser)

# Password label + textbox
$lblPass = New-Object System.Windows.Forms.Label
$lblPass.Text = "Password:"
$lblPass.Location = New-Object System.Drawing.Point(10,120)
$lblPass.AutoSize = $true
$form.Controls.Add($lblPass)

$txtPass = New-Object System.Windows.Forms.TextBox
$txtPass.Location = New-Object System.Drawing.Point(10,140)
$txtPass.Size = New-Object System.Drawing.Size(410,20)
$txtPass.UseSystemPasswordChar = $true
$form.Controls.Add($txtPass)

# Output folder label + textbox
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Output Folder:"
$lblOut.Location = New-Object System.Drawing.Point(10,170)
$lblOut.AutoSize = $true
$form.Controls.Add($lblOut)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(10,190)
$txtOut.Size = New-Object System.Drawing.Size(330,20)
$txtOut.Text = "C:\temp\Reports\ESXi"
$form.Controls.Add($txtOut)

# Browse button
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(350,188)
$btnBrowse.Size = New-Object System.Drawing.Size(70,23)
$form.Controls.Add($btnBrowse)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = ""
$lblStatus.Location = New-Object System.Drawing.Point(10,220)
$lblStatus.AutoSize = $true
$form.Controls.Add($lblStatus)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,245)
$progressBar.Size = New-Object System.Drawing.Size(410,20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$form.Controls.Add($progressBar)

# Run button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run"
$btnRun.Location = New-Object System.Drawing.Point(250,275)
$btnRun.Size = New-Object System.Drawing.Size(80,30)
$form.Controls.Add($btnRun)

# Cancel button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(340,275)
$btnCancel.Size = New-Object System.Drawing.Size(80,30)
$form.Controls.Add($btnCancel)

# ---------------- BUTTON EVENTS ----------------

# Folder picker
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select output folder for ESXi reports"
    $dialog.ShowNewFolderButton = $true

    if ($dialog.ShowDialog() -eq "OK") {
        $txtOut.Text = $dialog.SelectedPath
    }
})

$btnCancel.Add_Click({
    $form.Close()
})

# ---------------- RUN BUTTON ----------------
$btnRun.Add_Click({
    $lblStatus.Text = "Running..."
    $form.Refresh()

    $vCenters = $txtVC.Text.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if (-not $vCenters) {
        [System.Windows.Forms.MessageBox]::Show("Please enter at least one vCenter.")
        return
    }

    if ([string]::IsNullOrWhiteSpace($txtUser.Text) -or [string]::IsNullOrWhiteSpace($txtPass.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter username and password.")
        return
    }

    # Build PSCredential
    $securePass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
    $cred       = New-Object System.Management.Automation.PSCredential($txtUser.Text, $securePass)

    # Output folder
    $outFolder = $txtOut.Text
    if (-not (Test-Path $outFolder)) {
        New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
    }

    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

    # MASTER ARRAY
    $AllHosts = @()

    # Progress bar setup
    $progressBar.Value = 0
    $step = [math]::Floor(100 / $vCenters.Count)
    $current = 0

    foreach ($vc in $vCenters) {
        try {
            $lblStatus.Text = "Connecting to $vc..."
            $form.Refresh()

            Connect-VIServer -Server $vc -Credential $cred -ErrorAction Stop | Out-Null

            $hosts = Get-VMHost | Sort-Object Name
            $hostCount = $hosts.Count
            $hostIndex = 0

            $report = @()

            foreach ($h in $hosts) {
                $hostIndex++
                $lblStatus.Text = "Processing $vc → $($h.Name) ($hostIndex of $hostCount)"
                $form.Refresh()

                $report += [PSCustomObject]@{
                    vCenter        = $vc
                    Name           = $h.Name
                    Cluster        = $h.Parent.Name
                    ConnectionState= $h.ConnectionState
                    Manufacturer   = $h.ExtensionData.Hardware.SystemInfo.Vendor
                    Model          = $h.ExtensionData.Hardware.SystemInfo.Model
                    CPUType        = $h.ProcessorType
                    CPUCount       = $h.NumCpu
                    CoresPerCPU    = $h.ExtensionData.Hardware.CpuInfo.NumCpuCores / $h.NumCpu
                    MemoryGB       = [math]::Round($h.MemoryTotalGB,2)
                    ESXiVersion    = $h.Version
                    Build          = $h.Build
                    MgmtIP         = (
                        $h | Get-VMHostNetworkAdapter -VMKernel |
                        Where-Object { $_.ManagementTrafficEnabled }
                    ).IP
                }
            }

            $AllHosts += $report

            Disconnect-VIServer -Server $vc -Confirm:$false | Out-Null

            # Update progress bar
            $current += $step
            $progressBar.Value = [math]::Min($current, 100)
            $form.Refresh()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error processing $vc : $($_.Exception.Message)")
        }
    }

    if ($AllHosts.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No hosts collected from any vCenter.")
        return
    }

    # Determine common version across ALL hosts
    $commonVersion = ($AllHosts | Group-Object ESXiVersion | Sort-Object Count -Descending | Select-Object -First 1).Name

    foreach ($row in $AllHosts) {
    if ($row.ESXiVersion -eq $commonVersion) {
        $mismatch = "No"
    }
    else {
        $mismatch = "YES"
    }

    $row | Add-Member -NotePropertyName "Mismatch" -NotePropertyValue $mismatch -Force
}
    # Sort by vCenter → Host
    $AllHosts = $AllHosts | Sort-Object vCenter, Name

    # CSS
    $css = @"
<style>
body { font-family: Segoe UI, Arial; background:#f5f5f5; }
h1 { font-size: 22px; }
h2 { margin-top: 30px; }
table { border-collapse: collapse; width: 100%; background: white; }
th, td { border: 1px solid #ccc; padding: 6px; }
th { background: #0078d4; color: white; }
tr:nth-child(even) { background: #f2f2f2; }
tr:hover { background: #ffe8a6; }
.mismatch-row { background-color: #ffcccc !important; }
</style>
"@

    # Output file
    $timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    $outFile   = "$outFolder\ESXi-Host-Comparison-MERGED_$timestamp.html"

    # Build HTML
    $body = "<h1>ESXi Host Comparison - Multi-vCenter Report</h1>"
    $body += "<p>Generated: $(Get-Date)</p>"

    foreach ($vc in $vCenters) {
        $body += "<h2>$vc</h2>"
        $body += "<table><thead><tr>"

        $AllHosts[0].psobject.Properties.Name | ForEach-Object {
            $body += "<th>$_</th>"
        }
        $body += "</tr></thead><tbody>"

        foreach ($row in $AllHosts | Where-Object { $_.vCenter -eq $vc }) {
            $class = if ($row.Mismatch -eq "YES") { "class='mismatch-row'" } else { "" }
            $body += "<tr $class>"

            foreach ($col in $row.psobject.Properties.Name) {
                $body += "<td>$($row.$col)</td>"
            }

            $body += "</tr>"
        }

        $body += "</tbody></table>"
    }

    $html = ConvertTo-Html -Head $css -Body $body -Title "ESXi Host Comparison"

    $html | Out-File -FilePath $outFile -Encoding UTF8 -Force

    $progressBar.Value = 100
    $lblStatus.Text = "Done. Report saved to $outFile"
    $form.Refresh()
})

# ---------------- SHOW FORM ----------------
[void]$form.ShowDialog()
