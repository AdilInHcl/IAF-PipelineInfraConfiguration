<#
.SYNOPSIS
This script connects to Microsoft Graph using a service principal and assigns devices to groups based on JSON input.

.DESCRIPTION
This script uses a service principal to connect to Microsoft Graph and manages device-to-group assignments based on JSON input.

.EXAMPLE
    .\Assign-DevicesToGroups.ps1 -tenantId "xxxx-xxxx-xxxx" -clientId "xxxx-xxxx-xxxx" -clientSecret "yourSecret"

.NOTES
    FileName:    Assign-DevicesToGroups.ps1
    Author:      Mo Adil Ansari
    Created:     2025-08-04

    Version history:
    1.0.0 - (2025-08-04) Initial script creation
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientId,

    [ValidateNotNullOrEmpty()]
    [string]$clientSecret = $env:CLIENT_SECRET,

    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

# Genrate Token for the Catalogue Access
$token = Get-CatalogueAccessToken -username $username -password $password


# Convert the client secret to a secure string
$secretKey = ConvertTo-SecureString $clientSecret -AsPlainText -Force

# Create a PSCredential object for authentication
$Credential = New-Object System.Management.Automation.PSCredential ($clientId, $secretKey)

# Connect to Microsoft Graph API using the provided credentials and tenant ID
Connect-MgGraph -TenantId $tenantId -Credential $Credential

# To get Device group Id
function Get-GroupId {
    param (
        [string]$GroupName
    )
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"
    if ($group) { return $group.Id }
    else { throw "Group named '$GroupName' not found." }
}
# To get Device Device Id
function Get-DeviceId {
    param (
        [string]$DeviceName
    )
    $device = Get-MgDevice -Filter "displayName eq '$DeviceName'"
    if ($device) { return $device.Id }
    else { throw "Device named '$DeviceName' not found." }
}
# To associate VM in Device Group 
function Add-DeviceToGroup {
    param (
        [string]$DeviceId,
        [string]$GroupId
    )

    try {
        New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $DeviceId -ErrorAction Stop
        Write-Host "Successfully added device [$DeviceId] to group [$GroupId]."
    }
    catch {
        $err = $_.Exception.Message

        if ($err -like "*already exist*") {
            Write-Host "Device [$DeviceId] already added to group [$GroupId]."
        } else {
            Write-Error "Failed to add device [$DeviceId] to group [$GroupId]. Error: $err"
            return "Failed"
        }
    }

}

#Fetch the json file where all the information regarding VM is present
$LEVMCreationFileName = $env:Input_File_name
$LEVMCreationDataBasePath = $env:BUILD_BINARIESDIRECTORY
$LEVMCreationDataFilePath = Join-Path -Path $LEVMCreationDataBasePath -ChildPath $LEVMCreationFileName

# Check if the JSON file exists
if (Test-Path $LEVMCreationDataFilePath) {
    
    Write-Host "Reading apps from: $jsonFilePath"

    #Count How many VMs reguired
    $LEVMCreationData = Get-Content -Path $LEVMCreationDataFilePath| ConvertFrom-Json

    # Initialize a list to store DeviceGroupName and DeviceName from JSON
    $deviceInfoList = @()

    foreach ($app in $LEVMCreationData.Apps) {
        $deviceInfo = [PSCustomObject]@{
            IntuneAppName = $app.IntuneAppName
            DeviceGroupName = $app.DeviceGroupName
            DeviceName      = $app.DeviceName
        }
        $deviceInfoList += $deviceInfo
    }
}
else {
    Throw "JSON file at path '$jsonFilePath' does not exist."
    exit 1
}

# Process each VM and Device Group from the list and perform respective assignments
$FailedAssignedApps = @()
$SuccessAssignedApps = @()

foreach ($entry in $deviceInfoList) {
    try {
        $groupId = Get-GroupId -GroupName $entry.DeviceGroupName
        Write-Host "Group ID for $($entry.DeviceGroupName): $groupId"

        $deviceId = Get-DeviceId -DeviceName $entry.DeviceName
        Write-Host "Device ID for $($entry.DeviceName): $deviceId"

        Write-Host "Adding [$($entry.DeviceName)] to group [$($entry.DeviceGroupName)]"
        $response = Add-DeviceToGroup -DeviceId $deviceId -GroupId $groupId

        if ($response -eq 'Failed')
        {
            $FailedAssignedApps += $entry
            continue
        }
        
        $SuccessAssignedApps += $entry
    }
    catch {
        Write-Warning "Failed to add device '$($entry.DeviceName)' to group '$($entry.DeviceGroupName)': $_"
        $FailedAssignedApps += $entry
    }
}

# Save the updated JSON back to the file
$finalObject = $LEVMCreationData.Apps | Where-Object {$_.IntuneAppName -in $($SuccessAssignedApps.IntuneAppName)}
$finalObject = [PSCustomObject]@{
    Apps = $finalObject
}

#Fail the Pipeline If all Vms failed to be assigned
if (@($finalObject.Apps).Count -eq 0 ){
    Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - LE VM Creation failed" -InputFilePath $LEVMCreationDataFilePath
    Write-Output "All the devices Failed to assign to smoke test groups."
    exit 1
}

#Set the catalogue status for the apps where user  user assignation failed on VMs
if ($FailedAssignedApps.Count -ne 0 ){
    Write-Host "Updating Catalogue entry for the below Apps: "
    Write-Host $FailedAssignedApps.IntuneAppName
    Update-CatlogueStatus -AccessToken $token -Apps $FailedAssignedApps -Reason "IAF - LE VM Creation failed"
}

#Updated JSON for the group assignation
Write-Host "Updating the Device (VM) names in the $LEVMCreationDataFilePath"
$finalObject | ConvertTo-Json -Depth 10 | Set-Content $LEVMCreationDataFilePath

#Added a Wait time for the Vms to be visible on azure side.
Start-Sleep -Seconds 180