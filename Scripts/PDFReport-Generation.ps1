[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:CLIENT_SECRET
)
function Set-ApplicationJsonData {
        <#
        .SYNOPSIS
            Extracts the Json Data for the required App IDs
    
        .DESCRIPTION
             This Function calls the Intune Api for the Json Data based on the App Id supplied
    
        .PARAMETER AppName
            Application Name.
    
        .PARAMETER Counter
            For Serial Number
    
        .NOTES
            Author: Daniyal Ahmad / Adil Ansari  
            Contact:     
            Created:    
            Version history:
            1.0.0 - (2025-03-) Script created
        #>
        param(
            [parameter(Mandatory = $true, HelpMessage = "Application Name of the published App on Intune.")]
            [ValidateNotNullOrEmpty()]
            [string]$AppName,
            [parameter(Mandatory = $true, HelpMessage = "Counter  for the output Table")]
            [ValidateNotNullOrEmpty()]
            [int]$counter,
            [parameter(Mandatory = $true, HelpMessage = "App ID for the Intune APP Name")]
            [ValidateNotNullOrEmpty()]
            [string]$AppID
            )

            try { 
                  # Define Graph API URL to Fetch the Specific App by Object ID
                  $AppName = [System.Web.HttpUtility]::UrlEncode($AppName)
                  $GraphUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=displayName eq '$AppName'"
                  $graphApiUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
                  
                  Write-Host $AppName
                  $response = Invoke-RestMethod -Method Get -Uri $GraphUrl -Headers @{Authorization = "Bearer $AccessToken"} -ContentType "application/json"
                  $AppDetails = $response.value
                  
                  $FormattedDate = Get-Date $AppDetails.lastModifiedDateTime -Format "MMMM dd, yyyy, hh:mm tt" 
                  Write-Host "[Checking Status For: $AppName] --> $($AppDetails.publishingState)" 

                    if ($AppDetails.publishingState -ne "published")
                    {
                        $publishedstate = "<td style='color:red;'>Not Published</td>"
                        $deleteUrl = "$graphApiUrl/$($AppDetails.id)"
                        Invoke-RestMethod -Uri $deleteUrl -Headers @{Authorization = "Bearer $AccessToken"} -Method Delete
                        #"Application '$AppName' has been removed successfully!." 
                    }
                    else{
                        $publishedstate = "<td style='color:green;'>Published</td>"         
                    }

                    $TableRow = "<tr>
                                    <td>$counter</td>
                                    <td>$AppID</td>
                                    <td>$($AppDetails.displayName)</td>
                                    <td>$($AppDetails.publisher)</td>
                                    <td>$($AppDetails.applicableArchitectures)</td>
                                    <td>$FormattedDate</td>
                                    $publishedstate
                                </tr>"           
                }

            catch { 
                    $AppName = [System.Web.HttpUtility]::UrlDecode($AppName) 
                    $TableRow = "<tr>
                                    <td>$counter</td>
                                    <td>$AppID</td>
                                    <td>$AppName</td>
                                    <td>NA</td>
                                    <td>NA</td>
                                    <td>NA</td>
                                    <td style='color:red;'>Not Found on Intune</td>
                                </tr>
                                "
                }
                return $TableRow
}
function Set-ApplicationErrorLogData{
    $AppsFailLogFileName = "AppsFailureLog.json"
    $AppsFailLogFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $AppsFailLogFileName

    # If error log file is not created, return null
    if (-Not (Test-Path $AppsFailLogFilePath)) {
        return $null
    }
    else{
        # Load existing Log data from AppsFailureLog.json
        $AppLogData = Get-Content -Path $AppsFailLogFilePath | ConvertFrom-Json
        $AppsInfo = $AppLogData.apps
        $counter = 1
        $LogTable = ''
        foreach($app in $AppsInfo){
            $logs = '<ul/>'
            $AppID =  Get-AppID -AppName $app.appname
            #Fetch the list of errors for a particular App
            foreach($log in $app.log){
                $logs += "<li>$log</li>"
            }
            $LogTable += "<tr ><td>$counter</td><td>$AppID</td><td>$($app.appname)</td><td style='text-align: left;'>$($logs)</td></tr>"
            $counter += 1
        }
        return $LogTable
    }
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
# Define OAuth Token URL
$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
 
# Define Body for Authentication Request
$Body = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
}
 
