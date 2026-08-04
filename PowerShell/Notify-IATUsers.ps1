<#
.SYNOPSIS
    This script notifies the Application Owners once the IAT VMs are ready.
 
.DESCRIPTION
    This script notifies the Application Owners once the IAT VMS are created and ready.

.NOTES
    FileName:    Notify-IATUsers.ps1
    Author:      Daniyal Ahmad
    Modified by: Daniyal Ahmad
    Date:        
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TMUusername = $env:SMTP_USERNAME,

    [ValidateNotNullOrEmpty()]
    [string]$TMUpassword = $env:SMTP_PASSWORD
)

function Send-ScriptNotificationEmail {
    param(
        [Parameter(Mandatory = $true)]$Subject,
        [Parameter(Mandatory = $true)]$Recipient,
        [Parameter(Mandatory = $true)]$Body,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword
    )
    #Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "APP-CONVERSION@allianz.com"
    $messageSubject = $Subject
 
    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
 
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Port "587" -From $smtpFrom -To $Recipient -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}

try{
    #Fetch the json file where all the information regarding VM is present
    $IATVMCreationFileName = "APP_IAT.json"
    $IATVMCreationDataFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $IATVMCreationFileName
    $IATVMCreationData = Get-Content -Path $IATVMCreationDataFilePath | ConvertFrom-Json

    #Fetch Job name and build number
    $Job_name = $env:JOB_NAME
    $build = $env:BUILD_NUMBER

    # Load JSON from Recipient file
    $EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
    $data = Get-Content $EmailjsonPath | ConvertFrom-Json

    # Extract and split 'Cc' emails into array for Sharepoint Catalogue
    $FailureEmailTo = $data.IATVMFail.To

    #Set the HTML tags and Table Css
    $htmlbodypass = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>IAT Virtual Machine Provisioning</title>
    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            background-color: #f7f7f7;
            margin: 0;
            padding: 20px;
        }
        .container {
            background: #ffffff;
            padding: 25px;
            border-radius: 8px;
            max-width: 650px;
            margin: auto;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h2 {
            color: #003366;
            margin-top: 0;
        }
        a {
            color: #0066cc;
            text-decoration: none;
            font-weight: bold;
        }
        .highlight {
            background: #eef6ff;
            padding: 12px;
            border-left: 4px solid #0066cc;
            margin: 20px 0;
            border-radius: 4px;
        }
        .footer {
            margin-top: 30px;
            font-size: 14px;
            color: #555;
        }
    </style>
</head>
<body>

<div class="container">
    <h2>IAT Virtual Machine Provisioning Complete</h2>

    <p>Dear User,</p>

    <p>Your <strong>IAT virtual machine</strong> has been successfully provisioned and is now ready for use.</p>

    <div class="highlight">
        <p><strong>Access via Citrix DaaS:</strong>  
        <br><a href="https://Allianz.cloud.com">https://Allianz.cloud.com</a></p>

        <p>Look for the desktop icon: <strong>IAT Client</strong></p>
    </div>

    <p><strong>Important:</strong><br>
    Policies and core applications are deployed through <strong>Microsoft Intune</strong>.  
    Please allow some buffer time after your first login for all configurations and applications to install correctly.</p>

    <p class="footer">Best regards,<br>
    <strong>HCL Automation Team</strong></p>
</div>

</body>
</html>
'
    $failemailtemplate = '
    <!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>IAT Virtual Machine Provisioning Failed</title>
    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            background-color: #f7f7f7;
            margin: 0;
            padding: 20px;
        }
        .container {
            background: #ffffff;
            padding: 25px;
            border-radius: 8px;
            max-width: 650px;
            margin: auto;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h2 {
            color: #cc0000;
            margin-top: 0;
        }
        .highlight {
            background: #fff1f1;
            padding: 12px;
            border-left: 4px solid #cc0000;
            margin: 20px 0;
            border-radius: 4px;
        }
        .footer {
            margin-top: 30px;
            font-size: 14px;
            color: #555;
        }
    </style>
</head>
<body>

<div class="container">
    <h2>IAT Virtual Machine Provisioning Failed</h2>

    <p>Hello Team,</p>

    <p>We regret to inform you that the provisioning of your <strong>IAT virtual machine</strong> could not be completed successfully.</p>

    <div class="highlight">
        <p><strong>Status:</strong> VM Provisioning Failed</p>
        <p>The virtual machine could not be created due to a provisioning issue encountered during the deployment process.</p>
        <p><strong>User:</strong>{{UserEmail}}</p>
        <p><strong>VM:</strong>{{MachineName}}</p>
    </div>

    <p>
        We apologize for the inconvenience and appreciate your patience while the issue is being resolved.
    </p>

    <p class="footer">
        Best regards,<br>
        <strong>HCL Automation Team</strong>
    </p>
</div>

</body>
</html>
'
    $Subjectpass = " $Job_name Build: $build - Success "
    $SubjectFail = " $Job_name Build: $build - Failed "

    foreach($user in $IATVMCreationData){
        $AssignationStatus = $user.Status
    
        if ($AssignationStatus -eq "Assigned"){
            #Send Email for the application catalogue entry
            $ToEmail = $user.User
            Send-ScriptNotificationEmail -Subject $Subjectpass -Recipient $ToEmail -Body $htmlbodypass -TMUusername $TMUusername -TMUpassword $TMUpassword
        }
        else{
            $htmlbodyfail = $failemailtemplate
            $htmlbodyupdatedfail = $htmlbodyfail.Replace('{{UserEmail}}', $user.User)
            $htmlbodyupdatedfail = $htmlbodyupdatedfail.Replace('{{MachineName}}', $user.Device)

            Send-ScriptNotificationEmail -Subject $SubjectFail -Recipient $FailureEmailTo -Body $htmlbodyupdatedfail -TMUusername $TMUusername -TMUpassword $TMUpassword
            Write-Host "Device not mapped to $($user.User)"
        }
    }
    
}
catch{
    Write-Output"PS_ERROR_DESC= $_"
    exit 1
}