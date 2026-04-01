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

    #Azure VM and Resource Group parameters
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
  [string]$ResourceGroupName
)

try {        
        #LETestSuiteJsonPath = "${env.LEConfigJsonPath}StageResult\\"
        #LETestSuiteJsonFile = "${env.LETestSuiteJsonPath}PROD_LE_TESTSUITE_CREATION_180_StageResult.json" 
        
        #$testSuiteJsonFile = Join-Path $env:LETestSuiteJsonPath -ChildPath $env:LETestSuiteJsonFile
        $testSuiteJsonFile = $env:LETestSuiteJsonFile
        #Write-Host "File name :- " $testSuiteJsonFile
        $jsonObject = Get-Content -Path $testSuiteJsonFile -Raw | ConvertFrom-Json
        
        $SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)
 
        # Authenticate with Azure using the service principal
        Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential
    
        # Set the subscription context
        Select-AzSubscription -SubscriptionId $SubscriptionId


        foreach ($currentItem in $jsonObject.Apps) {
          
          # Variables
          $VMName = $currentItem.VMName   # Replace with your VM name
          # Reboot the VM
          Write-Host "Rebooting the VM: $VMName ..."
          #Write-Host "Rebooting the VM: $VMName in resource group: $ResourceGroupName..."
          Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName 

          # Check the VM status iteratively
        }

        Write-Host "Checking the VM status after reboot..."
        foreach ($currentItem in $jsonObject.Apps) {
          $VMStatus = ""
          $maxLimit = 10
          $limit = 1
          $VMName = $currentItem.VMName
          do {
              Start-Sleep -Seconds 10  # Wait for 10 seconds before checking again
              $VMStatus = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).Statuses | Where-Object { $_.Code -like "PowerState*" } | Select-Object -ExpandProperty Code
              Write-Host "Current VM Status: $VMStatus"
              if($limit -ge $maxLimit) {
                Write-Host "Maximum retry limit reached for VM: $VMName. Moving to the next app."
                break  # Exit the do-while loop
              }
          } while ($VMStatus -ne "PowerState/running")
      }
        Write-Host "The VM is now running and ready!"

}
catch {
  Write-Output "PS_ERROR_DESC= Error in Reboot_LE_SmokeTest_VM.ps1 script: $_"
  exit 1
}
