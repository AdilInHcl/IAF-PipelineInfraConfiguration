<#
.SYNOPSIS
    Create and assign Intune Win32 app dependencies, produce JSON report and HTML dependency log.

.DESCRIPTION
    Connects to Intune Graph, reads the apps assignment list and app metadata, validates
    dependency entries for parent apps, assigns dependencies when valid, removes parent apps
    when dependency validation fails, and emits a JSON report and an HTML dependency log.
    All errors are reported using PS_ERROR_DESC for pipeline detection.

.NOTES
    FileName:    AssignAppsList.ps1
    Author:      Saunak Ghosh
    Created:     20 November 2025
#>

param(
    [Parameter(Mandatory = $true)] [string]$TenantID,
    [Parameter(Mandatory = $true)] [string]$ClientID,
    [string]$ClientSecret = $env:CLIENT_SECRET
)

# ===== PATHS =====
$AppAssignListPath     = Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY "AppsPublishedList\AppsAssignList.json"
$AppListPath           = Join-Path $env:BUILD_SOURCESDIRECTORY         "appList.json"
$AppsBasePath          = Join-Path $env:BUILD_SOURCESDIRECTORY         "Apps"
$OutputDependencyJson  = Join-Path $env:BUILD_SOURCESDIRECTORY "DependencyAppList.json"



