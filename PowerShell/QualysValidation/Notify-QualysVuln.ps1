param(
    [string]$TMUusername,
    [string]$TMUpassword = $env:SMTP_PASSWORD
)

function Send-ScriptNotificationEmail {
    param(
        [Parameter(Mandatory = $true)]$Subject,
        [Parameter(Mandatory = $true)]$Recipient,
        [Parameter(Mandatory = $true)]$CC,
        [Parameter(Mandatory = $true)]$Body,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword
    )
    #Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "extern.iaftu01_non-personal-identity@allianz.com"
    $messageSubject = $Subject
 
    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Cc $CC -Port "587" -From $smtpFrom -To $Recipient -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}

# Load recipients
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:WORKSPACE -ChildPath "configs") -ChildPath "EmailRecipients.json"
$data = Get-Content $EmailjsonPath | ConvertFrom-Json

$EmailTo = $data.QualysDailyScan.To
$EmailCC = $data.QualysDailyScan.CC

#Input Meta deta file
$OutfileName = "VM_Details_baseline.txt"
$OutBasefolder = $env:DAILYSCANBASEFOLDER
$OutFilePath = Join-Path -Path $OutBasefolder -ChildPath $OutfileName

#HTML attchament File Folder Path
$timestamp = Get-Date -Format "yyyy_MM_dd" #Current Time stamp 
$OutHtmlFolderpath = Join-Path -Path $OutBasefolder -ChildPath "DailyScanResults/$($timestamp)"

$VMDetailFileContent = Get-Content -Path $OutFilePath -Raw | ConvertFrom-Json

if ($VMDetailFileContent.vulninfo -eq "No additional vulnerabilities detected") {
    Write-Host "No vulnerabilities found. Email will not be sent."
    exit 0
}

# Build HTML
$htmlstarttags = @"
<html><head><style>
body{font-family:Arial,sans-serif;}
.highlight{font-weight:bold;}
.footer{color:red;font-weight:bold;text-align:left;margin-top:20px;}
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid black; padding: 8px; text-align: center; }
th { background-color: #003781; color: white; }
tr:nth-child(even) { background-color: #f2f2f2; }
</style></head><body>
"@

$htmlendtags = @"
<br>
<p class='footer'>**** DO NOT REPLY TO THIS MESSAGE. THIS IS A SYSTEM GENERATED EMAIL ****</p>
<p>Thanks & Regards,<br>Automation Team</p></body></html>
"@

$message = @"
<p>Hi Team,</p>
<p>New Vulnerabilities have been detected. Please validate the baseline image.</p>
"@

$tablerows = ""
$counter = 1
foreach($vuln in $VMDetailFileContent.vulninfo){
    $tablerows += "<tr><td>$($counter)</td><td>$($vuln.QID)</td><td>$($vuln.SEVERITY)</td><td>$($vuln.RESULTS)</td><td>$($vuln.LAST_FOUND_DATETIME)</td></tr>"
    $counter += 1
}

$table = "<table><tr><th>S.NO</th><th>QID</th><th>Severity</th><th>Results</th><th>Last Found</th></tr>$tablerows</table>"

$body = $htmlstarttags + $message + $table + $htmlendtags
$Subject = "Qualys Daily Baseline Scan [IAF]: New Vulnerabilities detected"

Send-ScriptNotificationEmail -Subject $Subject -Recipient $EmailTo -CC $EmailCC -Body $body -TMUusername $TMUusername -TMUpassword $TMUpassword

Remove-Item -Path $OutFilePath -Force -Recurse -ErrorAction Stop