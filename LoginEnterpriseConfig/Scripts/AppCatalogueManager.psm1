#Get Catalogue Access Token
function Get-CatalogueAccessToken{
    param(
    [string]$username,
    [string]$password
    )

    $body = @{
        username = $username
        password = $password
    } | ConvertTo-Json

    $maxRetries = 3

    for($i = 1; $i -le $maxRetries; $i++){
        try{
            $response = Invoke-RestMethod -Method Post `
                -Uri "$($env:APP_CATALOGUE_BASE_URL)/auth/login" `
                -Headers @{
                    "accept" = "application/json"
                    "Content-Type" = "application/json"
                } `
                -Body $body

            $access_token = $response.access_token
            return $access_token
        }
        catch{
            Write-Warning "Get-CatalogueAccessToken failed. Attempt $i of $maxRetries. Error: $_"

            if($i -eq $maxRetries){
                throw
            }

            Start-Sleep -Seconds 10
        }
    }
}
#Get App Catalogue Status for a specific AppID
function Get-AppCatalogueStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$AppID
    )

    $headers = @{
        "accept" = "application/json"
        "Authorization" = "Bearer $AccessToken"
    }

    # Strip "FAM" prefix if present (API expects numeric ID only)
    $numericAppID = $AppID -replace '^FAM', ''
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/$numericAppID"

    try {
        $appData = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
        return @{
            Phase = $appData.AMC_Workflow_Phase
            Status = $appData.AMC_Status
            AppID = $AppID
        }
    }
    catch {
        throw "Failed to get app status from catalogue: $($_.Exception.Message)"
    }
}
# Updates AMC_Status to 'On Hold' with a failure reason when smoke test fails.
# This is the AppCatalogueUpdate function called by PollLEResult.ps1.
function AppCatalogueUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$AppID,
        [Parameter(Mandatory = $true)]
        [string]$IntuneAppName,
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [string]$Comment = ""
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/bulk-update"

    $numericAppID = $AppID -replace '^FAM', ''
    $scopeTag = Get-AppScopeTag -IntuneAppName $IntuneAppName
    $Scopes = $scopeTag | ConvertFrom-Json
    $updates = @{}
    if($Scopes -contains "AMC")
    { 
        $updates = @{
            AMC_Status          = "On Hold"
            On_Hold_Reason_AMC  = $Reason
        }
    }
    if($Scopes -contains "Service_AVC")
    { 
        $updates = @{
            AVCC_Status         = "On Hold"
            On_Hold_Reason_AVCC = $Reason
        }
    }
    if($Scopes -contains "AMC" -and $Scopes -contains "Service_AVC")
    { 
        $updates = @{
            AMC_Status          = "On Hold"
            On_Hold_Reason_AMC  = $Reason
            AVCC_Status         = "On Hold"
            On_Hold_Reason_AVCC = $Reason
        }
    }

    $payload = @{
        data = @(
            [PSCustomObject]@{
                AppID   = "$numericAppID"
                updates = $updates
            }
        )
    }
    $payloadJson = $payload | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $payloadJson -ErrorAction Stop
        if ($response.failed_count -gt 0) {
            Write-Host "AppCatalogueUpdate [Failed] for AppID: $AppID"
            Write-Host $response
        } else {
            Write-Host "AppCatalogueUpdate [Completed] AppID: $AppID set to On Hold. Reason: $Reason"
        }
    }
    catch {
        Write-Output "PS_ERROR_DESC= Failed to update catalogue for AppID $AppID : $($_.Exception.Message)"
        Exit 1
    }
}
function Get-AppScopeTag{
   param(
        [parameter(Mandatory = $true)]
        [string]$IntuneAppName
    )

    try {
      #Applist.json to fetch the app folder name
        $APPLISTJSONFILENAME = "appList.json"
        $IAF_Source_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\s" 
        Write-Host "IAF Source Directory : $IAF_Source_BINARIESDIRECTORY"
        $APPLISTJSONFILEPATH = Join-Path -Path $IAF_Source_BINARIESDIRECTORY -ChildPath $APPLISTJSONFILENAME

        $APPLISTJSONFILECONTENT = (Get-Content -Path $APPLISTJSONFILEPATH | ConvertFrom-Json).Apps
        
        #============= Put inside Loop =========
        
        $AppFoldername = ($APPLISTJSONFILECONTENT | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppFolderName

        $AppJsonPath = Join-path -Path ( Join-Path -Path $IAF_Source_BINARIESDIRECTORY -child "Apps") -ChildPath ( Join-Path -Path $AppFoldername -child "App.json")

        $AppJson = Get-Content -Path $AppJsonPath | ConvertFrom-Json

        $AppScopeTag= $AppJson.Information.ScopeTagName

        $tags = $AppScopeTag | ConvertTo-Json
        return $tags
    }
    catch {
      Write-Output "PS_ERROR_DESC= Error in while reading AO e-mail for Application from applist json in Create_TestSuite_Steps.ps1 script: $_"
      exit 1 
    }
        
}
Export-ModuleMember -Function Get-CatalogueAccessToken, Update-CatlogueStatus, Get-AppCatalogueStatus, Update-AppCataloguePhase, AppCatalogueUpdate
