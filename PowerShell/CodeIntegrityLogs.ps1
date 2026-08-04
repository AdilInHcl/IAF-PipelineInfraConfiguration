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

###############################################################################
# FUNCTION: Wait for RunCommand Extension to Become Free
###############################################################################
function Wait-RunCommandFree {
    param(
        [string]$rgName,
        [string]$vmName,
        [int]$TimeoutMinutes = 20
    )

    $extName = "RunCommandWindows"   # Change to RunCommandLinux for Linux VMs
    $start = Get-Date

    while ($true) {

        # Check extension state
        $ext = Get-AzVMExtension `
            -ResourceGroupName $rgName `
            -VMName $vmName `
            -Name $extName `
            -ErrorAction SilentlyContinue

        # If no extension OR extension completed → safe to run
        if (-not $ext -or $ext.ProvisioningState -in @("Succeeded","Failed")) {
            #Write-Host "RunCommand free on $vmName"
            return
        }

        Write-Host "RunCommand busy on $vmName (State: $($ext.ProvisioningState)). Waiting 15 sec..."
        Start-Sleep -Seconds 15

        # Timeout protection
        if ((Get-Date) -gt $start.AddMinutes($TimeoutMinutes)) {
            Write-Warning "RunCommand stuck for more than $TimeoutMinutes minutes on $vmName"
            Write-Warning "Attempting to remove stuck RunCommand extension..."

            # Kill stuck extension
            Remove-AzVMExtension `
                -ResourceGroupName $rgName `
                -VMName $vmName `
                -Name $extName `
                -Force

            Start-Sleep -Seconds 10
            return
        }
    }
}

###############################################################################
# FUNCTION: Delete CodeIntegrity Event Logs
###############################################################################
function Delete-Eventlogs {
    param (
        [string]$rgName,
        [string]$vmName
    )

    Wait-RunCommandFree -rgName $rgName -vmName $vmName

    $script = 'wevtutil cl "Microsoft-Windows-CodeIntegrity/Operational"'
    
    $command = Invoke-AzVMRunCommand `
        -ResourceGroupName $rgName `
        -Name $vmName `
        -CommandId 'RunPowerShellScript' `
        -ScriptString $script

    return $command.Value.Message
}

###############################################################################
# FUNCTION: Modify Log Size
###############################################################################
function Modify-LogSize {
    param (
        [string]$rgName,
        [string]$vmName
    )

    Wait-RunCommandFree -rgName $rgName -vmName $vmName

    $script = 'wevtutil sl "Microsoft-Windows-CodeIntegrity/Operational" /ms:2097152'
    
    $command = Invoke-AzVMRunCommand `
        -ResourceGroupName $rgName `
        -Name $vmName `
        -CommandId 'RunPowerShellScript' `
        -ScriptString $script

    return $command.Value.Message
}

###############################################################################
# AUTHENTICATION – Service Principal Login
###############################################################################
$SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)

Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential
Select-AzSubscription -SubscriptionId $SubscriptionId

###############################################################################
# READ VM INFO JSON FILE
###############################################################################
$IAF_BUILD_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\b" 
$vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json"
$jsonFilePath = Join-Path -Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName

if (-not (Test-Path $jsonFilePath)) {
    Throw "JSON file at path '$jsonFilePath' does not exist."
}

Write-Host "Reading VM info from: $jsonFilePath"

$InputJson = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json

if ($null -eq $InputJson.Apps) {
    $finalObject = [PSCustomObject]@{
        Apps = @($InputJson)
    }
}
else {
    $finalObject = $InputJson
}

$deviceInfoList = foreach ($app in $finalObject.Apps) {
    [PSCustomObject]@{
        DeviceGroupName = $app.DeviceGroupName
        DeviceName      = $app.DeviceName
    }
}

###############################################################################
# PROCESS EACH VM
###############################################################################
foreach ($entry in $deviceInfoList) {
    $VmName = $entry.DeviceName

    try {
        Write-Host "`n----------------------------------------------------------"
        Write-Host "Processing VM: $VmName"
        Write-Host "----------------------------------------------------------"

        Delete-Eventlogs -rgName $rgName -vmName $VmName
        Write-Host "Event Log Cleared for $VmName"

        Modify-LogSize -rgName $rgName -vmName $VmName
        Write-Host "Event Log size increased for $VmName"
    }
    catch {
        Write-Warning "PS_ERROR_DESC= Failed to modify Code Integrity logs for device '$VmName'. $_"
        exit 1
    }
}