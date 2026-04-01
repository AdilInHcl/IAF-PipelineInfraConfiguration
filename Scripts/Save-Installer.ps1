<#
.SYNOPSIS
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.DESCRIPTION
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.EXAMPLE
    .\Save-Installer.ps1

.NOTES
    FileName:    Save-Installer.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2024-03-04

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2023-06-14) Added support for download setup files from storage account
    1.0.2 - (2024-03-04) Added support for decompressing downloaded setup archive files and finding setup file within archive
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountAccessKey = $env:SA_SECRET,
    
    [ValidateNotNullOrEmpty()]
    [string]$GITHUB_PAT = $env:GIT_PAT_PSW
)
Process {
    # Functions
    function Save-File {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the download URL.")]
            [ValidateNotNullOrEmpty()]
            [string]$URI,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )
        Begin {
            # Force usage of TLS 1.2 connection
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Set TLS to different versions incase of VideoLan VLC
            if ($Name -like "*vlc*"){[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls13}

            # Disable the Invoke-WebRequest progress bar for faster downloads
            $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue

            # Initialize download retry variables
            $RetryCount = 0
            $RetryLimit = 3
            $RetryDelay = 5
        }
        Process {
            # Create path if it doesn't exist
            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }

            # Download installer file with retry logic
            do {
                try {
                    $OutFilePath = Join-Path -Path $Path -ChildPath $Name
                    if ($URI -match "github\.developer\.allianz\.io/(.*)/releases") {
                        $GitHubtoken = $GITHUB_PAT
                        $repo = $matches[1]  # Extracted Repo Address
                        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                        $headers.Add("Authorization", "token $GitHubtoken")
                       
                        # Invoke-WebRequest parameters
                        Write-Verbose -Message "Determining latest release ID"
                        $releases = "https://github.developer.allianz.io/api/v3/repos/$repo/releases/latest"
                        $id = ((Invoke-WebRequest $releases -Headers $headers -UseBasicParsing | ConvertFrom-Json)[0].assets | where-object { $_.name -eq $Name })[0].id			
                        
                        #Create a download URL
                        $download = "https://" + $GitHubtoken + ":@github.developer.allianz.io/api/v3/repos/$repo/releases/assets/$id"
                        Write-Verbose -Message "Download URL of latest release with ID : https://github.developer.allianz.io/api/v3/repos/$repo/releases/assets/$id"
                        $URI = $download
                        $headers.Add("Accept", "application/octet-stream")
				    } 
                    Invoke-WebRequest -Uri $URI -OutFile $OutFilePath -Headers $headers -UseBasicParsing -UserAgent "wget" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
                    Write-Warning -Message "Retrying in $($RetryDelay) seconds"
                    Start-Sleep -Seconds $RetryDelay
                    $RetryCount++
                }
            }
            while ($RetryCount -lt $RetryLimit -and -not(Test-Path -Path $OutFilePath))
        }
    }

    function Get-StorageAccountBlobContent {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account name.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountName,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account container name.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the name of the blob.")]
            [ValidateNotNullOrEmpty()]
            [string]$BlobName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$NewName
        )
        process {
            # Create path if it doesn't exist
            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    throw "$($MyInvocation.MyCommand): Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }

            # Create storage account context using access key
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountAccessKey
    
            try {
                # Retrieve the setup installer file from storage account
                Write-Output -InputObject "Downloading '$($BlobName)' in container '$($ContainerName)' from storage account: $($StorageAccountName)"
                $SetupFile = Get-AzStorageBlobContent -Context $StorageAccountContext -Container $ContainerName -Blob $BlobName -Destination $Path -Force -ErrorAction "Stop"

                # Rename downloaded file
                $SetupFilePath = Join-Path -Path $Path -ChildPath $BlobName
                if (Test-Path -Path $SetupFilePath) {
                    try {
                        Write-Output -InputObject "Renaming downloaded setup file to: $($NewName)"
                        Rename-Item -Path $SetupFilePath -NewName $NewName -Force -ErrorAction "Stop"
                    }
                    catch [System.Exception] {
                        throw "$($MyInvocation.MyCommand): Failed to rename downloaded setup file with error message: $($_.Exception.Message)"
                    }
                }
                else {
                    throw "$($MyInvocation.MyCommand): Could not find file after attempted download operation from storage account"
                }
            }
            catch [System.Exception] {
                throw "$($MyInvocation.MyCommand): Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
            }
        }
    }
    Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

    # Intitialize variables
    $AppsPrepareListFileName = "AppsPrepareList.json"
    $AppsPrepareListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsPrepareListFileName

    # Read content from AppsDownloadList.json file created in previous stage
    $AppsDownloadListFileName = "AppsDownloadList.json"
    $AppsDownloadListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName
    if (Test-Path -Path $AppsDownloadListFilePath) {
        # Construct list of applications to be processed in the next stage
        $AppsPrepareList = New-Object -TypeName "System.Collections.ArrayList"
        
        # Read content from AppsDownloadList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsDownloadListFilePath)"
        $AppsDownloadList = Get-Content -Path $AppsDownloadListFilePath | ConvertFrom-Json

        # Process each application in list and download installer
        foreach ($App in $AppsDownloadList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            $token = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET #Created token for catalogue entry

            # Construct directory structure for setup installers of the current app item based on pipeline workspace directory path and app package folder name property
            $AppSetupFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Installers\$($App.AppFolderName)"

            # Construct directory structure for downloaded icons of current app item based on pipeline workspace directory path and app package folder name property
            $AppIconFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Icons\$($App.AppFolderName)"

            try {
                # Save installer based on the source type
                switch ($App.AppSource) {
                    "StorageAccount" {
                        Write-Output -InputObject "Attempting to download '$($App.BlobName)' from: $($App.URI)"
                        Get-StorageAccountBlobContent -StorageAccountName $App.StorageAccountName -ContainerName $App.StorageAccountContainerName -BlobName $App.BlobName -Path $AppSetupFolderPath -NewName $App.AppSetupFileName -ErrorAction "Stop"
                    }
                    default {
                        Write-Output -InputObject "Attempting to download '$($App.AppSetupFileName)' from: $($App.URI)"

                    ########################################## Delete After Test ##################################
                                            #if ($App.IntuneAppName -eq "Notepad++"){$App.URI = "TestURL"}
                    ########################################### Delete After Test ##################################

                        Save-File -URI $App.URI -Path $AppSetupFolderPath -Name $App.AppSetupFileName -ErrorAction "Stop"
                    }
                }
                Write-Output -InputObject "Successfully downloaded installer"

                try {
                    # Save icon file if provided
                    if ($App.IconURI) {
                        Write-Output -InputObject "Attempting to download icon file from: $($App.IconURI)"
                        Save-File -URI $App.IconURI -Path $AppIconFolderPath -Name "Icon.png" -ErrorAction "Stop"
                        Write-Output -InputObject "Successfully downloaded icon file"
                    }

                    try {
                        # Construct path to downloaded setup file
                        $AppSetupFilePath = Join-Path -Path $AppSetupFolderPath -ChildPath $App.AppSetupFileName
    
                        # Expand compressed installer file if required
                        Write-Output -InputObject "Checking if downloaded file is a zip file"
                        if (($App.FileExtension -like "zip") -or ([System.IO.Path]::GetExtension($AppSetupFilePath).TrimStart(".") -like "zip")) {
                            Write-Output -InputObject "Attempting to expand downloaded zip file"
                            Expand-Archive -Path $AppSetupFilePath -DestinationPath $AppSetupFolderPath -ErrorAction "Stop"
                            Write-Output -InputObject "Successfully expanded zip file"
    
                            try {
                                # Find applicable setup file name based on known extensions within extracted archive
                                #$AppSetupFileName = Get-ChildItem -Path $AppSetupFolderPath -File | Where-Object { $PSItem.Extension -like ".exe" -or $PSItem.Extension -like ".msi" } | Sort-Object -Property "LastModified" -Descending | Select-Object -First 1 -ExpandProperty "Name" #$AppSetupFileName = Get-ChildItem -Path $AppSetupFolderPath -File | Where-Object { $PSItem.Extension -like ".exe" -or $PSItem.Extension -like ".msi" } | Select-Object -ExpandProperty "Name"
                                $AppSetupFileName = Get-ChildItem -Path $AppSetupFolderPath -File | Where-Object { $PSItem.Extension -like ".exe" -or $PSItem.Extension -like ".msi" -or $PSItem.Extension -like ".msp" -or $PSItem.Extension -like ".ps1"} | Sort-Object -Property "LastModified" -Descending | Select-Object -First 1 -ExpandProperty "Name" #$AppSetupFileName = Get-ChildItem -Path $AppSetupFolderPath -File | Where-Object { $PSItem.Extension -like ".exe" -or $PSItem.Extension -like ".msi" } | Select-Object -ExpandProperty "Name"
                            }
                            catch [System.Exception] {
                                Write-Warning -Message "Failed to find valid setup file within expanded zip file with error message: $($_.Exception.Message)"
                            }
    
                            try {
                                # Remove downloaded zip file after successful expansion
                                Write-Output -InputObject "Removing downloaded zip file"
                                Remove-Item -Path $AppSetupFilePath -Force -ErrorAction "Stop" -Confirm:$false
                            }
                            catch [System.Exception] {
                                Write-Warning -Message "Failed to remove downloaded zip file with error message: $($_.Exception.Message)"
                            }
                        }
                        else {
                            Write-Output -InputObject "No need to expand downloaded file, file extension is not a zip file"
    
                            # Handle setup file name variable
                            $AppSetupFileName = $App.AppSetupFileName
                        }
                    }
                    catch [System.Exception] {
                        Write-Warning -Message "Failed to expand downloaded zip file with error message: $($_.Exception.Message)"
                    }
    
                    # Validate setup installer was successfully downloaded
                    $AppSetupFilePath = Join-Path -Path $AppSetupFolderPath -ChildPath $AppSetupFileName
                    if (Test-Path -Path $AppSetupFilePath) {
                        # Construct new application custom object with required properties
                        $AppListItem = [PSCustomObject]@{
                            "IntuneAppName" = $App.IntuneAppName
                            "IntuneAppNamingConvention" = $App.IntuneAppNamingConvention
                            "AppPublisher" = $App.AppPublisher
                            "AppFolderName" = $App.AppFolderName
                            "AppSetupFileName" = $AppSetupFileName
                            "AppSetupFolderPath" = $AppSetupFolderPath
                            "AppSetupVersion" = $App.AppSetupVersion
                            "IconURL" = $App.IconURL
                        }
    
                        # Add to list of applications to be published
                        $AppsPrepareList.Add($AppListItem) | Out-Null
                    }
                    else {
                        Write-Warning -Message "Could not detect downloaded setup installer"
                        Write-Warning -Message "Application will not be added to app prepare list"
                    }
    
                    # Handle current application output completed message
                    Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed to download icon file with error message: $($_.Exception.Message)"
                }
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to download content for application: $($App.IntuneAppName)"
                Write-Warning -Message "Application will not be added to app prepare list"
            }
        }

        # Construct new json file with new applications to be published
        if ($AppsPrepareList.Count -ge 1) {
            $AppsPrepareListJSON = $AppsPrepareList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsPrepareListFileName)' in: $($AppsPrepareListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsPrepareList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsPrepareListJSON -FilePath $AppsPrepareListFilePath -NoClobber -Force

            #Update catalogue only for failed apps
            $FailedApps = $AppsDownloadList | Where-Object { $_.IntuneAppName -notin $AppsPrepareList.IntuneAppName }
            if($FailedApps.Count -ne 0) {Update-CatlogueStatus -AccessToken $token -Apps $FailedApps -Reason "IAF - Evergreen Source download failed"}

        }

        # Handle next stage execution or not if no new applications are to be published
        if ($AppsPrepareList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be prepared, aborting pipeline"
            $BinaryLocation = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath "AppsDownloadList.json"
            Update-CatlogueStatus -AccessToken $token -Apps "All" -InputFilePath $BinaryLocation  -Reason "IAF - Evergreen Source download failed"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "Allow pipeline to continue"
        }
    }
    else {
        Write-Output -InputObject "PS_ERROR_DESC= Failed to locate required $($AppsDownloadListFileName) file in build artifacts staging directory, aborting pipeline"
        exit 1
    }
}