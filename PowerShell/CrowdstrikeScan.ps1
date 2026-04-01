<#
.SYNOPSIS
    Runs CrowdStrike system-drive scans on Azure VMs and reports suspicious files.

.DESCRIPTION
     Runs CrowdStrike system-drive scans on Azure VMs and reports suspicious files.

.NOTES
    FileName: CrowdStrikeScan.ps1
    Author: Mo Adil Ansari / Daniyal Ahmad
    Version: 1.0
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$resourceGroupName,
    [string]$ClientId,
    [string]$ClientSecret = $env:PROD_CLIENT_SECRET_LE,
    [string]$BlobNameFolder,
    [string]$ARCHIVESTORAGEACCOUNTNAME,
    [string]$ARCHIVECONTAINERNAME,
    [string]$StorageAccountAccessKey = $env:SA_SECRET,
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET
)

Import-Module "$($env:WORKSPACE)/Scripts/UpdateCatalogue.psm1"

# Function to check scan status and count suspicious files
function Get-ScanStatus {
    param (
        [string]$ScanId
    )

    $statusScript = @"
    & `"C:\Program Files\Crowdstrike\CsScancli.exe`" --status=$ScanId
"@

    $command2 = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $statusScript
    $CommandOutput2 = $command2.Value.Message

    # Normalize spaces and split lines
    $lines = ($CommandOutput2.Trim() -replace '\s+', ' ') -split "`r?`n"

    $status = ""
    $suspiciousFiles = 0

    foreach ($line in $lines) {
        if ($line -match "Status:\s*(\w+)") {
            $status = $matches[1]
        }
        if ($line -match "Suspicious Files:\s*(\d+)") {
            $suspiciousFiles = [int]$matches[1]
        }
    }

    return @{ Status = $status; SuspiciousFiles = $suspiciousFiles; CommandOutput = $CommandOutput2 }
}

#Fetch the Supspicious files
function Fetch-SuspiciousFiles{
    param (
            [string]$CommandOutput
        )
    # Extract Suspicious Files count
    $SuspiciousCount = [regex]::Match($CommandOutput, "Suspicious Files:\s*(\d+)").Groups[1].Value

    # Extract suspicious file entries (lines that begin with number + colon)
    $SuspiciousFiles = ($CommandOutput -split "`n" | Where-Object { $_ -match '^\s*\d+:' }) -replace '^\s*\d+:\s*"', '' -replace '"$', ''
    
    return @{ SuspiciousCount = $SuspiciousCount; Paths = $SuspiciousFiles }

}

#Fetch the Event Logs
function Get-EventLogs{
#Command to fetch the crowdstrike logs in event viewer
$scriptEventViewer = @'
Get-WinEvent -FilterHashtable @{
    LogName = "CrowdStrike-Falcon Sensor-CSFalconService/Operational"
    Id      = 4
} | ForEach-Object {
    $xml = [xml]$_.ToXml()

    $xml.Event.EventData.Data |
        Where-Object { $_.Name -eq "ObjectName" } |
        Select-Object -ExpandProperty '#text'
}
'@


    #Fetch the event logs from the Vms:
    foreach ($vm in $successfullCompletedScans){
        $vmName = $vm.DeviceName
        $app = $finalObject.Apps | Where-Object {$_.DeviceName -eq $vm.DeviceName}

        $eventviewercommand = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $scriptEventViewer
        if ($eventviewercommand.Value.Message -like "*No events were found*")
        {
            Write-Host "No Suspicious Files detetcted on $vmName."
            $vm.Result = "No malicious files were detected"
            $app | Add-Member -NotePropertyName "CrowdstrikeScan" -NotePropertyValue "Pass" -Force
            continue
        }

        #Fetch the event logs in case a vulnerability detected
        $FilePath = $eventviewercommand.Value.Message
        $vm.Result = $FilePath
        Write-Host "Malicious Files detected on $vmName"
        Update-CatlogueStatus -AccessToken $token -Apps $vm -Reason "IAF - CrowdStrike malware identified"
        $app | Add-Member -NotePropertyName "CrowdstrikeScan" -NotePropertyValue "Failed" -Force
    }
}

