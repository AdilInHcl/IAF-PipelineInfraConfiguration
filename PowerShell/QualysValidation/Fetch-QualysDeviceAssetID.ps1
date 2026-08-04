[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username = $env:QUALYS_USERNAME,
    [string]$password = $env:QUALYS_KEY
)


# IT RETURNS THE ASSET ID OF THE MACHINE FROM QUALYS API
function Get-AssetDetails{
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$AssetIP
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

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body

    [string]$assetId = $response.ServiceResponse.data.HostAsset.id
    
    return $assetId

}

#Fetch the stale entries
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

#remove the stale assets
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
    #=================================================================================
    #Fetch the asset INFO
    #=================================================================================
    $OutfileName = "VM_Details_baseline.txt"
    $Outfolder = $env:DAILYSCANBASEFOLDER
    $OutFilePath = Join-Path -Path $Outfolder -ChildPath $OutfileName

    $VMDetailFileContent = Get-Content -Path $OutFilePath -Raw | ConvertFrom-Json

    $AssetIP = $VMDetailFileContent.IPaddress
    $vmName = $VMDetailFileContent.DeviceName

    # Fetch the device names
    $deviceObj = [PSCustomObject]@{
            DeviceName = $VMDetailFileContent.DeviceName
            IPaddress = $VMDetailFileContent.IPaddress
            AssetID = ""
            UIStatus = ""
            Status = ""
            vulninfo = ""
        }
    #=================================================================================
    #Remove stale entries
    #=================================================================================
    #Fetch the Stale Asset IDs from Qualys
    $StaleAssetIds = Fetch-StaleAssetIds -username $username -password $password -AssetIP $AssetIP -vmName $vmName
    $StaleIdsCount = @($StaleAssetIds).Count
    Write-Host "Device details: $vmName --> $AssetIP --> stale entries: $($StaleIdsCount)"

    if ($StaleIdsCount -ne 0){
        $assetsdeleted = Remove-QualysAssets -AssetIds $StaleAssetIds -username $username -password $password
        $assetsdeletedCount = @($assetsdeleted).successcount
        if($assetsdeletedCount -eq $StaleIdsCount){
            Write-Host "All Stale Entries deleted for $AssetIP"
        }
        else{
            Write-Host "PS_ERROR_DESC= Some Stale Entries were not deleted for $AssetIP : $($assetsdeleted.assets)"
            exit 1
        }
    }
    #=================================================================================
    #Fetch the asset ID for VM from Qualys UI
    #=================================================================================
    #Wait params for Scan to complete
    $maxRetries =  5#attempts
    $delayMinutes = 20 #minutes

    for ($retryCount = 0; $retryCount -le $maxRetries; $retryCount++) {
        
            #Fetch the Scan Status
            $assetId = Get-AssetDetails -username $username -password $password -AssetIP $AssetIP

            if ($assetId) {
                Write-Host "Asset ID details: $vmName --> $assetId"
                $deviceObj.UIStatus = "Updated"
                $deviceObj.AssetID = $assetId
                $deviceObj.Status = "UI Updated with the new $vmName Details"
                break
            }
            else{
                Write-Host "Qualys UI is not updated for $vmName"
                $deviceObj.UIStatus = "Not Updated"
                $deviceObj.Status = "UI Not Updated."
            }
            Write-Host "Qualys UI is not updated for $vmName . Waiting $delayMinutes minutes before retrying... (Attempt $($retryCount+1))"
            Start-Sleep -Seconds ($delayMinutes * 60)

    }

    #Exit in case asset not registered on the Qualys side
    if ($null -eq $deviceObj.AssetID){exit 1}

    #Create folder if not present
    if(Test-Path $Outfolder){New-Item -Path $Outfolder -ItemType "Directory" -Force}
    $deviceObj = $deviceObj | ConvertTo-Json
    Out-File -InputObject $deviceObj -FilePath $OutFilePath
}
catch{
     Write-Host "PS_ERROR_DESC= $_"
     exit 1
}