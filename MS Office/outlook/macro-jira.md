
Placeholder	            Replace With
YOURDOMAIN	            Your Jira Cloud domain (e.g., company.atlassian.net)
SEC	                    Your Jira project key
YOUR_BASE64_AUTH	      Base64 of email:APIToken


based on what I have read, convert base64, but working on path for more of an automated process. consider the token from Jira only last 1 year.
generate Base64:
Go to base64encode.org

Code: yourEmail@company.com:YourAPIToken

Copy the encoded string into the macro.
