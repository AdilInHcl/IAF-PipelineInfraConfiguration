<#
.SYNOPSIS
    This script creates a compressed file of the content in the app publish folder and uploads it to the specified storage account.

.DESCRIPTION
    This script creates a compressed file of the content in the app publish folder and uploads it to the specified storage account.

.EXAMPLE
    .\New-AppArchive.ps1

.NOTES
    FileName:    New-AppArchive.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2023-03-11
    Updated:     2023-03-11

    Version history:
    1.0.0 - (2023-03-11) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ContainerName,

    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountKey = $env:SA_SECRET
)
Process {
    Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"
    # Functions
    function Set-AzureContainerContent {
        <#
        .SYNOPSIS
            Upload a blob item to a specific Azure Storage Account and given container name.
    
        .DESCRIPTION
            Upload a blob item to a specific Azure Storage Account and given container name.
    
        .PARAMETER StorageAccountName
            Name of the Azure Storage account.
    
        .PARAMETER ContainerName
            Name of the Azure Storage container.
    
        .PARAMETER FilePath
            Path to the local file to be uploaded, including file name and extension.
    
        .NOTES
            Author:      Nickolaj Andersen
            Contact:     @NickolajA
            Created:     2023-01-06
            Updated:     2023-01-06
    
            Version history:
            1.0.0 - (2023-01-06) Script created
        #>
        param(
            [parameter(Mandatory = $true, HelpMessage = "Name of the Azure Storage account.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountName,
        
            [parameter(Mandatory = $true, HelpMessage = "Name of the Azure Storage container.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName,

            [parameter(Mandatory = $true, HelpMessage = "Storage Account Access Key.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountKey,
    
            [parameter(Mandatory = $true, HelpMessage = "Path to the local file to be uploaded, including file name and extension.")]
            [ValidateNotNullOrEmpty()]
            [string]$FilePath
        )
        try {
            # Construct context using OAuth authentication (Azure AD)
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction "Stop"
    
            try {
                $Content = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Context $StorageAccountContext -Force -ErrorAction "Stop"
    
                # Handle return value
                return $Content
            }
            catch [System.Exception] {
                throw "PS_ERROR_DESC= $($MyInvocation.MyCommand): Failed to upload storage account blob content. Error message: $($_.Exception.Message)"
            }
        }
        catch [System.Exception] {
            Write-Host "PS_ERROR_DESC= $($MyInvocation.MyCommand): Failed to retrieve storage account context. Error message: $($_.Exception.Message)"
            exit 1
        }
    }

    function Get-AppID{
        param(
        [string] $AppName
        )

        #Fetch the App IDs from the AppId.json in the binaries directory
        $AppIDJSONPath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppId.json"

        # Check if the JSON file exists
        if (Test-Path $AppIDJSONPath) {
            # Load JSON data
            $InputJson = Get-Content -Raw -Path $AppIDJSONPath | ConvertFrom-Json

            # Normalize: always wrap into .Apps
            if ($null -eq $InputJson.Apps) {
                # Legacy single app JSON → wrap it
                $AppInfoObject = [PSCustomObject]@{
                    Apps = @($InputJson)
                }
            }
            else {
                # Already has Apps → just keep as is
                $AppInfoObject = $InputJson
            }
        }
        else {
            Write-Host "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
            exit 1
        }
        $AppId = $AppInfoObject.Apps | Where-Object {$_.IntuneAppName -eq $AppName}| Select-Object AppId
        return $AppId.AppId
    }

    # Genrate Token for the Catalogue Access
    $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET

    # Intitialize variables
    $AppsPublishRootPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Publish"

    # Read content from AppsPublishList.json file created in previous stage and process each application
    $AppsPublishListFileName = "AppsPublishList.json"
    $AppsPublishListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsPublishList") -ChildPath $AppsPublishListFileName

    if (Test-Path -Path $AppsPublishListFilePath) {
        # Read content from AppsPrepareList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsPublishListFilePath)"
        $AppsPublishList = Get-Content -Path $AppsPublishListFilePath -ErrorAction "SilentlyContinue" | ConvertFrom-Json

        $SuccessUploadApps = @()
        # Process each app in publish list
        foreach ($App in $AppsPublishList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"
            $AppID = Get-AppID -AppName $App.IntuneAppName
            try {
                # Compress current app publish folder path
                $AppArchiveFileName = -join@($AppID,'_',$App.IntuneAppName.Replace(" ", "_"), "_", $App.AppSetupVersion, ".zip")
                $AppArchiveFilePath = Join-Path -Path $AppsPublishRootPath -ChildPath $AppArchiveFileName
                Write-Output -InputObject "Compressing path '$($App.AppPublishFolderPath)' into file: $($AppArchiveFileName)"
                Compress-Archive -Path "$($App.AppPublishFolderPath)\*" -DestinationPath $AppArchiveFilePath -ErrorAction "Stop"

                ########### Delete After Test ##############################
                    # if ($App.IntuneAppName -eq "Notepad++"){$AppArchiveFilePath = $null}
                    #if ($App.IntuneAppName -in @("Notepad++","MySQLWorkbench")){$AppArchiveFilePath = "DummyFail"}
                ############################################################

                try {
                    # Upload current archive file to storage account
                    if (Test-Path -Path $AppArchiveFilePath) {
                        Write-Output -InputObject "Uploading current app publish archive file to storage account: $($AppArchiveFilePath)"
                        Write-Output -InputObject "Storage account name: $($StorageAccountName)"
                        Write-Output -InputObject "Storage account container name: $($ContainerName)"
                        Set-AzureContainerContent -StorageAccountName $StorageAccountName -ContainerName $ContainerName -StorageAccountKey $StorageAccountKey -FilePath $AppArchiveFilePath -ErrorAction "Stop"

                        # Remove current archive file after upload
                        Write-Output -InputObject "Removing current app publish archive file: $($AppArchiveFilePath)"
                        Remove-Item -Path $AppArchiveFilePath -Force

                        # Handle current application output completed message
                        Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
                        $SuccessUploadApps += $App
                    }
                    else {
                        
                        Write-Warning"$($MyInvocation.MyCommand): Failed to detect current app publish archive file with expected full path: $($AppArchiveFilePath)"
                    }
                }
                catch [System.Exception] {
                    
                    Write-Warning "$($MyInvocation.MyCommand): Failed to upload current app publish archive file $($AppArchiveFileName) to storage account. Error message: $($_.Exception.Message)"
                }
            }
            catch [System.Exception] {
                
                Write-Warning "$($MyInvocation.MyCommand): Failed to compress current app publish folder path $($App.AppPublishFolderPath) to archive file $($AppArchiveFileName). Error message: $($_.Exception.Message)"
            }
        }

        
        $FailedUploadApps = $AppsPublishList | Where-Object { $_.IntuneAppName -notin $SuccessUploadApps.IntuneAppName } #Fetch the Apps Failed to upload

        $AppsPublishList = $SuccessUploadApps #Update the AppPublish content with the success apps

        if (@($FailedUploadApps).Count -gt 0){
            Write-Output "Updating status in catalogue for the apps failed to upload.. "
            Update-CatlogueStatus -AccessToken $token -Apps $FailedUploadApps -Reason "IAF - Archival to Storage account failed"

            $AppsPublishListFilePathBinary = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppsPublishList.json"

            #Incase no apps to publish to intune due to archival fails.
            if (@($AppsPublishList).Count -eq 0){
                Remove-Item -Path $AppsPublishListFilePath -Force -Recurse
                Remove-Item -Path $AppsPublishListFilePathBinary -Force -Recurse
                Write-Output "PS_ERROR_DESC= Failed to upload applications to Azure blob container..."
                exit 1
            }

            $AppsPublishList | ConvertTo-Json -Depth 10 | Set-Content $AppsPublishListFilePath    #Update the artifacts
            $AppsPublishList | ConvertTo-Json -Depth 10 | Set-Content $AppsPublishListFilePathBinary #Update the binaries
        }

    }
    else {
        Write-Output "PS_ERROR_DESC= $($MyInvocation.MyCommand): Failed to locate required $($AppsPublishListFileName) file in build artifacts staging directory"
        $BinaryLocation = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppsPublishList.json"
        Update-CatlogueStatus -AccessToken $token -Apps "All" -InputFilePath $BinaryLocation  -Reason "IAF - Archival to Storage account failed"
        exit 1
    }
}