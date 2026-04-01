<#
.SYNOPSIS
This script connects to Microsoft Graph using a service principal and removes devices from groups based on JSON input.

.DESCRIPTION
This script uses a service principal to connect to Microsoft Graph and manages device-to-group removals based on JSON input.

.EXAMPLE
    .\Remove-DevicesFromGroups.ps1 -tenantId "xxxx-xxxx-xxxx" -clientId "xxxx-xxxx-xxxx" -clientSecret "yourSecret"

.NOTES
    FileName:    Remove-DevicesFromGroups.ps1
    Author:      Mo Adil Ansari
    Created:     2025-08-09

    Version history:
    1.0.0 - (2025-08-05) Initial script for removing devices from groups
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientSecret
)

# Convert the client secret to a secure string
$secretKey = ConvertTo-SecureString $clientSecret -AsPlainText -Force

# Create a PSCredential object for authentication
$Credential = New-Object System.Management.Automation.PSCredential ($clientId, $secretKey)

# Connect to Microsoft Graph API using the provided credentials and tenant ID
Connect-MgGraph -TenantId $tenantId -Credential $Credential

# JSON file path
$jsonFilePath = "C:\LEVMCreationData\LEVMCreationData.json"

# Check if the JSON file exists
if (Test-Path $jsonFilePath) {
    # Read and convert JSON content into a PowerShell object
    $data = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json

    # Initialize a list to store DeviceGroupName and DeviceName from JSON
    $deviceInfoList = @()

    foreach ($app in $data.Apps) {
        $deviceInfo = [PSCustomObject]@{
            DeviceGroupName = $app.DeviceGroupName
            DeviceName      = $app.DeviceName
        }
        $deviceInfoList += $deviceInfo
    }
}
else {
    Throw "JSON file at path '$jsonFilePath' does not exist."
}

# Get group ID by display name
function Get-GroupId {
    param (
        [string]$GroupName
    )
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"
    if ($group) { return $group.Id }
    else { throw "Group named '$GroupName' not found." }
}

# Get device ID by display name
function Get-DeviceId {
    param (
        [string]$DeviceName
    )
    $device = Get-MgDevice -Filter "displayName eq '$DeviceName'"
    if ($device) { return $device.Id }
    else { throw "Device named '$DeviceName' not found." }
}

# Remove a device from a group
function Remove-DeviceFromGroup {
    param (
        [string]$DeviceId,
        [string]$GroupId
    )

    try {
        # Get group members to find the correct object to remove
        $members = Get-MgGroupMember -GroupId $GroupId -All
        $member = $members | Where-Object { $_.Id -eq $DeviceId }

        if ($member) {
            Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $DeviceId -ErrorAction Stop
            Write-Host "Successfully removed device [$DeviceId] from group [$GroupId]."
        }
        else {
            Write-Warning "Device [$DeviceId] is not a member of group [$GroupId]. Skipping..."
        }
    }
    catch {
        Write-Error "Failed to remove device [$DeviceId] from group [$GroupId]. Error: $_"
    }
}

# Process each VM and Device Group from the list
foreach ($entry in $deviceInfoList) {
    try {
        $groupId = Get-GroupId -GroupName $entry.DeviceGroupName
        $deviceId = Get-DeviceId -DeviceName $entry.DeviceName
        Remove-DeviceFromGroup -DeviceId $deviceId -GroupId $groupId
    }
    catch {
        Write-Warning "Failed to remove device '$($entry.DeviceName)' from group '$($entry.DeviceGroupName)': $_"
    }
}