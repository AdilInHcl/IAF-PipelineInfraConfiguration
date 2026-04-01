<#
.SYNOPSIS
    This script is responsible for removing the blocked apps App Download List.
 
.DESCRIPTION
     This script is responsible for removing the block apps App Download List. The Blocked Apps are present on Github

.NOTES
    FileName:    Download-AppConfigFile.ps1
    Author:      Daniyal Ahmad
    Contact:     
    Created:     
#>
try{
    # ===== Declare File Paths =====
    $DownloadFileName = "AppsDownloadList.json"
    $AppsDownloadsListPath =Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $DownloadFileName

    $repo = $env:GITHUB_ONBOARDING_REPO
    $owner = $env:GITHUB_OWNER_APPPACKAGING
    # The GitHub API URL
    $BlockedAppListApiUrl = "https://github.developer.allianz.io/api/v3/repos/$owner/$repo/contents/BlockedList.json?ref=$($env:GITHUB_ONBOARDING_REPO_BRANCH)"

    # Your personal access token (or other token) for authentication
    $token = $env:GIT_PAT_PSW

    # Setup headers for GitHub API
    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept"        = "application/vnd.github.v3.raw"  # to fetch raw file content
    }

    # Send GET request for to GITHUB for the Blocked version List JSON
    $blockedList = (Invoke-RestMethod -Uri $BlockedAppListApiUrl -Headers $headers -Method Get).Apps

    # Fetch the AppsDownloadsList.Json
    $AppDownloadList = Get-Content -Path $AppsDownloadsListPath -Raw | ConvertFrom-Json

    # Extract list of blocked names
    $blockedPairs = $blockedList | ForEach-Object {
        [PSCustomObject]@{
            IntuneAppName    = $_.IntuneAppName
            AppSetupVersion  = $_.AppSetupVersion
            IntuneAppNamingConvention = $_.IntuneAppNamingConvention
            AppPublisher = $_.AppPublisher

        }
    }

    #Detected Blocked Apps:
    $AppsDetected = $AppDownloadList | Where-Object {
        $app = $_
        ($blockedPairs | Where-Object {
            $_.IntuneAppName -eq $app.IntuneAppName -and (
                [string]::IsNullOrWhiteSpace($_.AppSetupVersion) -or
                $_.AppSetupVersion -eq $app.AppSetupVersion
            )
        })
    }

    #Apps Detected
    if ($null -ne $AppsDetected)
    {
        Write-Output "Below Blacklist Apps have been Detected!"
        $AppsDetected | Select-Object IntuneAppName, AppSetupVersion

        # Filter the apps that do NOT match any blocked pair
        $filteredApps = $AppDownloadList | Where-Object {
            $app = $_
            -not ($blockedPairs | Where-Object {
                $_.IntuneAppName -eq $app.IntuneAppName -and (
                    [string]::IsNullOrWhiteSpace($_.AppSetupVersion) -or
                    $_.AppSetupVersion -eq $app.AppSetupVersion
                )
            })
        }

        if ($null -eq $filteredApps){
            #Remove DownloadList incase all apps detected were blocked
            Remove-Item $AppsDownloadsListPath -Force 
            Write-Output "The Applications were blocked, aborting pipeline"
        }
        else{
            # Save the filtered Apps to the DownloadList
            $filteredApps | ConvertTo-Json -Depth 10 | Set-Content -Path $AppsDownloadsListPath -Encoding UTF8
        }
    }
    else {
        Write-Output "No Blacklist Apps have been Detected!"
    }
}
catch{
    Write-Output "PS_ERROR_DESC= $_"
    exit 1
}