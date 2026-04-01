<#
.SYNOPSIS
This script connects to citrix using a service principal and creates virtual machines for smoke testing.

.DESCRIPTION
This script connects to citrix using a service principal and creates virtual machines based on LE VM Creation JSON input.

.NOTES
    FileName:    Citrix-Add-Machine-LEVM.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
param(
    [string]$CitrixCustomerId,
    [string]$CatalogName,
    [string]$Tenant,
    [string]$SubscriptionId,
    [string]$resourceGroupName,
    [string]$clientId,
    [string]$clientSecret = $env:CLIENT_SECRET,
    [string]$citrixClientId,
    [String]$citrixPassword = $env:citrixPassword,
    [string]$DeliveryGroupName,
    [string]$CitrixIdpInstanceId,
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET
)
Import-Module Az.Accounts
Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"
Set-ExecutionPolicy Bypass -Scope Process -Force
asnp citrix.*

# Genrate Token for the Catalogue Access
$token = Get-CatalogueAccessToken -username $username -password $password

#Fetch the json file where all the information regarding VM is present
$LEVMCreationFileName = $env:Input_File_name
$LEVMCreationDataBasePath = $env:BUILD_BINARIESDIRECTORY
$LEVMCreationDataFilePath = Join-Path -Path $LEVMCreationDataBasePath -ChildPath $LEVMCreationFileName

#Count How many VMs reguired
$LEVMCreationData = Get-Content -Path $LEVMCreationDataFilePath| ConvertFrom-Json
$VDICount = ($LEVMCreationData.Apps|Measure).count
$EmailCount = ($LEVMCreationData.Apps|Measure).count

##########################################################################################################
#                                    Login to Citrix
##########################################################################################################
try {
    # Connect to Citrix Cloud
    Set-XDCredentials -CustomerId $CitrixCustomerId -APIKey $citrixClientId -SecretKey $citrixPassword -ProfileType CloudApi #-StoreAs "CitrixEUConnection" -Verbose
    Write-Host "Credentials Set.."
    Get-XDAuthentication #-ProfileName "CitrixEUConnection" -Verbose
    Write-Host "Successfully logged in to the Citrix Cloud"
}
catch{
    Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - LE VM Creation failed" -InputFilePath $LEVMCreationDataFilePath
    Write-Output "PS_ERROR_DESC= Failed to Connect to Citrix Error: $_"
    exit 1
}

##########################################################################################################
#                                    Add VM to the Machine Catlogue
##########################################################################################################
#OutputCatalog Name for Troubleshooting
Write-Host "Catalog Name: $CatalogName"
try {
    $adaccounts = New-AcctADAccount -IdentityPoolName $CatalogName -Count $VDICount -UseServiceAccount

    # Creating the VM(s) using the names list from the previous command
    Write-Host "Creating the virtual machine(s)... " -NoNewline
    $provTaskId = New-ProvVM -AdAccountName $adaccounts.SuccessfulAccounts -ProvisioningSchemeName $CatalogName -RunAsynchronously -ErrorAction Stop

    # Display a progress bar in case of a large number of VMs creation
    $provtask = Get-ProvTask -TaskId $provTaskId
    $totalpercent = 0

    While ($provtask.Active -eq $true) {
        try {
            $totalpercent = If ($provTask.TaskProgress) { $provTask.TaskProgress } else { 0 }
        }
        catch {
        }
        Write-Progress -Activity "Tracking progress" -status "$totalpercent% Complete:" -percentComplete $totalpercent
        Start-Sleep 3
        $provtask = Get-ProvTask -TaskId $provTaskId
    }

    Write-Host "OK" 
}
catch{
    Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - LE VM Creation failed" -InputFilePath $LEVMCreationDataFilePath
    Write-Output "PS_ERROR_DESC= Failed to Create VM Error: $_"    
    exit 1
}

