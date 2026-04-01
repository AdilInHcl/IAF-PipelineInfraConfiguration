Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\AppUpgradeDetection.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1"

$JsonFilePath = Join-Path $env:LEConfigJsonPath -ChildPath $env:LE_VM_inputFileName 
function Get-CatalogueToken{
    param(
    [string]$username,
    [string]$password
    )
    $body = @{
        username = $username
        password = $password
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Method Post `
        -Uri "$($env:APP_CATALOGUE_BASE_URL)/auth/login" `
        -Headers @{
            "accept" = "application/json"
            "Content-Type" = "application/json"
        } `
        -Body $body

    $access_token = $response.access_token
    Write-Host "Access Token generated ."
    return $access_token
}
function AppScopeTag 
{
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
      Write-Output "PS_ERROR_DESC= Error in while reading AO e-mail for Application from applist json in checkappCatalogueStatus.ps1 script: $_"
      exit 1 
    }
        
}
# Updates phase to 'Dev Testing' and sets AMC_Status to 'In Progress' via bulk-update endpoint.
# Called when an app moves from Packaging into the test pipeline.
function Update-AppCataloguePhase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$IntuneAppName,
        [Parameter(Mandatory = $true)]
        [string]$AppID,
        [string]$Phase = "Dev Testing"
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/bulk-update"

    $numericAppID = $AppID -replace '^FAM', ''
    $scopeTag = AppScopeTag -IntuneAppName $IntuneAppName
    $Scopes = $scopeTag | ConvertFrom-Json
    $updates = @{}
    if($Scopes -contains "AMC")
    { 
         $updates = @{
                    AMC_Workflow_Phase  = $Phase
                    AMC_Status          = "In Progress" 
                }
    }
    if($Scopes -contains "Service_AVC")
    { 
         $updates = @{
                    AVCC_Workflow_Phase = $Phase
                    AVCC_Status         = "In Progress"
                }
    }
    if($Scopes -contains "AMC" -and $Scopes -contains "Service_AVC")
    { 
        $updates = @{
                    AMC_Workflow_Phase  = $Phase
                    AMC_Status          = "In Progress"
                    AVCC_Workflow_Phase = $Phase
                    AVCC_Status         = "In Progress"
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
    Write-Host "request body " $payloadJson
    try {
        $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $payloadJson -ErrorAction Stop
        if ($response.failed_count -gt 0) {
            Write-Host "Phase Update [Failed] for AppID: $AppID"
        } else {
            Write-Host "Phase Update [Completed] AppID: $AppID -> Phase: $Phase"
        }
    }
    catch {
        Write-Output "Failed to update phase for AppID $AppID : $($_.Exception.Message)"
        Exit 1
    }
}
# Get credentials from environment variables
$Username = $env:APP_CATALOGUE_USERNAME
$Password = $env:APP_CATALOGUE_SECRET
try {
    Write-Host "=== App Catalogue Service Check Started ==="
    Write-Host "Reading apps JSON from: $JsonFilePath"
    
    # Validate JSON file exists
    if (-not (Test-Path $JsonFilePath)) {
        Write-Output "PS_ERROR_DESC= JSON file not found at: $JsonFilePath"
        exit 1
    }
    
    # Load JSON data
    $jsonObject = Get-Content -Path $JsonFilePath | ConvertFrom-Json
    $appsList = $jsonObject.Apps
    
    Write-Host "Total apps to check: $($appsList.Count)"
    
    $AccessToken = Get-CatalogueToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET
    
    # Process each app
    foreach ($app in $appsList) {
        $AppId = $app.AppId
        Write-Host "App Id : $AppId"
        $IntuneAppName = $app.IntuneAppName
        
        Write-Host "`n--- Checking: $IntuneAppName (AppId: $AppId) ---"
        
        try {
            # Query App Catalogue to get current phase/status
            #$catalogueStatus = Get-AppCatalogueStatus -AccessToken $AccessToken -AppID $AppId
            
            #Write-Host "  Phase: $($catalogueStatus.Phase)"
            #Write-Host "  Status: $($catalogueStatus.Status)"
            $result = Update-AppCataloguePhase -AccessToken $AccessToken -IntuneAppName $IntuneAppName -AppID $AppId -Phase "Dev Testing"
            Write-Host "app status change from packaging to Dev testing : $result"
            
        } catch {
            Write-Output "PS_ERROR_DESC= An unexpected error occurred while updating App Catalogue status for $IntuneAppName : $($_.Exception.Message)"
            exit 1
        }
    }
} catch {
    Write-Output "PS_ERROR_DESC= Error in App Catalogue Service Check: $($_.Exception.Message)"
    exit 1
}
