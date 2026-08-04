<#
.SYNOPSIS
This script connects to the Qualys using API and waits for the default scan to complete.

.DESCRIPTION
This script connects to the Qualys using API and waits for the default scan to complete.

.NOTES
    FileName:    WaitDefaultScan.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username,
    [string]$password = $env:QUALYS_KEY
)

#Import Module Restart-LEVM.ps1
Import-Module "$($env:WORKSPACE)/PowerShell/Restart-LEVM.psm1"

# IT RETURNS THE Last Scan Timestamp
function Get-LastScanTimestamp{
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
            Write-Verbose "Attempt $attempt of $MaxRetries to query LastScanTimestamp"

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -TimeoutSec 60

            return $response.ServiceResponse.data.HostAsset.lastVulnScan
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "All retry attempts failed. Unable to retrieve last scan timestamp."
            }
        }
    }
}

# IT RETURNS THE SCAN LAUNCHING STATUS AFTER THE QUALYS On Demand SCAN is TRIGGERED
function Launch-QualysODS{
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$AssetId

    )

    # Basic auth encoding
    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
    "Authorization"    = "Basic $encodedCreds"
    "Content-Type"     = "text/xml"
    "Cache-Control"    = "no-cache"
    }

    # Inline XML body (instead of SingleAgent_ODS.xml file)
    $body = @"
<?xml version="1.0" encoding="UTF-8"?>
<ServiceRequest></ServiceRequest>
"@

    # --- API URL ---
    $url = "https://qualysapi.qg2.apps.qualys.eu/qps/rest/1.0/ods/ca/agentasset/$($AssetId)?scan=Vulnerability_Scan&overrideConfigCpu=false"


    $headers = @{
        "Authorization" = "Basic $encodedCreds"
        "Content-Type"  = "text/xml"
    }

    # ------------------------------
    # Send POST Request
    # ------------------------------
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body

    # Output response
    if ($response.ServiceResponse.responseCode -eq "SUCCESS"){
        return "SUCCESS"
    }
    else{
        return "FAILURE, $response"
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

        # Initialize a list to store DeviceGroupName and DeviceName from JSON
        $deviceScanInfoList = @()

        foreach ($app in $finalObject.Apps) {
        $deviceInfo = [PSCustomObject]@{
            DeviceName = $app.DeviceName
            IPaddress = $app.IPaddress
            IntuneAppName = $app.IntuneAppName
            AssetID = $app.AssetID
            UIStatus = $app.UIStatus
            Status = $app.Status
            ScanTriggered = $app.ScanTriggered
            ScanIntiatedTime = ""
        }
        $deviceScanInfoList += $deviceInfo
       }
    }
    else {
        Write-Output "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }
    
    foreach ($vm in $deviceScanInfoList){
        $vmName =  $vm.DeviceName
        $AssetIP = $vm.IPaddress
        $assetID = $vm.AssetID

        if ($vm.ScanTriggered -eq "YES"){
            $ScanTriggerStatus = Launch-QualysODS -username $username -password $password -AssetId $assetID
            $scantime = Get-Date  #Fetch the TImestamp scan was triggered

            if($ScanTriggerStatus -eq "SUCCESS"){
                $utcTime  = [datetime]::Parse($scantime)
                $scancurrentTime = $utcTime.ToLocalTime()
                
                Write-Host "$ScanTriggerStatus : Qualys On Demand Scan Triggered [$scantime] for $vmName ( $assetID )"
                $vm.Status = "$ScanTriggerStatus : Qualys On Demand Scan Triggered [$scantime] for $vmName ( $assetID )"
            
                $vm.ScanIntiatedTime = $scancurrentTime.DateTime #Set the DateTime for the asset ID scans
            }
            else{
                Write-Host "$ScanTriggerStatus : Failed to initiate Qualys [$scantime] On Demand Scan on $vmName ( $assetID )"
                $vm.Status = "$ScanTriggerStatus : Failed to initiate Qualys [$scantime] On Demand Scan on $vmName ( $assetID )"
                $vm.ScanTriggered = "NO"
            }
        }
    }
    

    # Wrap in top-level structure
    $finalObject = [PSCustomObject]@{
        Apps = $deviceScanInfoList
    }

    # Save the result
    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $VMInfoFilePath -Encoding UTF8
}
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}