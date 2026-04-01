<#
.SYNOPSIS
    This script is responsible for installing the required PowerShell modules for the pipeline to function.

.DESCRIPTION
    This script is responsible for installing the required PowerShell modules for the pipeline to function.

.EXAMPLE
    .\Install-Modules.ps1

.NOTES
    FileName:    Install-Modules.ps1
    Author:      Nickolaj Andersen
    Updated by:  Daniyal Ahmad
    Created:     2022-04-04
    Updated:     2026-01-30

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2024-03-04) Improved module installation logic
    1.0.2 - (2026-01-30) Added functionality to download module from github release
#>

#Download module from PSGallery
function DownloadFrom-PsGallery{
    param(
        [string]$Module
    )
    try {
        $ModuleItem = Get-InstalledModule -Name $Module -ErrorAction "SilentlyContinue" -Verbose:$false
        if ($ModuleItem -ne $null) {
            Write-Output -InputObject "$($Module) module detected, checking for latest version"
            $LatestModuleItemVersion = (Find-Module -Name $Module -ErrorAction "Stop" -Verbose:$false).Version
            if ($LatestModuleItemVersion -ne $null) {
                if ($LatestModuleItemVersion -gt $ModuleItem.Version) {
                    Write-Output -InputObject "Latest version of $($Module) module is not installed, attempting to install: $($LatestModuleItemVersion.ToString())"
                    $UpdateModuleInvocation = Update-Module -Name $Module -Force -ErrorAction "Stop" -Confirm:$false -Verbose:$false
                }
                else {
                    Write-Output -InputObject "Latest version of $($Module) is already installed: $($ModuleItem.Version.ToString())"
                }
            }
            else {
                Write-Output -InputObject "Could not determine if module update is required, skipping update for $($Module) module"
            }
        }
        else {
            Write-Output -InputObject "Attempting to install module: $($Module)"
            $InstallModuleInvocation = Install-Module -Name $Module -Force -AllowClobber -ErrorAction "Stop" -Confirm:$false -Verbose:$false
            Write-Output -InputObject "Module $($Module) installed successfully"
        }
    }
    catch [System.Exception] {
        Write-Warning -Message "An error occurred while attempting to install $($Module) module. Error message: $($_.Exception.Message)"
    }
}

#Download module from GITHUB Releases
function DownloadFrom-GITHUB{
    param(
        [string]$Module,
        [string]$Repository
    )
    
    $BasemodulePath = "C:\Program Files\WindowsPowerShell\Modules"
    $modulePath = Join-path -Path $BasemodulePath -ChildPath $Module
    $GitHubtoken = $env:GIT_PAT_PSW
    #===========================================
    #Fetch the Latest Version Available on Agent
    #===========================================
    if (Test-Path $modulePath) {
        # Get all directories (folders) inside Evergreen
        $folders = Get-ChildItem -Path $modulePath -Directory | Select-Object -ExpandProperty Name

        if ($folders) {
            # Sort folders by version (splitting major.minor numbers and converting to integers)
            $latestVersion = $folders | Sort-Object {
                # Split version parts and convert to numbers
                ($_ -split '\.') | ForEach-Object { [int]$_ }
            } -Descending | Select-Object -First 1

        } else {
            Write-Output "No valid version folders found in '$modulePath'."
        }
    }
    else {
        Write-Host "Error: The folder path '$modulePath' does not exist."
        return "Failed"
    }

    #===========================================
    #Fetch the Latest Version Available on GITHUB
    #===========================================
    try{ 
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "token $GitHubtoken")
        $Owner = $env:GITHUB_OWNER_APPFACTORY                 

        # Invoke-WebRequest parameters to fetch the latest release ID
        $releases = "https://github.developer.allianz.io/api/v3/repos/$Owner/$Repository/releases/latest"
        $releaseinfo = (Invoke-WebRequest $releases -Headers $headers -UseBasicParsing| ConvertFrom-Json).assets

        #Fetch the version name
        $version = [System.IO.Path]::GetFileNameWithoutExtension($releaseinfo.name)

        #Create a download URL
        $url = $releaseinfo.url -split "//"
        $download_url = "$($url[0])//"+$GitHubtoken+":@$($url[1])"

        #Create the latest relaease info
        $latestRelease = [PSCustomObject]@{
            version = $version
            download_url  = $download_url
        }
    }
    catch{
        Write-Host "Error: $_"
        Write-Host "Please validate the latest release for $Repo : $releases"
        Write-Host "Download Failed !! "
        return "Failed"
    }

    #=================================================================
    #Download the Latest Version Available from GITHUB if available
    #=================================================================
    try{
        #Skip Dwonload if the version is already there
        if(-not($latestRelease.version -gt $latestVersion)){Write-Output "Latest version of $Module is already installed: $latestVersion"; return}

        #GitPAT
        $headers.Add("Accept", "application/octet-stream")

        #Create Dwonload ZIP folder Path
        $DownloadConfigpath = Join-Path -Path $modulePath -ChildPath "$($Module).zip"

        #Download Config Content
        Invoke-WebRequest -Uri $download_url -OutFile $DownloadConfigpath -Headers $headers -UseBasicParsing -UserAgent "wget" -ErrorAction "Stop"
    
        # --- Unzip the downloaded file ---
        Expand-Archive -Path $DownloadConfigpath -DestinationPath $modulePath -Force
   
        #Remove the zip folder and extracted folder
        Remove-Item $DownloadConfigpath -Force

    }
    catch{
        Write-Host "Error: $_"
        Write-Host "Please validate the latest release for $Repo : $releases"
        Write-Host "Skipping Download"
        return "Failed"
    }
}


# Ensure package provider is installed
$PackageProvider = Install-PackageProvider -Name "NuGet" -Force

$Modules = @{
    'Az.Storage'       = "PSGallery"
    'Az.Resources'     = "PSGallery"
    Evergreen       = "GITHUB"
    IntuneWin32App = "GITHUB"
    MSGraphRequest = "GITHUB"
}

#Hash table for GITHUB repos < module = Repo Name >
$Repos = @{
    Evergreen       = "IAF-EvergreenModule"
    IntuneWin32App  = "IAF-IntuneWin32AppModule"
    MSGraphRequest  = "IAF-MSGraphRequestModule"
}

foreach ($module in $Modules.Keys) {
    $source = $Modules[$module]
    Write-Output -InputObject "Attempting to locate $module on $($source)"

    if ($source -eq "GITHUB") {
        DownloadFrom-GITHUB -Module $module -Repository $Repos[$module]
    }
    elseif ($source -eq "PSGallery") {
        DownloadFrom-PsGallery -Module $module
    }
}