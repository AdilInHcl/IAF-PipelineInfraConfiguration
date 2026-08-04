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

function Validate-IntuneAppID {
    param(
        $AppId,
        $displayName
    )
    # $AppId= $child.AppId; $displayName= $child.DisplayName

    #Fetch the App from Intune based on APP ID
    $IntuneApp = Get-IntuneWin32App -DisplayName $displayName

    if ($IntuneApp.id -eq $AppId){
        return $true
    }
    else{
        return $false
    }
}

function Set-Dependency {
    param(
        [array]$childApps,
        [string]$parentAppId
    )

    $deps = @()
    $ChilAppDependencyStatus = @()
    $ChildAppsReport = @()

    foreach ($child in $childApps) {
        try{
            if (-not [string]::IsNullOrWhiteSpace($child.AppId)) {
                $AppIDCheck = Validate-IntuneAppID -AppId $child.AppId -displayName $child.DisplayName
                
                if($AppIDCheck){
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
# Check for Apps that require Dependency in AppsAssignList.json
# ==========================================================================================
Write-Host "Checking for Dependency Status on each App"
Write-Host "=========================================="

$FailedApps = @()
$DependencyReport = @()

foreach($app in $AppAssignContent){
    $IntuneAppName = $app.IntuneAppName
    $ParentAppID = $app.IntuneAppObjectID
    $DependencyCheck = ($AppListData | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppDependency

    Write-Host "[$IntuneAppName]"
    
    if($DependencyCheck -eq 'Yes')
    {
        Write-Host "Dependency: $DependencyCheck"
        $AppFolderName = ($AppListData | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppFolderName
        $AppJsonPath = Join-Path (Join-path -Path $AppsBasePath -ChildPath $AppFolderName) -ChildPath "App.json"
        $AppJsonCOntent = Get-Content -Raw $AppJsonPath | ConvertFrom-Json
        $Dependencies = $AppJsonContent.Information.DependencyAppList

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
        Write-Host "Dependency found:" $Dependencies.DisplayName -Separator ' || '
        $response = Set-Dependency -childApps $Dependencies -parentAppId $ParentAppID


        #Check for the Status of the Dependecy assignment
        if($response -eq "Dependency Set Failed"){
            $ParentAppReason = "Failed to Set Dependency for All Apps"
            $ParentAppStatus = "Failed"
            $ChildAppsresponse = @()
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
                if($child.Status -eq $null){continue} # Skip Null elements
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
