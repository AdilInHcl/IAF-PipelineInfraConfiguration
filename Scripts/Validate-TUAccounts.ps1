<#
.SYNOPSIS
This script validates the  TU account details vefore assignemnt to a citrix VM.

.DESCRIPTION
This script validates TU account details before assigning them to a Citrix VM. It first checks whether any VMs are already assigned to the TU account. 
If no VMs are found, the script adds the TU account to the LE config file by mapping it to the appropriate application.

.EXAMPLE
    .\Validate-TUAccounts.ps1

.NOTES
    FileName:    Validate-TUAccounts.ps1
    Author:      Daniyal Ahmad
    Created:     2025-08-04

    Version history:
    1.0.0 - (22025-08-04) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CitrixCustomerId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$citrixClientId,

    [ValidateNotNullOrEmpty()]
    [string]$citrixPassword = $env:citrixPassword
)

#Fetch the Free Group Details from Intune
function Validate-VMAssignment {
    param (
        [string]$TU_account
    )

    # Get all machines assigned to the user
    $assignedMachines = (Get-BrokerMachine -AssociatedUserName $TU_account| measure).count
    if($assignedMachines -eq 0) {return $false}else{return $true}
}

# Connct to Citrix Cloud
Set-XDCredentials -CustomerId $CitrixCustomerId -APIKey $citrixClientId -SecretKey $citrixPassword -ProfileType CloudApi -StoreAs "CitrixEUConnection"

#connection
Get-XDAuthentication -ProfileName "CitrixEUConnection"
Write-Host "Successfully logged in to the Citrix Cloud"

# Construct path for AppsPublishList.json file created in previous stage
$AppsPublishListFileName = "AppsPublishList.json"
$AppsPublishListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishList") -ChildPath $AppsPublishListFileName

#Fetch the Count of apps to be deployed on intune
$AppsPublishList = Get-Content -Path $AppsPublishListFilePath | ConvertFrom-Json 
$AppDeployCount = ($AppsPublishList | Measure).count

# Construct path for AppsPublishList.json file created in previous stage
$TU_Accounts = "LE-TA.json"
$TU_AccountsFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath $TU_Accounts

#Fetch the TU accounts from the json File and validate if they are not assigned to a VM
$TU_AccountsLists = Get-Content -Path $TU_AccountsFilePath | ConvertFrom-Json 

#Validate the assignment for each TU account
$UnAssignedTuAccounts = @()

#Check for each account
foreach ($TU in $TU_AccountsLists.TU){
        
    $isAssigned = Validate-VMAssignment -TU_account $TU
    #Write-Host $TU" is Assigned: "$isAssigned

    #Store the unassigned accounts to the list
    if ($isAssigned -eq $false){
       $UnAssignedTuAccounts += [PSCustomObject]@{
            TUAccount   = $TU
            AppCount    = 0
        }    
    }
}

$TU_AccountCount = ($UnAssignedTuAccounts | Measure).count

# Validate the number of smoke test groups with the apps deployed in this build
Write-Host "Validating if enough TU accounts are there"
if($AppDeployCount -gt $TU_AccountCount){
    Write-Host "PS_ERROR_DESC= Aborting Pipeline. Error: Not enough TU counts are present for each Applications."
    exit 1
}

Write-Host "Tu account Validation completed.."
Write-Host "Total accounts available: $TU_AccountCount"
Write-Host "Total Apps to be assigned : $AppDeployCount"

try{
    #Set the assignment group ID to the App.json for each App
    foreach ($App in $AppsPublishList){
        Write-Host "[Setting TU account for App: $($App.IntuneAppName)]"

        #Fetch a group from the list of Smoke test groups with no devices assigned
        $TUAccountToUpdate = $UnAssignedTuAccounts | Where-Object { $_.AppCount -eq 0 } | Select-Object -First 1
        
        $account = $TUAccountToUpdate.TUAccount

        # Update the AppCount property (App assigned to smoke test group)
        if ($TUAccountToUpdate) {
            $TUAccountToUpdate.AppCount += 1
            Write-Host "$($App.IntuneAppName) will be mapped to Test account: $account"
        } 
        else {
            Write-Host "PS_ERROR_DESC= Aborting Pipeline. Error: No matching TU account "
            exit 1
        }

        #Updating the AssignList with Device Group Name
        $App | Add-Member -MemberType NoteProperty -Name "TUAccountName" -Value $account

        Write-Host "[Assignation Completed for $($App.IntuneAppName)]"
    }
    # Save the updated JSON back to the file
    Write-Host "Updated the AppPublishList.json with the TU test accounts for each app!"
    $AppsPublishList | ConvertTo-Json -Depth 10 | Set-Content $AppsPublishListFilePath
}
catch{
    Write-Host "PS_ERROR_DESC= Aborting Pipeline. Error: Failed to assign TU accounts to the AppsPublishList.json File: $_"
    exit 1
}