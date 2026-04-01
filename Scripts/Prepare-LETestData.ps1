<#
.SYNOPSIS
    This script Fetch Data from AppList.json and AppsAssignList.json ans create LEApps.Json
 
.DESCRIPTION
    This script will create the Apps data for LE Smoke Test.

.Input Command : powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -Command "& { . '${env.BUILD_SOURCESDIRECTORY}\\Scripts\\Prepare-LETestData.ps1'}"

.NOTES
    FileName:    LEPublishedList.ps1
    Author:      Mo Adil Ansari
    Modified by: Mo Adil Ansari
    Date:04 July 2025        
#>


# =========================
# Function: Merge-LEAppData
# =========================
function Create-LEAppData {
    param (
        [string]$InputJsonPath,
        [string]$OutputJsonPath
    )
    try {
        Write-Host "Reading apps from: $InputJsonPath"

        # Load JSON data
        $InputJson = Get-Content -Raw -Path $InputJsonPath | ConvertFrom-Json

        # Normalize: always wrap into .Apps
        if ($null -eq $InputJson.Apps) {
            # Legacy single app JSON → wrap it
            $finalObject = [PSCustomObject]@{
                Apps = @($InputJson)
            }
        }
        else {
            # Already has Apps → just keep as is
            $finalObject = $InputJson
        }

        # Add PackageName to each app
        foreach ($App in $finalObject.Apps) {
            $AppPackageName = "$($App.AppPublisher)_$($App.IntuneAppName)_PKG"
            Write-Host "Adding Deployed Package name for $($App.IntuneAppName): $AppPackageName"
            $App | Add-Member -MemberType NoteProperty -Name "PackageName" -Value $AppPackageName -Force
        }

        # Save final JSON output
        $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputJsonPath -Encoding UTF8
        Write-Host "Final JSON saved to: $OutputJsonPath" -ForegroundColor Green
    }
    catch {
        Write-Error "PS_ERROR_DESC= Error during merge operation: $_"
        exit 1
    }
}

#Fetch Job name and build number
$Job_name = $env:JOB_NAME
$build = $env:BUILD_NUMBER

$InputFileName = "LEVMCreationData_${Job_name}_${build}.json"
$basefolder_Input = $env:BUILD_BINARIESDIRECTORY
Write-Host "Reading InputFileName : '$InputFileName'"

# Ensure the output folder exists
$OutputFileName = "LEAppList_${Job_name}_${build}.json"
$basefolder_Output = "C:\LESmokeTestData"

#Validate Output Folder
if (-not (Test-Path $basefolder_Output)) {
    New-Item -ItemType Directory -Path $basefolder_Output -Force | Out-Null
}

# Build path
$inputJsonPath = Join-Path -Path $basefolder_Input -ChildPath $InputFileName
$outputJsonPath = Join-Path -Path $basefolder_Output -ChildPath $OutputFileName

# Call merge funation
Create-LEAppData -InputJsonPath $inputJsonPath -OutputJsonPath $outputJsonPath