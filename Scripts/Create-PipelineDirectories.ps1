<#
.SYNOPSIS
    This script outputs references system and build variables used during the pipeline execution.

.DESCRIPTION
    This script outputs references system and build variables used during the pipeline execution.

.EXAMPLE
    .\Write-Variable.ps1

.NOTES
    FileName:    Create-PipelineDirectories.ps1
    Author:      Daniyal Ahmad
    Created:     2026-01-20


    Version history:
    1.0.0 - (2022-11-29) Script created
#>

# Output referenced variables
Write-Output "PIPELINE_WORKSPACE: $($env:PIPELINE_WORKSPACE)"
Write-Output "BUILD_BINARIESDIRECTORY: $($env:BUILD_BINARIESDIRECTORY)"
Write-Output "BUILD_ARTIFACTSTAGINGDIRECTORY: $($env:BUILD_ARTIFACTSTAGINGDIRECTORY)"
Write-Output "BUILD_SOURCESDIRECTORY: $($env:BUILD_SOURCESDIRECTORY)"
Write-Output "Creating Sub-Directories....."

# Top‑level directories
$BasePath = $env:PIPELINE_WORKSPACE
$directories = @('a', 'b')

foreach ($dir in $directories) {
    $path = Join-Path -Path $BasePath  -ChildPath $dir

    if (-not (Test-Path $path)) {
        Write-Output "Creating directory: $path"
        New-Item -Path $path -ItemType Directory | Out-Null
    } else {
        Write-Output "Directory already exists: $path"
    }
}

# Subdirectories inside 'a' Artifacts
$subDirectories = @('AppsProcessList', 'AppsDownloadList', 'AppsPublishedList')
$subBasePath = Join-Path -Path $BasePath -ChildPath 'a'

foreach ($sub in $subDirectories) {
    $subPath = Join-Path $subBasePath $sub

    if (-not (Test-Path $subPath)) {
        Write-Output "Creating directory: $subPath"
        New-Item -Path $subPath -ItemType Directory | Out-Null
    } else {
        Write-Output "Directory already exists: $subPath"
    }
}
