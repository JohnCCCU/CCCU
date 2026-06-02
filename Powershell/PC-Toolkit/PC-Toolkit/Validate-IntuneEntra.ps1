<#
.SCOPE
    - script prints a full health report for (Active Directory \ Intune \ Entra)
    - This has to be on the device used testing enrollment \ Adding and or Removing
        - Entra: Displays devices that are registered or joined to Azure AD
        - Intune: Only manages devices that are enrolled for management
        - Active Directory: Only for On-Prem sites

.CREATED BY
    - John W. Braunsdorf

.DATE
    - 06/02/2026
#>

Write-Host "=== Entra Join Status ==="
dsregcmd /status

Write-Host "`n=== Intune Enrollment GUIDs ==="
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" |
Where-Object { $_.Name -match "GUID" } |
Select-Object PSChildName

Write-Host "`n=== Intune Management Extension ==="
Get-Service IntuneManagementExtension

Write-Host "`n=== EnterpriseMgmt Scheduled Tasks ==="
Get-ScheduledTask | Where-Object TaskName -Match "EnterpriseMgmt"