# ==========================================================================================
# FUNCTION: Set Dependency
# ==========================================================================================
function Set-Dependency {
    param(
        [array]$childApps,
        [string]$parentAppId
    )
    try {
        $deps = @()
        foreach ($child in $childApps) {
            if (-not [string]::IsNullOrWhiteSpace($child.ActualAppId)) {
                $deps += New-IntuneWin32AppDependency -ID $child.ActualAppId -DependencyType "AutoInstall"
            }
        }
        if ($deps.Count -gt 0) {
            Add-IntuneWin32AppDependency -ID $parentAppId -Dependency $deps
            Write-Output "Dependencies successfully set for parent app ID: $parentAppId"
        }
        else {
            Write-Output "No valid dependencies to set for parent app ID: $parentAppId"
        }
    }
    catch {
        Write-Output "Error setting dependency: $($_.Exception.Message)"
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
    Write-Error "PS_ERROR_DESC= Failed to connect to Intune Graph: $($_.Exception.Message)"
    exit 1
}

# ==========================================================================================
# LOAD JSON FILES
# ==========================================================================================
try {
    $AppListData = Get-Content -Raw $AppListPath       | ConvertFrom-Json
    $InputJson   = Get-Content -Raw $AppAssignListPath | ConvertFrom-Json
}
catch {
    Write-Error "PS_ERROR_DESC= Failed to parse JSON: $($_.Exception.Message)"
    exit 1
}

# Normalize JSON structure
$ParentAppsToProcess = if ($InputJson -and $InputJson.PSObject.Properties.Name -contains 'Apps') {
    @($InputJson.Apps)
}
elseif ($InputJson -is [System.Array]) {
    @($InputJson)
}
else { @($InputJson) }

# ==========================================================================================
# MAIN PROCESSING LOOP
# ==========================================================================================
$DependencyReport = @()

foreach ($ParentAppData in $ParentAppsToProcess) {
    $ParentAppName = $ParentAppData.IntuneAppName
    $ParentAppId   = $ParentAppData.IntuneAppObjectID
    Write-Output "`n=== Processing Parent App: $ParentAppName ($ParentAppId) ==="

    $ParentAppRecord = $AppListData.Apps | Where-Object { $_.IntuneAppName -eq $ParentAppName }

    if (-not $ParentAppRecord) {
        Write-Warning "Parent app $ParentAppName not found in appList.json. Skipping..."
        continue
    }

    if (-not $ParentAppRecord.PSObject.Properties['AppDependency'] -or $ParentAppRecord.AppDependency.Trim() -ne "Yes") {
        Write-Output "Skipping: App does not require dependencies."
        continue
    }

    # Load parent App.json
    $ParentAppJsonPath = Join-Path (Join-Path $AppsBasePath $ParentAppRecord.AppFolderName) "App.json"
    try {
        $ParentAppJson = Get-Content -Raw $ParentAppJsonPath | ConvertFrom-Json
    }
    catch {
        Write-Output "Failed to read App.json for $ParentAppName"
        $DependencyReport += [PSCustomObject]@{
            ParentAppName = $ParentAppName
            ParentAppId   = $ParentAppId
            Status        = "failed"
            Reason        = "Unable to read App.json"
            ChildApps     = @()
        }
        continue
    }

    $DependencyApps = $ParentAppJson.Information.DependencyAppList
    if (-not $DependencyApps -or $DependencyApps.Count -eq 0) {
        Write-Output "No dependencies found for $ParentAppName. Skipping..."
        continue
    }

    # Validate child apps
    $ChildAppsReport = @()
    $HasFailure = $false

    foreach ($child in $DependencyApps) {
        try {
            $displayName = $child.DisplayName.Trim()
            $expectedId  = $child.AppId
            $app = Get-IntuneWin32App -DisplayName $displayName

            if ($app -and $app.id -and $app.id -eq $expectedId) {
                $ChildAppsReport += [PSCustomObject]@{
                    DisplayName   = $displayName
                    ExpectedAppId = $expectedId
                    ActualAppId   = $app.id
                    Status        = "success"
                    Reason        = "Dependency validated"
                }
            }
            else {
                $ChildAppsReport += [PSCustomObject]@{
                    DisplayName   = $displayName
                    ExpectedAppId = $expectedId
                    ActualAppId   = if ($app) { $app.id } else { "" }
                    Status        = "failure"
                    Reason        = "App not found or ID mismatch"
                }
                $HasFailure = $true
            }
        }
        catch {
            $ChildAppsReport += [PSCustomObject]@{
                DisplayName   = if ($child.DisplayName) { $child.DisplayName } else { "" }
                ExpectedAppId = if ($child.AppId) { $child.AppId } else { "" }
                ActualAppId   = ""
                Status        = "failure"
                Reason        = $_.Exception.Message
            }
            $HasFailure = $true
        }
    }

    # Take action based on child app validation
    if ($HasFailure) {
        try {
            Remove-IntuneWin32App -ID $ParentAppId -ErrorAction Stop
            $ParentStatus = "failure"
            $ParentReason = "Parent app removed due to dependency failures"
        } catch {
            $ParentStatus = "failure"
            $ParentReason = "Dependency failures detected, but removal failed: $($_.Exception.Message)"
        }
    } else {
        # Set valid dependencies only
        $validChildren = $ChildAppsReport | Where-Object { $_.Status -eq "success" }
        if ($validChildren.Count -gt 0) {
            Set-Dependency -childApps $validChildren -parentAppId $ParentAppId
        }
        $ParentStatus = "success"
        $ParentReason = "Dependencies processed successfully"
    }

    # Add to report
    $DependencyReport += [PSCustomObject]@{
        ParentAppName = $ParentAppName
        ParentAppId   = $ParentAppId
        Status        = $ParentStatus
        Reason        = $ParentReason
        ChildApps     = $ChildAppsReport
    }
}

# ==========================================================================================
# SAVE JSON OUTPUT
# ==========================================================================================
if ($DependencyReport.Count -gt 0) {
    try {
        $DependencyReport | ConvertTo-Json -Depth 12 | Out-File $OutputDependencyJson -Encoding UTF8
        Write-Output "Dependency report saved to: $OutputDependencyJson with $($DependencyReport.Count) entries."
    }
    catch {
        Write-Error "Failed to save dependency report: $_"
    }
} else {
    Write-Output "No dependencies processed. Skipping JSON report generation."
}

# ==========================================================================================
# SAVE DEPENDENCY LOG
# ==========================================================================================
$DependencyLogPath = Join-Path $PSScriptRoot "..\configs\DependencyLog.txt"

if ($DependencyReport.Count -gt 0) {
    $TableRows = @()
    foreach ($entry in $DependencyReport) {
        if ($entry.ChildApps -and $entry.ChildApps.Count -gt 0) {
            $isFirst = $true
            foreach ($child in $entry.ChildApps) {
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
    $hasFailure = ($DependencyReport | Where-Object { $_.Status -eq "failure" }).Count
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
