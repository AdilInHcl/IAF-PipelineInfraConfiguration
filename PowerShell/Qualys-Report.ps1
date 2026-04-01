<#
.SYNOPSIS
This script compares the baseline report and the on demand scan report and creates a delta report. 

.DESCRIPTION
This script compares the baseline report and the on demand scan report and creates a delta report.

.NOTES
    FileName:    Qualys-Report.ps1
    Author:      Daniyal Ahmad
    Created:     2026-02-04
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ARCHIVESTORAGEACCOUNTNAME,
    [string]$ARCHIVECONTAINERNAME,
    [string]$BASELINE_BLOBNAME_FOLDER,
    [string]$StorageAccountAccessKey = $env:PROD_SA_SECRET,
    [string]$REPORT_BLOBNAME,
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

#Fetch the baseline report from the azure storage account
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
            [string]$BlobNameFolder,

            [parameter(Mandatory = $true, HelpMessage = "Specify the base folder download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$BasePath
        )
        process {
            # Create storage account context using access key
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountAccessKey

            #fetch the latest baseline scan file in blob
            $baselineblobs = Get-AzStorageBlob -Context $StorageAccountContext -Container $ContainerName | Where-Object { $_.Name -like "$($BlobNameFolder)/*" }
            $BlobName = ($baselineblobs | Sort-Object LastModified -Descending | Select-Object -First 1).Name

            # Create path if it doesn't exist
            $Path = Join-Path -Path $BasePath -ChildPath $baselinelatestfile

            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Host -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    throw "$($MyInvocation.MyCommand): Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }
    
            try {
                # Retrieve the setup installer file from storage account
                Write-Host "Downloading '$($BlobName)' in container '$($ContainerName)' from storage account: $($StorageAccountName)"
                $SetupFile = Get-AzStorageBlobContent -Context $StorageAccountContext -Container $ContainerName -Blob $BlobName -Destination $Path -Force -ErrorAction "Stop"

                return $BlobName
            }
            catch [System.Exception] {
                throw "$($MyInvocation.MyCommand): Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
            }
        }
    }

# Generate HTML table for vulnerabilities
function Generate-VulnTable {
    param ($vulns)

    if ($vulns.Count -eq 0) {
        return "<p>No vulnerabilities found.</p>"
    }

    $table = @"
<table>
    <tr><th>QID</th><th>Unique Vuln ID</th><th>Description</th><th>Paths</th><th>First Found</th><th>Last Found</th><th>Severity</th></tr>
"@
    foreach ($vuln in $vulns) {
        
        $lines = $vuln.RESULTS -split "`r?`n"
        $description = $lines[0] # first line 
        $pathLines = $lines[1..($lines.Count-1)] # slice: all remaining lines


        $table += "<tr class='sev-$($vuln.severity)'><td>$($vuln.QID)</td><td>$($vuln.UNIQUE_VULN_ID)</td><td>$($description)</td><td>$($pathLines)</td><td>$($vuln.FIRST_FOUND_DATETIME)</td><td>$($vuln.LAST_FOUND_DATETIME)</td><td>$($vuln.SEVERITY)</td></tr>"
    }
    $table += "</table>"
    return $table
}

# Set the HTML contents in the template file
function Set-QualysReportHTMLContent{
        param(
        [string]$QualysComparisonTemplatePath,
        [string]$VmName,
        [string]$assetId,
        [System.Object]$VulnsDetected,
        [string]$QualysODScantable,
        [string]$appName
        )
        try{
            $template = Get-Content -Path $QualysComparisonTemplatePath -Raw

            $TotalVulnsDetected = [PSCustomObject]@{
                high = @($VulnsDetected | Where-Object {$_.severity -ge 4}).Count
                medium = @($VulnsDetected | Where-Object {$_.severity -in @(2,3)}).Count
                low = @($VulnsDetected | Where-Object {$_.severity -le 1}).Count
                total = @($VulnsDetected).Count
            }

            # Generate HTML report using template
            $template = $template -replace '{{Date}}', (Get-Date)
            $template = $template -replace '{{VMNAME}}', $VmName
            $template = $template -replace '{{ASSETID}}', $assetId
            $template = $template -replace '{{APPINSTALLED}}', $appName


            $template = $template -replace '{{CRITICAL_HIGH}}', $TotalVulnsDetected.high
            $template = $template -replace '{{MEDIUM}}', $TotalVulnsDetected.medium
            $template = $template -replace '{{LOW}}', $TotalVulnsDetected.low
            $template = $template -replace '{{TOTAL}}', $TotalVulnsDetected.total

            $template = $template -replace '{{VULN_ROWS}}', $QualysODScantable
            $html = $template
               
            return $html

        } 
        catch {
            Write-Error "Failed to create HTML file: $_"
            exit 1
        }

    }

