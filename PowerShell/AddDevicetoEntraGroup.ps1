[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DeviceGroupName,
    [string]$DeviceName,
    [string]$clientSecret = $env:clientSecret,
    [string]$tenantId,
    [string]$clientId
)

Write-Host "CLientID = $clientId"
Write-Host "TenantID = $tenantId"
Write-Host "DeviceGroupName = $DeviceGroupName"
Write-Host "DeviceName = $DeviceName"


# Convert the client secret to a secure string
$secretKey = ConvertTo-SecureString $clientSecret -AsPlainText -Force

# Create a PSCredential object for authentication
$Credential = New-Object System.Management.Automation.PSCredential ($clientId, $secretKey)

# Connect to Microsoft Graph API using the provided credentials and tenant ID
Connect-MgGraph -TenantId $tenantId -Credential $Credential

Write-Host "Successfully logged in to the Azure Tenant" -ForegroundColor Green

# To get Device group Id
function Get-GroupId {
    param (
        [string]$GroupName
    )

    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"

    if ($group) {
        return $group.Id
    }
    else {
        throw "Group named '$GroupName' not found."
    }
}

# To get Device Device Id
function Get-DeviceId {
    param (
        [string]$DeviceName
    )

    $device = Get-MgDevice -Filter "displayName eq '$DeviceName'"

    if ($device) {
        return $device.Id
    }
    else {
        throw "Device named '$DeviceName' not found."
    }
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
        Write-Error "Failed to add device [$DeviceId] to group [$GroupId]. Error: $_"
    }
}

$groupId = Get-GroupId -GroupName $DeviceGroupName
$deviceId = Get-DeviceId -DeviceName $DeviceName

Add-DeviceToGroup -DeviceId $deviceId -GroupId $groupId
