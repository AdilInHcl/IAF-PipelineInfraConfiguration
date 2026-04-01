<#
.SYNOPSIS
This script connects to the Qualys using API and removes the stale entries for the VMs mapped to the IP of the smoke test VMs earlier.

.DESCRIPTION
This script connects to the Qualys using API and removes the stale entries for the VMs mapped to the IP of the smoke test VMs earlier. We do this inorder to get false data.

.NOTES
    FileName:    Remove-StaleEntries.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username,
    [string]$password = $env:QUALYS_KEY,
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$resourceGroupName,
    [string]$ClientId,
    [string]$ClientSecret = $env:PROD_CLIENT_SECRET_LE
)

# IT RETURNS THE ASSET ID OF THE MACHINE FROM QUALYS API
function Fetch-StaleAssetIds {
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$AssetIP,

        [Parameter(Mandatory=$true)]
        [string]$vmName,

        [int]$MaxRetries = 5,
        [int]$RetryDelaySeconds = 3
    )

    # Basic auth encoding
    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
        "Authorization"     = "Basic $encodedCreds"
        "X-Requested-With"  = "powershell"
        "Content-Type"      = "text/xml"
    }

    $body = @"
<?xml version="1.0" encoding="UTF-8"?>
<ServiceRequest>
  <filters>
    <Criteria field="address" operator="EQUALS">$AssetIP</Criteria>
  </filters>
</ServiceRequest>
"@

    $url = "https://qualysapi.qg2.apps.qualys.eu/qps/rest/2.0/search/am/hostasset"

    $attempt = 0
    $response = $null

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++
            Write-Host "Fetching stale assets for $AssetIP (Attempt $attempt of $MaxRetries)..."

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body
            break  # success → exit retry loop
        }
        catch {
            Write-Host "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -ge $MaxRetries) {
                throw "Failed to fetch stale asset IDs after $MaxRetries attempts."
            }

            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    $assetIds = $response.ServiceResponse.data.HostAsset |
                Where-Object { $_.name -ne $vmName } |
                Select-Object id

    return @($assetIds)
}

#IT returns the IP address of the VMs
function Get-VMPrivateIP{
    param (
    [Parameter(Mandatory=$true)]
    [string]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$vmName
    )

    # Get NIC attached to the VM
    $nicId = (Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName).NetworkProfile.NetworkInterfaces[0].Id
    $nic   = Get-AzNetworkInterface -ResourceId $nicId

    # Fetch private IP
    $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
    return $privateIp


}

