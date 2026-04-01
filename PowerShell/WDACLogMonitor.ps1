<#
.SYNOPSIS
    Fetches Error 3076 logs from the Code Integrity event log on an Azure VM and generates an XML output.

.DESCRIPTION
    This script retrieves event logs with Event ID 3076 from the "Microsoft-Windows-CodeIntegrity/Operational" log on a specified Azure VM. The logs are filtered based on Event ID 3076 and the result is returned as an XML output.

.NOTES
    FileName: WDACLogMonitor.ps1
    Author : Manish Mishra
#>

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
    [string]$resourceGroupName
)

#Function To Fetch the Error 3076 logs and generate XML
function Detect-Errorlogs{
    param(
        [string] $rgName,
        [string] $vmName
        )

    # Script to run on the VM
 try {
    # Check the VM's power state
    $commandResult = $null
    $errorResult = $null
    $vm = Get-AzVM -ResourceGroupName $rgName -Name $vmName -Status
    $vmStatus = $vm.Statuses | Where-Object { $_.Code -like "PowerState*" }

    if ($vmStatus.Code -eq "PowerState/running") {
        # VM is running, proceed with the command execution
        $script = @'
try {
$events = Get-WinEvent -LogName "Microsoft-Windows-CodeIntegrity/Operational" -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -eq 3076 }

if ($events) {
    $events
    Write-Host "WDAC_Logs: $events"
    
} else {
    Write-Host "PS_ERROR_DESC: No matching events found"
}
} catch {
    Write-Host "PS_ERROR_DESC: Failed to detect WDAC Logs due to unexpected error :" + $_.Exception.Message
}
'@
        try {
            $commandResult = Invoke-AzVMRunCommand -ResourceGroupName $rgName -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString $script
            $errorResult = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "WDAC_Logs"
            return $errorResult
        } catch {
            Write-Host "PS_ERROR_DESC: Failed to execute command due to VM state error: " + $_.Exception.Message
            Exit 1
            #return "PS_ERROR_DESC: VM is not running or accessible."
        }

    } else {
        # VM is not running, return a custom error message
        Write-Host "PS_ERROR_DESC: VM is not running. Current state: $($vmStatus.DisplayStatus)"
        return "PS_ERROR_DESC: VM is powered off or not accessible."
    }
} catch {
    Write-Host "PS_ERROR_DESC: An unexpected error occurred: " + $_.Exception.Message
    #return $null #"Custom Error: An unexpected error occurred."
    Exit 1
}
}

