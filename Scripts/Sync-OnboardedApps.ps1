<#
.SYNOPSIS
    This script is responsible for copying App onboarded files from GitHub Repository to the Evergreen Latest version and Jenkins work folder.
 
.DESCRIPTION
     This script is responsible for copying App onboarded files from GitHub Repository to the Evergreen Latest version and Jenkins work folder.

.NOTES
    FileName:    Sync-OnboardedApps.ps1
    Author:      Daniyal Ahmad/ Adil Ansari
    Contact:     
    Created:     
#>

#Input Parameters for repo and owner of the github
[CmdletBinding(SupportsShouldProcess = $true)]
param (

    [ValidateNotNullOrEmpty()]
    [string]$github_owner = $env:GITHUB_OWNER_APPPACKAGING,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$repository,
 
    [ValidateNotNullOrEmpty()]
    [string]$githubtoken = $env:GIT_PAT_PSW
)

#Set Up Variables
$Headers = @{"Authorization" = "Bearer $githubtoken"}
$Root_Path =  $env:BUILD_SOURCESDIRECTORY
$local_path = "$Root_Path\Apps_temp"
$appList_path = "$Root_Path\appList.json"

# Ensure local folder exists
if (-not (Test-Path $local_path)) {
    New-Item -ItemType Directory -Path $local_path | Out-Null
}

# -------------------------------
# Download Apps and applist.json 
# -------------------------------
Write-Output "Syncing the Apps Data and applist.json from: $github_owner/$repository"
try {
    
    git clone --branch $env:GITHUB_ONBOARDING_REPO_BRANCH --single-branch "https://$($githubtoken):x-oauth-basic@github.developer.allianz.io/$github_owner/$repository.git" $local_path 2>$null

    $AppsunzippedFolder = Join-path -Path $local_path -ChildPath "Apps"
    $ApplistjsonPath = Join-path -Path $local_path -ChildPath "appList.json"

    Copy-Item -Path $ApplistjsonPath -Destination $env:BUILD_SOURCESDIRECTORY -Recurse -Force #Move the applist.json
    Copy-Item -Path $AppsunzippedFolder -Destination $env:BUILD_SOURCESDIRECTORY -Recurse -Force #Move the Apps folder to build source directory

    Remove-Item -Path $local_path -Recurse -Force
    }
catch{
    Write-Output "PS_ERROR_DESC= $_"
    exit 1
    }