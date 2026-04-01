<#
.SYNOPSIS
    This script Fetch Data from AppList.json and AppsAssignList.json ans create LEVMCreationData.Json
 
.DESCRIPTION
    This script will create the Apps data for LE VM Creation Test.

.Input Command : powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -Command "& { . '${env.BUILD_SOURCESDIRECTORY}\\Scripts\\Prepare-LETestData.ps1'}"

.NOTES
    FileName:    Prepare-LEVMCreationData.ps1
    Author:      Daniyal Ahmad
    Modified by: Daniyal Ahmad
    Date:08 August 2025        
#>
# =========================
# Function: Merge-LEAppData
# =========================
function Merge-LEAppData {
    param (
        [string]$AppsJsonPath,
        [string]$PublishJsonPath,
        [string]$OutputJsonPath
    )

    try {
               
        # Read and parse JSON content
        Write-Host "Reading apps Paths path from: $AppsJsonPath"
        $appsContent = Get-Content -Raw -Path $AppsJsonPath | ConvertFrom-Json

        Write-Host "Reading Version data of Apps from: $PublishJsonPath"
        $publishContent = Get-Content -Raw -Path $PublishJsonPath | ConvertFrom-Json      

        # Map AppPath by App Name appList.json
        $AppPath = @{}
        $AppId = @{}
        $AppPublisher = @{}
        $AppSource = @{}
        foreach ($app in $appsContent.Apps) {
            $AppPath[$app.IntuneAppName] = $app.AppPath
            $AppPublisher[$app.IntuneAppName] = $app.AppPublisher
            $AppSource[$app.IntuneAppName] = $app.AppSource
            $AppId[$app.IntuneAppName] = Get-AppID -AppName $app.IntuneAppName
        }

        # Merge matched data
        $appsArray = @()
        foreach ($publish in $publishContent) {
            $appName = $publish.IntuneAppName
            
            #Fetch the App notes for Family ID and AppId
            $appJsonPath = Join-path -path $publish.AppPublishFolderPath -ChildPath "App.json"
            $appInfo = Get-Content -Raw -Path $appJsonPath | ConvertFrom-Json
            $appNotes = Get-AppDetails -Notes $appInfo.Information.Notes

            if ($AppPath.ContainsKey($appName)) {
               
                $appsArray += [PSCustomObject]@{
                    IntuneAppName   = $appName
                    AppID   = $AppId[$appName]
                    FamilyID = $appNotes.FamilyID
                    AppPublisher = $AppPublisher[$appName]
                    AppSetupVersion = $publish.AppSetupVersion
                    DeviceGroupName = $publish.DeviceGroupName
                    DeviceGroupId = $publish.DeviceGroupId
                    TUAccount   = $publish.TUAccountName
                    AppPath = $AppPath[$appName]
                    AppSource = $AppSource[$appName]
                }
            }
            else {
                Write-Warning "No ExePath found for app '$appName' in apps.json"
            }
        }

        # Wrap in top-level structure
        $finalObject = [PSCustomObject]@{
            Apps = $appsArray
        }

        # Ensure output directory exists
        if (-not (Test-Path -Path (Split-Path -Path $OutputJsonPath))) {
            $OutputFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "LEConfigData"
            Write-Host "Creating output folder: $OutputFolderPath"
            New-Item -ItemType Directory -Path $OutputFolderPath -Force | Out-Null
        }

        # Save the result
        $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputJsonPath -Encoding UTF8
        Write-Host "Final JSON saved to: $OutputJsonPath" -ForegroundColor Green
    }
    catch {
        Write-Error "PS_ERROR_DESC= Error during merge operation: $_"
        exit 1
    }
}
function Get-AppDetails {
    param (
        [string]$Notes
    )

    $result = [PSCustomObject]@{
        AppID    = $null
        FamilyID = $null
    }

    if ($Notes -match 'AppID:\s*(\S+)') {
        $result.AppID = $matches[1]
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
            Write-Host "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
            exit 1
        }
        $AppId = $AppInfoObject.Apps | Where-Object {$_.IntuneAppName -eq $AppName}| Select-Object AppId
        return $AppId.AppId
}

Write-Host "[Creating LE Test Data File]"
# ===== Declare File Paths =====
$AppsFileName = "appList.json"
$PublishFileName= "AppsPublishList.json"

$appsJsonPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath $AppsFileName
$PublishJsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishList") -ChildPath $PublishFileName

Write-Host "Searching for Required Files to merge in the LE Test Data Json!"

# Check if any required file is missing
if (-not (Test-Path -Path $appsJsonPath) -or -not (Test-Path -Path $PublishJsonPath)) {
    Write-Error "PS_ERROR_DESC= One or more required files are missing. Stopping pipeline."
    exit 1
}

Write-Host "All Files are present:"
Write-Host $appsJsonPath
Write-Host $PublishJsonPath

#Fetch Job name and build number
$Job_name = $env:JOB_NAME
$build = $env:BUILD_NUMBER

# Create file name with embedded variables
$OutputFileName = "LEVMCreationData_${Job_name}_${build}.json"
Write-Host "OutputFileName : '$OutputFileName'"

# Ensure the output folder exists
$basefolder = $env:BUILD_BINARIESDIRECTORY
if (-not (Test-Path $basefolder)) {
    New-Item -ItemType Directory -Path $basefolder -Force | Out-Null
}

#Outfile Path
$outputJsonPath = Join-Path -Path $basefolder -ChildPath $OutputFileName
Write-Host "Creating Out File Path: $outputJsonPath"

# Run the main function
Merge-LEAppData -AppsJsonPath $appsJsonPath -PublishJsonPath $PublishJsonPath -OutputJsonPath $outputJsonPath
