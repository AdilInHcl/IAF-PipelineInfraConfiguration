<#
.SYNOPSIS
    This script makes a catalogue Entry incase of a new version is available
 
.DESCRIPTION
    This script makes a catalogue Entry incase of a new version is available
 
.NOTES
    FileName:    Notify-CatalogueEntry.ps1
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
        [Parameter(Mandatory = $true)]$CC,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword
    )
    #Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "noreply-wps-app@allianz.com"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd")  # Add timestamp to subject
    $messageSubject = $Subject
    $Body = " "

    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
 
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Port "587" -From $smtpFrom -To $Recipient -Cc $CC -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}

# Declare Paths for the input file name LEVMCreationData file in binaries folder of IAF
$LEVMCreationJsonPath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $env:Input_File_name
# Check if the JSON file exists
if (Test-Path $LEVMCreationJsonPath) {

    # Load JSON data (do not overwrite the path variable)
    Write-Host "Reading apps from: $LEVMCreationJsonPath"
    $LEVMCreationJsonContent = Get-Content -Raw -Path $LEVMCreationJsonPath | ConvertFrom-Json
}
else {
    Write-Output "PS_ERROR_DESC= JSON file at path '$LEVMCreationJsonPath' does not exist."
    exit 1
}

# Load JSON from file
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
$data = Get-Content $EmailjsonPath | ConvertFrom-Json

# Extract 'To' email for Sharepoint Catalogue
$toEmail = $data.SharePointCatalogue.To

# Extract and split 'Cc' emails into array for Sharepoint Catalogue
$ccEmails = $data.SharePointCatalogue.CC

try{
    $sleepcounter = 1
    foreach($App in $LEVMCreationJsonContent.Apps){
        
        if ($App.CrowdstrikeScan -ne "Pass" -or $App.QualysScan -ne "Pass" -or $App.WDACScan -ne "Pass"){

            #Subject for the catalogue entry in the format ---> App:<FamilyID>:<Application Name>:<IAF Version>
            $subject = "IAF App:$($App.AppID):$($App.FamilyID):$($App.IntuneAppName):$($App.AppSetupVersion):Dev Testing Failed"

            Write-Host "Sending Out Email for [$($App.IntuneAppName)] version: $($App.AppSetupVersion)"
            #Send Email for the application catalogue entry 
            Send-ScriptNotificationEmail -Subject $Subject -Recipient $toEmail -CC $ccEmails -TMUusername $TMUusername -TMUpassword $TMUpassword

            if ($sleepcounter -lt @($AppDownloadJson).Count){
                Start-Sleep -Seconds 300
                $sleepcounter ++
            } 
        }   
    }
}
catch{
    Write-Output "PS_ERROR_DESC= Unable to Send Entry for Share Point Catalogue Entry. Error: $_"
    exit 1
}
