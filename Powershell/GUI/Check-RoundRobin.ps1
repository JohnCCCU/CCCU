<#

SCOPE:
PowerShell DNS round‑robin checker can be built by repeatedly querying a hostname with multiple A‑records and observing whether 
the returned IP rotates. PowerShell’s Resolve-DnsName cmdlet is the correct tool for this, since it performs structured DNS queries 
and returns object‑based results you can easily analyze 

open cmd in admin mode, cd to path where the Check-RoundRobin.ps1 resides
then update dns name
.\Check-RoundRobin.ps1 -Hostname "www.example.com" -Iterations 50 -DelayMs 200

CREATED BY: John Braunsdorf

DATE: 04/16/2026

#>


param(
    [Parameter(Mandatory=$true)]
    [string]$Hostname,

    [int]$Iterations = 20,
    [int]$DelayMs = 300
)

$results = @()

for ($i = 1; $i -le $Iterations; $i++) {
    try {
        $answer = Resolve-DnsName -Name $Hostname -Type A -DnsOnly
        $ip = ($answer | Where-Object { $_.Type -eq "A" }).IPAddress
        $results += $ip
        Write-Host "[$i] $ip"
    }
    catch {
        Write-Warning "DNS query failed on iteration $i"
    }

    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "`nUnique IPs returned:"
$results | Sort-Object -Unique

Write-Host "`nReturn frequency:"
$results | Group-Object | Sort-Object Count -Descending | Format-Table Name,Count