# Request Access Token
$TokenResponse = Invoke-RestMethod -Method Post -Uri $TokenUrl -ContentType "application/x-www-form-urlencoded" -Body $Body
$AccessToken = $TokenResponse.access_token

# Validate Token Retrieval
if (-not $AccessToken) { 
    Write-Output "PS_ERROR_DESC= { `"error`": `"Failed to retrieve access token`" }"
    exit 1
}

# Define File paths
$AppsDownloadListFileName = "AppsDownloadList.json"
$AppsDownloadListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName

#Smoke test VM creation File
$Job_name = $env:JOB_NAME
$build = $env:BUILD_NUMBER
$SmokeTestVMFileName = "LEVMCreationData_$($Job_name)_$($build).json"
$SmokeTestVMFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $SmokeTestVMFileName

if (Test-Path $SmokeTestVMFilePath){
    $SmokeTestVMFileContent = (Get-Content -Path $SmokeTestVMFilePath -Raw | ConvertFrom-Json).Apps
}
else{
    Write-Host "$SmokeTestVMFileName not found."
}

# HTML Report path
$IntuneTemplateFileName = "IntuneReportTemplate.html"
$TemplatePath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath $IntuneTemplateFileName  # Path to the HTML template
$ReportPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "Intune_App_Report.html"   # Path to save the report
$TableEmail = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "TableEmail.txt"   # Path to save the Table for Email Body
$ErrorTable = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "ErrorTable.txt"   # Path to save the Table for Error Log Body

#PDF Report Path
$ReportPath_PDF = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "Intune_App_Report.pdf"   # Path to save the report


