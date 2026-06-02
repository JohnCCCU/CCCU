PC Toolkit
A unified PowerShell‑based GUI for Windows device lifecycle management.

📌 Overview
The PC Toolkit is a modular PowerShell application that provides a centralized WPF GUI for performing common device administration tasks. It streamlines workflows for IT technicians, helpdesk staff, and system administrators by consolidating multiple scripts into a single, easy‑to‑use interface.

The toolkit is ideal for environments where devices are frequently re‑imaged, re‑deployed, offboarded, or validated for compliance.

✨ Features
🧹 Remove Device
Runs Remove-Device.ps1 to:

Remove device from Active Directory

Clean local join state

Remove MDM/Intune artifacts

Remove scheduled tasks

Generate cleanup logs

🔗 Join Device
Runs Join-Device.ps1 to:

Join a device to an on‑premises domain

Support OU placement

Authenticate using domain join credentials

Log all join operations

🔍 Intune / Entra Validation
Runs an external script (Validate-IntuneEntra.ps1) to:

Validate Azure AD join

Validate Intune MDM enrollment

Display results in the GUI

🔄 Reboot
Provides a controlled reboot option using elevated privileges.

🖥️ WPF GUI
Tabbed interface

Clean layout

Cancel button to close the application

Portable path structure using $PCToolkit

C:\temp\PC-Toolkit\
│
├── PC-Toolkit-GUI.ps1
├── Remove-Device.ps1
├── Join-Device.ps1
├── Validate-IntuneEntra.ps1
└── (additional scripts)

The GUI dynamically loads scripts using:
$PCToolkit = "C:\temp\PC-Toolkit"

⚙️ Requirements
Windows 10 or later

PowerShell 5.1+

Administrator privileges

Domain connectivity (for join operations)

Internet/Entra connectivity (for validation)

🚀 Usage
Launch the GUI
powershell -ExecutionPolicy Bypass -File "C:\temp\PC-Toolkit\PC-Toolkit-GUI.ps1"
<img width="733" height="113" alt="image" src="https://github.com/user-attachments/assets/72c716e6-8196-4d51-9145-e8084ceabadb" />

🧹 Remove a Device
Open Remove Device tab

Enter computer name

Click Run Remove‑Device

Review output

🔗 Join a Device
Open Join Device tab

Enter:

Computer Name

Domain Name

Join User

OU Path (optional)

Click Run Join‑Device

🔍 Validate Intune / Entra
Open Intune / Entra Validation tab

Enter computer name

Click Run Validation Script

🔄 Reboot
Open the Reboot tab → click Reboot Now.

🛠️ Configuration
Toolkit Path
All scripts reference:
$PCToolkit = "C:\temp\PC-Toolkit"
<img width="725" height="112" alt="image" src="https://github.com/user-attachments/assets/51b7c7f2-024e-4d08-b4bf-2d5d2e4c9753" />

Script Paths
Built using Join-Path:
$RemoveScriptPath   = Join-Path $PCToolkit "Remove-Device.ps1"
$JoinScriptPath     = Join-Path $PCToolkit "Join-Device.ps1"
$ValidateScriptPath = Join-Path $PCToolkit "Validate-IntuneEntra.ps1"
<img width="721" height="156" alt="image" src="https://github.com/user-attachments/assets/d0336170-6aac-4075-a3c6-fe0933a672ea" />

📘 Scope
In Scope
Device removal

Device domain join

Device validation

Local reboot operations

Centralized GUI execution

Out of Scope
Bulk operations

Remote device management

Automated remediation

Cloud‑side Intune deletion

OS deployment or imaging

👥 Intended Users
IT technicians

Helpdesk analysts

System administrators

Deployment engineers

📝 Logging
Scripts generate logs such as:
C:\Join-<ComputerName>.log
C:\Cleanup-<ComputerName>.log
<img width="721" height="132" alt="image" src="https://github.com/user-attachments/assets/e0688ca4-db06-4846-817d-f13ab6b674b1" />

🔧 Extensibility
The toolkit is modular. You can easily add:

New tabs

New scripts

Remote execution

Bulk CSV processing

Log viewer tabs

📄 License
Internal use only. Not intended for public distribution.
