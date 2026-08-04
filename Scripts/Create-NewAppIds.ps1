<#
.SYNOPSIS
    Creates or resolves AppIDs in the Allianz App Catalogue.

.DESCRIPTION
    Reads AppsPrepareList.json, extracts FamilyID and version details from each app’s App.json,
    checks whether the version already exists in the Catalogue, and creates a new AppID if needed.
    Outputs a consolidated AppId.json file for downstream pipeline use.

.PARAMETER username
    Username for App Catalogue authentication.

.PARAMETER password
    Password for App Catalogue authentication.

.NOTES
    FileName:    Create-NewAppIds.ps1
    Author:      Mo Adil Ansari
    Created:     09 Jan 2026
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

# Returns Family ID 
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

#Returns All the Apps for a specific Family ID
function Get-FamilyAppsInfo{
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$FamilyID,
        [Parameter(Mandatory = $false)]
        [string]$Fields
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"        
    }

    #Set the URI as per the input fields
    if($null -eq $Fields){
        $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/family/$($FamilyID)"
    }else{
        $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/family/$($FamilyID)?fields=$($Fields)"
    }
    try{
        $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
        return $response
    }catch{
        Write-Host "Failed to Fetch the Apps for FamilyID: $FamilyID . $_"
        return "Failed"
    }
}

#Creates and returns the AppID after creation
function Create-NewAppID {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$FamilyID
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $body = @{
        Application_Name = $AppName
        Application_Version = $Version
        Family_ID = $FamilyID
    } | ConvertTo-Json

    #URL to create a new App ID.
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/create"

    try{
        $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body 
        return $response
    }
    catch{
        Write-Host "Failed to created App ID for $AppName . $_"
        Write-Host "Skipping App: $AppName"
        return "Failed"
    }
}

# Declare Paths
$AppsDownloadListJsonPath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppsDownloadList.Json"

try{
    # Check if the JSON file exists
    if (Test-Path $AppsDownloadListJsonPath) {
        Write-Host "Reading apps from: $AppsDownloadListJsonPath"

        # Load JSON data
        $AppsDownloadListContent = Get-Content -Raw -Path $AppsDownloadListJsonPath | ConvertFrom-Json
        
        # Initialize a list to store IntuneAppName and App I'd
        $AppIdJson = @()

        foreach ($app in $AppsDownloadListContent) {
            $AppInfo = [PSCustomObject]@{
                IntuneAppName = $app.IntuneAppName
                AppId      = $null
            }
            $AppIdJson += $AppInfo
        }

    }
    else {
        Write-Host "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }

    # Genrate Access Token for the Catalogue Access
    $token = Get-CatalogueAccessToken -username $username -password $password
    
    foreach($App in $AppIdJson){
        
        Write-Host "[Catlogue Entry $($App.IntuneAppName) : Initiated]"
        $latestVersion = $AppsDownloadListContent |where-object {$_.IntuneAppName -eq $App.IntuneAppName} |select-object AppSetupVersion
        $FolderName = $AppsDownloadListContent |where-object {$_.IntuneAppName -eq $App.IntuneAppName} |select-object AppFolderName

        # Declare file PAth for the App.json
        $AppJsonFolderPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps") -ChildPath $FolderName.AppFolderName
        $AppJsonFilePath = Join-Path -Path $AppJsonFolderPath -ChildPath "App.json"

        $AppJson = Get-Content -Path $AppJsonFilePath | ConvertFrom-Json
        $AppNotes = $AppJson.Information.Notes

        #Fetch the Family ID
        $AppDetails = Get-AppDetails -Notes $AppNotes

        #Validate if the Family ID is present in the App.Json
        if(-not ($AppDetails.FamilyID)){
            Write-Host "PS_ERROR_DESC= Family ID missing for $($App.IntuneAppName)"
            exit 1
        }

        #Fetch the AppID, Name and version of all apps in the particular family ID
        $FieldNames = "AppID,Application_Name,Application_Version"
        $AppsInfo = Get-FamilyAppsInfo  -AccessToken $token -FamilyID $AppDetails.FamilyID -Fields $FieldNames

        #Check FamilyID if not exists, skip
        if ($AppsInfo -eq "Failed"){
            Write-Host "Skipping App: $($App.IntuneAppName)"
            continue
        }

        #Validate if the App version is already present in the catalogue
        $check = $AppsInfo.applications|Where-Object{$_.Application_Version -eq $latestVersion.AppSetupVersion}

        #Check if there is a same verion of app in the catalogue
        if(@($check).Count -ne 0){
            Write-Host "App Version $($latestVersion.AppSetupVersion) already present for $($App.IntuneAppName). AppID : [$($check.AppID)]"
            $App.AppId = $check.AppID
            continue
        }

        # Create a new App ID for the latest version
        $newAppobj = Create-NewAppID  -AccessToken $token -AppName $App.IntuneAppName -Version $latestVersion.AppSetupVersion -FamilyID $AppDetails.FamilyID

        #Check if the App ID has been added to the Catalogue
        if($newAppobj.success -eq $true)
        {
            Write-Host "$($App.IntuneAppName) has been added to the Catalogue. App ID : [$($newAppobj.AppID)]"
            $App.AppId = $newAppobj.AppID
        }
    }

    # Wrap in top-level structure
    $AppIdJson = $AppIdJson | Where-Object {$_.AppId -ne $null}
    $finalOutputObject = [PSCustomObject]@{
        Apps = $AppIdJson
    }

    # Save the result
    $OutFileName = "AppId.json"
    $OutputFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $OutFileName

    Write-Host "AppId.json generated successfully."
    $finalOutputObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFilePath -Encoding UTF8

    Write-Host "Updating the AppDownloadList.json in b(binaries folders) for Apps in case Catalogue entry fails."  
    $validNames = $AppIdJson.IntuneAppName
    $AppsDownloadListContent = $AppsDownloadListContent | Where-Object {$validNames -contains $_.IntuneAppName}
    $AppsDownloadListContent | ConvertTo-Json -Depth 10 | Set-Content -Path $AppsDownloadListJsonPath -Encoding UTF8

    #Update the the same file to artifacts folders Downloads
    $AppsDownloadListArtifacts = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath "AppsDownloadList.Json"
    Copy-Item -Path $AppsDownloadListJsonPath -Destination $AppsDownloadListArtifacts -Recurse -Force

    }
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}