<#

.SYNOPSIS
PSAppDeployToolkit.Extensions - Provides the ability to extend and customize the toolkit by adding your own functions that can be re-used.

.DESCRIPTION
This module is a template that allows you to extend the toolkit with your own custom functions.

This module is imported by the Invoke-AppDeployToolkit.ps1 script which is used when installing or uninstalling an application.

#>

##*===============================================
##* MARK: MODULE GLOBAL SETUP
##*===============================================

# Set strict error handling across entire module.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

$adtSession = Get-ADTSession

##*===============================================
##* MARK: FUNCTION LISTINGS
##*===============================================

function New-ADTExampleFunction
{
    <#
    .SYNOPSIS
        Basis for a new PSAppDeployToolkit extension function.

    .DESCRIPTION
        This function serves as the basis for a new PSAppDeployToolkit extension function.

    .INPUTS
        None

        You cannot pipe objects to this function.

    .OUTPUTS
        None

        This function does not return any output.

    .EXAMPLE
        New-ADTExampleFunction

        Invokes the New-ADTExampleFunction function and returns any output.
    #>

    [CmdletBinding()]
    param
    (
    )

    begin
    {
        # Initialize function.
        Initialize-ADTFunction -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process
    {
        try
        {
            try
            {
            }
            catch
            {
                # Re-writing the ErrorRecord with Write-Error ensures the correct PositionMessage is used.
                Write-Error -ErrorRecord $_
            }
        }
        catch
        {
            # Process the caught error, log it and throw depending on the specified ErrorAction.
            Invoke-ADTFunctionErrorHandler -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -ErrorRecord $_
        }
    }

    end
    {
        # Finalize function.
        Complete-ADTFunction -Cmdlet $PSCmdlet
    }
}


##*===============================================
##* Adding Branding Key Function
##*===============================================
#Scriptmodifiedon&by : 10/04/2025 
 
[string]$BrandingKeyPath = 'HKLM:\Software\AllianzPackages\'
$Time = Get-Date
 
Function Branding-Key {
 
<# Create or delete audit key
   Branding-Key -Action "Create" -AppID "Test" -Revision "01" -Platform "AMC and AVC" will create the audit key.
   Branding-Key -Action "Delete" -AppID "Test" will delete the audit key.
#>
    [CmdletBinding()]
	Param (
        [Parameter(Mandatory=$true)]
		[ValidateSet('Create','Delete')]
		[string]$Action = 'Create',
 
        [Parameter(Mandatory=$false)]
        [string]$AppID,
 
        [Parameter(Mandatory=$false)]
        [string]$Revision,
 
        [Parameter(Mandatory=$false)]
        [string]$Platform
 
    )
 
    Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		#Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
        Initialize-ADTFunction -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
 
	}
	Process {
        $BrandingKey = "HKLM:\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG"
        $Date = [System.DateTime]::Now
        IF ($Action -eq 'Create') {
            # Creating Branding key properties
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'AppID' -Type 'String' -Value $($adtSession.AppID)
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'FamilyID' -Type 'String' -Value $($adtSession.FamilyID)
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'Version' -Type 'String' -Value $($adtSession.AppVersion)
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'PackageMode' -Type 'String' -Value 'IAF'
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'InstallDate' -Type 'String' -Value $Date
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'Installed' -Type 'String' -Value 'Yes'
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'Package Revision' -Type 'String' -Value $($adtSession.AppRevision)
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'Platform' -Type 'String' -Value $($adtSession.Platform)
            Set-ADTRegistryKey -Key "$BrandingKey" -Name 'PSADT version' -Type 'String' -Value $($adtSession.DeployAppScriptVersion)
        } 
        ELSE {Remove-ADTRegistryKey -Key "$BrandingKey"}
    }
}


##==================================== Compare version function =======================================================================================================


 function Compare-Version {
    param(
        [string]$VersionA,
        [string]$VersionB,
        [ValidateSet("eq","gt","lt","ge","le")]
        [string]$Comparison = "eq"
    )

    # If either input is null, empty, or whitespace â†’ return false
    if ([string]::IsNullOrWhiteSpace($VersionA) -or [string]::IsNullOrWhiteSpace($VersionB)) {
        return $false
    }

    # Normalize inline
    $normalize = {
        param([string]$v)
        $parts = $v.Trim().Split('.')

        # Convert each part to int (removes leading zeros like '00')
        $nums = foreach ($p in $parts) { [int]$p }

        # Strip trailing zeros, but keep at least Major.Minor
        while ($nums.Count -gt 2 -and $nums[-1] -eq 0) {
            $nums = $nums[0..($nums.Count - 2)]
        }

        # Ensure at least 2 segments for [version] casting
        if ($nums.Count -lt 2) { $nums += 0 }

        return [version]($nums -join '.')
    }

    $v1 = & $normalize $VersionA
    $v2 = & $normalize $VersionB

    switch ($Comparison) {
        "eq" { return $v1 -eq $v2 }
        "gt" { return $v1 -gt $v2 }
        "lt" { return $v1 -lt $v2 }
        "ge" { return $v1 -ge $v2 }
        "le" { return $v1 -le $v2 }
    }
}


##====================================HKCU Reg Function=================================================

If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
}
Else {
    $InvocationInfo = $MyInvocation
}
[String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent


$dir = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

##=======================TimeStamp function===================================================================================================================
function timestampfunction {
    foreach ($i in $input){
        "$(Get-Date): $i"
    }
}

#=======================Import Registry file User for all logged on users and current user===============================================================================
Function Import-RegistryFileUser {	
	Param([String]$DisplayName, [String]$RegFile)
	$Output = "Import User registry key of "+$DisplayName+" ....."
	Write-Host "Import User registry key of"$DisplayName" ....." -NoNewline
    $Log = $Env:programdata+"\AZMDM\AppLogs\Package_"+$DisplayName+".txt"
    If (!(Test-Path $Log))  {New-Item -Path $Log -Force}
    $Reg1=""+$RegFile+""
	$Executable = """$($adtSession.DirSupportFiles)\Import-Registry.ps1"""
    $Args= "-File $Executable -RegFile $Reg1 -CurrentUser -AllUsers -DefaultProfile"
    $ErrCode = powershell.exe -Command (Start-Process powershell -ArgumentList $Args -WindowStyle Hidden -Wait -Passthru).ExitCode                                                              
	If ($ErrCode -eq 0) {
		$Output = $Output+"Success" | timestampfunction | Add-Content $Log -Force 
		Write-Host "Success" -ForegroundColor Yellow
	} elseif ($ErrCode -eq 1) {
         $Output = $Output+"Partially Success, registry may not exist or incorrect reg_file " | timestampfunction | Add-Content $Log -Force 
		Write-Host "Partially Success, registry may not exist or incorrect reg_file " -ForegroundColor Green }
     else {
		$Output = $Output+"Failed with error code "+$ErrCode | timestampfunction | Add-Content $Log -Force 
		Write-Host "Failed with error code "$ErrCode -ForegroundColor Red
	}
}


##*===============================================
##* MARK: SCRIPT BODY
##*===============================================

# Announce successful importation of module.
Write-ADTLogEntry -Message "Module [$($MyInvocation.MyCommand.ScriptBlock.Module.Name)] imported successfully." -ScriptSection Initialization
