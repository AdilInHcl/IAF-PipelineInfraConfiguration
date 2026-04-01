[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:PROD_CLIENT_SECRET_LE,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName
)

try {
    Write-Host "Starting app installation verification via Allianz Registry"
    
    # Ensure the Input file exists
    $vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json" # // LE Vm info file
    $sourceJsonFileName = "LEAppList_$env:IAF_JOBNAME`_$env:IAF_BUILD.json"    
    $sourceJsonFile = Join-Path -Path $env:LEConfigJsonPath -ChildPath $sourceJsonFileName
    $destJsonFile = Join-Path -Path $env:IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName
    
    Write-Host "Source JSON: $sourceJsonFile"
    Write-Host "Destination JSON: $destJsonFile"
    
    # Check if files exist
    if (-not (Test-Path $sourceJsonFile)) {
        Write-Output "PS_ERROR_DESC= Source JSON file not found at: $sourceJsonFile"
        exit 1
    }
    
    if (-not (Test-Path $destJsonFile)) {
        Write-Output "PS_ERROR_DESC= Destination JSON file not found at: $destJsonFile"
        exit 1
    }
    
    # Read JSON files
    $sourceData = Get-Content -Path $sourceJsonFile -Raw | ConvertFrom-Json
    $destData = Get-Content -Path $destJsonFile -Raw | ConvertFrom-Json
    
    Write-Host "Source apps count: $($sourceData.Apps.Count)"
    Write-Host "Destination apps count: $($destData.Apps.Count)"
    
    # Authenticate with Azure
    Write-Host "Authenticating with Azure"
    $SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)
    Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential | Out-Null
    Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
    
    $installedCount = 0
    $notInstalledCount = 0
    $verificationFailedCount = 0
    
    # Process each app in destination JSON
    foreach ($destApp in $destData.Apps) {
        $familyId = $destApp.FamilyID
        $deviceName = $destApp.DeviceName
        
        # Find matching app in source JSON by FamilyID
        $sourceApp = $sourceData.Apps | Where-Object { $_.FamilyID -eq $familyId }
        
        if (-not $sourceApp) {
            Write-Host "Warning: No matching app found in source JSON for FamilyID: $familyId"
            $destApp | Add-Member -NotePropertyName "InstallationCheck" -NotePropertyValue "Failed" -Force
            $notInstalledCount++
            continue
        }
        
        $packageName = $sourceApp.PackageName
        $intuneAppName = $sourceApp.IntuneAppName
        
        Write-Host "Verifying: $intuneAppName (FamilyID: $familyId, Package: $packageName) on VM: $deviceName"
        
        try {
            # Build registry check script
            $script = @"
`$path = "HKLM:\SOFTWARE\AllianzPackages\$packageName"
`$props = Get-ItemProperty -Path `$path -ErrorAction SilentlyContinue
if (`$props -ne `$null) {
    `$output = [PSCustomObject]@{
        PackageName  = "$packageName"
        Installed    = `$props.Installed
        PackageMode  = `$props.PackageMode
        InstallDate  = `$props.InstallDate
        Revision     = `$props.PackageRevision
        Platform     = `$props.Platform
        Version      = `$props.Version
        PSADTVersion = `$props.'PSADT Version'
    }
    `$output | ConvertTo-Json -Compress
} else {
    Write-Output '{"Error":"Package not found or missing properties."}'
}
"@
            
            # Execute on VM
            $command = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $deviceName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
            $result = $command.Value[0].Message.Trim()
            
            # Parse JSON result
            try {
                $json = $result | ConvertFrom-Json -ErrorAction Stop
                
                if ($json.Error) {
                    $destApp | Add-Member -NotePropertyName "InstallationCheck" -NotePropertyValue "Failed" -Force
                    Write-Host "  Result: Not installed"
                    $notInstalledCount++
                } else {
                    $destApp | Add-Member -NotePropertyName "InstallationCheck" -NotePropertyValue "Pass" -Force
                    Write-Host "  Result: Installed (Version: $($json.Version))"
                    $installedCount++
                }
            } catch {
                $destApp | Add-Member -NotePropertyName "InstallationCheck" -NotePropertyValue "Failed" -Force
                Write-Host "  Result: Invalid JSON returned (marked as Pass - fail-safe)"
                $verificationFailedCount++
            }
            
        } catch {
            $destApp | Add-Member -NotePropertyName "InstallationCheck" -NotePropertyValue "Failed" -Force
            Write-Host "  Result: Verification failed (marked as Pass - fail-safe)"
            $verificationFailedCount++
        }
    }
    
    # Save updated JSON
    $updatedJson = $destData | ConvertTo-Json -Depth 10
    Set-Content -Path $destJsonFile -Value $updatedJson
    
    Write-Host "Verification complete. Installed: $installedCount, Not installed: $notInstalledCount, Failed: $verificationFailedCount"
    Write-Host "Updated file: $destJsonFile"

    if ($notInstalledCount -eq $sourceData.Apps.Count){
        Write-Output "No Apps were installed"
    }
    
} 
catch {
    Write-Host "Error during app installation verification: $($_.Exception.Message)"
    Write-Output "PS_ERROR_DESC= Error in Verify-AppInstallation-OnVM.ps1 script: $_"
    exit 1
}
