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


Placeholder	            Replace With
YOURDOMAIN	            Your Jira Cloud domain (e.g., company.atlassian.net)
SEC	                    Your Jira project key
YOUR_BASE64_AUTH	      Base64 of email:APIToken


based on what I have read, convert base64, but working on path for more of an automated process. consider the token from Jira only last 1 year.
generate Base64:
Go to base64encode.org

Code: yourEmail@company.com:YourAPIToken

Copy the encoded string into the macro.
