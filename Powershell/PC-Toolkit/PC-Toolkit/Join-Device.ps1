<#
.SYNOPSIS
    Minimal‑footprint join script for AD + Entra + Intune.
    - Renames device
    - Joins on‑prem Active Directory
    - Forces Entra registration (dsregcmd /join)
    - Forces Intune MDM enrollment
    - Writes join log
    - make sure to user domain account "AdminXX" to join

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 06/02/2026

add_pc_ad_entra_v.1.0.ps1
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName,

    [Parameter(Mandatory=$true)]
    [string]$DomainName,

    [Parameter(Mandatory=$true)]
    [string]$JoinUser
)

# --- Logging ---
$Log = "C:\Join-$ComputerName.log"
function Write-Log { param($m) "$((Get-Date).ToString('u'))  $m" | Tee-Object -FilePath $Log -Append }

Write-Log "Starting join process for $ComputerName"

# --- 1. Rename Computer ---
try {
    Write-Log "Renaming computer to $ComputerName..."
    Rename-Computer -NewName $ComputerName -Force -ErrorAction Stop
    Write-Log "Rename successful."
}
catch {
    Write-Log "Rename failed: $($_.Exception.Message)"
}

# --- 2. Join Active Directory ---
try {
    Write-Log "Joining Active Directory domain $DomainName..."
    $Password = Read-Host "Enter password for $JoinUser" -AsSecureString
    $Cred = New-Object System.Management.Automation.PSCredential($JoinUser, $Password)

    Add-Computer -DomainName $DomainName -Credential $Cred -ErrorAction Stop
    Write-Log "Domain join successful."
}
catch {
    Write-Log "Domain join failed: $($_.Exception.Message)"
}

# --- 3. Force Entra ID Registration ---
try {
    Write-Log "Running dsregcmd /join..."
    dsregcmd /join | Out-Null
    Write-Log "Entra registration triggered."
}
catch {
    Write-Log "dsregcmd /join failed: $($_.Exception.Message)"
}

# --- 4. Trigger Intune MDM Enrollment ---
try {
    Write-Log "Triggering Intune MDM enrollment..."
    $Task = Get-ScheduledTask -TaskName "Schedule created by enrollment client" -ErrorAction SilentlyContinue
    if ($Task) {
        Start-ScheduledTask -TaskName "Schedule created by enrollment client"
        Write-Log "MDM enrollment task executed."
    }
    else {
        # Fallback modern enrollment trigger
        Start-Process "C:\Windows\System32\DeviceEnroller.exe" -ArgumentList "/c /AutoEnrollMDM"
        Write-Log "Fallback MDM enrollment executed."
    }
}
catch {
    Write-Log "MDM enrollment trigger failed: $($_.Exception.Message)"
}

Write-Log "Join process complete. Reboot recommended."
