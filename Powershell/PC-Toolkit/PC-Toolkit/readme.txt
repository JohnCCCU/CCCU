Welcome to AD \ Intune \ Entra program

Start with the PC-Toolkit-GUI.ps1 to get everything started

Purpose
The PC‑Toolkit provides a unified interface for performing common device lifecycle operations on Windows endpoints. It consolidates multiple 
administrative scripts into a single, easy‑to‑use GUI to streamline device preparation, troubleshooting, and re‑deployment.

 - In‑Scope Functionality
   The toolkit includes the following capabilities:

1. Device Removal Operations
   Runs the Remove‑Device.ps1 script

   Removes the device from Active Directory

   Performs local cleanup (MDM artifacts, scheduled tasks, join state)

   Logs all actions for auditing

2. Device Join Operations
   Runs the Join‑Device.ps1 script

   Supports domain join with credentials

   Supports OU targeting

   Prepares devices for imaging or deployment

   Logs all join operations
 
3. Device Validation
   Runs an external Intune/Entra validation script

   Validates Azure AD join status

   Validates Intune MDM enrollment

   Displays results directly in the GUI

4. System Reboot
   Provides a controlled reboot option

Uses elevated privileges when required

5. Centralized GUI
   WPF‑based interface

   Tabbed layout for each function

   Cancel button to close the application

   Portable path structure using $PCToolkit

   Make sure to cd to path of the "PC-Toolkit" folder in cmd prompt or from powershell prompt

Note: if you want to run the scripts individually, here are some variable options;

1. Remove from AD\Intune
$cred = Get-Credential
.\Remove-Device.ps1 -ComputerName hostname -Credential $cred


Add to AD\Intune

1. Basic (default OU)
.\Join-Enterprise.ps1 `
  -ComputerName hostname `
  -DomainName "YOURDOMAIN.local" `
  -JoinUser "YOURDOMAIN\JoinAccount"

OR

.\Join-Enterprise.ps1 -ComputerName hostname -DomainName "YOURDOMAIN.local" -JoinUser "YOURDOMAIN\JoinAccount" 

2. With OU targeting
.\Join-Enterprise.ps1 `
  -ComputerName hostname `
  -DomainName "YOURDOMAIN.local" `
  -JoinUser "YOURDOMAIN\JoinAccount" `
  -OUPath "OU=Laptops,OU=Devices,DC=YOURDOMAIN,DC=local"

OR

.\Join-Enterprise.ps1 -ComputerName hostname -DomainName "YOURDOMAIN.local" -JoinUser "YOURDOMAIN\JoinAccount" -OUPath "OU=Laptops,OU=Devices,DC=YOURDOMAIN,DC=local"


3. Reboot afterward (recommended)
Restart-Computer -Force
