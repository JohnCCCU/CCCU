VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ThisOutlookSession"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = True
Sub PhishingAlertInbound()

    Dim objItem As MailItem
    Dim newMail As MailItem
    Dim headerInfo As String
    Dim originalHTML As String
    Dim separator As String
    
    ' Ensure a mail item is selected
    If TypeName(Application.ActiveExplorer.Selection.Item(1)) <> "MailItem" Then
        MsgBox "Please select an email first."
        Exit Sub
    End If
    
    Set objItem = Application.ActiveExplorer.Selection.Item(1)
    
    ' Extract header info including original subject
    headerInfo = "<p>" & _
                 "<b>From:</b> " & objItem.SenderName & "<br>" & _
                 "<b>Original Subject:</b> " & objItem.Subject & "<br>" & _
                 "<b>Date:</b> " & objItem.ReceivedTime & _
                 "</p>"
    
    ' Build separator with centered, bold, red text
    separator = "<div style='margin:15px 0; text-align:center; font-weight:bold; color:red;'>" & _
                "-------------------- ORIGINAL EMAIL BELOW --------------------" & _
                "</div>"
    
    ' Get original HTML body
    originalHTML = objItem.HTMLBody
    
    ' Create new email
    Set newMail = Application.CreateItem(olMailItem)
    
    With newMail
        .To = "email_user_1; email_user_2"
        .Subject = "Phishing Alert"
        
        ' Build HTML body
        .HTMLBody = "<p><b>ALERT PHISHING Alert -</b></p>" & _
                    headerInfo & _
                    separator & _
                    originalHTML
        
        .Display
    End With

End Sub


