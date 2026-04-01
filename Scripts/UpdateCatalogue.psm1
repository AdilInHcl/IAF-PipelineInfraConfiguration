<#
.SYNOPSIS
    This .psm1 module connects to the app catlogue and updates the status of the apps in the catalogue

.DESCRIPTION
    This .psm1 module connects to the app catlogue and updates the status of the apps in the catalogue

.NOTES
    FileName: UpdateCatalogue.psm1
    Author : Daniyal Ahmad
#>

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

#Update the Catalogue with status for each App
function Update-CatlogueStatus {
    param(
        [Parameter(Mandatory = $true)]
        $AccessToken,
        [Parameter(Mandatory = $true)]
        $Apps,
        [Parameter(Mandatory = $true)]
        $REASON,
        $InputFilePath #Only if all the apps are failing
    )

    # Validation rule if Apps = 'All' there should be an input file that contains info about all apps
    if ($Apps -eq "All" -and [string]::IsNullOrWhiteSpace($InputFilePath)) 
    { throw "InputFilePath is required when Apps = 'All'."; exit 1}

    ###########################################################
    # Headers and URO for updating the Apps status in catlogue
    ###########################################################
    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    #URL to create a new App ID.
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/bulk-update"

    ########################################################
    # Map Scope Tags in App.json  with Catalogue column Name
    ########################################################
    $Columns = @{
        Service_AMC = @{Status = 'AMC_Status';Reason = 'On_Hold_Reason_AMC'} #For ADT APPS
        AMC = @{Status = 'AMC_Status';Reason = 'On_Hold_Reason_AMC'} #For PROD APPS
        Service_AVC = @{Status = 'AVCC_Status';Reason = 'On_Hold_Reason_AVCC'}
    }
    
    ###########################################################
    # Get File contents for AppID and AppList.json
    ###########################################################
    $APPIDJSONFILENAME = "AppId.json"
    $APPIDJSONFILEPATH = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $APPIDJSONFILENAME
    $APPIDJSONCONTENT = (Get-content -Raw -path $APPIDJSONFILEPATH | ConvertFrom-Json).Apps

    $APPLISTJSONFILENAME = "appList.json"
    $APPLISTJSONFILEPATH = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath $APPLISTJSONFILENAME
    $APPLISTJSONFILECONTENT = (Get-content -Raw -path $APPLISTJSONFILEPATH | ConvertFrom-Json).Apps

    if ($Apps -eq "All"){
        if (Test-Path $InputFilePath) {
            Write-Host "Reading apps from: $InputFilePath"

            # Load JSON data
            $InputJson = Get-Content -Raw -Path $InputFilePath | ConvertFrom-Json

            # Normalize: always wrap into .Apps
            if ($null -eq $InputJson.Apps) {
                $missingApps = $InputJson
            }
            else {
                # Already has Apps → just keep as is
                $missingApps = $InputJson.Apps
            }
        }
        else {
            Write-Output "PS_ERROR_DESC= JSON file at path '$InputFilePath' does not exist."
            exit 1
        }
    }
    else{
        $missingApps = $Apps
    }
    
    $updatelist = @()

    ########################################################
    # Create PayloadJson
    ########################################################
    Write-Host "[$REASON]"
    Write-Host "Updating Catalogue for Missing Apps: $($missingApps.IntuneAppName -join ", ")" 

    foreach ($App in $missingApps) {

        $AppName = $App.IntuneAppName
        $AppFoldername = ($APPLISTJSONFILECONTENT | Where-Object { $_.IntuneAppName -eq $AppName }).AppFolderName
        $AppID = ($APPIDJSONCONTENT | Where-Object { $_.IntuneAppName -eq $AppName }).AppId
        if($null -eq $AppID){Write-Host "AppID not available for $AppName. Skipping Catalogue entry... "; continue} #Skipp App in case the AppID is not created

        $AppFolderPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps/$AppFoldername"
        $AppJsonPath = Join-Path -Path $AppFolderPath -ChildPath "App.json"

        $AppJsonContent = Get-Content -Raw -Path $AppJsonPath | ConvertFrom-Json
        $ScopeTags = $AppJsonContent.Information.ScopeTagName
        if($null -eq $ScopeTags){Write-Host "Scope tags missing for $AppName. Skipping Catalogue entry... "; continue} #Skipp App in case the Scope tags missing

        foreach ($scope in $ScopeTags) {

            # Build the updates object as a hashtable
            $updates = @{
                ($Columns[$scope].Status) = "On Hold"
                ($Columns[$scope].Reason) = $REASON
            }

            # Build the final object
            $data = [PSCustomObject]@{
                AppID   = "$AppID"
                updates = $updates
            }

            $updatelist += $data
        }
    }
    if (@($updatelist).Count -gt 0){

        $payload = @{
        data = $updatelist
        }

        $payloadJson = $payload | ConvertTo-Json -Depth 10
        $status = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $payloadJson 
        #Check if the App ID has been added to the Catalogue
        if($status.failed_count -gt 0 ){
            Write-Host "Catalogue Update [Failed]"
            $uniqueAppIds = $updatelist.AppID | Select-Object -Unique
            Write-Host "Failed to update AppIDs [$uniqueAppIds]"
        }else{
            Write-Host "Catalogue Update [Completed]"
            $uniqueAppIds = $updatelist.AppID | Select-Object -Unique
            Write-Host "Updated Catalogue for AppIDs [$uniqueAppIds]"
        }
    }
}