<#
.SYNOPSIS
    Minimal‑footprint cleanup for AD + Entra ID joined devices.
    - Removes computer from on‑prem Active Directory
    - Forces Entra ID unjoin (dsregcmd /leave)
    - Clears local join state
    - Removes MDM/Intune scheduled tasks (GUID-based)
    - Writes cleanup log
    - make sure to user domain account "AdminXX" to remove

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 06/01/2026
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

# --- Logging ---
$Log = "C:\Cleanup-$ComputerName.log"
function Write-Log { param($m) "$((Get-Date).ToString('u'))  $m" | Tee-Object -FilePath $Log -Append }

Write-Log "Starting cleanup for $ComputerName"

# --- 1. Remove from Active Directory ---
try {
    Write-Log "Attempting AD removal..."
    Remove-ADComputer -Identity $ComputerName -Confirm:$false -ErrorAction Stop
    Write-Log "AD computer object removed successfully."
}
catch {
    Write-Log "AD removal failed or object not found: $($_.Exception.Message)"
}

# --- 2. Remove from Entra ID (local device) ---
try {
    Write-Log "Running dsregcmd /leave..."
    dsregcmd /leave | Out-Null
    Write-Log "Entra ID unjoin completed."
}
catch {
    Write-Log "dsregcmd /leave failed: $($_.Exception.Message)"
}

# --- 3. Clear local join artifacts ---
Write-Log "Clearing local join state..."
$Paths = @(
    "HKLM:\SOFTWARE\Microsoft\Enrollments",
    "HKLM:\SOFTWARE\Microsoft\Provisioning",
    "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin"
)

foreach ($Path in $Paths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed $Path"
    }
}

# --- 4. GUID Discovery for MDM/Intune Cleanup ---
Write-Log "Searching for MDM enrollment GUID..."

$Guid = (Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" |
    Where-Object { $_.Name -match "GUID" } |
    Select-Object -ExpandProperty PSChildName -ErrorAction SilentlyContinue)

if ($Guid) {
    Write-Log "Found MDM GUID: $Guid"
} else {
    Write-Log "No MDM GUID found. Skipping EnterpriseMgmt task cleanup."
}

# --- 5. Remove EnterpriseMgmt Scheduled Tasks ---
if ($Guid) {
    Write-Log "Removing EnterpriseMgmt scheduled tasks..."

    $Tasks = @(
        "\Microsoft\Windows\EnterpriseMgmt\$Guid",
        "\Microsoft\Windows\EnterpriseMgmt\$Guid\Schedule created by enrollment client",
        "\Microsoft\Windows\EnterpriseMgmt\$Guid\SessionRetry"
    )

    foreach ($Task in $Tasks) {
        try {
            Unregister-ScheduledTask -TaskName $Task -Confirm:$false -ErrorAction Stop
            Write-Log "Removed task: $Task"
        }
        catch {
            Write-Log "Task not found or could not be removed: $Task"
        }
    }

    # Remove folder on disk
    $Folder = "C:\Windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$Guid"
    if (Test-Path $Folder) {
        Remove-Item $Folder -Recurse -Force
        Write-Log "Removed folder: $Folder"
    }
}

Write-Log "Cleanup complete."
Write-Log "Reboot recommended to finalize state."