#function to read AzVMRunCommand output
function Get-AzVMRunCommand-Response{
 param(
        [object]$commandResult,
        [string]$outPutKey
    )  
     $result = $null
    foreach ($message in $commandResult.Value) {
        #Write-Host "command output: " $message.Message
        if ($message.Message -match "PS_ERROR_DESC: (\S+)") {
            #Write-Host "message : "$message.Message
            $result = $message.Message
            break
        }
        if ($message.Message -match  "${outPutKey}: (\S+)") {
            #Write-Host "output key : " $outPutKey
            #Write-Host "matched value : " $message.Message
            #$result = $matches[1]
            $result =  $message.Message
            break
        } 
    }
    return $result 
}
#Function to generate WDAC Base Policy Event Log XML File
function Generate-BasePolicy-XML{
    param(
        [string] $rgName,
        [string] $vmName,
        [string] $AppId,
        [string] $AppName
        )  
     
$XMLFile = "$AppId`_$AppName.xml"
$XMLFilePath = "C:\Temp\$XMLFile"

$script = @'
$path = "@XMLFilePath@"

try {
    New-CIPolicy -MultiplePolicyFormat -Level Publisher -Fallback Hash -FilePath $path -UserPEs -Audit
    Write-Host "Base_Policy_Xml: $path"
} catch {
    Write-Host "PS_ERROR_DESC: Failed to create Base Policy. " + $_.Exception.Message
}
'@

# Replace the token locally before sending to Azure
$scriptToSend = $script.Replace("@XMLFilePath@", $XMLFilePath)
try {
    $commandResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $rgName `
    -Name $vmName `
    -CommandId "RunPowerShellScript" `
    -ScriptString $scriptToSend

    # Parse the output to extract BasePolicyID
    $basePolicyPath = $null
    
    $basePolicyPath = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "Base_Policy_Xml"

    # Output the result
    if ($basePolicyPath) {
        Write-Host "Base Policy command executed successfully, Base Policy created."
        Write-Host "Created Base Policy, Xml Path: $basePolicyPath"
        $lines = $basePolicyPath -split "`r`n|`n|`r"
        # Filter out the unwanted line
        $BasePolicyXMLFile = $lines | Where-Object { $_ -notmatch "Scan completed successfully" }
        return $BasePolicyXMLFile
    } else {
        #Write-Host "ERROR: Found error in Create Base Policy command output."
        Write-Host $basePolicyPath
        return $null
    }
}
catch {
    Write-Host "PS_ERROR_DESC: Found error while Creating Base Policy : " + $_.Exception.Message
    Exit 1
}

}
# command to convert Base policy to SupplymentBase policy
function Convert-BasePolicy-To-SupplymentBasePolicy{
    param(
        [string] $rgName,
        [string] $vmName,
        [string] $AppId,
        [string] $AppName ,
        [Guid] $BasePolicyID
        )  

#$BasePolicyID = '{67DDE2A6-C92D-481A-A040-8F3584676703}'
Write-Host $BasePolicyID
$script = @'
$path = "@XMLFilePath@"
$BasePolicyID = "@BasePolicyID@"
try {
    Set-CIPolicyIdInfo -FilePath $path -SupplementsBasePolicyID $BasePolicyID
    #Write-Host "Base Policy converted to Supplement Base Policy successfully."
    Write-Host "SupplementBasePolicyXml: $path"
} catch {
    Write-Host "PS_ERROR_DESC: Failed to convert Base Policy to Supplement Base Policy. " + $_.Exception.Message
}
'@

# Replace the token locally before sending to Azure
$FileName = "${AppId}_${AppName}.xml"
$BasePolicyXMLPath = "C:\Temp\$FileName"
$scriptToSend = $script.Replace("@XMLFilePath@", $BasePolicyXMLPath).Replace("@BasePolicyID@",$BasePolicyID)
#Write-host $scriptToSend
try{
$commandResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $rgName `
    -Name $vmName `
    -CommandId "RunPowerShellScript" `
    -ScriptString $scriptToSend

    # Output the result
   # Parse the output to extract BasePolicyID
    $SupplementBasePolicyPath = $null
    
    $SupplementBasePolicyPath = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "SupplementBasePolicyXml"
    # Output the result
    if ($SupplementBasePolicyPath) {
        Write-Host "Base Policy converted to Supplement Base Policy successfully."
        Write-Host "Supplement Base Policy XML file Path is: $SupplementBasePolicyPath"
        return $SupplementBasePolicyPath
    } else {
        #Write-Host "ERROR: Found error in Convert Base Policy to Supplement Base Policy command output."
        Write-Host $SupplementBasePolicyPath
        return $null
    }
}
catch {
    Write-Host "PS_ERROR_DESC: Found error while Converting Base Policy to supplement Base Policy : " + $_.Exception.Message
    Exit 1
}
}
#Remove audit mode:
function Remove-Audit-Mode{
    param(
        [string] $rgName,
        [string] $vmName,
        [string] $AppId,
        [string] $AppName
        
        )  
$script = @'
$path = "@XMLFilePath@"
$BasePolicyID = '{@BasePolicyID@}'
try {
    Set-RuleOption -FilePath $path -Option 3 -Delete
    #Write-Host "Audit Mode Removed from Base Policy XML successfully."
    Write-Host "AuditModeRemoved: Yes"
} catch {
    Write-Host "PS_ERROR_DESC: Failed to Remove Audit Mode from Base Policy Xml. " + $_.Exception.Message
}
'@
# Replace the token locally before sending to Azure
$FileName = "${AppId}_${AppName}.xml"
$BasePolicyXMLPath = "C:\Temp\$FileName"
$scriptToSend = $script.Replace("@XMLFilePath@", $BasePolicyXMLPath)
try{
#Write-host $scriptToSend
$commandResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $rgName `
    -Name $vmName `
    -CommandId "RunPowerShellScript" `
    -ScriptString $scriptToSend

   # Parse the output 
   $AuditMode = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "AuditModeRemoved"
    
    # Output the result
    if ($AuditMode -eq "Yes") {
        Write-Host "Audit Mode Removed from Base Policy XML successfully."
        #Write-Host "Audit Mode Removed from Base Policy XML"
        return $AuditMode
    } else {
        Write-Host $AuditMode
        return $null
    }
    }
  catch {
    Write-Host "PS_ERROR_DESC: Found error while Audit Mode : " + $_.Exception.Message
    Exit 1
}
}
#modify friendly name in xml file
function Update-FriendlyName{
    param(
        [string] $rgName,
        [string] $vmName,
        [string] $AppId,
        [string] $AppName
        )  
   
# Inner script (NO escape of $)
$scriptGet = @'
$xmlFilePath = "@PolicyXMLFilePath@"
$AppId = "@AppId@"
$AppName = "@AppName@"

 try {
        if (Test-Path -Path $xmlFilePath) {
            [xml]$xmlData = Get-Content -Path $xmlFilePath
            # Define the namespace
            $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xmlData.NameTable)
            $namespaceManager.AddNamespace("ns", "urn:schemas-microsoft-com:sipolicy")

            # Update FriendlyName attributes in FileRules
            foreach ($allowNode in $xmlData.SelectNodes("//ns:FileRules/ns:Allow", $namespaceManager)) {
                $friendlyName = $allowNode.Attributes["FriendlyName"].Value
                    $allowNode.Attributes["FriendlyName"].Value = $AppId +"_"+$AppName+"-"+$friendlyName
            }
            # Save the modified XML back to the file
            $xmlData.Save($xmlFilePath)
            Write-Host "FriendlyName: $xmlFilePath"
        } else {
        Write-Host "PS_ERROR_DESC: Policy File does not exist: $xmlFilePath"
        }
    }
    catch {
        Write-Host "PS_ERROR_DESC: Failed to update FriendlyName Xml. " + $_.Exception.Message
    }
'@

$FileName = "${AppId}_${AppName}.xml"
$xmlFilePath = "C:\Temp\$FileName"
$scriptToSend = $scriptGet.Replace("@PolicyXMLFilePath@", $xmlFilePath).Replace("@AppId@", $AppId).Replace("@AppName@", $AppName)
#Write-Host $scriptToSend
try{
$commandResult = Invoke-AzVMRunCommand `
    -ResourceGroupName $rgName `
    -Name $vmName `
    -CommandId "RunPowerShellScript" `
    -ScriptString $scriptToSend 

    $XmlPathWitUpdate_FriendlyName = $null
    
    $XmlPathWitUpdate_FriendlyName = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "FriendlyName"
    # Output the result
    if ($XmlPathWitUpdate_FriendlyName) {
        Write-Host "FriendlyName attributes updated successfully. XML file Path is: $XmlPathWitUpdate_FriendlyName"
        return $XmlPathWitUpdate_FriendlyName
    } else {
        #Write-Host "ERROR: Found error in Convert Base Policy to Supplement Base Policy command output."
        Write-Host $XmlPathWitUpdate_FriendlyName
        return $null
    }   
    }
  catch {
    Write-Host "PS_ERROR_DESC: Found error while update FriendlyName : " + $_.Exception.Message
    Exit 1
}
}
#function to create directory on Git and save file
function SaveFile_On_GitGub{
    param(
    [parameter(Mandatory = $true)]
    [string] $rgName,
    [parameter(Mandatory = $true)]
    [string] $vmName,
    [string]$GitHubRepoURL = "https://github.developer.allianz.io/api/v3/repos",
    [parameter(Mandatory = $true,HelpMessage = "Github Repo Owner Name is required.")]
    [string]$Owner,
    [parameter(Mandatory = $true,HelpMessage = "Github Repo Name is required.")]
    [string]$Repo,
    [parameter(Mandatory = $true,HelpMessage = "Github Repo Branch name is required to which file needs to be saved.")]
    [string]$Branch,
    [parameter(Mandatory = $true,HelpMessage = "Folder Name in Git Branch file to be uploaded, including Folder name.")]
    [string]$FolderPath,
    [parameter(Mandatory = $true,HelpMessage = "Path to the local file to be uploaded, including file name and extension.")]
    [string]$LocalFile,
    [parameter(Mandatory = $true,HelpMessage = "Include App ID.")]
    [string]$AppID,
    [parameter(Mandatory = $true,HelpMessage = "Include App Name.")]
    [string]$AppName
)

    $folderName = $AppID +"_"+ $AppName
    $FolderPath = $FolderPath + "/" + $folderName
    $ApiBaseUrl = $GitHubRepoURL
    $GitHubToken = $env:GIT_PAT_PSW

    $scriptGet = @'
$folderName = "@folderName@"
$FolderPath = "@FolderPath@"
$ApiBaseUrl = "@ApiBaseUrl@"
$Owner = "@Owner@"
$Repo ="@Repo@"
$Branch ="@Branch@"
$LocalFile = "@LocalFile@"
$GitHubToken = "@GitHubToken@"

    # Headers for authentication
   $headers = @{
        "Authorization" = "Bearer $GitHubToken"
        "Accept"        = "application/vnd.github.v3+json"
    }
    Write-Host $GitHubToken
    # --- 1. Check if folder exists ---
    try {
        # Try to get the folder content
        $folderCheck = Invoke-RestMethod -Uri "$ApiBaseUrl/$Owner/$Repo/contents/$FolderPath" -Headers $headers -Method Get
        Write-Host "FileSaveOnGithub: Folder exists: $FolderPath"
    }
    catch {
        # Folder doesn't exist, so we create it with a placeholder file (.gitkeep)
        Write-Host "FileSaveOnGithub: Folder does NOT exist. Creating folder: $FolderPath"
    
        # Create a simple placeholder content
        $createFolderBody = @{
            message = "Create folder placeholder"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("folder created automatically"))
            branch  = $Branch
            private = $false
        } | ConvertTo-Json

        # Send the request to create the placeholder file in the folder path
        $ApiUrl = "$ApiBaseUrl/$Owner/$Repo/contents/$FolderPath"
        Invoke-RestMethod -Method Put `
            -Uri "$ApiUrl/.gitkeep" `
            -Headers $headers `
            -Body $createFolderBody

        Write-Host "FileSaveOnGithub: Folder created successfully with placeholder file."
    }
    
        # --- 2. Upload the actual file to the folder ---
        #Write-Host $LocalFile
        if (Test-Path -Path $LocalFile) {
        
        $FileName = [System.IO.Path]::GetFileName($LocalFile)
        $FileContentBytes = [System.IO.File]::ReadAllBytes($LocalFile)
        $FileBase64 = [Convert]::ToBase64String($FileContentBytes)

        # check if file already exists (for updating)
        $fileApiUrl = "$ApiBaseUrl/$Owner/$Repo/contents/$FolderPath/$FileName"

        $sha = $null
        $headers = @{
            "Authorization" = "Bearer $GitHubToken"
            "Accept"        = "application/vnd.github.v3+json"
        }
        try {
            $existingFile = Invoke-RestMethod -Uri $fileApiUrl -Headers $headers
            $sha = $existingFile.sha
            Write-Host "FileSaveOnGithub: Updating existing file..."
        }
        catch {
            Write-Host "FileSaveOnGithub: Uploading new file..."
        }

        $body = @{
            message = "Add or update file $FileName"
            content = $FileBase64
            branch  = $Branch
        }

        if ($sha) { $body.sha = $sha }
          write-host $fileApiUrl
          $bodyJson = $body | ConvertTo-Json
          Invoke-RestMethod -Method Put -Uri $fileApiUrl -Headers $headers  -Body $bodyJson
          Write-Host "FileSaveOnGithub: File uploaded successfully to $FolderPath/$FileName"

        } else {
            Write-Host "PS_ERROR_DESC: File not found at path: $LocalFile"
        }
'@
 
    $scriptToSend = $scriptGet.Replace("@folderName@", $folderName).Replace("@FolderPath@", $FolderPath).Replace("@ApiBaseUrl@", $ApiBaseUrl).Replace("@GitHubToken@", $GitHubToken).
    Replace("@Owner@", $Owner).Replace("@Repo@", $Repo).Replace("@Branch@", $Branch).Replace("@LocalFile@", $LocalFile).Replace("@GitHubToken@",$GitHubToken)
    #Write-Host "command to execute on VM" 
    #Write-Host $scriptToSend
try{
    #Write-Host $scriptToSend
    $commandResult = Invoke-AzVMRunCommand `
        -ResourceGroupName $rgName `
        -Name $vmName `
        -CommandId "RunPowerShellScript" `
        -ScriptString $scriptToSend 

        $XmlFileUploadOnGit = $null
    
        $XmlFileUploadOnGit = Get-AzVMRunCommand-Response -commandResult $commandResult -outPutKey "FileSaveOnGithub"
        # Output the result
        if ($XmlFileUploadOnGit) {
            Write-Host "XML file uploaded on GitHub. XML file Path is: $XmlFileUploadOnGit"
            return $XmlFileUploadOnGit
        } else {
            #Write-Host "ERROR: Found error in Convert Base Policy to Supplement Base Policy command output."
            Write-Host $XmlFileUploadOnGit
            return $null
        }  
 }
  catch {
    Write-Host "PS_ERROR_DESC: Found error while Saving WDAC error log file on Github : " + $_.Exception.Message
    Exit 1
}

}
$VMInfoFileName = $env:Input_File_name
$jsonFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName
Write-Host "Json File Path is :- "$jsonFilePath

