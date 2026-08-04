param(
[string]$Status,
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
        [Parameter(Mandatory = $true)]$TMUpassword,
        [Parameter(Mandatory = $false)]$AttachmentPath
    )

    # Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "APP-CONVERSION@allianz.com"
    $messageSubject = $Subject

    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)

    # Build parameters dynamically
    $mailParams = @{
        SmtpServer = $smtpServer
        Credential = $credentials
        Port       = 587
        From       = $smtpFrom
        To         = $Recipient
        Cc         = $CC
        Subject    = $messageSubject
        Body       = $Body
        BodyAsHtml = $true
        UseSsl     = $true
        Priority   = 'High'
    }

    if ($AttachmentPath) {
        $mailParams.Add("Attachments", $AttachmentPath)
    }

    Send-MailMessage @mailParams
}


#Declare COnfigs Folder
$configsPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath 'configs'

# Read table files
$EmailTable = Get-Content "$configsPath\TableEmail.txt" -Raw
$LogTable   = Get-Content "$configsPath\ErrorTable.txt" -Raw


# Read Dependency Log if exists
$DependencyTable = ""
$dependencyLogFile = Join-Path $configsPath "DependencyLog.txt"
if (Test-Path $dependencyLogFile) {
    $DependencyTable = Get-Content $dependencyLogFile -Raw
}
$dependencyParagraph = ""
if ($DependencyTable) {
    $dependencyParagraph = "<p>The following table shows the dependency validation and assignment results for the apps listed above:</p>"
}

# HTML templates
$htmlStarttags = @"
<html><head><style>
body{font-family:Arial,sans-serif;}
.highlight{font-weight:bold;}
.footer{color:red;font-weight:bold;text-align:left;margin-top:20px;}
table{border-collapse:collapse;width:100%;}
th,td{border:1px solid black;padding:8px;text-align:center;}
th{background-color:#003781;color:white;}
tr:nth-child(even){background-color:#f2f2f2;}
</style></head><body>
<p>Hello Team,</p>
<p class="footer">**** DO NOT REPLY TO THIS MESSAGE. THIS IS A SYSTEM GENERATED EMAIL ****</p>
"@

$htmlEndtags = @"
<p>Thanks & Regards,<br>Automation Team</p></body></html>
"@

$tableHtml = @"
<table>
<tr><th>S.NO</th><th>App ID</th><th>Display Name</th><th>Publisher</th>
<th>Applicable Architectures</th><th>Created Date</th><th>Published State</th></tr>
$EmailTable
</table>
$dependencyParagraph
$DependencyTable
$LogTable
"@

# Determine status
switch ($Status) {
    "SUCCESS" {
        $body = "<p>The Jenkins pipeline build <span class='highlight'>$env:BUILD_ID</span> completed successfully. Applications have been published on Intune.</p>"
        $subject = "Jenkins Pipeline Build ($env:BUILD_ID) Successful. Applications Published"
    }
    "PARTIAL" {
        $body = "<p>The Jenkins pipeline build <span class='highlight'>$env:BUILD_ID</span> has partially failed. Some applications were not published.</p>"
        $subject = "Jenkins Pipeline Build ($env:BUILD_ID) Partially Failed. Publishing Issue"
    }
}

#Final BODY
$finalBody = $htmlStarttags + $body + $tableHtml + $htmlEndtags

# Load JSON from Recipient file
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
$data = Get-Content $EmailjsonPath | ConvertFrom-Json

# Extract and split To and  'Cc' emails based on the the pipeline type
if($env:PIPELINE_TYPE -eq "E2E"){
    $EmailTo = $data.IAFAppPublishStatus.To
    $EmailCC = $data.IAFAppPublishStatus.CC
}
else{
    $EmailTo = $data.IAFAppPublishStatusTest.To
    $EmailCC = $data.IAFAppPublishStatusTest.CC
}

#PDF Path of the report
$PDFFIlepath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath 'configs') -ChildPath "Intune_App_Report.pdf"
if (-not(Test-Path $PDFFIlepath)){
    Write-Host "PS_ERROR_DESC= Error: PDF File Not present. $_ !!!"
    exit 1
}

#Trigger EMAIL
try{
    Send-ScriptNotificationEmail -Subject $subject -Recipient $EmailTo -CC $EmailCC -Body $finalbody -TMUusername $TMUusername -TMUpassword $TMUpassword -AttachmentPath $PDFFIlepath
}
catch{
    Write-Output "PS_ERROR_DESC= Error: Failed to send Email. $_ !!!"
    exit 1
}