# Generate HTML table for vulnerabilities
function Generate-MaliciousFilePathTable {
    param (
        $malfiles,
        $result
        )

    if ($malfiles.Count -eq 0) {
        return "<p>No threat detected.<br>$($result)</p>"
    }
    $table = @"
<table>
    <tr><th>Serial No.</th><th>File Path</th><th>File Name</th></tr>
"@
    $count = 1
    foreach ($filepath in $malfiles) {
        $filename = ($filepath -split "\\")[-1]
        $table += "<tr><td>$count</td><td>$filepath</td><td>$filename</td></tr>"
        $count += 1
    }
    $table += "</table>"
    return $table
}

# Set the HTML contents in the template file
function Set-ReportHTMLContent{
        
        param(
        [string]$CrowdstrikeHtmlTemplatePath,
        [string]$VmName,
        [string]$appName,
        [string]$mal_table,
        $FilesDetected
        )
        try{
            $template = Get-Content -Path $CrowdstrikeHtmlTemplatePath -Raw

            $TotalFilesDetected = $FilesDetected.Count

            # Generate HTML report using template
            $template = $template -replace '{{Date}}', (Get-Date)
            $template = $template -replace '{{VMNAME}}', $VmName
            $template = $template -replace '{{APPINSTALLED}}', $appName

            $template = $template -replace '{{TOTAL}}', $TotalFilesDetected

            $template = $template -replace '{{MAL_ROWS}}', $mal_table
            $html = $template
               
            return $html

        } 
        catch {
            Write-Error "Failed to create HTML file: $_"
            exit 1
        }

}

