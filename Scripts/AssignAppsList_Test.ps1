<#
.SYNOPSIS
    Assign Intune Win32 app dependencies, produce JSON report and HTML dependency log.

.DESCRIPTION
    Connects to Intune Graph, reads the apps assignment list and app metadata, validates
    dependency entries for parent apps, assigns dependencies when valid, removes parent apps
    when dependency validation fails, and emits a JSON report and an HTML dependency log.
    All errors are reported using PS_ERROR_DESC for pipeline detection.

.NOTES
    FileName:    AssignAppsList.ps1
    Author:      Daniyal Ahmad
    Created:     20 November 2025
#>

param(
    [Parameter(Mandatory = $true)] [string]$TenantID,
    [Parameter(Mandatory = $true)] [string]$ClientID,
    [string]$ClientSecret = $env:CLIENT_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

function Set-Dependency {
    param(
        [array]$childApps,
        [string]$parentAppId
    )

    # $childApps = $DependencyAppList; $parentAppId = $ParentAppID

    $deps = @()
    $ChilAppDependencyStatus = @()
    $ChildAppsReport = @()

    foreach ($child in $childApps) {
        try{
            if (-not [string]::IsNullOrWhiteSpace($child.AppId)) {                
                    $deps += New-IntuneWin32AppDependency -ID $child.AppId -DependencyType "AutoInstall"
                    $ChildAppsReport += [PSCustomObject]@{
                        DisplayName   = $child.DisplayName
                        Status        = "Success"
                        Reason        = "Dependency validated"
                    }
                }
                else{  
                    $ChildAppsReport += [PSCustomObject]@{
                        DisplayName   = $child.DisplayName
                        Status        = "Failure"
                        Reason        = "App not found or ID mismatch"
                    }
                }
            
        }
        catch{
            $ChildAppsReport += [PSCustomObject]@{
                    DisplayName   = $child.DisplayName
                    Status        = "Failure"
                    Reason        = "Error: $_"
                }
        }
    }

    if ($deps.Count -gt 0) {
        try{
            Add-IntuneWin32AppDependency -ID $parentAppId -Dependency $deps
        }
        catch{
            return "Dependency Set Failed"
        }
    }

    return  $ChildAppsReport
}
function Get-LatestDeployedVersion{
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$FamilyID,
        [Parameter(Mandatory = $false)]
        [string]$Fields
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"        
    }

    #Set the URI as per the input fields
    if($null -eq $Fields){
        $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/family/$($FamilyID)"
    }else{
        $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/family/$($FamilyID)?fields=$($Fields)"
    }
    try{
        $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
        return $response
    }catch{
        Write-Host "Failed to Fetch the Apps for FamilyID: $FamilyID . $_"
        return "Failed"
    }
}
function Validate-AppIDNotes{
    param(
        $IntuneAppDetected,
        $AppID = $CatlogueProdLatestAppDetected.AppID
    )

    foreach($app in $IntuneAppDetected){
        $AppIDMatchString = "AppID:\s*$($AppID)"
        if ($app.Notes -match $AppIDMatchString){
            return $app
        }
    }

}
# ==========================================================================================
# CONNECT TO INTUNE GRAPH
# ==========================================================================================
try {
    $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction Stop
    Write-Output "Connected to Intune Graph successfully."
}
catch {
    Write-Output "PS_ERROR_DESC= Failed to connect to Intune Graph: $($_.Exception.Message)"
    exit 1
}

# ==========================================================================================
# LOAD JSON FILES
# ==========================================================================================
try{
    $AppAssignListPath     = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishedList") -ChildPath "AppsAssignList.json"
    $AppListPath           = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "appList.json"
    $AppsBasePath          = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps"
    $OutputDependencyJson  = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "DependencyAppList.json"

    $AppListData = (Get-Content -Raw $AppListPath       | ConvertFrom-Json).Apps
    $AppAssignContent   = Get-Content -Raw $AppAssignListPath | ConvertFrom-Json
}
catch{
    Write-Output "PS_ERROR_DESC= Failed to parse JSON: $($_.Exception.Message)"
    exit 1
}

# ==========================================================================================
# CONNECT TO MSGraphRequest
# ==========================================================================================
# Intune Access Token
$AuthToken = Get-AccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"

