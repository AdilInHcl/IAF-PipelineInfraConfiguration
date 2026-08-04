<#
.SYNOPSIS
This script is reponsible to restart the VMs incase the they are shut down

.DESCRIPTION
This script is reponsible to restart the VMs incase the they are shut down

.NOTES
    FileName:    Restart-LEVM.psm1
    Author:      Daniyal Ahmad
    Created:     2026-04-30

#>
#Start the VMs in case turned off
function Restart-CitrixVm {
    param(
        [Parameter(Mandatory = $true)]
        $Machines
    )

    foreach($MachineName in $Machines){
        # Get machine info from Citrix
        $machine = Get-BrokerMachine -MachineName $MachineName -ErrorAction SilentlyContinue

        if (-not $machine) {
            Write-Warning "Machine '$MachineName' not found in Citrix."
            continue
        }

        $powerState = $machine.PowerState
        Write-Host "Current power state of $MachineName is: $powerState"

        try {
            switch ($powerState) {

                "On" {
                    Write-Host "VM is ON. Attempting restart..."
                    $result = New-BrokerHostingPowerAction -Action Restart -MachineName $MachineName
                    if ($result.Action -eq "Restart") {
                        Write-Host "Restart command sent successfully."
                    }
                }

                "Off" {
                    Write-Host "VM is OFF. Powering it ON..."
                    $result = New-BrokerHostingPowerAction -Action TurnOn -MachineName $MachineName
                    if ($result.Action -eq "TurnOn") {
                        Write-Host "Power-on command sent successfully."
                    }
                }
                default {
                    Write-Warning "VM '$MachineName' is in state '$powerState'. No automatic action taken."
                }
            }
        }
        catch {
            Write-Warning "Failed to restart VM '$MachineName': $($_.Exception.Message)"
        }
    }

    #Wait for the VMs to restart 
    Start-Sleep -Seconds 120
}

###############################
# Connect to Citrix Cloud
###############################
function Connect-Citrix {
    param(
        [string]$CitrixCustomerId = $env:CitrixCustomerId,
        [string]$citrixClientId   = $env:citrixClientId,
        [string]$citrixPassword   = $env:citrixPassword,
        [int]$MaxRetries          = 10
    )

    $ProfileName = "ApiCred"

    for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {

        try {
            Write-Host "Connecting to Citrix Cloud (Attempt $Attempt of $MaxRetries)..."

            # First try existing profile
            try {
                Write-Host "Trying existing Citrix profile: $ProfileName"

                $Auth = Get-XDAuthentication `
                    -ProfileName $ProfileName `
                    -Force `
                    -ErrorAction Stop

                Write-Host "Successfully authenticated using existing profile."

                return $Auth
            }
            catch {
                Write-Warning "Existing profile failed. Recreating profile..."
            }

            # Recreate profile
            $SetToken = Set-XDCredentials `
                -CustomerId $CitrixCustomerId `
                -APIKey $citrixClientId `
                -SecretKey $citrixPassword `
                -ProfileType CloudApi `
                -StoreAs $ProfileName `
                -ErrorAction Stop

            Write-Host "Credentials stored successfully."

            Start-Sleep -Seconds 5

            # Authenticate using newly created profile
            $Auth = Get-XDAuthentication `
                -ProfileName $ProfileName `
                -Force `
                -ErrorAction Stop

            Write-Host "Successfully logged in to Citrix Cloud."

            return $Auth
        }
        catch {

            Write-Warning "Citrix authentication attempt $Attempt failed."
            Write-Warning "Error: $($_.Exception.Message)"

            if ($_.Exception.InnerException) {
                Write-Warning "Inner Error: $($_.Exception.InnerException.Message)"
            }

            # Only clear profile on final failure
            if ($Attempt -eq $MaxRetries) {

                if (Get-Command Clear-XDCredentials -ErrorAction SilentlyContinue) {
                    Clear-XDCredentials `
                        -ProfileName $ProfileName `
                        -ErrorAction SilentlyContinue
                }

                Write-Output "PS_ERROR_DESC= Failed to Connect to Citrix after $MaxRetries attempts. Error: $($_.Exception.Message)"
                throw
            }

            Start-Sleep -Seconds (10 * $Attempt)
        }
    }
}
