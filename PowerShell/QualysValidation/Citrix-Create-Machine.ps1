<#
.SYNOPSIS
This script connects to citrix using a service principal and creates virtual machines for smoke testing.

.DESCRIPTION
This script connects to citrix using a service principal and creates virtual machines based on LE VM Creation JSON input.

.NOTES
    FileName:    Citrix-Create-Machine.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
param(
    [string]$CitrixCustomerId,
    [string]$CatalogName,
    [string]$Tenant,
    [string]$clientId,
    [string]$clientSecret = $env:CLIENT_SECRET,
    [string]$citrixClientId,
    [String]$citrixPassword = $env:citrixPassword,
    [string]$DeliveryGroupName,
    [string]$CitrixIdpInstanceId,
    [string]$resourceGroupName,
    [string]$SubscriptionId
)
Import-Module Az.Accounts
Import-Module "$($env:WORKSPACE)/Scripts/CitrixConnect.psm1"
Set-ExecutionPolicy Bypass -Scope Process -Force
asnp citrix.*

#IT returns the IP address of the VMs
function Get-VMPrivateIP{
    param (
    [Parameter(Mandatory=$true)]
    [string]$resourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$vmName
    )

    # Get NIC attached to the VM
    $nicId = (Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName).NetworkProfile.NetworkInterfaces[0].Id
    $nic   = Get-AzNetworkInterface -ResourceId $nicId

    # Fetch private IP
    $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
    return $privateIp


}

#Count How many VMs reguired
$VDICount = 1

##########################################################################################################
#                                    Login to Citrix
##########################################################################################################
try {
    # Connect to Citrix Cloud
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
    Write-Host "$($ProvVMS.VMname)"

    #Provising Actual VM's
    $ProvVMS | Lock-ProvVM -ProvisioningSchemeUid $ProvSchemeUid -Tag 'Brokered' | Out-Null
    $ProvVMS | ForEach-Object { New-BrokerMachine -CatalogUid $Uid -MachineName $_.ADAccountSid } | Out-Null

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
Write-Host "1 Minute Sleep time to let machines sync their power states with Citrix DaaS"
Start-Sleep -Seconds 60

#Turning ON the VMs
Write-Host "Turning ON the newly created Machines..."
foreach ($vm in $ProvVMS.ADAccountName) 
    { $VmOn = New-BrokerHostingPowerAction -Action TurnOn -MachineName $vm }

Write-Host "Machine Created and Turned ON"


Write-Host "5 Minute Sleep time to let machines sync with Azure."
Start-Sleep -Seconds 300

##########################################################################################################
#                                   Save the VM Name to a temp file
##########################################################################################################

# Convert client secret to a secure string and create credential object
$SecurePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$Credential     = New-Object System.Management.Automation.PSCredential ($clientId, $SecurePassword)

# Connect to Azure using Service Principal
$connection = Connect-AzAccount -ServicePrincipal -Tenant $Tenant -Credential $Credential
$connection = Select-AzSubscription -SubscriptionId $SubscriptionId

$IP = Get-VMPrivateIP -resourceGroup $resourceGroupName -vmName $ProvVMS.VMName

$scantime = Get-Date  #Fetch the TImestamp scan was triggered
$utcTime  = [datetime]::Parse($scantime)
$scancurrentTime = $utcTime.ToLocalTime()               

$vm_Details = [PSCustomObject]@{
    DeviceName = $ProvVMS.VMName
    IPaddress = $IP
    CreatedOn = $scancurrentTime.DateTime
}

$vm_Details = $vm_Details | ConvertTo-Json

$OutfileName = "VM_Details_baseline.txt"
$Outfolder = $env:DAILYSCANBASEFOLDER

#Create folder if not present
if(-not (Test-Path $Outfolder)){New-Item -Path $Outfolder -ItemType "Directory" -Force | Out-Null}

$OutFilePath = Join-Path -Path $Outfolder -ChildPath $OutfileName
Out-File -InputObject $vm_Details -FilePath $OutFilePath