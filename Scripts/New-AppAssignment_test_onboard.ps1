<#
.SYNOPSIS
    This script creates assignment for the published application according to what's defined in the app specific App.json file.

.DESCRIPTION
    This script creates assignment for the published application according to what's defined in the app specific App.json file.

.EXAMPLE
    .\New-AppAssignment.ps1

.NOTES
    FileName:    New-AppAssignment_test_onboard.ps1
    Author:      Daniyal
    Contact:     Daniyal
    Created:     2023-10-08
    Updated:     2023-10-08

    Version history:
    1.0.0 - (2023-10-08) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantID,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientID,

    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:CLIENT_SECRET
)
Process {

    Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"    

    # To associate VM in Device Group 
    function Set-IntuneAppGroupAssignment {
        param(
            [Parameter(Mandatory)]
            $App,
            $AssignmentItem
        )

        Write-Output "Preparing assignment parameters for group with ID: '$($AssignmentItem.GroupID)'"

        # Base parameter set
        $AppAssignmentArgs = @{
            ID      = $AssignmentItem.ID
            GroupID = $AssignmentItem.GroupID
            Intent  = $AssignmentItem.Intent
            ErrorAction = 'Stop'
        }

        # Include / Exclude
        switch ($AssignmentItem.GroupMode.ToLower()) {
            "include" { $AppAssignmentArgs.Include = $true }
            "exclude" { $AppAssignmentArgs.Exclude = $true }
            default {
                throw "Invalid GroupMode '$($AssignmentItem.GroupMode)'. Must be 'include' or 'exclude'."
            }
        }

        # EXECUTE ASSIGNMENT
        try {
            Write-Host "Adding '$($AssignmentItem.GroupMode)' assignment with intent '$($AssignmentItem.Intent)' for group '$($AssignmentItem.GroupID)'"

            $WarningVar = $null
            $appresponse = Add-IntuneWin32AppAssignmentGroup @AppAssignmentArgs -WarningVariable WarningVar -WarningAction Continue

            if ($appresponse.'@odata.context'){
                return @{
                    Status = "Success"
                    App    = $App
                    Group  = $AssignmentItem.GroupID
                }
            }
            elseif ($WarningVar -match "duplicate assignments of this type is not permitted") {
                # Treat duplicate assignment as success
                return @{
                    Status = "Success"
                    App    = $App
                    Group  = $AssignmentItem.GroupID
                    Note   = "Assignment already existed"
                }
            }
            else {
                return @{
                    Status = "Failed"
                    App    = $App
                    Group  = $AssignmentItem.GroupID
                }
            }
        }
        catch {
            Write-Host "Failed to assign app '$($App.IntuneAppName)' to group '$($AssignmentItem.GroupID)': $($_.Exception.Message)"

            return @{
                Status = "Failed"
                App    = $App
                Group  = $AssignmentItem.GroupID
                Error  = $_.Exception.Message
            }
        }
    }

    
    # Construct path for AppsAssignList.json file created in previous stage
    $AppsAssignListFileName = "AppsAssignList.json"
    $AppsAssignListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishedList") -ChildPath $AppsAssignListFileName

    $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry

    # Retrieve authentication token using client secret from key vault
    try{
       $AuthToken = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"
    }
    catch{
        $BinaryLocation = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppsAssignList.json"
        Update-CatlogueStatus -AccessToken $token -Apps "All" -InputFilePath $BinaryLocation  -Reason "IAF - Assign App LE Group Failed"
        Write-Host "PS_ERROR_DESC= Error message: $_ "
        exit 1
    }

    if (Test-Path -Path $AppsAssignListFilePath) {
        # Read content from AppsAssignList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsAssignListFilePath)"
        $AppsAssignList = Get-Content -Path $AppsAssignListFilePath | ConvertFrom-Json

        # Process each application in list and create assignment according to what's defined in the app specific App.json file
        $failedApps = @()
        foreach ($App in $AppsAssignList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"
            $appName  = $App.IntuneAppName

           $GroupInfo =  [PSCustomObject]@{
                GroupMode = "Include"
                ID = $App.IntuneAppObjectID
                GroupID = "0f9c7422-f684-4e05-950d-0fd410caad73"
                Intent = "Available"
                ErrorAction = "Stop"
                Notification = "showAll"
            }

            $response = Set-IntuneAppGroupAssignment -App $appName -AssignmentItem $GroupInfo

            if ($response.Status -eq "Failed") {
                $failedApps += $App
                continue
            }


            # Handle current application output completed message
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
        }
    }
    else {
        Write-Output -InputObject "Attempted to read contents from: $($AppsAssignListFilePath)"
        Write-Output -InputObject "No application assignment list found, skipping assignment configuration"
    }
}