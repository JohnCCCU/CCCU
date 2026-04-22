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

    ' -------------------------------
    ' VARIABLES
    ' -------------------------------
    Dim objItem As MailItem
    Dim newMail As MailItem
    Dim headerInfo As String
    Dim originalHTML As String
    Dim separator As String
    Dim jiraSummary As String
    Dim jiraDescription As String
    Dim jiraTicket As String
    Dim jiraInsert As String

    ' Jira API variables
    Dim http As Object
    Dim url As String
    Dim jsonBody As String
    Dim authHeader As String
    Dim response As String

    ' -------------------------------
    ' VALIDATE SELECTION
    ' -------------------------------
    If TypeName(Application.ActiveExplorer.Selection.Item(1)) <> "MailItem" Then
        MsgBox "Please select an email first."
        Exit Sub
    End If

    Set objItem = Application.ActiveExplorer.Selection.Item(1)

    ' -------------------------------
    ' BUILD JIRA PAYLOAD
    ' -------------------------------
    jiraSummary = "Phishing Alert - " & objItem.Subject
    jiraDescription = "Sender: " & objItem.SenderName & vbCrLf & _
                      "Subject: " & objItem.Subject & vbCrLf & _
                      "Received: " & objItem.ReceivedTime & vbCrLf & vbCrLf & _
                      "Original email content included in Outlook notification."

    ' -------------------------------
    ' JIRA API CALL
    ' -------------------------------
    url = "https://YOURDOMAIN.atlassian.net/rest/api/3/issue"

    jsonBody = "{""fields"": {""project"": {""key"": ""SEC""}," & _
               """summary"": """ & jiraSummary & """," & _
               """description"": """ & jiraDescription & """," & _
               """issuetype"": {""name"": ""Task""}}}"

    Set http = CreateObject("MSXML2.XMLHTTP")

    ' Replace with Base64("email:APIToken")
    authHeader = "Basic YOUR_BASE64_AUTH"

    http.Open "POST", url, False
    http.setRequestHeader "Content-Type", "application/json"
    http.setRequestHeader "Authorization", authHeader
    http.Send jsonBody

    response = http.responseText

    ' Extract Jira ticket key
    If InStr(response, "key") > 0 Then
        jiraTicket = Split(Split(response, """key"":""")(1), """")(0)
    Else
        jiraTicket = "ERROR_CREATING_TICKET"
    End If

    ' -------------------------------
    ' INSERT JIRA TICKET INTO EMAIL
    ' (bold + red + clickable)
    ' -------------------------------
    jiraInsert = "<p><b>Jira Ticket:</b> " & _
                 "<a href='https://YOURDOMAIN.atlassian.net/browse/" & jiraTicket & "'" & _
                 " style='color:red; font-weight:bold;'>" & jiraTicket & "</a></p>"

    ' -------------------------------
    ' BUILD HEADER INFO
    ' -------------------------------
    headerInfo = "<p>" & _
                 "<b>From:</b> " & objItem.SenderName & "<br>" & _
                 "<b>Original Subject:</b> " & objItem.Subject & "<br>" & _
                 "<b>Date:</b> " & objItem.ReceivedTime & _
                 "</p>"

    separator = "<div style='margin:15px 0; text-align:center; font-weight:bold; color:red;'>" & _
                "-------------------- ORIGINAL EMAIL BELOW --------------------" & _
                "</div>"

    originalHTML = objItem.HTMLBody

    ' -------------------------------
    ' BUILD FINAL EMAIL
    ' -------------------------------
    Set newMail = Application.CreateItem(olMailItem)

    With newMail
        .To = "email_user_1; email_user_2"
        .Subject = "Phishing Alert"

        .HTMLBody = "<p><b>ALERT PHISHING Alert -</b></p>" & _
                    jiraInsert & _
                    headerInfo & _
                    separator & _
                    originalHTML

        .Display
    End With

End Sub


