<#
.SYNOPSIS
    This script performs cleanup activities of files created by previous pipeline executions.

.DESCRIPTION
    This script performs cleanup activities of files created by previous pipeline executions.

.EXAMPLE
    .\Remove-Files.ps1

.NOTES
    FileName:    Remove-Files.ps1
    Author:      Nickolaj Andersen/Daniyal Ahmad
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2025-04-11

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2024-04-17) Updated with assignment file cleanup
    1.0.2 - (2025-04-10) Updated with assignment Cleanup Previous Builds to free disk
#>
Process {
    # Cleanup Previous Builds Folders to free up disk space
    $CurrentBuildId = $env:BUILD_ID
    $WorkspaceFolder = Split-Path -Path $env:PIPELINE_WORKSPACE -Parent
    $CutoffDate = (Get-Date).AddDays(-7)

    $BuildFoldersList = Get-ChildItem -Path $WorkspaceFolder -Directory
    foreach ($build in $BuildFoldersList) {
        # Skip current build folder
        if ($build.Name -eq $CurrentBuildId.ToString()) {
            continue
        }
        if ($build.LastWriteTime -lt $CutoffDate) {
            Write-Host "Removing build older than 2 days: $($build.FullName)"
            Remove-Item -Path $build.FullName -Recurse -Force
        }
    }
    # Intitialize variables
    $AppsListFileNames = @("AppsProcessList.json", "AppsDownloadList.json", "AppsPrepareList.json", "AppsPublishList.json", "AppsAssignList.json")
    $RootFolderNames = @("Installers", "Publish", "LatestFiles")

    # Cleanup previous app list files from workspace
    foreach ($AppsListFileName in $AppsListFileNames) {
        $AppsListFilePath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath $AppsListFileName
        if (Test-Path -Path $AppsListFilePath) {
            Write-Output -InputObject "Attempting to cleanup existing $($AppsListFileName) file found in pipeline workspace directory"
            Remove-Item -Path $AppsListFilePath -Force -Recurse -Confirm:$false
        }
    }

    # Cleanup previously downloaded installer files and publish folder
    foreach ($RootFolderName in $RootFolderNames) {
        $RootFolderNamePath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath $RootFolderName
        if (Test-Path -Path $RootFolderNamePath) {
            Write-Output -InputObject "Attempting to cleanup existing root folder directory: $($RootFolderName)"
            Remove-Item -Path $RootFolderNamePath -Recurse -Force -Confirm:$false
        }
    }
}