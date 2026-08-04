<#
.SYNOPSIS
    This .psm1 module connects to citrix and performs citrix related functions

.DESCRIPTION
    This .psm1 module connects to citrix and performs citrix related functions

.NOTES
    FileName: UpdateCatalogue.psm1
    Author : Daniyal Ahmad
#>

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

