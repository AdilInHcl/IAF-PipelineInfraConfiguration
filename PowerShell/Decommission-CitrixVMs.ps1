<#
.SYNOPSIS
Decommissions Citrix VMs by removing them from Delivery Groups, powering them off, and cleaning up associated AD and provisioning objects.

.DESCRIPTION
This script connects to Azure and Citrix Cloud using service principals and decommissions virtual machines (VDIs) from specified Citrix Delivery Groups.

.NOTES
FileName:    Decommission-CitrixVMs.ps1
Author:      Mo Adil Ansari
Created:     2025-08-05

Version history:
1.0.0 - Initial version
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CitrixCustomerId,

    [Parameter(Mandatory = $true)]
    [string]$citrixClientId,
    
    [string]$citrixPassword = $env:citrixPassword,
    [string]$CatalogName = $env:LEClient_CatalogName
)

# Load Citrix PowerShell modules
asnp citrix.*

# Authenticate to Citrix Cloud using CloudAPI credentials
Set-XDCredentials -CustomerId $CitrixCustomerId -APIKey $citrixClientId -SecretKey $citrixPassword -ProfileType CloudApi -StoreAs "CitrixEUPackagingConnection"

# Initiate authentication session using saved profile
Get-XDAuthentication -ProfileName "CitrixEUPackagingConnection"
Write-Host "Successfully logged in to the Citrix Cloud."

# Ensure the Input file exists
$VMInfoFileName = $env:Input_File_name
$JsonFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName

if (Test-path $JsonFilePath){
    # Load list of virtual machines from a JSON file
    Write-Host "Fetching the vm names from" $JsonFilePath
    $vmList = Get-Content -Path $JsonFilePath | ConvertFrom-Json
    Write-Host $vmList.Apps.DeviceName
}else{
    Write-Host "$JsonFilePath not present"
    exit 1
}


# Get the catalog name to  clean up AD accounts
$brokercatalog = (Get-BrokerCatalog -CatalogName $CatalogName).CatalogName
Write-Host "CatalogName is $brokercatalog"

# Loop through each VM in the list
foreach ($vm in $vmList.Apps) {
    # Extract machine name from JSON object
    $machineName = $vm.DeviceName

    # Retrieve machine details from Citrix Broker
    $vmObject = Get-BrokerMachine -MachineName $machineName
    $desktopGroup = $vmObject.DesktopGroupName
    $id = $vmObject.SID  # Security Identifier for the machine AD account

    try {
        # If machine is in a Delivery Group, remove it
        if ($desktopGroup) {
            Write-Host "Removing $machineName from Delivery Group $desktopGroup..."
            Remove-BrokerMachine -InputObject $vmObject -DesktopGroup $desktopGroup -Force
        }
        else {
            Write-Host "$machineName is not in a Delivery Group. Proceeding to remove from Broker DB."
        }

        # Disable maintenance mode
        Write-Host "Setting machine $machineName into Maintenance mode"
        Set-BrokerMachine -MachineName $machineName -InMaintenanceMode $false

        # Power off the virtual machine
        Write-Host "Powering off machine $machineName"
        New-BrokerHostingPowerAction -Action TurnOff -MachineName $machineName

        # Wait for VM to shutdown
        Start-Sleep -Seconds 20

        # Unlock VM for removal from provisioning
        Write-Host "Unlocking and removing VM from provisioning"
        Get-ProvVM -VMName $machineName | Unlock-ProvVM

        # Remove VM from provisioning system
        Get-ProvVM -VMName $machineName | Remove-ProvVM

        # Remove machine object from Citrix Broker
        Write-Host "Removing machine object from broker..."
        Remove-BrokerMachine -MachineName $machineName
        Write-Host "Machine $machineName has been fully decommissioned."

        # Clean up associated AD account from the identity pool
        Remove-AcctADAccount -IdentityPoolName $brokercatalog -ADAccountSid $id -RemovalOption None -UseServiceAccount -Force
    }
    catch {
        # Handle any errors that occurred during the process
        Write-Host "Failed to decommission machine $machineName : $_"
    }
}