##########################################################################################################
#                                    Add VM to the Delivery Group
##########################################################################################################
try {
    # Get the ProvisioningSchemeUid to add the VM(s) to the catalog
    Write-Host "Getting Provisioning Scheme Uid... " -NoNewline
    $ProvSchemeUid = (Get-ProvScheme -ProvisioningSchemeName $CatalogName).ProvisioningSchemeUid.Guid
    Write-Host "$ProvSchemeUid found" 

    # Finding the catalog UID to attach the VM(s) to
    Write-Host "Finding Catalog's UId... " -NoNewline
    $Uid = (Get-BrokerCatalog -CatalogName $CatalogName).Uid
    Write-Host "$Uid found" 

    # Listing the newly created VM(s) in order to add them to the catalog. "Brokered" tag means the VM is created but not attached
    # We are listing those
    $ProvVMS = Get-ProvVM -ProvisioningSchemeUid $ProvSchemeUid -MaxRecordCount 10000 | Where-Object { $_.Tag -ne "Brokered" }
    Write-Host "Assigning newly created machines to $CatalogName..."
    Write-Host "Virtual machines are as follows" 

    #Provising Actual VM's
    $ProvVMS | Lock-ProvVM -ProvisioningSchemeUid $ProvSchemeUid -Tag 'Brokered'
    $ProvVMS | ForEach-Object { New-BrokerMachine -CatalogUid $Uid -MachineName $_.ADAccountSid }

    Write-Host "$VDIcount VDIs created in $CatalogName" 

    #Fetching Delivery Group Since the Folder Arrangement inside DaaS Console messes up the script...

    $dg = Get-BrokerDesktopGroup -DesktopGroupName $DeliveryGroupName

    #adding machines to the delivery Group
    Write-Host "Adding Machines to the Delivery Group" 
    foreach ($vm in $ProvVMS.ADAccountName) 
        { Add-BrokerMachine -MachineName $vm -DesktopGroup $dg.Name }
}
catch{
    Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - LE VM Creation failed" -InputFilePath $LEVMCreationDataFilePath
    Write-Output "PS_ERROR_DESC= Failed to Add VM to Delivery Group Error: $_"
    exit 1
}


#Giving 1 Minute sleep time to sync the machines' power state with Studio and PowerON the machine.
Write-Host "1 Minute Sleep time to let machines sync their power states with Citrix DaaS"
Start-Sleep -Seconds 60

#Turning ON the VMs
Write-Host "Turning ON the newly created Machines..."
foreach ($vm in $ProvVMS.ADAccountName) 
    { $VmOn = New-BrokerHostingPowerAction -Action TurnOn -MachineName $vm }

Write-Host "OK..."

##########################################################################################################
#                                 Map User to the the VM created
##########################################################################################################
Write-Host "Assigning Users to the VDIs based on the Email Addresses Provided..."

Write-Host "Emails to be added: $EmailCount"

$machines = @($ProvVMS.VMName)
$count = 0

$FailedAssignedApps = @()

# Regex for matching a GUID (used for OID)
$guidRegex = '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'

foreach ($user in $LEVMCreationData.Apps){
    $userEmail = $user.TUAccount
    $machine = $machines[$count]

    Write-Host "Assigning user $userEmail to machine $machine"
    try {
        $PrimaryClaimRaw = (Get-BrokerUser -Name $userEmail).PrimaryClaim
        $oidMatch = [regex]::Match($PrimaryClaimRaw, $guidRegex)

        if ($oidMatch.Success) {
            $PrimaryClaim = $oidMatch.Value
            $userClaim = "AzureAD:$CitrixIdpInstanceId\$Tenant\$PrimaryClaim"
            Add-BrokerUser -Name $userClaim -PrivateDesktop $machine -ErrorAction Stop
            $user | Add-Member -MemberType NoteProperty -Name "DeviceName" -Value $machine
            Write-Host "Assigned: $userEmail to $machine with OID $PrimaryClaim"
            $count += 1

        }
        else {
            Write-Warning "Skipping user $userEmail - Could not extract OID from PrimaryClaim: $PrimaryClaimRaw"
            $FailedAssignedApps += $user

        }
    }
    catch {
        Write-Error "PS_ERROR_DESC= Failed to assign $userEmail to $machine - $_"
        $FailedAssignedApps += $user
    }
}

# Save the updated JSON back to the file
$finalObject = $LEVMCreationData.Apps | Where-Object {$null -ne $_.DeviceName}
$finalObject = [PSCustomObject]@{
    Apps = $finalObject
}

#Fail the Pipeline If all Vms failed to be assigned
if (@($finalObject.Apps).Count -eq 0 ){
    Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - LE VM Creation failed"
    Write-Output "The Devices Failed to assign to users."
    exit 1
}

#Set the catalogue status for the apps where user  user assignation failed on VMs
if ($FailedAssignedApps.Count -ne 0 ){
    Write-Host "Updating Catalogue entry for the below Apps: "
    Write-Host $FailedAssignedApps.IntuneAppName
    Update-CatlogueStatus -AccessToken $token -Apps $FailedAssignedApps -Reason "IAF - LE VM Creation failed"
}

#Updated JSON for the group assignation
Write-Host "Updating the Device (VM) names in the $LEVMCreationDataFilePath"
$finalObject | ConvertTo-Json -Depth 10 | Set-Content $LEVMCreationDataFilePath