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
    $smtpFrom = "noreply-wps-app@allianz.com"
    $messageSubject = $Subject
 
    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Cc $CC -Port "587" -From $smtpFrom -To $Recipient -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}

# Load recipients
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:WORKSPACE -ChildPath "configs") -ChildPath "EmailRecipients.json"
$data = Get-Content $EmailjsonPath | ConvertFrom-Json

$EmailTo = $data.IAFModuleUpdate.To
$EmailCC = $data.IAFModuleUpdate.CC

# Load table rows from previous stage
$rowsFile = Join-Path -Path $env:WORKSPACE -ChildPath "module_updates.html"
$tablerows = Get-Content -Path $rowsFile -Raw

if (-not $tablerows) {
    Write-Host "No updates found. Email will not be sent."
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
<p>Hi Team,</p>
<p>The new IAF PS module version is now available.</p>
"@

$htmlendtags = @"
<br>
<p>Please review the changes included in this release and proceed with testing the module in the ADT environment.<br>After completing your review, implement any required updates in ADT and perform thorough testing to ensure everything functions as expected.</p>
<p class='footer'>**** DO NOT REPLY TO THIS MESSAGE. THIS IS A SYSTEM GENERATED EMAIL ****</p>
<p>Thanks & Regards,<br>Automation Team</p></body></html>
"@

$table = "<table><tr><th>S.NO</th><th>MODULE</th><th>NEW VERSION</th></tr>$tablerows</table>"
$body = $htmlstarttags + $table + $htmlendtags
$Subject = "IAF: Latest PS Module Version Released"

Send-ScriptNotificationEmail -Subject $Subject -Recipient $EmailTo -CC $EmailCC -Body $body -TMUusername $TMUusername -TMUpassword $TMUpassword
Remove-Item -Path $rowsFile -Force -Recurse -ErrorAction Stop