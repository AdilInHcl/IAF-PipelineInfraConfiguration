<#
.SYNOPSIS
    This script sets the supersedence for the Apps deployed to Intune through IAF.
 
.DESCRIPTION
    This script will check for the latest deployed app on Intune in the current run of IAF and set the supersedence to it.

.Input Command : powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -Command "& { . '${env.BUILD_SOURCESDIRECTORY}\\Scripts\\Set-Supersedence.ps1' 
-TenantID '${ARM_TENANT_ID}' -ClientID '${ARM_CLIENT_ID}' 
-ClientSecret '${ADT_CLIENT_SECRET}' }"


.NOTES
    FileName:    Set-Supersedence.ps1
    Author:      Daniyal Ahmad
    Modified by: Daniyal Ahmad
    Date:        
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:CLIENT_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

#Fetch the App ID and Family ID from notes
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

try{
    #Create Acces Token
    $AuthToken = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

    # Retrieve all applications
    $Win32AppResources = Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"

    #Path of AppPrepareList.json
    $AppsPrepareListFileName = "AppsPrepareList.json"
    $AppsPrepareListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPrepareList") -ChildPath $AppsPrepareListFileName

    # Read and convert JSON
    $AppsPrepareList = Get-Content $AppsPrepareListFilePath -Raw | ConvertFrom-Json
}
catch{
    $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry
    Update-CatlogueStatus -AccessToken $token -Apps "All" -InputFilePath $AppsPrepareListFilePath  -Reason "IAF - Set App Supersedence Failed"
    Write-Output "PS_ERROR_DESC= $_"
    exit 1
}

#Create the app name based on the naming convention
$FailedApps = @()
foreach ($App in $AppsPrepareList) {

        switch ($App.IntuneAppNamingConvention) {
            "PublisherAppNameAppVersion" {
                $AppDisplayName = -join@($App.AppPublisher, " ", $App.IntuneAppName)
                $AppDeployedName = -join@($App.AppPublisher, " ", $App.IntuneAppName, " ", $App.AppSetupVersion)
            }
            "PublisherAppName" {
                $AppDisplayName = -join@($App.AppPublisher, " ", $App.IntuneAppName)
                $AppDeployedName = -join@($App.AppPublisher, " ", $App.IntuneAppName)
            }
            "AppNameAppVersion" {
                $AppDisplayName = $App.IntuneAppName
                $AppDeployedName = -join@($App.IntuneAppName, " ", $App.AppSetupVersion)
            }
            "AppName" {
                $AppDisplayName = $App.IntuneAppName
                $AppDeployedName = $App.IntuneAppName
            }
            default {
                $AppDisplayName = $App.IntuneAppName
                $AppDeployedName = $App.IntuneAppName
            }
        }
        
        #Check for Published status
        $appStatus = $Win32AppResources | Where-Object { $PSItem.displayName -like "$($AppDeployedName)" }
        Write-Host "[Onboarding Status : $AppDeployedName] --> $($appStatus.publishingState)"     
           
        #Fetch the second latest version on intune to be superseded
        if($appStatus.publishingState -eq "published") {

            $deployedappNotes = $appStatus.notes
            $deployedappDetails = Get-AppDetails -Notes $deployedappNotes

            #Check if Family Id and AppId is there for the app published
            if (($deployedappDetails.FamilyID -ne $null) -and ($deployedappDetails.AppID -ne $null)) {

                Write-Host "App Details for $($appStatus.displayName)"
                Write-Host "AppID: $($deployedappDetails.AppID)"
                Write-Host "FamilyID: $($deployedappDetails.FamilyID)"

                $AppDisplayName = "*$AppDisplayName*"
                $oldApps = $Win32AppResources | Where-Object { $PSItem.displayName -like "$($AppDisplayName)" }

                #List out the Apps with the same family ID
                $matchedFamilyApps = @()  # Initialize an empty array to save the apps with same Family ID
                foreach($detected_apps in $oldApps){
                    $oldappDetails = Get-AppDetails -Notes $detected_apps.notes
                    if ($oldappDetails.FamilyID -eq  $deployedappDetails.FamilyID){
                        $matchedFamilyApps += $detected_apps  # Add matching app to the array
                    }
                }

                #Fetch the last app version deployed to Intune before the current deployment
                $previousApps = $matchedFamilyApps | Where-Object {$_.displayVersion -ne $appStatus.displayVersion}

                #Check if there is no App to be Superseded
                if (@($previousApps).Count -gt 0) {

                    Write-Host "The older versions detected for $($App.IntuneAppName): $($previousApps.displayVersion -join '||')"
                    $AppId = $appStatus.id     # The app you're adding supersedence to

                    #Fetch the App ID and Family ID of the Superseded app
                    Write-Host  "Setting supersedence to App: $($appStatus.displayname)"

                    # Build clean OrderedDictionary objects
                    $SuperededappList = @()

                    foreach($appinfo in $previousApps){
                        $SupersededAppNotes = $appinfo.notes
                        $SupersededappDetails = Get-AppDetails -Notes $SupersededAppNotes

                        if ($deployedappDetails.FamilyID -eq $SupersededappDetails.FamilyID){
            
                            #ID of the version to be superseded
                            $SupersedeId = $appinfo.id

                            try{                
                                # Create new supersedence entry 
                                $entry = New-Object System.Collections.Specialized.OrderedDictionary
                                $entry["@odata.type"] = "#microsoft.graph.mobileAppSupersedence"
                                $entry["targetId"] = $SupersedeId
                                $entry["supersedenceType"] = "update"
                                $SuperededappList += $entry
                            }
                            catch{
                                Write-Warning "Error Setting Up Supersedence to $($appinfo.displayName) : $_"
                                $FailedApps += $App
                                break
                            }
                        }
                    }

                    #Set the supersedence for all apps:
                    if ($SuperededappList){
                        $response = Add-IntuneWin32AppSupersedence -ID $AppId -Supersedence $SuperededappList
                    }
                    else{
                        Write-Host "Failed to Set supersendence for $($App.IntuneAppName). "
                    }
                    
                }
                else {
                    Write-Host "Supersedence cannot be set for $AppDeployedName [No Previous Versions detected on Intune]"
                }
            }else{
                Write-Host "Supersedence cannot be set for $AppDeployedName [FamilyID/AppID cannot be detected]" 
                $FailedApps += $App
            }
        }else {
            Write-Host "Supersedence cannot be set for $AppDeployedName [App not published to intune]"
            $FailedApps += $App
        }
}

# Update the catlogue for the apps where supersedence failed
if ($FailedApps){
    $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry
    Update-CatlogueStatus -AccessToken $token -Apps $FailedApps -Reason "IAF - Set App Supersedence Failed"
}