#IT deletes the stale entries for the IPs
function Remove-QualysAssets {
    param(
        [Parameter(Mandatory = $true)]
        [array] $AssetIds,

        [Parameter(Mandatory = $true)]
        [string] $username,

        [Parameter(Mandatory = $true)]
        [string] $password,

        [int] $MaxRetries = 3,
        [int] $RetryDelaySeconds = 3
    )

    # Basic auth encoding
    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
    $headers = @{
        "Authorization" = "Basic $encodedCreds"
        "Content-Type"  = "text/xml"
    }

    # Inline XML body
    $body = @"
<?xml version="1.0" encoding="UTF-8"?>
<ServiceRequest></ServiceRequest>
"@

    $assetsDeleted = [PSCustomObject]@{
        successcount  = 0
        failed = @()
    }

    foreach ($AssetId in $AssetIds.id) {

        $Url = "https://qualysapi.qg2.apps.qualys.eu/qps/rest/2.0/uninstall/am/asset/$AssetId"
        $success = $false
        $attempt = 0

        while (-not $success -and $attempt -lt $MaxRetries) {
            $attempt++

            try {
                $response = Invoke-RestMethod -Method POST -Uri $Url -Body $Body -Headers $headers -ErrorAction Stop

                if ($response.ServiceResponse.responseCode -eq "SUCCESS") {
                    $success = $true
                }
                else {
                    Write-Warning "Attempt $attempt : API returned failure for Asset ID $AssetId"
                }
            }
            catch {
                Write-Warning "Attempt $attempt failed for Asset ID $AssetId : $($_.Exception.Message)"
            }

            if (-not $success -and $attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }

        # After all retries:
        if ($success) {
            # SUCCESS → increment count
            $assetsDeleted.successcount++
        }
        else {
            # FAILURE → add to failed list
            $assetsDeleted.failed += $AssetId
        }
    }

    return $assetsDeleted
}

try{
    # Convert client secret to a secure string and create credential object
    $SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential     = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)

    # Connect to Azure using Service Principal
    $connection = Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential
    $connection = Select-AzSubscription -SubscriptionId $SubscriptionId

    # Ensure the Input file exists
    $VMInfoFileName = $env:Input_File_name
    $jsonFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName

    # OutFilePath 
    $Device_Status_File_name = "QualysScanDeviceStatus.json"
    $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
    $ScanFolder = Join-Path -Path "C:\SCANS\Qualys" -childPath $IAF_BUILD_TAG
    $OutputJsonPath = Join-Path -Path $ScanFolder -ChildPath $Device_Status_File_name

    # Check if the JSON file exists
    if (Test-Path $jsonFilePath) {
    
        Write-Host "Reading apps from: $jsonFilePath"

        # Load JSON data
        $InputJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json

        # Normalize: always wrap into .Apps
        if ($null -eq $InputJson.Apps) {
            # Legacy single app JSON → wrap it
            $finalObject = [PSCustomObject]@{
                Apps = @($InputJson)
            }
        }
        else {
            # Already has Apps → just keep as is
            $finalObject = $InputJson
        }
    }
    else {
        Write-Host "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }

    # Fetch the device names
    $deviceObjbase = foreach ($entry in $finalObject.Apps) {
        [PSCustomObject]@{
            DeviceName = $entry.DeviceName
            IntuneAppName = $entry.IntuneAppName
            IPaddress = ""
            InstallationCheck = $entry.InstallationCheck
        }
    }
    
    $deviceObj = $deviceObjbase | Where-Object {$_.InstallationCheck -ne 'Failed'}

    #Fetch the IP address for the VMs created and remove the stale entries on Qualys
    foreach ($vm in $deviceObj){
    
        $vmName =  $vm.DeviceName

        #Fetch IP address
        $IP = Get-VMPrivateIP -resourceGroup $resourceGroupName -vmName $vmName 
        $vm.IPaddress = $IP

        #Fetch the Stale Asset IDs from Qualys
        $StaleAssetIds = Fetch-StaleAssetIds -username $username -password $password -AssetIP $IP -vmName $vmName
        $StaleIdsCount = @($StaleAssetIds).Count
        Write-Host "Device details: $vmName --> $IP --> stale entries: $($StaleIdsCount)"

        if ($StaleIdsCount -ne 0){
            $assetsdeleted = Remove-QualysAssets -AssetIds $StaleAssetIds -username $username -password $password
            $assetsdeletedCount = $assetsdeleted.successcount
            if($assetsdeletedCount -eq $StaleIdsCount){
                Write-Host "All Stale Entries deleted for $IP"
            }
            else{
                Write-Host "Retrying to delete the stale asset. $($assetsdeleted.failed)"
                #Retry again to delete.
                $StaleAssetIds = Fetch-StaleAssetIds -username $username -password $password -AssetIP $IP -vmName $vmName
                $assetsdeleted = Remove-QualysAssets -AssetIds $StaleAssetIds -username $username -password $password
                if($($assetsdeleted.successcount) -ne @($StaleAssetIds).Count){Write-Output "PS_ERROR_DESC= Failed to delete stale asset IDs after retries for $IP on Qualys";exit 1}
            }
        }
    }
    # Wrap in top-level structure
    $finalObject = [PSCustomObject]@{
        Apps = $deviceObj
    }

    # Save the results
    if(-not(Test-Path $ScanFolder)){New-Item -Path $ScanFolder -ItemType Directory | Out-Null}
    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputJsonPath -Encoding UTF8
}
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}