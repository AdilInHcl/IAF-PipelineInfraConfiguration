<#
.SYNOPSIS
    This script notifies the Application Owners incase of a new version is available
 
.DESCRIPTION
    This script notifies the Application Owners incase of a new version is available

.NOTES
    FileName:    Notify-ApplicationOwner.ps1
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
    $smtpFrom = "APP-CONVERSION@allianz.com"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd")  # Add timestamp to subject
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
    #Create Acces Token
    $accesstoken = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

    # Retrieve all applications
    $Win32AppResources = Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"

    #Path for the AppDownload List
    $AppsDownloadListFileName="AppsDownloadList.json"
    $AppPublishedFileName="AppsAssignList.json"
    $AppDownloadListpath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName
    $AppPublishedpath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishedList") -ChildPath $AppPublishedFileName

    #Fetch the list of Apps to be downloaded
    $AppDownloadJson = Get-Content -Path $AppDownloadListpath | ConvertFrom-Json
    $AppPublishedJson = Get-Content -Path $AppPublishedpath | ConvertFrom-Json

    #Base Path for all Apps
    $AppJsonBasePath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -Childpath "Apps"

    # Load JSON from Recipient file
    $EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
    $data = Get-Content $EmailjsonPath | ConvertFrom-Json

    # Extract and split 'Cc' emails into array for Sharepoint Catalogue
    $ccEmails = $data.EmailToApplicationOwner.CC

    #counter
    $count = 1

    #Set the HTML tags and Table Css
    $htmlheadtags = "<html><head><style>
        body {
            font-family: Calibri, Arial, sans-serif;
            color: #333333;
            line-height: 1.5;
        }
        .container {
            border: 1px solid #d9d9d9;
            padding: 20px;
            border-radius: 8px;
            
            max-width: 650px;
        }
        h2 {
            color: #003366;
            margin-bottom: 15px;
        }
        .label {
            font-weight: bold;
            color: #003366;
        }
        .section {
            margin-bottom: 12px;
        }
        .note {
            font-size: 12px;
            color: #555555;
            margin-top: 20px;
            border-top: 1px dashed #cccccc;
            padding-top: 10px;
        }
    </style><head><body>"

    $htmldivtag = "<div class='container'>
    <h2>Dear Application Owner,</h2>

    <p>You are being notified that the Application onboarding automated pipeline has identified a new version for your application and is being onboarded into the process to replace the existing version. Please find the details below.</p>
    
    <div class='section'>
        <span class='label'>AppID generated in the catalogue:</span> {{AppID}}
    </div>

    <div class='section'>
        <span class='label'>Application Name:</span> {{Application_Name}}
    </div>

    <div class='section'>
        <span class='label'>New version:</span> {{New_version}}
    </div>

    <div class='section'>
        <span class='label'>Existing version in Intune:</span> {{Existing_version}}
    </div>

    </div>"

    $htmlendtags = "<p>You will be notified once the onboarding is completed and application ready for testing.</p>

    <p>Regards,<br>
    <strong>WPS-Application Team</strong><br>
    <a href='https://allianzms.sharepoint.com/sites/DE1214-connect-az-technology-workplace-services-application-portfolio-management'>APM Connect Page</a></p>

    <p class='note'>
        N.B: This mailbox is not monitored. For any queries reply to this email with 
        <strong>APP-CONVERSION@allianz.com</strong> in 'To' address.
    </p>
    </body>
    </html>"

    #Extract the Apps deployed on Intune and skip the failed Apps
    $AppsPublished = $AppPublishedJson | Where-Object {$_.IntuneAppObjectID -ne $null} | Select-Object IntuneAppName
    $AppDownloadJson = $AppDownloadJson | Where-Object {$_.IntuneAppName -in $AppsPublished.IntuneAppName}


    foreach($App in $AppDownloadJson){
        
        $AppDisplayName = $App.IntuneAppName
        $AppID = Get-AppID -AppName $AppDisplayName

        #Application specific Configuration Path
        $AppJsonPath = Join-Path -Path $AppJsonBasePath -ChildPath "$($App.AppFolderName)\App.json"

        #Fetch the Email of Application Owners from the App.json
        $AppJson = Get-Content -Path $AppJsonPath | ConvertFrom-Json
        $AppOwnerEmail= $AppJson.Information.Owner

        $ToEmail = $AppOwnerEmail -split ';'

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
        $filteredApps = $Win32AppResources | Where-Object { $_.displayName -like "*$AppDisplayName*"}

        # If no previous versions detetcted
        if(-not $filteredApps){
            $appExistingVersion = "N/A"
            $AppNameExisting = "N/A"
        }
        else{
            $appExistingVersion = ($filteredApps |
                                    Where-Object {
                                        $_.displayVersion -and
                                        [version]::TryParse($_.displayVersion, [ref]$null)
                                    } | Sort-Object { [version]$_.displayVersion } -Descending | Select-Object displayVersion)[1].displayVersion # second highest version

            $AppDetails.Version = $appExistingVersion
            $AppNameExisting = Get-IntuneAppName -NameConvention $App.IntuneAppNamingConvention -App $AppDetails
        }

        #Table structure for Email
        $divupdatedTable = $htmldivtag`
                    -replace "{{AppID}}", $AppID `
                    -replace "{{Application_Name}}", $App.IntuneAppName `
                    -replace "{{New_version}}", $App.AppSetupVersion `
                    -replace "{{Existing_version}}", $appExistingVersion


        #Set the Email Subject for Body Table
        $subject = "Subject : Evergreen App Update notification : $($App.IntuneAppName) - new version $($App.AppSetupVersion) is being onboarded to WPS Platforms"
        $body_message = $htmlheadtags + $divupdatedTable + $htmlendtags

        #Send Email for the application catalogue entry
        Write-Host "Sending out email for $($App.IntuneAppName) - new version $($App.AppSetupVersion)."
        Send-ScriptNotificationEmail -Subject $Subject -Recipient $ToEmail -Body $body_message -CC $ccEmails -TMUusername $TMUusername -TMUpassword $TMUpassword
    }
}
catch{
    Write-Output "PS_ERROR_DESC= $_"
    exit 1
}