#======================== Connect AzAccount for remote VM access ==========================
$SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$Credential     = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)

$connection = Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential
$connection = Select-AzSubscription -SubscriptionId $SubscriptionId
#===========================================================================================


try {
    # Check if the JSON file exists
    if (Test-Path $jsonFilePath) {   
        # Load JSON data 
        $jsonObject = Get-Content -Path $jsonFilePath | ConvertFrom-Json

        $WDAC_Scan_Result = @() 
        foreach ($app in $jsonObject.Apps) {
            
            # Check for the installation status of the application
            if ($app.InstallationCheck -eq "Failed"){
                Write-Host "$($app.IntuneAppName) Failed to install on the $($app.DeviceName). Skipping Scan..."
                $app | Add-Member -NotePropertyName "WDACScan" -NotePropertyValue "App not installed" -Force
                continue
            }

        #======================== Initialize WDAC scan result Object ==========================
            $currentResult = [PSCustomObject]@{

            IntuneAppName     = $app.IntuneAppName
            AppSetupVersion   = $app.AppSetupVersion
            FamilyID          = $app.FamilyID
            AppId            =  $app.AppID
            DeviceName        = $app.DeviceName
            TUAccount         = $app.TUAccount
            WDACScanStatus    = ""
            WDACScanResult    = ""
            Description       = "" 
            WDACScanReport    = ""
            }
            #=========== Set the VM Name and Resource Group Name ==================           
            $ResourceGroupName = $resourceGroupName
            $VmName = $app.DeviceName

            $AppName = $app.IntuneAppName
            $AppId = $app.FamilyID   # the FamilyID needs to be replaced with AppID
            $eventMessage = Detect-Errorlogs -rgName $ResourceGroupName -vmName $VmName
           
            if ($eventMessage -match "PS_ERROR_DESC: (\S+)")
            {
                $response = $eventMessage.split("PS_ERROR_DESC:")
                if($response.Trim() -eq "No matching events found") {              
                    Write-Host "No WDAC event Found."
                    $currentResult.WDACScanStatus    = "Completed"
                    $currentResult.WDACScanResult    = "Pass"
                    $currentResult.Description = "NA"
                    $app | Add-Member -NotePropertyName "WDACScan" -NotePropertyValue "Pass" -Force
               }
                else {
                Write-Host $response #$eventMessage.split("PS_ERROR_DESC:")[1]
                $currentResult.WDACScanStatus    = "In-Complete"
                $currentResult.WDACScanResult    = "Failed"
                $currentResult.Description = $eventMessage
                $app | Add-Member -NotePropertyName "WDACScan" -NotePropertyValue "Failed" -Force
              }
            }
            
            elseif($eventMessage -match "WDAC_Logs: (\S+)")
            {
                Write-Host "Error detected on $VmName. [App Installed: $AppName]"
                $BasePolicyXML = Generate-BasePolicy-XML -rgName $resourceGroupName  -vmName $VmName -AppId $AppId -AppName $AppName
                Write-Host "Base Policy Xml generated."
                
                $BasePolicyID = $env:BasePolicyID

                $SupplementBasePolicy = Convert-BasePolicy-To-SupplymentBasePolicy -rgName $resourceGroupName  -vmName $vmName -AppId $AppId -AppName $AppName -BasePolicyID $BasePolicyID
                Write-Host "Base Policy Converted to Supplement Base policy."
                
                $RemoveAuditMode = Remove-Audit-Mode -rgName $resourceGroupName  -vmName $vmName -AppId $AppId -AppName $AppName
                Write-Host "Audit Log removed from Base Policy."

                $updatedFriendlyNameFile = Update-FriendlyName -rgName $resourceGroupName  -vmName $vmName -AppId $AppId -AppName $AppName 
                Write-Host "FriendlyName updated from Base Policy XMl."
                
                # --------------------------------------Save WDAC file on GitHub -----------------------------------------
                $Owner       = $env:Owner
                $Repo        = $env:Repo
                $Branch      = $env:Branch
                $FolderPath  = $env:FolderPath   # Folder inside repo

                #Local XML file path to upload on Github
                $FileName = "${AppId}_${AppName}.xml"
                $LocalFile = "C:\Temp\$FileName"
                #$LocalFile   = 
                Write-Host "File path with updated FriendlyName $LocalFile"
                SaveFile_On_GitGub -rgName $resourceGroupName -vmName $VmName -Owner $Owner -Repo $Repo -Branch $Branch -FolderPath $FolderPath -LocalFile $LocalFile -AppID $AppId -AppName $AppName
                $currentResult.WDACScanStatus    = "Completed"
                $currentResult.WDACScanResult    = "Failed"
                $currentResult.Description= $eventMessage
                $currentResult.WDACScanReport="NA"
                $app | Add-Member -NotePropertyName "WDACScan" -NotePropertyValue "Failed" -Force

            }   
            
            
            $WDAC_Scan_Result = $WDAC_Scan_Result + $currentResult
        }
        $WDACScanResult = [PSCustomObject]@{
          Apps = $WDAC_Scan_Result
            }

            $FinalResult = $WDACScanResult | ConvertTo-Json -Depth 7 
            # saving stage result file inside of the pipeline
            $WDAC_Result = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_WDAC_Result.json"
            $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
            $ScanFolder = Join-Path -Path "C:\SCANS\WDAC" -childPath $IAF_BUILD_TAG
            if(-not(Test-Path $ScanFolder)){New-Item -Path $ScanFolder -ItemType Directory | Out-Null}
            $OutputJsonPath = Join-Path -Path $ScanFolder -ChildPath $WDAC_Result

            Write-Host $OutputJsonPath
            Set-Content -Path $OutputJsonPath -Value $FinalResult

        $jsonObject | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFilePath -Encoding UTF8
    }
    else {
        Write-Host "PS_ERROR_DESC= JSON file at path '$jsonFilePath' does not exist."
        exit 1
    }
}
catch {
    Write-Host "PS_ERROR_DESC= Error occurred. Error: $_"
    exit 1
}
