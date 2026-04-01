<#
.SYNOPSIS
    This script is responsible for updating the appList based on OnDemand trigger.
 
.DESCRIPTION
    This script is responsible for updating the appList based on OnDemand trigger. It will replace the default content in appList with on demand appList.

.NOTES
    FileName:    Replace-AppList.ps1
    Author:      Daniyal Ahmad   
    Created:     11-Nov-2025
#>
#Input Parameters for repo and owner of the github
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    
    [ValidateNotNullOrEmpty()]
    [string]$github_owner = $env:GITHUB_OWNER_APPPACKAGING,
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$repo_name,
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NewAppListName
    
)

# ===== Declare File Paths =====
$DefaultAppListName = "AppList.json"
$DefaultAppListFilePath =Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath $DefaultAppListName

# The GitHub API URL of on demand applist
$OnDemandAppListApiUrl = "https://github.developer.allianz.io/api/v3/repos/$($github_owner)/$($repo_name)/contents/$($NewAppListName)?ref=$($env:GITHUB_ONBOARDING_REPO_BRANCH)"

# Your personal access token (or other token) for authentication
$token = $env:GIT_PAT_PSW

# Setup headers for GitHub API
$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github.v3.raw"  # to fetch raw file content
}

try{
    # Send GET request for to GITHUB for the new applist JSON
    $NewAppListContent = Invoke-RestMethod -Uri $OnDemandAppListApiUrl -Headers $headers -Method Get 

    # Validate the file content
    if ($NewAppListContent.Apps.Count -eq 0){
        Write-Host "JSON Object data empty or Incorrect. Aborting Pipeline!"
        exit 1
    }

    # Remove the defualt appList with ne appList.json
    $NewAppListContent | ConvertTo-Json -Depth 10 | Set-Content -Path $DefaultAppListFilePath -Encoding UTF8
}
catch{
    Write-Output "PS_ERROR_DESC= Please validate the file $NewAppListName on Github $($github_owner)/$($repo_name). $_"
    exit 1
}