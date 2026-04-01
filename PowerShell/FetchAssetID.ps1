<#
.SYNOPSIS
This script connects to Qualys using API and fetches the asset ID of the Smoke test VMs

.DESCRIPTION
This script connects to Qualys using API and fetches the asset ID of the Smoke test VMs

.NOTES
    FileName:    FetchAssetID.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username,
    [string]$password = $env:QUALYS_KEY
)

# IT RETURNS THE ASSET ID OF THE MACHINE FROM QUALYS API
function Get-AssetDetails {
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$AssetIP,

        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
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

    # Retry loop
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {

        try {
            Write-Verbose "Attempt $attempt of $MaxRetries to query Qualys API"

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -TimeoutSec 60

            # If successful, extract and return asset ID
            $assetId = $response.ServiceResponse.data.HostAsset.id
            return $assetId
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -lt $MaxRetries) {
                Write-Verbose "Retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "All retry attempts failed. Unable to retrieve asset details."
            }
        }
    }
}

try{
    # Ensure the Input file exists
    $Device_Status_File_name = "QualysScanDeviceStatus.json"
    $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
    $ScanFolder = Join-Path -Path "C:\SCANS\Qualys" -childPath $IAF_BUILD_TAG
    $VMInfoFilePath = Join-Path -Path $ScanFolder -ChildPath $Device_Status_File_name

    # Check if the JSON file exists
    if (Test-Path $VMInfoFilePath) {
    
        Write-Host "Reading apps from: $VMInfoFilePath"

        # Load JSON data
        $InputJson = Get-Content -Raw -Path $VMInfoFilePath | ConvertFrom-Json

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
        Write-Output "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }

    # Fetch the device names
    $deviceObj = foreach ($entry in $finalObject.Apps) {
        [PSCustomObject]@{
            DeviceName = $entry.DeviceName
            IPaddress = $entry.IPaddress
            IntuneAppName = $entry.IntuneAppName
            AssetID = ""
            UIStatus = ""
            Status = ""
        }
    }

    #Wait params for Scan to complete
    $maxRetries =  3 #attempts
    $delayMinutes = 10 #minutes
    $RunningDevices = $deviceObj

    #Fetch the Status from each VM on Qualys Scan
    for ($retryCount = 0; $retryCount -le $maxRetries; $retryCount++) {
    
        foreach ($vm in $RunningDevices){
            $vmName =  $vm.DeviceName
            $AssetIP = $vm.IPaddress

            #Fetch the Scan Status
            $assetId = Get-AssetDetails -username $username -password $password -AssetIP $AssetIP

            if ($assetId) {
                Write-Host "Asset ID details: $vmName --> $assetId"
                $vm.UIStatus = "Updated"
                $vm.AssetID = $assetId
                $vm.Status = "UI Updated with the new $vmName Details"
            }
            else{
                Write-Host "Qualys UI is not updated for $vmName"
                $vm.UIStatus = "Not Updated"
                $vm.Status = "UI Not Updated."
            }
        }

    
        #Skip the Iteration  of the Completed Scan
        $RunningDevices = $deviceObj | Where-Object { $_.UIStatus -ne "Updated" }

        #Check if devices in running status and Initiate a sleep before retry
        if(@($RunningDevices).count -gt 0){
            Write-Host "Qualys UI is not updated for below VMs. Waiting $delayMinutes minutes before retrying... (Attempt $($retryCount+1))"
            Start-Sleep -Seconds ($delayMinutes * 60)
        }
        else{
            break
        }

    }

    #Display the Vms still not Updated
    if ($RunningDevices){
        Write-Host "Below VMs are still not Updated on the Qualys UI"
        $deviceObj | Where-Object { $_.UIStatus -ne "Updated" } | Select-Object DeviceName
    }

    #Abort VMs incase no VM was updated on Qualys side
    if (@($RunningDevices).Count -eq @($deviceObj).count){
        Write-output "No VMs were Updated on the Qualys UI. Stopping Pipeline"
        exit 1
    }

    # Wrap in top-level structure
    $finalObject = [PSCustomObject]@{
        Apps = $deviceObj
    }

    # Save the result
    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $VMInfoFilePath -Encoding UTF8
}
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}
