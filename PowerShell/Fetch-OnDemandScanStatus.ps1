<#
.SYNOPSIS
This script connects to Qualys using API and fetches the on demand status by comapring the trigger time and the last timestamp

.DESCRIPTION
This script connects to Qualys using API and fetches the on demand status by comapring the trigger time and the last timestamp

.NOTES
    FileName:    Fetch_OnDemandScanStatus.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username,
    [string]$password = $env:QUALYS_KEY
)

# IT RETURNS THE Last Scan Timestamp
function Get-LastScanTimestamp {
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

    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
        "Authorization"     = "Basic $encodedCreds"
        "X-Requested-With"  = "powershell"
    }

    $url = "https://qualysapi.qg2.apps.qualys.eu/api/4.0/fo/asset/host/vm/detection/?action=list&ips=$AssetIP&show_asset_id=1&show_results=1&include_vuln_type=confirmed"

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Verbose "Attempt $attempt of $MaxRetries to query Qualys API (LastScanTimestamp)"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            return $response.HOST_LIST_VM_DETECTION_OUTPUT.RESPONSE.HOST_LIST.HOST.LAST_SCAN_DATETIME
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -lt $MaxRetries) {
                Write-Verbose "Retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "All retry attempts failed. Unable to retrieve last scan timestamp."
            }
        }
    }
}

#Fetch qualys title and severity 
function Get-QualysVmVulnsDetails {
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

    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
        "Authorization"     = "Basic $encodedCreds"
        "X-Requested-With"  = "powershell"
    }

    $url = "https://qualysapi.qg2.apps.qualys.eu/api/4.0/fo/asset/host/vm/detection/?action=list&ips=$AssetIP&show_asset_id=1&show_results=1&include_vuln_type=confirmed"

    # Retry wrapper
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Verbose "Attempt $attempt of $MaxRetries to query Qualys VM vulnerabilities"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            break
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "All retry attempts failed. Unable to retrieve VM vulnerability list."
            }
        }
    }

    $vulnDetected = $response.HOST_LIST_VM_DETECTION_OUTPUT.RESPONSE.HOST_LIST.HOST.DETECTION_LIST.DETECTION

    $cleanList = foreach ($item in $vulnDetected) {

        $resultsText = $null
        if ($item.RESULTS.'#text') {
            $resultsText = $item.RESULTS.'#text'
        } elseif ($item.RESULTS.InnerText) {
            $resultsText = $item.RESULTS.InnerText
        }

        [PSCustomObject]@{
            UNIQUE_VULN_ID          = $item.UNIQUE_VULN_ID
            QID                     = $item.QID
            TYPE                    = $item.TYPE
            SEVERITY                = $item.SEVERITY
            SSL                     = $item.SSL
            RESULTS                 = $resultsText
            STATUS                  = $item.STATUS
            FIRST_FOUND_DATETIME    = $item.FIRST_FOUND_DATETIME
            LAST_FOUND_DATETIME     = $item.LAST_FOUND_DATETIME
            TIMES_FOUND             = $item.TIMES_FOUND
            LAST_TEST_DATETIME      = $item.LAST_TEST_DATETIME
            LAST_UPDATE_DATETIME    = $item.LAST_UPDATE_DATETIME
            IS_IGNORED              = $item.IS_IGNORED
            IS_DISABLED             = $item.IS_DISABLED
            LAST_PROCESSED_DATETIME = $item.LAST_PROCESSED_DATETIME
        }
    }

    return $cleanList
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
            AssetID = $app.AssetID
            IntuneAppName = $app.IntuneAppName
            UIStatus = $app.UIStatus
            Status = $app.Status
            ScanTriggered = $app.ScanTriggered
            ScanIntiatedTime = $app.ScanIntiatedTime
            vulninfo = ""
            ScanCompletedTime = ""
        }
        $deviceScanInfoList += $deviceInfo
       }
    }
    else {
        Write-Output "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }

    #Wait params for Scan to complete
    $maxRetries = 4 #attempts
    $delayMinutes = 30 #minutes
    $UnderScanningDevices = $deviceScanInfoList | Where-Object {$_.ScanTriggered -eq 'YES'}

    #Fetch the Status from each VM on Qualys Scan
    for ($retryCount = 0; $retryCount -le $maxRetries; $retryCount++) {
    
        foreach ($vm in $UnderScanningDevices){
            $vmName =  $vm.DeviceName
            $AssetIP = $vm.IPaddress
            $assetID = $vm.AssetID
            $utcTime  = [datetime]::Parse($vm.ScanIntiatedTime)
            $ScanIntiatedTime = $utcTime.ToLocalTime()

            #Fetch the On Demand Scan Status
            $currentscantimestamp = Get-LastScanTimestamp -username $username -password $password -AssetIP $AssetIP
            $utcTime  = [datetime]::Parse($currentscantimestamp)
            $currentscantimestamp = $utcTime.ToLocalTime()

            if ($currentscantimestamp -gt $ScanIntiatedTime){#check if the OD scan has completed
                Write-Host "Qualys On Demand Scan completed [$currentscantimestamp] for $vmName ( $assetID )"
                $vm.Status = "Scan Completed:[$currentscantimestamp]"
                $vm.ScanCompletedTime = $currentscantimestamp.DateTime #Set the DateTime for the asset ID scans completion

                #Fetch the vulnerabilities detected.
                $ScanDetails = Get-QualysVmVulnsDetails -username $username -password $password -AssetIP $AssetIP
                $vm.vulninfo = $ScanDetails
                
            }
            else{
                Write-Host "Qualys On Demand Scan is still running on $vmName ( $assetID )"
            }
            
        }

        #Skip the Iteration  of the Completed Scan
        $UnderScanningDevices = $UnderScanningDevices | Where-Object { $_.ScanCompletedTime -eq "" }

        #Check if devices in running status and Initiate a sleep before retry
        if(@($UnderScanningDevices).count -gt 0){
            Write-Host "Qualys On Demand Scan is not completed on VM(s). Waiting $delayMinutes minutes before retrying... (Attempt $($retryCount+1))"
            Start-Sleep -Seconds ($delayMinutes * 60)
        }
        else{
            break
        }
    }

    if(@($UnderScanningDevices).count -gt 0){
            Write-Host "Qualys On Demand Scan is still running for below VM(s)"
            Write-Host $UnderScanningDevices.DeviceName
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