#Fetching Intune App Data
$MaxRetries  = 10
$RetryDelay  = 30
$Attempt     = 0
$Win32AppResources    = $null
while ($Attempt -lt $MaxRetries -and $null -eq $Win32AppResources) {
    $Attempt++
    try {
        $Win32AppResources = @(Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')")
    }
    catch {
        Write-Output "$_"
        Write-Output -InputObject "Failed to upload to inutne on attempt $Attempt/$MaxRetries for '$($App.IntuneAppName)': ErrMsg. Retrying in $RetryDelay seconds..."
        Start-Sleep -Seconds $RetryDelay
    }
}

# ==========================================================================================
# Check for Apps that require Dependency in AppsAssignList.json
# ==========================================================================================
Write-Host "Checking for Dependency Status on each App"
Write-Host "=========================================="

$FailedApps = @()
$DependencyReport = @()

#Fetch the catalogue token
$token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry


foreach($app in $AppAssignContent){
    $IntuneAppName = $app.IntuneAppName
    $ParentAppID = $app.IntuneAppObjectID
    $DependencyCheck = ($AppListData | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppDependency

    Write-Host "[$IntuneAppName]"
    
    if($DependencyCheck -eq 'Yes')
    {
        Write-Host "Dependency: $DependencyCheck"
        $AppListDetails = $AppListData | Where-Object {$_.IntuneAppName -eq $IntuneAppName}
        $AppFolderName = $AppListDetails.AppFolderName
        $AppJsonPath = Join-Path (Join-path -Path $AppsBasePath -ChildPath $AppFolderName) -ChildPath "App.json"
        $AppJsonCOntent = Get-Content -Raw $AppJsonPath | ConvertFrom-Json
        $Dependencies = $AppJsonContent.Information.DependencyAppList

         #Fetch the Workflow field names for catalogue
        $ScopeTags = $AppJsonContent.Information.ScopeTagName
        $ScopeFields = @{
            Service_AMC = @{Status = 'AMC_Status';Reason = 'On_Hold_Reason_AMC'} #For ADT APPS
            AMC = @{Status = 'AMC_Status';Reason = 'On_Hold_Reason_AMC'} #For PROD APPS
            Service_AVC = @{Status = 'AVCC_Status';Reason = 'On_Hold_Reason_AVCC'}
        }

        $WorkflowFieldNames = ''
        foreach($ScopeTag in $ScopeTags){
            $WorkflowFieldNames += ','+ $ScopeFields[$ScopeTag].Status
        }

        if(-not($Dependencies)){
           Write-Host "Dependency not found in the file: $AppJsonPath"
           Write-Host "Updating Catalogue for failed App Dependency status."

           $DependencyReport += [PSCustomObject]@{
            ParentAppName = $IntuneAppName
            ParentAppId   = $ParentAppID
            Status        = "failed"
            Reason        = "Dependency not found in the file: $AppJsonPath"
            ChildApps     = @()
        }

           $FailedApps += $app
           continue
        }

        #Set Dependencies
        Write-Host "Dependency found:" $Dependencies.FamilyID -Separator ' || '
        
        #Catalogue Field Names
        $FieldNames = "AppID,Application_Name,Application_Version"+$WorkflowFieldNames
        $DependencyAppList = @()

        foreach($FamilyID in $Dependencies.FamilyID){

            $AppList = Get-LatestDeployedVersion -AccessToken $token -FamilyID $FamilyID -Fields $FieldNames
            $CatlogueProdLatestAppDetected = $AppList.applications |Where-Object {$_.AMC_Status -eq 'Complete' -or $_.AVCC_Status -eq 'Complete'}|Sort-Object { [version]$_.Application_Version } -Descending |Select-Object -First 1
            $IntuneAppDetected = $Win32AppResources | Where-Object {$_.displayVersion -eq $CatlogueProdLatestAppDetected.Application_Version}
            $LatestIntuneAppDetected = Validate-AppIDNotes -IntuneAppDetected @($IntuneAppDetected) -AppID $CatlogueProdLatestAppDetected.AppID    

            if (-not($LatestIntuneAppDetected.id)){
                Write-Host "$($CatlogueProdLatestAppDetected.Application_Name)[$($CatlogueProdLatestAppDetected.Application_Version)] not present on intune. Skipping..."
                Write-Host "-----"
            }
            else{
                Write-Host "Latest version Detected [$FamilyID] : $($LatestIntuneAppDetected.displayName). Adding..."
                Write-Host "------"
            }
            $DependencyAppList += [PSCustomObject]@{
                    DisplayName = $LatestIntuneAppDetected.displayName
                    AppId = $LatestIntuneAppDetected.id
            }
        }

        
        $response = Set-Dependency -childApps $DependencyAppList -parentAppId $ParentAppID


        #Check for the Status of the Dependecy assignment
        if($response -eq "Dependency Set Failed"){
            $ParentAppReason = "Failed to Set Dependency for All Apps"
            $ParentAppStatus = "Failed"
            $ChildAppsresponse = @()
            $FailedApps += $app
         }
         elseif($response.Status -contains "Failure"){
            $FailedApps += $app
            $ParentAppReason = "Failed to Set Dependency for some Apps"
            $ParentAppStatus = "Failed"
            $ChildAppsresponse = $response
        }
        else{
            $ParentAppReason = "Dependencies processed successfully"
            $ParentAppStatus = "Success"
            $ChildAppsresponse = $response
        }

        # Add to report
        $DependencyReport += [PSCustomObject]@{
            ParentAppName = $IntuneAppName
            ParentAppId   = $ParentAppId
            Status        = $ParentAppStatus
            Reason        = $ParentAppReason
            ChildApps     = $ChildAppsresponse
        }

        Write-Host "=========================================="
    }
    else{
        Write-Host "Dependency: No"
        Write-Host "=========================================="
    }
}

# Update the catlogue for the apps where supersedence failed
if ($FailedApps){
    $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry
    Update-CatlogueStatus -AccessToken $token -Apps $FailedApps -Reason "IAF - Set App dependency in Intune failed"
}
# ==========================================================================================
# SAVE DEPENDENCY LOG
# ==========================================================================================
$DependencyLogPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -Childpath "\configs\DependencyLog.txt"

if ($DependencyReport.Count -gt 0) {
    $TableRows = @()
    foreach ($entry in $DependencyReport) {
        if ($entry.ChildApps -and $entry.ChildApps.Count -gt 0) {
            $isFirst = $true
            foreach ($child in $entry.ChildApps) {
                if($null -eq $child.Status){continue} # Skip Null elements
                $StatusText = if ($child.Status -eq "success") { "SUCCESS" } else { "FAILURE" }
                $Color = if ($StatusText -eq "SUCCESS") { "green" } else { "red" }
                $reason = if ($child.Status -eq "success") { "N/A" } else { $child.Reason }
                $parentName = if ($isFirst) { $($entry.ParentAppName) } else { "" }
                $isFirst = $false
                $TableRows += @"
<tr>
<td style='padding:6px;border:1px solid #ccc;'>$parentName</td>
<td style='padding:6px;border:1px solid #ccc;'>$($child.DisplayName)</td>
<td style='padding:6px;border:1px solid #ccc;color:$Color;font-weight:bold;'>$($StatusText.ToUpper())</td>
<td style='padding:6px;border:1px solid #ccc;'>$reason</td>
</tr>
"@
            }
        } else {
            $StatusText = if ($entry.Status -eq "success") { "SUCCESS" } else { "FAILURE" }
            $Color = if ($StatusText -eq "SUCCESS") { "green" } else { "red" }
            $reason = if ($entry.Status -eq "success") { "N/A" } else { $entry.Reason }
            $TableRows += @"
<tr>
<td style='padding:6px;border:1px solid #ccc;'>$($entry.ParentAppName)</td>
<td style='padding:6px;border:1px solid #ccc;'>-</td>
<td style='padding:6px;border:1px solid #ccc;color:$Color;font-weight:bold;'>$($StatusText.ToUpper())</td>
<td style='padding:6px;border:1px solid #ccc;'>$reason</td>
</tr>
"@
        }
    }

    $TableHtml = @"
<table>
<tr>
<th>Display Name</th>
<th>Dependency Display Name</th>
<th>Status</th>
<th>Reason</th>
</tr>
$($TableRows -join "`n")
</table>
"@

    # Add summary line
    $hasFailure = ($DependencyReport | Where-Object { $_.Status -eq "Failed" }).Count
    if ($hasFailure -eq 0) {
        $TableHtml += "<p>All application dependencies have been successfully assigned and configured.</p>"
    } else {
        $TableHtml += "<p>Dependency assignment failed for one or more applications. Please review the details above.</p>"
    }

    $TableHtml | Out-File $DependencyLogPath -Encoding UTF8
    Write-Output "Dependency log saved to: $DependencyLogPath"
} else {
    Write-Output "No dependencies processed. Skipping dependency log generation."
}
