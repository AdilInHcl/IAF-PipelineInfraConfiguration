<#
.SYNOPSIS
    Deletes and modifies the Code Integrity event log on an Azure VM.

.DESCRIPTION
    This script deletes the "Microsoft-Windows-CodeIntegrity/Operational" event logs and modifies the log size to 2MB on the specified Azure VM. It connects to Azure using a service principal and runs commands remotely on the VM.

.NOTES
    FileName: CodeIntegrityLogs.ps1
    Author: Mo Adil Ansari & Daniyal Ahmad
    Version: 1.0
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    #[parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:PROD_CLIENT_SECRET_LE,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    # Azure VM and Resource Group parameter
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$rgName
)

# Script to delete EventLogs
function Delete-Eventlogs {
    param (
        [string]$rgName,
        [string]$vmName
    )

    # Script to run on the VM
    $script = 'wevtutil cl "Microsoft-Windows-CodeIntegrity/Operational"'
    
    # Execute the command
    $command = Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $script

    # Output the result
    return $command.Value.Message
}

# Script to modify log size for CodeIntegrity
function Modify-LogSize {
    param (
        [string]$rgName,
        [string]$vmName
    )

    # Script to run on the VM
    $script = 'wevtutil sl "Microsoft-Windows-CodeIntegrity/Operational" /ms:2097152'
    
    # Execute the command
    $command = Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $script

    # Output the result
    return $command.Value.Message
}

#======================== Connect AzAccount for remote VM access ==========================
$SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)

# Authenticate with Azure using the service principal
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential

# Set the subscription context
Select-AzSubscription -SubscriptionId $SubscriptionId

#=========== Set the VM Name and Resource Group Name ==================

# Ensure the Input file exists
$IAF_BUILD_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\b" 
$vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json" # // LE Vm info file
$jsonFilePath = Join-Path -Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName

# Check if the JSON file exists
if (Test-Path $jsonFilePath) {
    
    Write-Host "Reading apps from: $jsonFilePath"

    # Load JSON data
    $InputJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json

    # Normalize: always wrap into .Apps
    if ($null -eq $InputJson.Apps) {
        # Legacy single app JSON → wrap it
        $finalObject = [PSCustomObject]@{
            Apps = @($InputJson)
        }
    }
    else {
        # Already has Apps → just keep as is
        $finalObject = $InputJson
    }

    # Initialize a list to store DeviceGroupName and DeviceName from JSON
    $deviceInfoList = @()

    foreach ($app in $finalObject.Apps) {
        $deviceInfo = [PSCustomObject]@{
            DeviceGroupName = $app.DeviceGroupName
            DeviceName      = $app.DeviceName
        }
        $deviceInfoList += $deviceInfo
    }
}
else {
    Throw "JSON file at path '$jsonFilePath' does not exist."
    exit 1
}

$ResourceGroupName = $rgName

foreach ($entry in $deviceInfoList) {
    $VmName = $entry.DeviceName

    try {
        # Calling the functions with the passed parameters
        Delete-Eventlogs -rgName $ResourceGroupName -vmName $VmName
        Write-Host "Event Log Cleared for $VmName"

        Modify-LogSize -rgName $ResourceGroupName -vmName $VmName
        Write-Host "Event Log size increased for $VmName"
    }
    catch {
        Write-Warning "PS_ERROR_DESC= Failed to modify code Integrity logs for device '$($VmName)'. $_"
        exit 1
    }
}