# [CmdletBinding(SupportsShouldProcess = $true)]
# param (
#   [parameter(Mandatory = $true)]
#   [string]$intuneAppName,

#   [parameter(Mandatory = $true)]
#   [string]$familyID,

#   # [parameter(Mandatory = $true)]
#   # [string]$OE,

#   [parameter(Mandatory = $true)]
#   [string]$continuousTestName
# )
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppUpgradeDetection.psm1"
try {
  $intuneAppName = $env:intuneAppName
  $familyID = $env:familyID 
  $continuousTestName = $env:continuousTestName 
  # Write-Host "App Name $intuneAppName"
  # Write-Host "familyID $familyID"
  # Write-Host "continuous Test Name $continuousTestName"
  # Write-Host "calling Add_ContinuousTest_To_App method" 
   Add_ContinuousTest_To_App -FamilyId $familyID -IntuneAppName $intuneAppName -ContinuousTestName $continuousTestName
  #Write-Host "continuous test added" 
  
}
catch {
  Write-Output "PS_ERROR_DESC= Error in AddContinuousTestName.ps1 script: $_"
  exit 1
}
