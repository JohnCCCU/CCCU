contains outlook macros, powershell

Enable the Developer tab  
File → Options → Customize Ribbon → check Developer.

Open the VBA editor  
Press Alt + F11.

Insert a module  
In the left Project pane:
Project1 (VbaProject.OTM) → right‑click → Insert → Module.

Write your macro  
Example:

vba
Sub TestMessage()
    MsgBox "Hello from Outlook macro!"
End Sub
Save and close the VBA editor.

# Create menu shortcut and assign macro to it
Add to Ribbon
File → Options → Customize Ribbon

On the right, choose a tab (e.g., Home (Mail)).

Click New Group → rename if desired.

On the left, under Choose commands from, select Macros.

Select your macro → Add >>.

Click Modify to choose an icon and label.

Click OK.