if (Test-Path -Path $AppsDownloadListFilePath) {
    # Read content from AppsPrepareList.json file and convert from JSON format
    Write-Output "Reading contents from: $($AppsDownloadListFilePath)"
    $AppsDownloadList = Get-Content -Path $AppsDownloadListFilePath -ErrorAction "SilentlyContinue" | ConvertFrom-Json

    # Counter for the apps
    $Counter = 0
    $pass = 0
    $failedApps = New-Object -TypeName "System.Collections.ArrayList"

    foreach ($App in $AppsDownloadList) {
        $Counter ++ 
        $AppID = Get-AppID -AppName $App.IntuneAppName

        #Create App Name for  Intune Search
        $NameConvention = $App.IntuneAppNamingConvention
        if ($NameConvention -eq "PublisherAppNameAppVersion")
            {$AppName = $App.AppPublisher+" "+$App.IntuneAppName+" "+$App.AppSetupVersion}
        elseif($NameConvention -eq "AppNameAppVersion")
            {$AppName = $App.IntuneAppName+" "+$App.AppSetupVersion}
        elseif($NameConvention -eq "PublisherAppName")
            {$AppName = $App.AppPublisher+" "+$App.IntuneAppName}
        else
            {$AppName = $App.IntuneAppName}

        $TableRow = Set-ApplicationJsonData -AppName $AppName -counter $Counter -AppID $AppID
        $TableRows += $TableRow

        # Check if the application has been published and incress $pass counter by 1
        if ($TableRow -match "<td style='color:green;'>Published</td>") {
            Write-Output "$Counter : [Checking Status For: $AppName] --> Published"
            $pass ++
        }
        else{
            $failedApps.Add($App) | Out-Null #Failed to published app list
        }
    }

    #Fetch Error Logs for the Apps
    $Log = Set-ApplicationErrorLogData
    if( $Log -ne $null){
        $ErrorLog = "<p>Below apps failed to onboard due to following errors</p><table><tr>
            <th class='error-header'>S.NO</th>
            <th class='error-header'>App ID</th>
            <th class='error-header'>App Name</th>
            <th class='error-header'>Error Descriptions</th></tr>$Log</table>"
    }else{
        $ErrorLog = ""
    }

    # Latest TimeStamp
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $time = "Generated on: $Timestamp"

    # Compute Onboarding Status
    $DependencyJsonPath = Join-Path $env:BUILD_SOURCESDIRECTORY "DependencyAppList.json"
    $OnboardingStatus = "N/A"
    if (Test-Path $DependencyJsonPath) {
        $DependencyData = Get-Content -Raw $DependencyJsonPath | ConvertFrom-Json
        $FailedCount = ($DependencyData | Where-Object { $_.Status -ne "success" }).Count
        if ($FailedCount -eq 0) {
            $OnboardingStatus = "Successful"
        } else {
            $OnboardingStatus = "Failed - Dependency Issues"
        }
    }

    # Read the HTML Template
    $HTMLTemplate = Get-Content -Path $TemplatePath -Raw

    # Inject Table Rows into Template
    $HTMLReport = $HTMLTemplate -replace "{{TABLE_ROWS}}", $TableRows`
                                -replace "{{GENERATED_TIME}}", $time`
                                -replace "{{BUILD_ID}}", $env:BUILD_ID`
                                -replace "{{ERROR_LOGS}}", $ErrorLog`
                                -replace "{{ONBOARDING_STATUS}}", $OnboardingStatus

    # Save the Final Report
    $HTMLReport | Out-File -Encoding utf8 -FilePath $ReportPath
    $TableRows  | Out-File -Encoding utf8 -FilePath $TableEmail
    $ErrorLog   | Out-File -Encoding utf8 -FilePath $ErrorTable

    # PDF Report Generation
    $TempUserDataDir = "$env:TEMP\edge_headless_profile"
    $EdgeErrorLog  = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "Error.log"

    $process = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    -ArgumentList "--headless --disable-gpu --disable-background-networking --disable-software-rasterizer --disable-features=Sync,Identity --disable-sync --disable-features=NetworkService,RendererCodeIntegrity --no-default-browser-check --no-first-run --user-data-dir=$TempUserDataDir --print-to-pdf=$ReportPath_PDF $ReportPath --disable-logging  "`
    -NoNewWindow -Wait `
    -RedirectStandardError $EdgeErrorLog `
    -ErrorAction SilentlyContinue

    if (Test-Path -Path $EdgeErrorLog) {

        # Read the content of the Error.log file
        $logContent = Get-Content -Path $EdgeErrorLog
        Remove-Item -Recurse -Force $TempUserDataDir -ErrorAction SilentlyContinue
        Remove-Item $EdgeErrorLog

        $messages = $logContent | Where-Object { $_ -match "bytes" }
        if ($messages.Count -gt 0) {
            $messages | ForEach-Object { Write-Output $_ }
        } 
        else {
            Write-Output "PS_ERROR_DESC= File was not Converted to PDF format"
            exit 1
        } 
    }

    #Remove .HTML and Warning Log FILE
    Remove-Item $ReportPath
    Write-Output "PDF Report generated successfully at $ReportPath_PDF"
    Write-Output " Counter: $Counter | Passed: $pass | Failed: $($failedApp.Count)"
    if ($Counter -eq $pass){
        Write-Output "All Applications were published on Intune."
    }
    else {
        Write-Output "Some Applications were not published. Please find the report in the email !!!"
        $UpdatedLeVmFile = $SmokeTestVMFileContent | Where-Object{$_.IntuneAppName -notin $($failedApps.IntuneAppName)}
        $UpdatedLeVmFile = [PSCustomObject]@{
            Apps = $UpdatedLeVmFile
        }
        $updatedJson = $UpdatedLeVmFile | ConvertTo-Json -Depth 10
        Out-File -InputObject $updatedJson -FilePath $SmokeTestVMFilePath -Force -ErrorAction "Stop" | ConvertTo-Json
    }
}

else{
    Write-Output "PS_ERROR_DESC= AppsDownloadList.json is not present on the give location: $AppsDownloadListFilePath"
    exit 1
}