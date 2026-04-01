<#
.SYNOPSIS
    This script notifies the HCL Teams incase of a new version is available
 
.DESCRIPTION
    This script notifies the HCL Team incase of a new version is available

.NOTES
    FileName:    Notify-HCLTeams.ps1
    Author:      Daniyal Ahmad
    Modified by: Daniyal Ahmad
    Date:        
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:CLIENT_SECRET,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

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
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Port "587" -From $smtpFrom -To $Recipient -Cc $CC -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}
function Get-IntuneAppName {
    param(
        [Parameter(Mandatory = $true)]$NameConvention,
        [Parameter(Mandatory = $true)]$AppInfo
    )

    #Create App Name for  Intune Search
    if ($NameConvention -eq "PublisherAppNameAppVersion")
        {$AppName = $AppInfo.Publisher+" "+$AppInfo.IntuneAppName+" "+$AppInfo.Version}
    elseif($NameConvention -eq "AppNameAppVersion")
        {$AppName = $AppInfo.IntuneAppName+" "+$AppInfo.Version}
    elseif($NameConvention -eq "PublisherAppName")
        {$AppName = $AppInfo.Publisher+" "+$AppInfo.IntuneAppName}
    else
        {$AppName = $AppInfo.IntuneAppName}

    return $AppName
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

try{
    #Create Access Token
    $accessToken = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

    # Retrieve all applications
    $Win32AppResources = Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"

    #Path for the AppDownload List
    $AppsDownloadListFileName="AppsDownloadList.json"
    $AppPublishedFileName="AppsAssignList.json"
    $AppDownloadListpath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName
    $AppPublishedpath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishedList") -ChildPath $AppPublishedFileName

    #Fetch the list of Apps to be downloaded and Published Apps list
    $AppDownloadJson = Get-Content -Path $AppDownloadListpath | ConvertFrom-Json
    $AppPublishedJson = Get-Content -Path $AppPublishedpath | ConvertFrom-Json

    # Load JSON from Recipient file
    $EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
    $data = Get-Content $EmailjsonPath | ConvertFrom-Json

    # Extract and split 'Cc' emails into array for Sharepoint Catalogue
    $EmailTo = $data.EmailToHCLTeam.To
    $EmailCC = $data.EmailToHCLTeam.CC

    #counter
    $count = 1

    #Set the HTML tags and Table Css
    $htmlstarttags = "<html><head><style>body{font-family:Arial,sans-serif;}.highlight{font-weight:bold;}.footer{color:red;font-weight:bold;text-align:left;margin-top:20px;}
                        table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid black; padding: 8px; text-align: center; }th { background-color: #003781; color: white; }
                        tr:nth-child(even) { background-color: #f2f2f2; } h2, h4 { text-align: center; } .error-header {background-color: red;color: white;}
                        </style></head><body><p>Hello Team,</p>
                        <p class='footer'>**** DO NOT REPLY TO THIS MESSAGE. THIS IS A SYSTEM GENERATED EMAIL ****</p>"
    $htmlendtags =   "<p>Thanks & Regards,<br>Automation Team</p></body></html>"
    $table = "<table><tr><th>S.NO</th><th>App ID</th><th>AppName</th><th>Existing Version</th><th>Existing Display Name</th><th>Latest Version</th><th>Latest DisplayName</th></tr>"

    #Extract the Apps deployed on Intune and skip the failed Apps
    $AppsPublished = $AppPublishedJson | Where-Object {$_.IntuneAppObjectID -ne $null} | Select-Object IntuneAppName
    $AppDownloadJson = $AppDownloadJson | Where-Object {$_.IntuneAppName -in $AppsPublished.IntuneAppName}

    foreach($App in $AppDownloadJson){
        
        $AppDisplayName = $App.IntuneAppName
        $AppID = Get-AppID -AppName $AppDisplayName

        #Set AppDetails for the latest App 
        $AppDetails = [PSCustomObject]@{
        Publisher     = $App.AppPublisher
        IntuneAppName = $App.IntuneAppName
        Version       = $App.AppSetupVersion
        }

        #Body Email variable declaration
        $body_message = ""

        #Fetch the existing Version
        $AppNameLatest = Get-IntuneAppName -NameConvention $App.IntuneAppNamingConvention -AppInfo $AppDetails

        #Fetch the exiting version and name of the App in Intune
        $filteredApps = $Win32AppResources | Where-Object { $_.displayName -like "*$AppDisplayName*" -and $_.notes -like "*Deployment Engineer: Intune App Factory*"}
        $appExistingVersion = ($filteredApps | Sort-Object { [version]$_.rules.comparisonValue } -Descending)[1].displayVersion # second highest version
        $AppDetails.Version = $appExistingVersion
        $AppNameExisting = Get-IntuneAppName -NameConvention $App.IntuneAppNamingConvention -App $AppDetails

        Write-Host "[$AppDisplayName]"
        Write-Host "Latest Version: $($App.AppSetupVersion)"
        Write-Host "Intune Version: $appExistingVersion"

        # N/A in case application not present previously on Intune
        if(-not $appExistingVersion){
            $appExistingVersion = "N/A"
            $AppNameExisting = "N/A" 
        }

        #Table structure for Email
        $EmailTable = "<tr><td>$count</td><td>$AppID</td><td>$($App.IntuneAppName)</td><td>$appExistingVersion</td><td>$AppNameExisting</td><td>$($App.AppSetupVersion)</td><td>$AppNameLatest</td></tr></table>"

        #Set the Email Subject for Body Table
        $subject = "New Version available for $($App.IntuneAppName)"
        $body_message = $htmlstarttags + $table + ${EmailTable} + $htmlendtags

        #Send Email for the application catalogue entry
        Send-ScriptNotificationEmail -Subject $Subject -Recipient $EmailTo -CC $EmailCC -Body $body_message -TMUusername $TMUusername -TMUpassword $TMUpassword
    }
}
catch{
    Write-Output"PS_ERROR_DESC= $_"
    exit 1
}