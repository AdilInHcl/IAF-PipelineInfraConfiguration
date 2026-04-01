<#
.SYNOPSIS
This script is reponsible to turn on the VMs incase the they are shut down

.DESCRIPTION
This script is reponsible to turn on the VMs incase the they are shut down

.NOTES
    FileName:    TurnOn-LEVM.ps1
    Author:      Daniyal Ahmad
    Created:     2026-03-11

#>
param(
    [string]$CitrixCustomerId,
    [string]$citrixClientId,
    [String]$citrixPassword = $env:citrixPassword
)
asnp citrix.*

#Start the VMs in case turned off
function Start-CitrixVmIfOff {
    param(
        [Parameter(Mandatory = $true)]
        [string] $MachineName
    )

    # Get machine info from Citrix
    $machine = Get-BrokerMachine -MachineName $MachineName -ErrorAction SilentlyContinue

    if (-not $machine) {
        Write-Warning "Machine '$MachineName' not found in Citrix."
        return
    }

    $powerState = $machine.PowerState
    Write-Host "Current power state of $MachineName is: $powerState"

    if ($powerState -eq "On") {
        Write-Host "VM is already powered on. No action taken."
        return "On" #return 'On' flag incase Vm is already ON
    }

    if ($powerState -eq "Off") {
        Write-Host "VM is off. Attempting to power it on..."
        try {
            $result = New-BrokerHostingPowerAction -Action TurnOn -MachineName $MachineName
            if ($result.Action -eq 'TurnOn'){Write-Host "Power-on command sent successfully."}
        }
        catch {
            Write-Warning "Failed to start VM '$MachineName': $($_.Exception.Message)"
        }
        return "TurnedOn" #return 'TurnedOn' flag incase Vm is off and turned on
    }

    # Any other state (Suspended, Unknown, Unmanaged)
    Write-Warning "VM '$MachineName' is in state '$powerState'. No automatic action taken."
}

###############################
# Connect to Citrix Cloud
###############################
try {
    Set-XDCredentials -CustomerId $CitrixCustomerId -APIKey $citrixClientId -SecretKey $citrixPassword -ProfileType CloudApi #-StoreAs "CitrixEUConnection" -Verbose
    Write-Host "Credentials Set.."
    Get-XDAuthentication #-ProfileName "CitrixEUConnection" -Verbose
    Write-Host "Successfully logged in to the Citrix Cloud" 
}
catch{
    Write-Output "PS_ERROR_DESC= Failed to Connect to Citrix Error: $_"
    exit 1
}

# Ensure the Input file exists
$IAF_BUILD_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\b" 
$vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json" # // LE Vm info file
$jsonFilePath = Join-Path -Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName

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
    Write-Output "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
    exit 1
}


###############################
# Turn On the VM in case Off
###############################
$VmStatus = @()
foreach ($vm in $deviceInfoList){
    $Status = Start-CitrixVmIfOff -MachineName $vm.DeviceName
    $VmStatus += $Status
}

if ($VmStatus -contains 'TurnedOn'){
    Write-Output "Waiting for the Vms to turn on..."
    Start-Sleep -Seconds 60
}