#Store the PDF on storage account
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
        [string]$FilePath,
    
        [parameter(Mandatory = $true, HelpMessage = "Path to the Azure Folder where file is to be uploaded")]
        [ValidateNotNullOrEmpty()]
        [string]$BlobName
    )
    try {
        # Construct context using OAuth authentication (Azure AD)
        $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction "Stop"
    
        try {
            $Content = Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Context $StorageAccountContext -Blob $BlobName -Force -ErrorAction "Stop"
            Write-Host "File Uploaded to Azure BLOB $BlobName"
            # Handle return value
            return $Content
        }
        catch [System.Exception] {
            throw "$($MyInvocation.MyCommand): Failed to upload storage account blob content. Error message: $($_.Exception.Message)"
        }
    }
    catch [System.Exception] {
        throw "$($MyInvocation.MyCommand): Failed to retrieve storage account context. Error message: $($_.Exception.Message)"
    }
}

#====================================================================
#  Declare Paths of templates and Download the baseline scan results
#====================================================================
try{
    $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
    $ScanFolder = Join-Path -Path "C:\SCANS\Qualys" -childPath $IAF_BUILD_TAG
    $QualysComparisonTemplatePath = Join-Path -Path $env:WORKSPACE -ChildPath "configs\Qualys_Report_template.html"

    #Path to the On demand scanned VM details
    $Device_Status_File_name = "QualysScanDeviceStatus.json"
    $QualysODScanVMReportPath = Join-Path -Path $ScanFolder -ChildPath $Device_Status_File_name

    #Fetch the Apps from the LEVM Creation file
    $VMInfoFileName = $env:Input_File_name
    $jsonFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName

    $token = Get-CatalogueAccessToken -username $username -password $password # Catlogue token

    # Check if the JSON file exists
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
        $AppOnDevice = $finalObject.Apps
    }

    #Scanned VMs JSON content
    $qulaysScanStatus = (Get-Content -Raw -Path $QualysODScanVMReportPath | ConvertFrom-Json).Apps 
    $scanned_vms = $qulaysScanStatus| Where-Object {$_.ScanCompletedTime -ne ""}
    $running_vms = $qulaysScanStatus| Where-Object {$_.ScanCompletedTime -eq "" -and $_.ScanTriggered -eq 'YES'} 

    #Set the status for the runiing VMs
    if(@($running_vms).Count -gt 0){
        Write-HOST "The Qualys Scan is still running on below VMs:"
        Write-HOST "Devices: $($running_vms.DeviceName)"
        Write-HOST "[Please validate the Qulays services on the VMs.]"

        foreach($vm in $running_vms){
            $app = $finalObject.Apps | Where-Object {$_.DeviceName -eq $vm.DeviceName}
            $app | Add-Member -NotePropertyName "QualysScan" -NotePropertyValue "Running" -Force
            Update-CatlogueStatus -AccessToken $token -Apps $vm -Reason "IAF - Qualys Vulnerability Identified"
        }
    }

    #if the Scan is running on all VMs exit else gather report
    if(@($running_vms).Count -eq @($qulaysScanStatus).Count){
        Write-HOST "The Qualys Scan is still running on all the VMs. Skipping Scan results";
        exit
    }
    else{
        #OutPut Folder Path to Save HTML files (Comparison Reports)
        $OutHtmlFolderpath = Join-Path -Path $ScanFolder -ChildPath "Results"
        if(-not(Test-Path $OutHtmlFolderpath)){New-Item -Path $OutHtmlFolderpath -ItemType "directory"| Out-Null}

        #Save the baseline report to C:\SCANS\Qualys\<build-tag>
        $latestbaselineblobname = Get-StorageAccountBlobContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -BlobNameFolder $BASELINE_BLOBNAME_FOLDER -BasePath $ScanFolder

        $QualysBaselineScanReportPath = Join-Path -Path $ScanFolder -ChildPath $latestbaselineblobname

        # Check if baseline json files exist
        if (-not (Test-Path $QualysBaselineScanReportPath)) {
            Write-Error "Baseline Scan report $ODScanReport not found on path $QualysBaselineScanReportPath."
            exit 1
        }

        #Baseline image JSON content
        $baseline_vm = (Get-Content -Raw -Path $QualysBaselineScanReportPath | ConvertFrom-Json).Apps

        Write-Host "================================================================"
        foreach($vm in $scanned_vms){
             #Fetch app details from the le vm creation file
             $app = $finalObject.Apps | Where-Object {$_.DeviceName -eq $vm.DeviceName}
             #Fetch the Vulnerabilities Detected apart form the baseline VM
             $vulns_detected = $vm.vulninfo | Where-Object { $_.QID -notin $baseline_vm.vulninfo.QID }
             if (@($vulns_detected).Count -eq 0){
                Write-Host "No Vulnerabilities were Detected for $($vm.DeviceName)"
                $app | Add-Member -NotePropertyName "QualysScan" -NotePropertyValue "Pass" -Force
             }
             else{
                $app | Add-Member -NotePropertyName "QualysScan" -NotePropertyValue "Failed" -Force
                Update-CatlogueStatus -AccessToken $token -Apps $vm -Reason "IAF - Qualys Vulnerability Identified"

                $Total_Vulns_detected = @($vulns_detected).Count
                Write-Host "Vulnerabilities Detected for $($vm.DeviceName) : $Total_Vulns_detected"
                $vulns_Table = Generate-VulnTable -vulns $vulns_detected

                $AppInstalled = $AppOnDevice | Where-Object {$_.DeviceName -eq $vm.DeviceName} | Select-Object IntuneAppName, AppSetupVersion
                $appName = "$($AppInstalled.IntuneAppName) $($AppInstalled.AppSetupVersion)"

                $html_content = Set-QualysReportHTMLContent -QualysComparisonTemplatePath $QualysComparisonTemplatePath -VmName $vm.DeviceName -assetId $vm.AssetID -VulnsDetected $vulns_detected -QualysODScantable $vulns_Table -appName $appName
                #Set the HTML content 
                $OutHTMLFileName = "$($vm.DeviceName)-$($AppInstalled.IntuneAppName)-QualysScanReport.html"
                $OutputHtmlPath = Join-Path -Path $OutHtmlFolderpath -ChildPath $OutHTMLFileName 
                $html_content | Out-File -FilePath $OutputHtmlPath

                #Store the Report on the Azure storage account
                $REPORT_BLOBNAME_FILE = "$($REPORT_BLOBNAME)/$OutHTMLFileName"
                Set-AzureContainerContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -StorageAccountKey $StorageAccountAccessKey -BlobName $REPORT_BLOBNAME_FILE -FilePath $OutputHtmlPath
             }
             Write-Host "================================================================"
        }
    }

    #Update the input file for results
    $finalObject.Apps | ForEach-Object {
        if ($_.InstallationCheck -eq "Failed") {
            $_ | Add-Member -NotePropertyName "QualysScan" -NotePropertyValue "App not installed" -Force
        }
    }

    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath -Encoding UTF8

}
catch{
    Write-Output "PS_ERROR_DESC= Unable to generate comparison report: $_"
    exit 1
}