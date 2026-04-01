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
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TMUusername,

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
function Get-FamilyID {
    param (
        [string]$Notes
    )

    $result = [PSCustomObject]@{
        FamilyID = $null
    }
    
    if ($Notes -match 'FamilyID:\s*(\S+)') {
        $result.FamilyID = $matches[1]  # Remove trailing @ if present
    }

    return $result
}
function Get-AppID{
    param(
    [string] $AppName
    )

    #Fetch the App IDs from the AppId.json in the binaries directory
    $AppIDJSONPath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppId.json"

    # Check if the JSON file exists
    if (Test-Path $AppIDJSONPath) {
    
        Write-Host "Reading apps from: $AppIDJSONPath"

        # Load JSON data
        $InputJson = Get-Content -Raw -Path $AppIDJSONPath | ConvertFrom-Json

        # Normalize: always wrap into .Apps
        if ($null -eq $InputJson.Apps) {
            # Legacy single app JSON → wrap it
            $AppInfoObject = [PSCustomObject]@{
                Apps = @($InputJson)
            }
        }
        else {
            # Already has Apps → just keep as is
            $AppInfoObject = $InputJson
        }
    }
    else {
        Write-Host "PS_ERROR_DESC= APPID JSON file at path '$AppIDJSONPath' does not exists."
        exit 1
    }
    $AppId = $AppInfoObject.Apps | Where-Object {$_.IntuneAppName -eq $AppName}| Select-Object AppId
    return $AppId.AppId
}

#Path for the AppDownload List
$AppsDownloadListFileName="AppsDownloadList.json"
$AppDownloadListpath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName

#Fetch the list of Apps to be downloaded
Write-Host "Fetching All the applications from AppDownloadLists.json"
$AppDownloadJson = Get-Content -Path $AppDownloadListpath | ConvertFrom-Json

#Base Path for all Apps
$AppJsonBasePath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -Childpath "Apps"

# Load JSON from file
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
$data = Get-Content $EmailjsonPath | ConvertFrom-Json

# Extract 'To' email for Sharepoint Catalogue
$toEmail = $data.SharePointCatalogue.To

# Extract and split 'Cc' emails into array for Sharepoint Catalogue
$ccEmails = $data.SharePointCatalogue.CC

try{
    Write-Host "Sending Emails for Automated Sharepoint Catalogue Entry"
    $sleepcounter = 1
    foreach($App in $AppDownloadJson){
        #Path for each App.json in the download list 
        $AppJsonPath = Join-Path -Path $AppJsonBasePath -ChildPath "$($App.AppFolderName)\App.json"

        #Fetch the list of Apps to be downloaded
        $AppJson = Get-Content -Path $AppJsonPath | ConvertFrom-Json
        $AppNotes= $AppJson.Information.Notes

        #Fetch the Family ID
        $AppDetails = Get-FamilyID -Notes $AppNotes
        $AppID = ""
        $AppID = Get-AppID -AppName $App.IntuneAppName

        #Subject for the catalogue entry in the format ---> App:<FamilyID>:<Application Name>:<IAF Version>
        $subject = "New IAF Evergreen App:$($AppID):$($AppDetails.FamilyID):$($App.IntuneAppName):$($App.AppSetupVersion)"

        Write-Host "Sending Out Email for [$($App.IntuneAppName)] version: $($App.AppSetupVersion)"
        #Send Email for the application catalogue entry 
        Send-ScriptNotificationEmail -Subject $Subject -Recipient $toEmail -CC $ccEmails -TMUusername $TMUusername -TMUpassword $TMUpassword

        if ($sleepcounter -lt @($AppDownloadJson).Count){
            Start-Sleep -Seconds 300
            $sleepcounter ++
        }       
    }
}
catch{
    Write-Output "PS_ERROR_DESC= Unable to Send Entry for Share Point Catalogue Entry. Error: $_"
    exit 1
}
