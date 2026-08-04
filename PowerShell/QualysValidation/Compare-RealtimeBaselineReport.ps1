[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ARCHIVESTORAGEACCOUNTNAME,
    [string]$username,
    [string]$password = $env:QUALYS_KEY,
    [string]$ARCHIVECONTAINERNAME,
    [string]$BASELINE_BLOBNAME_FOLDER,
    [string]$DAILY_REPORT_BLOBNAME,
    [string]$REPORT_BLOBNAME,
    [string]$StorageAccountAccessKey = $env:PROD_SA_SECRET
)
Import-Module "$($env:WORKSPACE)/Scripts/CitrixConnect.psm1"

# IT RETURNS THE Last Scan Timestamp
function Get-LastScanTimestamp{
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,

        [Parameter(Mandatory=$true)]
        [string]$password,

        [Parameter(Mandatory=$true)]
        [string]$AssetIP
    )

    # Basic auth encoding
    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
    "Authorization"     = "Basic $encodedCreds"
    "X-Requested-With"  = "powershell"
    }

    $url = "https://qualysapi.qg2.apps.qualys.eu/api/4.0/fo/asset/host/vm/detection/?action=list&ips=$AssetIP&show_asset_id=1&show_results=1&include_vuln_type=confirmed"

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    $lastScantimestamp = $response.HOST_LIST_VM_DETECTION_OUTPUT.RESPONSE.HOST_LIST.HOST.LAST_SCAN_DATETIME
    return $lastScantimestamp

}

