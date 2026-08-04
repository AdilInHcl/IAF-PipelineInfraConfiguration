<#
.SYNOPSIS
This script connects to citrix using a service principal and creates virtual machines for IAT testing.

.DESCRIPTION
This script connects to citrix using a service principal and creates virtual machines based on LE VM Creation JSON input.

.NOTES
    FileName:    Citrix-Add-Machine-IATClient.ps1
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
    [string]$CitrixIdpInstanceId
)
Import-Module Az.Accounts
Import-Module "$($env:WORKSPACE)/Scripts/CitrixConnect.psm1"
Set-ExecutionPolicy Bypass -Scope Process -Force
asnp citrix.*

#Fetch the json file where all the information regarding VM is present
$IATVMCreationFileName = "APP_IAT.json"
$IATVMCreationDataFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $IATVMCreationFileName

#Count How many VMs reguired
$IATVMCreationData = Get-Content -Path $IATVMCreationDataFilePath| ConvertFrom-Json
Write-Host "Apps detected for IAT :  [$($IATVMCreationData.Apps.IntuneAppName)]"

# Map to track user-machine assignments
$vmEmailMap = @()

foreach ($App in $IATVMCreationData.Apps) {
    $IATUsers = $App.Users
    foreach ($user in $IATUsers) {

        #Object to save the email mapping
        $VMinfo = [PSCustomObject]@{
            User = $user
            Device = $null
            Status = $null
            IntuneAppName = $App.IntuneAppName
            AppID = $App.AppID
        }

        $vmEmailMap += $VMinfo
    }
}

#Total VMs Required
$VDICount = @($vmEmailMap).Count

##########################################################################################################
#                                    Login to Citrix
##########################################################################################################
try {
    Connect-Citrix
}
catch{
    Write-Output "PS_ERROR_DESC= Failed to Connect to Citrix Error: $_"
    exit 1
}

##########################################################################################################
#                                    Add VM to the Machine Catlogue
##########################################################################################################
#OutputCatalog Name for Troubleshooting
Write-Host "Catalog Name: $CatalogName"
Write-Host "Number of users detected: $VDICount"

try {
    $adaccounts = New-AcctADAccount -IdentityPoolName $CatalogName -Count $VDICount -UseServiceAccount

    # Creating the VM(s) using the names list from the previous command
    Write-Host "Creating the virtual machine(s)... " -NoNewline
    $provTaskId = New-ProvVM -AdAccountName $adaccounts.SuccessfulAccounts -ProvisioningSchemeName $CatalogName -RunAsynchronously -ErrorAction Stop

    # Display a progress bar in case of a large number of VMs creation
    $provtask = Get-ProvTask -TaskId $provTaskId    

}
catch{
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
    Write-Output "PS_ERROR_DESC= Failed to Add VM to Delivery Group Error: $_"
    exit 1
}


#Giving 1 Minute sleep time to sync the machines' power state with Studio and PowerON the machine.
Write-Host "Wait for machines to sync their power states with Citrix DaaS"
Start-Sleep -Seconds 120

#Turning ON the VMs
Write-Host "Turning ON the newly created Machines..."
foreach ($vm in $ProvVMS.ADAccountName) 
{ $VM_TurnON = New-BrokerHostingPowerAction -Action TurnOn -MachineName $vm }

Write-Host "Vms Turned On... [$($ProvVMS.VMName)]"

##########################################################################################################
#                                 Map User to the the VM created
##########################################################################################################
Write-Host "Assigning Users to the VDIs based on the Email Addresses Provided..."

#Assigning VDIs to the Users
$machines = @($ProvVMS.VMName)
Write-Host "VMs Provisioned:"
Write-Host $machines

# Regex for matching a GUID (used for OID)
$guidRegex = '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'

# # Validate count matches
# if (@($machines).Count -ne $VDICount) {
#     throw "Mismatch in email and VDI count. Emails: $($emailList.Count), VDIs: $VDICount"
# }

# Loop through VMs and emails
for ($i = 0; $i -lt $VDICount; $i++) {
    $machine = $machines[$i]
    $userEmail = $vmEmailMap[$i].User

    Write-Host "Assigning user $userEmail to machine $machine"

    try {
        $PrimaryClaimRaw = (Get-BrokerUser -Name $userEmail).PrimaryClaim
        $oidMatch = [regex]::Match($PrimaryClaimRaw, $guidRegex)

        if ($oidMatch.Success) {
            $PrimaryClaim = $oidMatch.Value
            $userClaim = "AzureAD:$CitrixIdpInstanceId\$Tenant\$PrimaryClaim"
            Add-BrokerUser -Name $userClaim -PrivateDesktop $machine -ErrorAction Stop
            $vmEmailMap[$i].Device = $machine
            $vmEmailMap[$i].Status = "Assigned"
            Write-Host "Assigned: $userEmail to $machine with OID $PrimaryClaim"
        }
        else {
            Write-Warning "Skipping user $userEmail - Could not extract OID from PrimaryClaim: $PrimaryClaimRaw"
            $vmEmailMap[$i].Device = $machine
            $vmEmailMap[$i].Status = "Failed"
            
        }
    }
    catch {
        Write-Output "PS_ERROR_DESC= Failed to assign $userEmail to $machine - $_"
        $vmEmailMap[$i].Device = $machine
        $vmEmailMap[$i].Status = "Failed"
    }
}

##########################################################################################################
#                                 # Tagging with expiration and owner
##########################################################################################################
Import-Module Az.Accounts -Force
# Wait for sync with Azure
Write-Host "Waiting for Azure sync before tagging..."
Start-Sleep -Seconds 60

# Azure login
$secureKey = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$AzureCredential = New-Object System.Management.Automation.PSCredential($clientId, $secureKey)

Disable-AzContextAutosave
Connect-AzAccount -Credential $AzureCredential -Tenant $Tenant -Subscription $SubscriptionId -ServicePrincipal
Write-Host "Successfully logged in to Azure" -ForegroundColor Green

$currentDate = Get-Date
$expirationDate = $currentDate.AddDays(5).ToString('yyyy-MM-dd')

foreach ($userinfo in $vmEmailMap) {
    $owner = $userinfo.User
    $vmName = $userinfo.Device

    try {
        $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -ErrorAction Stop
        $tags = $vm.Tags
        if (-not $tags) { $tags = @{} }

        $tags["ExpirationDate"] = $expirationDate
        $tags["Owner"] = $owner
        $tags["ExtendCount"] = "0"

        Set-AzResource -ResourceId $vm.Id -Tag $tags -Force -ErrorAction Stop
        Write-Host "$($vm.Name) tagged with Owner=$owner and ExpirationDate=$expirationDate"
    }
    catch {
        Write-Error "PS_ERROR_DESC= PSFailed to tag $vmName $_"
        exit 1  # This will stop the script and signal failure to Jenkins
    }
    
}

#Update the IAT List with the user, devices and apps mapping
Write-Host "Mapped the users with Devices"
$IATUSERDEVICEJSON = $vmEmailMap | ConvertTo-Json -Depth 3
$IATUSERDEVICEJSON | Out-File -FilePath $IATVMCreationDataFilePath -Encoding utf8