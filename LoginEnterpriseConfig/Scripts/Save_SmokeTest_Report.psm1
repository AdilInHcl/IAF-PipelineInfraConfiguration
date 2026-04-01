function Save_ApplicationTestReport{
        param(
            # [parameter(Mandatory = $true, HelpMessage = "Name of the Azure Storage account.")]
            # [ValidateNotNullOrEmpty()]
            # [string]$StorageAccountName,
       
            [parameter(Mandatory = $true, HelpMessage = "Path to the local file to be uploaded, including file name and extension.")]
            [ValidateNotNullOrEmpty()]
            [string]$FilePath
        )
        $StorageAccountName = $env:ARCHIVESTORAGEACCOUNTNAME
        $ContainerName =  $env:ARCHIVECONTAINERNAME
        $StorageAccountKey = $env:PROD_SA_SECRET
        try {
            # Construct context using OAuth authentication (Azure AD)
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction "Stop"
   
            try {
                $Content = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Context $StorageAccountContext -Force -ErrorAction "Stop"
   
                # Handle return value
                return $Content
            }
            catch {
                Write-Output "PS_ERROR_DESC= Failed to upload storage account blob content. Error : $_"
                exit 1
            }
        }
        catch {
                Write-Output "PS_ERROR_DESC= Failed to retrieve storage account context. Error message: $_"
                exit 1
            }
    }

    function Save_ApplicationTestScript {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Path to the local file to be uploaded, including file name and extension.")]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )
    
    $StorageAccountName = $env:ARCHIVESTORAGEACCOUNTNAME
    #$ContainerName =  $env:ARCHIVECONTAINERNAME
    $ContainerName =  "lescripts"
    $StorageAccountKey = $env:PROD_SA_SECRET

    try {
        # Construct context using OAuth authentication (Azure AD)
        $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction "Stop"
        
        try {
            
            # Upload the file to the specific subfolder
            $Content = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Context $StorageAccountContext -Force -ErrorAction "Stop"
            
            # Handle return value
            return $Content
           }
           catch {
                Write-Output "PS_ERROR_DESC= Failed to upload storage account blob content. Error : $_"
                exit 1
            }
        }
        catch {
                Write-Output "PS_ERROR_DESC= Failed to retrieve storage account context. Error message: $_"
                exit 1
            }
}

 