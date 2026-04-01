<#
.SYNOPSIS
    This script updates the  assignment for the published application based on the Smoke Test groups available.

.DESCRIPTION
    This script updates the  assignment for the published application based on the Smoke Test groups available.

.EXAMPLE
    .\Validate-SmokeTestGroups.ps1

.NOTES
    FileName:    Validate-SmokeTestGroups.ps1
    Author:      Daniyal Ahmad
    Created:     2025-07-31

    Version history:
    1.0.0 - (2025-07-31) Script created
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


# To get Device group Id
function Get-GroupName {
    param (
        [string]$GroupId
    )
    $group = Get-MgGroup -GroupId $GroupId
    if ($group) { return $group.DisplayName }
    else { throw "Group named '$GroupName' not found." }
}

#Create Access Token For member details(MSGraphOperation)
$AuthToken = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

#Setup Connection with MSintune(MGGraph)
$secretKey = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($ClientID, $secretKey)

# Connect to MSIntune
$msgraph_connection = Connect-MgGraph -TenantId $TenantID -Credential $Credential

# Construct path for AppsPublishList.json file created in previous stage
$AppsPublishListFileName = "AppsPublishList.json"
$AppsPublishListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishList") -ChildPath $AppsPublishListFileName
$AppsPublishList = Get-Content -Path $AppsPublishListFilePath | ConvertFrom-Json 

#Fetch the smoke test group details from App.Json for each App to be published
Write-Host "Fetching the Smoke Test Device Groups from App.json ...."

try{
    #Set the assignment group ID to the App.json for each App
    foreach ($App in $AppsPublishList){
        Write-Host "[Fetching Group details for : $($App.IntuneAppName)]"
        $AppPublishPath = $App.AppPublishFolderPath
        $AppsAssignFilePath = Join-Path -Path $AppPublishPath -ChildPath "App.json"
        $AppJson = Get-Content -Path $AppsAssignFilePath | ConvertFrom-Json

        #Fetch the Test group ID and Name
        #$SMOKE_TEST_GROUP_ID = ($AppJson.Assignment | Where-Object { $_.Test -eq "Smoke"}).GroupID
        $SMOKE_TEST_GROUP_ID = ($AppJson.Assignment | Where-Object { $_.Groupdescription -eq "Test Groups for IAF LE Smoke testing"}).GroupID
        
        #Fetch group Directly from Intune
        $SMOKE_TEST_GROUP_NAME = Get-GroupName -GroupId $SMOKE_TEST_GROUP_ID
        
        #Check for group on Intune
        if($null -ne $SMOKE_TEST_GROUP_NAME){
            Write-Host "$SMOKE_TEST_GROUP_NAME Group found.. "
        }
        else{
            Write-Host "No Smoke Test Group available for $($App.IntuneAppName) on Intune"
            exit 1
        }

        #Check for group in App.json
        if ($null -eq $SMOKE_TEST_GROUP_ID){
            Write-Host "No Smoke Test Group was found in App.Json for $($App.IntuneAppName)"
            exit 1
        }

        #Updating the AssignList with Device Group Name
        $App | Add-Member -MemberType NoteProperty -Name "DeviceGroupName" -Value $SMOKE_TEST_GROUP_NAME
        $App | Add-Member -MemberType NoteProperty -Name "DeviceGroupID" -Value $SMOKE_TEST_GROUP_ID

        # Convert back to JSON with formatting and save it
        Write-Host "Updating the Assignment details in  $AppsAssignFilePath"
        $AppJson | ConvertTo-Json -Depth 10 | Set-Content $AppsAssignFilePath

        Write-Host "[Smoke Test Group validation completed for $($App.IntuneAppName)]"
    }
    # Save the updated JSON back to the file
    Write-Host "Updated the AppPublishList.json with the Smoke test groups for each app!"
    $AppsPublishList | ConvertTo-Json -Depth 10 | Set-Content $AppsPublishListFilePath    
}
catch{
    Write-Host "Aborting Pipeline. Error: $_"
    exit 1
}