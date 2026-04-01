#Input Parameters for repo and owner of the github
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$owner
)
#Upload the latest module to github repo release
function Upload-LatestRelease {
    param(
        [string]$repo,
        [string]$owner,
        [string]$tag,
        [string]$releaseName,
        [string]$version,
        [string]$zipFilePath
    )

    # Base GitHub release URL
    $baseApiUrl = "https://github.developer.allianz.io/api/v3"
    $githubToken = $env:GIT_PAT_PSW

    # Headers
    $headers = @{
        Authorization = "token $githubToken"
        Accept        = "application/vnd.github+json"
    }

    # Create the release (targeting dev branch)
    $releaseData = @{
        tag_name          = $tag
        name              = $releaseName
        body              = $version
        draft             = $false
        prerelease        = $true
    } | ConvertTo-Json

    $releaseResponse = Invoke-RestMethod -Uri "$baseApiUrl/repos/$owner/$repo/releases" `
                                         -Method Post `
                                         -Headers $headers `
                                         -Body $releaseData `
                                         -ContentType "application/json"

    # Extract upload URL
    $uploadUrl = $releaseResponse.upload_url -replace "{\?name,label}", ""

    # Upload the ZIP file
    $zipFileName = [System.IO.Path]::GetFileName($zipFilePath)
    $fileBytes = [System.IO.File]::ReadAllBytes($zipFilePath)

    $uploadResponse = Invoke-RestMethod -Uri "$($uploadUrl)?name=$zipFileName" `
                                        -Method Post `
                                        -Headers $headers `
                                        -Body $fileBytes `
                                        -ContentType "application/zip"

    Write-Host "Release created: $($releaseResponse.html_url)"
    Write-Host "Asset uploaded: $($uploadResponse.browser_download_url)"
}

#Fetch the latest module version from github repo release
function Find-LatestVersionRelease{
    param(
        [string]$Repo,
        [string]$Owner
    )

    #GitPAT
    $GitHubtoken = $env:GIT_PAT_PSW
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "token $GitHubtoken")
    
    try{                      
        $releasesUrl = "https://github.developer.allianz.io/api/v3/repos/$Owner/$Repo/releases"

        $allReleases = (Invoke-WebRequest -Uri $releasesUrl -Headers $headers -UseBasicParsing | ConvertFrom-Json).tag_name -split 'v'

        # Pick the latest dev release (GitHub returns releases sorted by creation date)
        $latestDevReleaseVersion = $allReleases | Sort-Object -Descending |Select-Object -First 1

        return $latestDevReleaseVersion
    }
    catch{
        Write-Host "$Unable to fetch the Version details from GitHub : $Owner/$Repo"
        Write-Host "Skipping $Repo"
        
    }
}

try{
    #Path to the module folder where latest version will be installed
    $temp_module_download_location = "C:\Manual_installed_modules"
    if(-not(Test-Path $temp_module_download_location)){New-Item -Path $temp_module_download_location -ItemType Directory >$null 2>&1}

    # Output file for Jenkins
    $outputFile = Join-Path -Path $env:WORKSPACE -ChildPath "module_updates.html"
    if (Test-Path $outputFile) { Remove-Item $outputFile -Force }

    #Modules
    $modules = @("Evergreen", "IntuneWin32App", "MSGraphRequest")

    #Hash table "module = Repo Name"
    $repos = @{
        Evergreen       = "IAF-EvergreenModule"
        IntuneWin32App  = "IAF-IntuneWin32AppModule"
        MSGraphRequest  = "IAF-MSGraphRequestModule"
    }

    #Set the variable for the table content
    $tablerows = ""
    $counter = 1
    
    Write-Host "##### [Module Update Intitated] #####"
    foreach($module in $modules){
        Write-Host " [$module] "

        #Find the Latest Version of the Module on Github with "*-dev" tag
        $GitHublatestRelease = Find-LatestVersionRelease -Repo $repos[$module] -Owner $owner
        Write-Host "GitHublatestRelease: $GitHublatestRelease"

        # Find and Install the latest modules
        $Latest_version_details = (Find-Module -Name $module).Version
        Write-Host "Latest Version: $Latest_version_details"

        if(($null -eq $Latest_version_details)-or($null -eq $GitHublatestRelease)){
            Write-Output "PS_ERROR_DESC= Version Info not available"
            exit 1
        }

        if($Latest_version_details -gt $GitHublatestRelease){
            
            #Install The Module
            Save-Module -Name $module -Path $temp_module_download_location

            #Define Locations of latest dwonloaded modules
            $Evergreen_Latest_module_location = Join-Path -Path $temp_module_download_location -childpath "$module\$($Latest_version_details)"
            $Latest_module_zip = Join-Path -Path $temp_module_download_location -childpath "$($Latest_version_details).zip"
            Compress-Archive -Path $Evergreen_Latest_module_location -DestinationPath $Latest_module_zip

            #Set the upload info
            $repo = $repos[$module]
            $tag = "v$($Latest_version_details)"   # Release tag
            $version = $Latest_version_details
            $releaseName = "$($module)-$($Latest_version_details)" # Release name

            try{
                Upload-LatestRelease -repo $repo -owner $owner -tag $tag -releaseName $releaseName -zipFilePath $Latest_module_zip -version $version
                $tablerows += "<tr><td>$counter</td><td>$module</td><td>$version</td></tr>"
                $counter += 1
                }
            catch{
                Write-Host "Failed to Upload $module on $owner/$repo. $_"
                Write-Host "Skipping $module"
            }
            Write-Host "========================================================================================"
        }
        else{
            Write-Host "The latest version: $Latest_version_details is already present on GITHUB repo $owner/$($repos[$module])"
            Write-Host "========================================================================================"
        }
    }

    #Clear the folders once upload version completed
    Remove-Item $temp_module_download_location -Recurse -Force

    # Write table rows to file for next stage
    if($tablerows -ne ""){
        $tablerows | Out-File $outputFile -Encoding utf8
        Write-Output "New versions available."    
    }

}
catch {
    Write-Output "PS_ERROR_DESC= $_"
    exit 1
}