#Fetch qualys title and severity 
function Get-QualysVmVulnsDetails {
    param (
        [Parameter(Mandatory=$true)]
        [string]$username,
        [Parameter(Mandatory=$true)]
        [string]$password,
        [Parameter(Mandatory=$true)]
        [string]$AssetIP
    )

    # Basic auth encoding
    $pair = "$username`:$password"
    $encodedCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    $headers = @{
    "Authorization"     = "Basic $encodedCreds"
    "X-Requested-With"  = "powershell"
    }

    $url = "https://qualysapi.qg2.apps.qualys.eu/api/4.0/fo/asset/host/vm/detection/?action=list&ips=$AssetIP&show_asset_id=1&show_results=1&include_vuln_type=confirmed"

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    $vulnDetected = $response.HOST_LIST_VM_DETECTION_OUTPUT.RESPONSE.HOST_LIST.HOST.DETECTION_LIST.DETECTION

    #Create a clean list of the vuln detetcted
    $cleanList = foreach ($item in $vulnDetected) {

        # Extract RESULTS text safely
        $resultsText = $null
        if ($item.RESULTS.'#text') {
            $resultsText = $item.RESULTS.'#text'
        } elseif ($item.RESULTS.InnerText) {
            $resultsText = $item.RESULTS.InnerText
        }

        # Build a clean object
        [PSCustomObject]@{
            UNIQUE_VULN_ID          = $item.UNIQUE_VULN_ID
            QID                     = $item.QID
            TYPE                    = $item.TYPE
            SEVERITY                = $item.SEVERITY
            SSL                     = $item.SSL
            RESULTS                 = $resultsText
            STATUS                  = $item.STATUS
            FIRST_FOUND_DATETIME    = $item.FIRST_FOUND_DATETIME
            LAST_FOUND_DATETIME     = $item.LAST_FOUND_DATETIME
            TIMES_FOUND             = $item.TIMES_FOUND
            LAST_TEST_DATETIME      = $item.LAST_TEST_DATETIME
            LAST_UPDATE_DATETIME    = $item.LAST_UPDATE_DATETIME
            IS_IGNORED              = $item.IS_IGNORED
            IS_DISABLED             = $item.IS_DISABLED
            LAST_PROCESSED_DATETIME = $item.LAST_PROCESSED_DATETIME
        }
    }

    return $cleanList
}

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
function Get-VulnTable {
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

function Remove-VMs{
    param(
        [string]$machineName,
        [string]$CatalogName =  $env:LEClient_CatalogName,
        [string]$DeliveryGroupName = $env:LEClient_DeliveryGroupName
    )

        # Get the catalog name to  clean up AD accounts
        $brokercatalog = (Get-BrokerCatalog -CatalogName $CatalogName).CatalogName
        Write-Host "CatalogName is $brokercatalog"

        # Retrieve machine details from Citrix Broker
        $vmObject = Get-BrokerMachine -MachineName $machineName
        $desktopGroup = $vmObject.DesktopGroupName
        $id = $vmObject.SID  # Security Identifier for the machine AD account

        try {
            # If machine is in a Delivery Group, remove it
            if ($desktopGroup) {
                Write-Host "Removing $machineName from Delivery Group $desktopGroup..."
                Remove-BrokerMachine -InputObject $vmObject -DesktopGroup $desktopGroup -Force | Out-Null
            }
            else {
                Write-Host "$machineName is not in a Delivery Group. Proceeding to remove from Broker DB."
            }

            # Disable maintenance mode
            Write-Host "Setting machine $machineName into Maintenance mode"
            Set-BrokerMachine -MachineName $machineName -InMaintenanceMode $false

            # Power off the virtual machine
            Write-Host "Powering off machine $machineName"
            New-BrokerHostingPowerAction -Action TurnOff -MachineName $machineName | Out-Null

            # Wait for VM to shutdown
            Start-Sleep -Seconds 20

            # Unlock VM for removal from provisioning
            Write-Host "Unlocking and removing VM from provisioning"
            Get-ProvVM -VMName $machineName | Unlock-ProvVM | Out-Null

            # Remove VM from provisioning system
            Get-ProvVM -VMName $machineName | Remove-ProvVM | Out-Null

            # Remove machine object from Citrix Broker
            Write-Host "Removing machine object from broker..."
            Remove-BrokerMachine -MachineName $machineName | Out-Null
            Write-Host "Machine $machineName has been fully decommissioned."

            # Clean up associated AD account from the identity pool
            Remove-AcctADAccount -IdentityPoolName $brokercatalog -ADAccountSid $id -RemovalOption None -UseServiceAccount -Force
        }
        catch {
            # Handle any errors that occurred during the process
            Write-Host "Failed to process machine $machineName : $_"
        }
    
}
try{
    #=================================================================================
    #Fetch the asset INFO
    #=================================================================================
    $OutfileName = "VM_Details_baseline.txt"
    $OutBasefolder = $env:DAILYSCANBASEFOLDER
    $OutFilePath = Join-Path -Path $OutBasefolder -ChildPath $OutfileName
    $QualysComparisonTemplatePath = Join-Path -Path $env:WORKSPACE -ChildPath "configs\Qualys_Report_template.html"
    
    $timestamp = Get-Date -Format "yyyy_MM_dd" #Current Time stamp 
    $OutHtmlFolderpath = Join-Path -Path $OutBasefolder -ChildPath "DailyScanResults/$($timestamp)"

    if(-not(Test-Path $OutHtmlFolderpath)){New-Item -Path $OutHtmlFolderpath -ItemType "Directory" -Force | Out-Null}

    $VMDetailFileContent = Get-Content -Path $OutFilePath -Raw | ConvertFrom-Json

    $AssetIP = $VMDetailFileContent.IPaddress
    $vmName = $VMDetailFileContent.DeviceName

    #=================================================================================
    #Fetch the Default Scan Status for VM on Qualys Scan
    #=================================================================================
    #Wait params for Scan to complete
    $completed = $false #attempts
    $delayMinutes = 30 #minutes
    $retryCount = 1

    while($false -eq $completed) {

        $assetID = $VMDetailFileContent.AssetID

        #Fetch the Default Scan Status
        $lastscantimestamp = Get-LastScanTimestamp -username $username -password $password -AssetIP $AssetIP

        if ($lastscantimestamp){#check if the default scan has completed
            Write-Host "Qualys Default Scan completed [$lastscantimestamp] for $vmName ( $assetID )"
            $VMDetailFileContent.Status = "Scan Completed:[$lastscantimestamp]"

            #Fetch the vulnerabilities detected.
            $ScanDetails = Get-QualysVmVulnsDetails -username $username -password $password -AssetIP $AssetIP
            $VMDetailFileContent.vulninfo = $ScanDetails
            $completed = $true
            break
                
        }
        else{
            Write-Host "Qualys Default Scan is still running on $vmName ( $assetID )"
        }
            
        Write-Host "Qualys Default Scan is not completed. Waiting $delayMinutes minutes before retrying... (Attempt $($retryCount+1))"
        $retryCount += 1
        Start-Sleep -Seconds ($delayMinutes * 60)

    }
    
    #Exit in case Default Scan still running not registered on the Qualys side
    if ($null -eq $VMDetailFileContent.vulninfo){exit 1}

    $VMTempDetailFileContent = $VMDetailFileContent | ConvertTo-Json
    Out-File -InputObject $VMTempDetailFileContent -FilePath $OutFilePath

    #=================================================================================
    #Fetch the latest updated JSON baseline report from the sharepoint
    #=================================================================================
    #Save the baseline report to C:\SCANS\Qualys\<build-tag>
    $latestbaselineblobname = Get-StorageAccountBlobContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -BlobNameFolder $BASELINE_BLOBNAME_FOLDER -BasePath $OutBasefolder

    $QualysBaselineScanReportPath = Join-Path -Path $OutBasefolder -ChildPath $latestbaselineblobname

    # Check if baseline json files exist
    if (-not (Test-Path $QualysBaselineScanReportPath)) {
        Write-Error "Baseline Scan report $ODScanReport not found on path $QualysBaselineScanReportPath."
        exit 1
    }

    #Baseline image JSON content
    $baseline_vm = (Get-Content -Raw -Path $QualysBaselineScanReportPath | ConvertFrom-Json).Apps

    #=================================================================================
    #Compare and Place the JSON baseline report on the sharepoint
    #=================================================================================

    #Fetch app details from the le vm creation file
    $vulns_detected = $VMDetailFileContent.vulninfo | Where-Object { $_.QID -notin $baseline_vm.vulninfo.QID }

    Write-Host "================================================================"
    if (@($vulns_detected).Count -eq 0){
        Write-Host "No new vulnerabilities were Detected on $($VMDetailFileContent.DeviceName)"
        $VMDetailFileContent.vulninfo = "No additional vulnerabilities detected"
    }
    else{
        $VMDetailFileContent.vulninfo = $vulns_detected

        $Total_Vulns_detected = @($vulns_detected).Count
        Write-Host "Additional Vulnerabilities Detected on $($VMDetailFileContent.DeviceName) : $Total_Vulns_detected"

        #Add the new Vuln to the baseline report
        Write-Host "Adding the new detected vulnerabilities to the baseline report"
        $baseline_vm.vulninfo += $vulns_detected

        #=================================================================================
        #Place the JSON baseline report on the sharepoint
        #=================================================================================
        $Scanresultfilename = [System.IO.Path]::GetFileName($QualysBaselineScanReportPath)

        # Wrap in top-level structure
        $finalObject = [PSCustomObject]@{
            Apps = $baseline_vm
        }

        # Save the result
        $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $QualysBaselineScanReportPath -Encoding UTF8
        Write-Host "Baseline Scan Json updated at: $QualysBaselineScanReportPath"

        #Place the file on the azure 
        $REPORT_BLOBNAME_FILE = "$($BASELINE_BLOBNAME_FOLDER)/$Scanresultfilename"
        Set-AzureContainerContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -StorageAccountKey $StorageAccountAccessKey -BlobName $REPORT_BLOBNAME_FILE -FilePath $QualysBaselineScanReportPath
        Write-Host "Upload completed to azure blob: Blob containers/qualysreport/$($REPORT_BLOBNAME_FILE)"

        #=================================================================================
        #Place the Report on the sharepoint and agent
        #=================================================================================
        $vulns_Table = Get-VulnTable -vulns $vulns_detected
        $html_content = Set-QualysReportHTMLContent -QualysComparisonTemplatePath $QualysComparisonTemplatePath -VmName $VMDetailFileContent.DeviceName -assetId $VMDetailFileContent.AssetID -VulnsDetected $vulns_detected -QualysODScantable $vulns_Table -appName "No apps installed."
    
        #Set the HTML content
        $OutHTMLFileName = "$($VMDetailFileContent.DeviceName)-$($timestamp).html"
        $OutputHtmlPath = Join-Path -Path $OutHtmlFolderpath -ChildPath $OutHTMLFileName 
        $html_content | Out-File -FilePath $OutputHtmlPath

        #Store the Report on the Azure storage account
        $REPORT_BLOBNAME_FILE = "$($DAILY_REPORT_BLOBNAME)/$OutHTMLFileName"
        Set-AzureContainerContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -StorageAccountKey $StorageAccountAccessKey -BlobName $REPORT_BLOBNAME_FILE -FilePath $OutputHtmlPath

        Write-Output "Notify Vulnerabilities" # Flag for the email notification stage
    }

    #Save the VM Details File
    $OutJsonFileName = "$($VMDetailFileContent.DeviceName)-$($timestamp).json"
    $VMDetailFileContent = $VMDetailFileContent | ConvertTo-Json
    $OutFilePath = Join-Path -Path $OutHtmlFolderpath -ChildPath $OutJsonFileName
    Write-Host "Saving Scan data at $OutFilePath"
    Out-File -InputObject $VMDetailFileContent -FilePath $OutFilePath

    Write-Host "================================================================"

    #=================================================================================
    # Decommision the VM
    #=================================================================================
    asnp citrix.*
    Connect-Citrix
    Remove-VMs -machineName $vmName

}
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}