#Convert FIle to PDF
function Generate-PDFReport{
 
    param(
    [string]$SourceFolderPath,
    [string]$PDFFileName,
    [string]$SourceFileName
    )

    # PDF Report Generation
    $TempUserDataDir = "$env:TEMP\edge_headless_profile"
    $EdgeErrorLog  = Join-Path -Path (Join-Path -Path $env:WORKSPACE -ChildPath "configs") -ChildPath "Error.log"
    $ReportPath_PDF = Join-Path -Path $SourceFolderPath -ChildPath $PDFFileName
    $ReportPath = Join-Path -Path $SourceFolderPath -ChildPath $SourceFileName

    $process = Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    -ArgumentList "--headless --disable-gpu --disable-background-networking --disable-software-rasterizer --disable-features=Sync,Identity --disable-sync --disable-features=NetworkService,RendererCodeIntegrity --no-default-browser-check --no-first-run --user-data-dir=$TempUserDataDir --print-to-pdf=$ReportPath_PDF $ReportPath --disable-logging  "`
    -NoNewWindow -Wait `
    -RedirectStandardError $EdgeErrorLog `
    -ErrorAction SilentlyContinue

    if (Test-Path -Path $EdgeErrorLog) {

        # Read the content of the Error.log file
        $logContent = Get-Content -Path $EdgeErrorLog
        Remove-Item -Recurse -Force $TempUserDataDir -ErrorAction SilentlyContinue
        Remove-Item $EdgeErrorLog -ErrorAction SilentlyContinue

        $messages = $logContent | Where-Object { $_ -match "bytes" }
        if ($messages.Count -gt 0) {
            $messages | ForEach-Object { Write-Host $_ }
        } 
        else {
            Write-Host "PS_ERROR_DESC= $ReportPath was not Converted to PDF format"
            exit 1
        } 
    }

    #Remove .HTML and Warning Log FILE
    Remove-Item $ReportPath -ErrorAction SilentlyContinue
    Write-Host "PDF Report generated successfully at $ReportPath_PDF"

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

try{
    # Convert client secret to a secure string and create credential object
    $SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential     = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)

    # Connect to Azure using Service Principal
    $connection = Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential
    $connection = Select-AzSubscription -SubscriptionId $SubscriptionId

    # Ensure the Input file exists
    $VMInfoFileName = $env:Input_File_name
    $jsonFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName

    # HTML Template
    $CrowdstrikeReportTemplatePath = Join-Path -Path $env:WORKSPACE -ChildPath "configs\Crowdstrike_Report_template.html"

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
    }
    else {
        Write-Output "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }

    # Fetch the device names
    $deviceObjbase = foreach ($entry in $finalObject.Apps) {
        [PSCustomObject]@{
            DeviceName = $entry.DeviceName
            IntuneAppName = $entry.IntuneAppName
            Version = $entry.AppSetupVersion
            Triggered = "No"
            ScanID = ""
            Result = ""
            ScanStatus = ""
            InstallationCheck = $entry.InstallationCheck
        }
    }
    
    $deviceObj = $deviceObjbase | Where-Object {$_.InstallationCheck -ne 'Failed'}

    # Script to start AV scan on the VM
    $Crowdstrikescript = @'
& "C:\Program Files\Crowdstrike\CsScancli.exe" --scan-system-drive
'@
    #==========================================================================================
    # Intiate Crowdstrike Scan for each VM
    #==========================================================================================
    $token = Get-CatalogueAccessToken -username $username -password $password # Catlogue token
    foreach ($vm in $deviceObj){
        $vmName = $vm.DeviceName

        try{
            # Execute the scan command on the VM
            Write-Host "Initiate Crowdstrike Scan[$vnName]"
            $command = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $Crowdstrikescript

            # Extract the Scan ID from the command output
            $CommandOutput = $command.Value.Message
            $scanId = ($CommandOutput -split ':')[1].Trim()

            if (-not $scanid){
            Write-Host "Scan Could not be inititated for $vmName"
            Update-CatlogueStatus -AccessToken $token -Apps $vm -Reason "IAF - CrowdStrike malware identified"
            continue
            }

            Write-Host "OnDemand Crowdstrike Scan Intitiated on $vmName "
            $vm.Triggered = "Yes"
            $vm.ScanID = $scanId

        }
        catch{
            Write-Warning "Failed to intiate Crowdstrike Scan on $vmName : $_"
            $vm.Triggered = "Failed to intiate Crowdstrike Scan on $vmName : $_"
            Update-CatlogueStatus -AccessToken $token -Apps $vm -Reason "IAF - CrowdStrike malware identified"
        }   
    }

    #==========================================================================================
    #Wait params for Scan to complete
    #==========================================================================================
    $maxRetries = 5 #attempts
    $delayMinutes = 5 #minutes

    #Fetch the Status from each VM
    for ($retryCount = 0; $retryCount -le $maxRetries; $retryCount++) {

        $token = Get-CatalogueAccessToken -username $username -password $password # Catlogue token

        #Skip the Iteration  of the Completed Scan
        $RunningDevices = $deviceObj | Where-Object { $_.ScanStatus -ne "Completed" -and $_.Triggered -eq "Yes"}

        #Check if devices in running status and Initiate a sleep before retry
        if(@($RunningDevices).count -gt 0){
            Write-Host "OnDemand Crowdstrike Scan is still running. Waiting $delayMinutes minutes before retrying... (Attempt $($retryCount+1))"
            Start-Sleep -Seconds ($delayMinutes * 60)
        }
        else{
            break
        }

        foreach ($vm in $RunningDevices){
            $vmName = $vm.DeviceName
            $scanId = $vm.ScanID

            #Fetch the Scan Status
            $result = Get-ScanStatus -ScanId $scanId
                $status = $result.Status
                $suspiciousFiles = $result.SuspiciousFiles
                $CommandOutput = $result.CommandOutput

                if ($status -eq "Completed") {
                    if ($suspiciousFiles -eq 0) {
                        Write-Host "OnDemand Crowdstrike Scan completed successfully for $vmName ."
                        $vm.Result = "No suspicious files detected."
                    } 
                    else {
                        $SuspiciousFilesObj = Fetch-SuspiciousFiles -CommandOutput $CommandOutput
                        Write-Host "OnDemand Crowdstrike Scan completed with suspicious file(s)."
                        $vm.Result = "Suspicious Files detected. $($SuspiciousFilesObj.Paths)"
                    }
                    $vm.ScanStatus = "Completed"
                }

                elseif ($status -eq "Running") {
                    $vm.ScanStatus = "Running"
                    $vm.Result = "Scan still in progress."
                }

                else {
                    Write-Host "Scan did not run successfully for $vmName. Status: $status"
                    $vm.ScanStatus = $status
                }
        }
    }

    #==========================================================================================
    #Get Event Logs
    #==========================================================================================
    $token = Get-CatalogueAccessToken -username $username -password $password # Catlogue tokenp
    $successfullCompletedScans = $deviceObj | Where-Object { $_.ScanStatus -eq "Completed"}

    if(@($successfullCompletedScans).Count -gt 0){
        Get-EventLogs
    }else{
        Write-Output "The Crowdstrike scan failed for all the VMs. "
        Update-CatlogueStatus -AccessToken $token -Apps "All" -Reason "IAF - CrowdStrike malware identified" -InputFilePath $jsonFilePath
    }

    #==========================================================================================
    #Save the report incase a VM has threat 
    #==========================================================================================
    $OutJsonCrowdstrikeResults = "Crowdstrike_Results.json"
    $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
    $ScanFolder = Join-Path -Path "C:\SCANS\Crowdstrike" -childPath $IAF_BUILD_TAG
    $OutJsonCrowdstrikeResultPath = Join-Path -Path $ScanFolder -ChildPath $OutJsonCrowdstrikeResults

    # Wrap in top-level structure
    $resultObject = [PSCustomObject]@{
        Apps = $deviceObj
    }
    if(-not(Test-Path $ScanFolder)){New-Item -Path $ScanFolder -ItemType "directory"| Out-Null}
    $resultObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutJsonCrowdstrikeResultPath -Encoding UTF8

    foreach($vm in $deviceObj){
        
        if ($vm.Result -eq "No malicious files were detected"){continue}
        
        # Ensure the Input file exists
        $ResultFileName = "$($vm.DeviceName)_CrowdstrikeScan_Report.html"
        $OutFolderpath = Join-Path -Path $ScanFolder -ChildPath "Results"
        if(-not(Test-Path $OutFolderpath)){New-Item -Path $OutFolderpath -ItemType "directory"| Out-Null}
        $OutHtmlFilePath = Join-Path -Path $OutFolderpath -ChildPath $ResultFileName

        #Create a table to be placed in th pdf file for the malicious files detetcted
        
        $malfiles = $vm.Result | Select-String -Pattern '\\Device\\.*' -AllMatches | ForEach-Object { $_.Matches.Value }
        $mal_table = Generate-MaliciousFilePathTable -malfiles $malfiles -result $vm.Result

        #Generate the HTML content and save PDF from the template
        $appName = "$($vm.IntuneAppName) $($vm.Version)"
        $html_content = Set-ReportHTMLContent -VmName $vm.DeviceName -CrowdstrikeHtmlTemplatePath $CrowdstrikeReportTemplatePath -appName $appName -mal_table $mal_table -FilesDetected $malfiles
        
        $html_content | Out-File -FilePath $OutHtmlFilePath

        #Convert to PDF
        $PDFFileName = "$($vm.DeviceName)_CrowdstrikeScan_Report.pdf"
        Generate-PDFReport -SourceFolderPath $OutFolderpath -PDFFileName $PDFFileName -SourceFileName $ResultFileName

        #Move the PDF file to sharepoint
        $PDFlocation = Join-Path -Path $OutFolderpath -ChildPath $PDFFileName
        $REPORT_BLOBNAME_FILE = "$($BlobNameFolder)/$PDFFileName"
        Set-AzureContainerContent -StorageAccountName $ARCHIVESTORAGEACCOUNTNAME -ContainerName $ARCHIVECONTAINERNAME -StorageAccountKey $StorageAccountAccessKey -BlobName $REPORT_BLOBNAME_FILE -FilePath $PDFlocation
    }

    #Update the input file for results
    $finalObject.Apps | ForEach-Object {
        if ($_.InstallationCheck -eq "Failed") {
            $_ | Add-Member -NotePropertyName "CrowdstrikeScan" -NotePropertyValue "App not installed" -Force
        }
    }

    $finalObject | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath -Encoding UTF8

}
catch{
    Write-Output "PS_ERROR_DESC= Crowdstrike scan failed: $_"
    exit 1
}