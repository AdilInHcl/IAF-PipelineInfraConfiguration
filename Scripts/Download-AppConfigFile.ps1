<#
.SYNOPSIS
    This script is responsible for downloading the COnfig files to Installer Folders.
 
.DESCRIPTION
     This script is responsible for downloading the COnfig files to Installer Folders. The additional config files are placed on github

.NOTES
    FileName:    Download-AppConfigFile.ps1
    Author:      Daniyal Ahmad
    Contact:     
    Created:     
#>

#Input Parameters for repo and owner of the github
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateNotNullOrEmpty()]
    [string]$github_owner = $env:GITHUB_OWNER_APPPACKAGING
)
#--------------------------------
#Download App-AppConfigData
#--------------------------------
function Download-AppConfigData{
    param(
        [string]$Repo,
        [string]$OutFilePath,
        [string]$Owner
    )

    #GitPAT
    $GitHubtoken = $env:GIT_PAT_PSW
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "token $GitHubtoken")
    
    try{                      
        # Invoke-WebRequest parameters to fetch the latest release ID
        Write-Verbose -Message "Determining latest release ID"
        $releases = "https://github.developer.allianz.io/api/v3/repos/$Owner/$Repo/releases/latest"
        $id = ((Invoke-WebRequest $releases -Headers $headers -UseBasicParsing | ConvertFrom-Json)[0].assets | where { $_.name -like "*.zip" })[0].id		
    
                     
        #Create a download URL
        $download = "https://" + $GitHubtoken + ":@github.developer.allianz.io/api/v3/repos/$Owner/$Repo/releases/assets/$id"
        Write-Verbose -Message "Download URL of latest release with ID : https://github.developer.allianz.io/api/v3/repos/$repo/releases/assets/$id"
        $URI = $download
        $headers.Add("Accept", "application/octet-stream")

        #Create Dwonload ZIP folder Path
        $DownloadConfigpath = Join-Path -Path $OutFilePath -ChildPath "config.zip"

        #Download Config Content
        Invoke-WebRequest -Uri $URI -OutFile $DownloadConfigpath -Headers $headers -UseBasicParsing -UserAgent "wget" -ErrorAction "Stop"
    
        # --- Unzip the downloaded file ---
        Write-Host "Extracting ZIP..."
        $TempExtract = Join-Path -Path $OutFilePath -ChildPath "TMP_Extract_$(Get-Random)"
        New-Item -ItemType Directory -Path $TempExtract | Out-Null
        Expand-Archive -Path $DownloadConfigpath -DestinationPath $TempExtract -Force

        #Copy Files to the ouput file path of the Apps
        Write-Host "Copying files"
        Copy-Item -Path "$TempExtract\*" -Destination $OutFilePath -Recurse -Force
    
        #Remove the zip folder and extracted folder
        Remove-Item $DownloadConfigpath -Force
        Remove-Item $TempExtract -Recurse -Force 
    }
    catch{
        Write-Host "Error: $_"
        Write-Host "Please validate the latest release for $Repo : $releases"
        Write-Host "Skipping $Repo"
    }
}

# ===== Declare File Paths =====
$DownloadFileName = "AppsDownloadList.json"
$AppsDownloadsListPath =Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $DownloadFileName
$AppDownloadList = Get-Content -Path $AppsDownloadsListPath -Raw | ConvertFrom-Json

# Verify Applist.json exists
$ApplistPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "appList.json"
if (-not (Test-Path $ApplistPath)) {
    Write-Error "Applist.json not found at path: $ApplistPath"
    exit 1
}

#Fetch the ApplList Content
$AppListJson = Get-Content -Path $ApplistPath -Raw | ConvertFrom-Json


#Search for the App downloaded in the appList
$AppList = $AppListJson.Apps | Where-Object {
    $app = $_
    $AppDownloadList.IntuneAppName -contains $app.IntuneAppName
}

#Loop through each app in applist
foreach ($app in $AppList) {
    $AppName = $app.IntuneAppName
    $AppFolder = $app.AppFolderName
    $AppConfigFiles = $app.AppConfigFiles
 
    # Skip missing or invalid AppConfigFiles values silently
    if ($AppConfigFiles -ne 'Yes') { continue }
 
    Write-Host "====================================================="
    Write-Host "App Name   : $AppName"
    Write-Host "App Folder : $AppFolder"

    # Only for AppConfigFiles = Yes → Build full app.json path
    $AppJsonPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps\$AppFolder\App.json"
 
    # Skip missing app.json silently
    if (-not (Test-Path $AppJsonPath)) { continue }
 
    # Parse app.json safely
    try {
        $AppJson = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json
    } catch {
        continue
    }
 
    # Skip if no Notes section
    $Notes = $AppJson.Information.Notes
    if (-not $Notes) { continue }
 
    # Find AppConfigGitHubRepoName line
    $RepoLine = $Notes | Where-Object { $_ -match '^AppConfigGitHubRepoName\s*:' }
    if (-not $RepoLine) { continue }
 
    # Extract RepoName
    $RepoName = ($RepoLine -split ":", 2)[1].Trim()
    $RepoName = $RepoName -replace '\s', ''
 
    # Validation: Show output and download only if valid RepoName exists
    if (-not [string]::IsNullOrWhiteSpace($RepoName) -and $RepoName -ne 'NA') {
        Write-Host "-----------------------------------------------------"
        Write-Host "AppConfigGitHubRepoName: $RepoName"
        Write-Host "App JSON Path          : $AppJsonPath"
        Write-Host ""
 
        # Call download function
        $OutPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Installers\$AppFolder"
        
        try {
            Download-AppConfigData -Repo $RepoName -OutFilePath $OutPath -Owner $github_owner
        }
        catch{
            Write-Host "Download Failed."
            
        }
    }
}
