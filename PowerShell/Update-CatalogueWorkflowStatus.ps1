[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET,
    
    [ValidateNotNullOrEmpty()]
    [string]$TMUusername = $env:SMTP_USERNAME,

    [ValidateNotNullOrEmpty()]
    [string]$TMUpassword = $env:SMTP_PASSWORD
)

#Update the Catalogue with status for each App
function Update-CatlogueWorkflowStatus {
    param(
        [Parameter(Mandatory = $true)]
        $AccessToken,
        [Parameter(Mandatory = $true)]
        $App,
        [Parameter(Mandatory = $true)]
        $Text
    )
   
    ###########################################################
    # Headers and URO for updating the Apps status in catlogue
    ###########################################################
    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    #URL to create a new App ID.
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/bulk-update"

    ########################################################
    # Map Scope Tags in App.json  with Catalogue column Name
    ########################################################
    $Columns = @{
        Service_AMC = @{Status = 'AMC_Status';Workflow = 'AMC_Workflow_Phase'} #For AMC ADT APPS
        AMC = @{Status = 'AMC_Status';Workflow = 'AMC_Workflow_Phase'} #For AMC PROD APPS
        Service_AVC = @{Status = 'AVCC_Status';Workflow = 'AVCC_Workflow_Phase'} #For AVCC ADT/PROD APPS
    }
   
    ###########################################################
    # Get File contentsAppList.json
    ###########################################################

    $APPLISTJSONFILENAME = "appList.json"
    $APPLISTJSONFILEPATH = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath $APPLISTJSONFILENAME
    $APPLISTJSONFILECONTENT = (Get-content -Raw -path $APPLISTJSONFILEPATH | ConvertFrom-Json).Apps  

    $AppName = $App.IntuneAppName
    $AppFoldername = ($APPLISTJSONFILECONTENT | Where-Object { $_.IntuneAppName -eq $AppName }).AppFolderName
    
    ########################################################
    # Create PayloadJson
    ########################################################
    Write-Host "Updating Workflow Phase in Catalogue for Apps: $($App.IntuneAppName) to $Text"

    $AppFolderPath = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps/$AppFoldername"
    $AppJsonPath = Join-Path -Path $AppFolderPath -ChildPath "App.json"

    $AppJsonContent = Get-Content -Raw -Path $AppJsonPath | ConvertFrom-Json
    $ScopeTags = $AppJsonContent.Information.ScopeTagName
    if($null -eq $ScopeTags){Write-Host "Scope tags missing for $AppName. Skipping Catalogue entry... "; return "Failed"} #Skipp App in case the Scope tags missing

    # Bulk load for catlaogue update
    $updatelist = @()

    foreach ($scope in $ScopeTags) {

        # Build the updates object as a hashtable
        $updates = @{
            ($Columns[$scope].Status) = "In Progress"
            ($Columns[$scope].Workflow) = $Text
        }

        # Build the final object
        $data = [PSCustomObject]@{
            AppID   = "$($App.AppID)"
            updates = $updates
        }

        $updatelist += $data
    }
    
    if (@($updatelist).Count -gt 0){

        $payload = @{
        data = $updatelist
        }

        $payloadJson = $payload | ConvertTo-Json -Depth 10
        $status = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $payloadJson

        #Check if the App ID has been added to the Catalogue
        if($status.failed_count -gt 0 ){
            Write-Host "Catalogue Update [Failed]"
            Write-Host "Failed to update AppIDs [$($App.AppID)]"
            return "Failed"
        }else{
            Write-Host "Catalogue Update [Completed]"
            Write-Host "Updated Catalogue for AppIDs [$($App.AppID)]"
            return "Success"
        }
    }
}
#Returns the Access Token for the Catalogue Sharepoint Access
function Get-CatlogueAccessToken{
    param(
    [string]$username,
    [string]$password
    )
    $body = @{
        username = $username
        password = $password
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Method Post `
        -Uri "$($env:APP_CATALOGUE_BASE_URL)/auth/login" `
        -Headers @{
            "accept" = "application/json"
            "Content-Type" = "application/json"
        } `
        -Body $body

    $access_token = $response.access_token
    return $access_token
}
#Send Emails to catalogue entry
function Send-ScriptNotificationEmail {
    param(
        [Parameter(Mandatory = $true)]$Subject,
        [Parameter(Mandatory = $true)]$Recipient,
        [Parameter(Mandatory = $true)]$CC,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword
    )
    #Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "noreply-wps-app@allianz.com"
    $timestamp = (Get-Date).ToString("yyyy-MM-dd")  # Add timestamp to subject
    $messageSubject = $Subject
    $Body = " "

    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
 
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Port "587" -From $smtpFrom -To $Recipient -Cc $CC -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}

###################################################
#Update Ctalogue using API
###################################################
try{
    #Fetch the json file where all the information regarding IAT VM is present
    $Email = $false
    $IATVMCreationFileName = "APP_IAT.json"
    $IATVMCreationDataFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $IATVMCreationFileName

    if (Test-Path $IATVMCreationDataFilePath){
        $IATVMCreationData = Get-Content -Path $IATVMCreationDataFilePath| ConvertFrom-Json
        
        # Apps that need IAT testing
        $IATApps = $IATVMCreationData | Select-Object IntuneAppName, AppID -Unique
    }
    
    #Fetch the json file where all the information regarding VM is present
    $LEVMCreationFileName = $env:Input_File_name
    $LEVMCreationDataFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $LEVMCreationFileName
    $LEVMCreationData = Get-Content -Path $LEVMCreationDataFilePath| ConvertFrom-Json

    # Apps that need AO testing
    $AO = $LEVMCreationData.Apps | Where-Object {$_.IntuneAppName -notin @($IATVMCreationData.IntuneAppName)}
    $AOApps = $AO | Where-Object {$_.CrowdstrikeScan -eq "Pass" -and $_.QualysScan -eq "Pass" -and $_.WDACScan -eq "Pass"}

    #Fetch access token from catalogue status
    $token = Get-CatlogueAccessToken -username $username -password $password

    # Update the ctalogue for the Apps that need AO testing
    if($AOApps){
        foreach ($entry in $AOApps){
            Write-Host "Updating Catalogue for AO Apps."
            Update-CatlogueWorkflowStatus -AccessToken $token -App $entry -Text "AO Testing"
            $Email = $true
        }
    }else{
        Write-Host "No Apps marked for AO Testing."
    }

    # Update the ctalogue for the Apps that need AO testing
    if($IATApps){
        foreach ($entry in $IATApps){
            Write-Host "Updating Catalogue for IAT Apps."
            Update-CatlogueWorkflowStatus -AccessToken $token -App $entry -Text "IAT Phase"
            $Email = $true
        }
    }else{
        Write-Host "No Apps marked for IAT Testing."
    }

}
catch{
    Write-Output "PS_ERROR_DESC= Catalogue update failed."
    exit 1
}

###################################################
# Send the email to  for record keeping
###################################################
if ($Email){
    try{
        # Load JSON from file
        $EmailjsonPath = Join-Path -Path (Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "configs") -ChildPath "EmailRecipients.json"
        $data = Get-Content $EmailjsonPath | ConvertFrom-Json

        # Extract 'To' email for Sharepoint Catalogue
        $toEmail = $data.SharePointCatalogue.To

        # Extract and split 'Cc' emails into array for Sharepoint Catalogue
        $ccEmails = $data.SharePointCatalogue.CC

        foreach($Appintesting in $LEVMCreationData.Apps){
            
            if ($Appintesting.IntuneAppName -in @($IATVMCreationData.IntuneAppName)){
                # set subject line to IAT testing
                $testing = "Moved to IAT Testing"
            }
            else{
                # set subject line to AO testing
                $testing = "Moved to AO Testing"
            }
            
            $Subject = "IAF App:$($Appintesting.AppID):$($Appintesting.FamilyID):$($Appintesting.IntuneAppName):$($Appintesting.AppSetupVersion):$($testing)"
            
            #Send Email for the application catalogue entry 
            Write-Host "Sending Out Email for [$($Appintesting.IntuneAppName)] version: $($Appintesting.AppSetupVersion) [$testing]"
            Send-ScriptNotificationEmail -Subject $Subject -Recipient $toEmail -CC $ccEmails -TMUusername $TMUusername -TMUpassword $TMUpassword
        }
    }
    catch{
        Write-Output "PS_ERROR_DESC= Failed to send the email for Catalogue updation."
        exit 1
    }
}
else{
    Write-Host "No Apps found for Email."
}