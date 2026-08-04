Import-Module "$env:WORKSPACE\PowerShell/FinalEmail-Content.psm1"
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1"
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppUpgradeDetection.psm1"
function Get-IATTestingStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppID
    )

    try {
        # Strip "FAM" prefix if present (API expects numeric ID only)
        $numericAppID = $AppID -replace '^FAM', ''
        
        # Authenticate with App Catalogue API
        $APP_CATALOGUE_PASSWORD = $env:APP_CATALOGUE_SECRET
        $AccessToken = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $APP_CATALOGUE_PASSWORD
        
        if (-not $AccessToken) {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in Get-IATTestingStatus method, Error : Failed to obtain access token"
            return $null
        }
        
        # Make GET request to App Catalogue API
        $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/$numericAppID"
        $appData = Invoke-RestMethod `
            -Uri $uri `
            -Method GET `
            -Headers @{ 
                Authorization = "Bearer $AccessToken"
                accept = "application/json" 
            } `
            -ErrorAction Stop
        
        # Extract and return IAT_Testing field
        return $appData.IAT_Testing
    }
    catch {
        Write-Host "PS_ERROR_DESC= Runtime error occurred in Get-IATTestingStatus method, Error : $($_.Exception.Message)"
        return $null
    }
}
function Prepare_EmailBody_TableContent {
    param (
        [parameter(Mandatory = $true)]
        [string]$AppName,  

        [parameter(Mandatory = $false)]
        [array]$AppID,  

        [parameter(Mandatory = $true)]
        [string]$AppVersion,  

        #[parameter(Mandatory = $true)]
        [string]$SmokeTestResult,  

        #[parameter(Mandatory = $true)]
        [string]$WDACResult,  

        #[parameter(Mandatory = $true)]
        [string]$QualysScanResult , 

        #[parameter(Mandatory = $false)]
        [string]$CrowdstrikeResult,

        [string]$ContinuousTestResult,

        [parameter(Mandatory = $true)]
        [string]$pickemailtemplate
        
    )

    # Read and populate email template
    try {
        # Determine template path based on the flag passed from caller
        if ($pickemailtemplate -eq "Failed") {
            # Any test failed - use Failure template
            $templatePath = "$($env:WORKSPACE)\configs\EmailTemplates\CombinedEmail_Failure.html"
            Write-Host "Using Failure template"
        } elseif ($pickemailtemplate -eq "IAT") {
            # IAT_Testing is set - use IAT template
            $templatePath = "$($env:WORKSPACE)\configs\EmailTemplates\CombinedEmail_IATTest.html"
            Write-Host "Using IAT template"
        } elseif ($pickemailtemplate -eq "AO") {
            # IAT_Testing is null/empty - use AO template
            $templatePath = "$($env:WORKSPACE)\configs\EmailTemplates\CombinedEmail_AOTest.html"
            Write-Host "Using AO template"
        } else {
            Write-Host "PS_ERROR_DESC= Invalid email template type: $pickemailtemplate. Valid values are: Failed, IAT, AO"
            exit 1
        }
        
        # Write-Host "Template file path :- " $templatePath
        if (-not (Test-Path $templatePath)) {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_EmailBody_TableContent method. Email template file not found at: $templatePath"
            exit 1
        }
        $emailTemplate = Get-Content $templatePath -Raw -ErrorAction Stop
        # Write-Host "Email tempalte content"
        
        $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Generate HTML table rows from data
        # NOTE: The parameters WDACResult, QualysScanResult, CrowdstrikeResult, ContinuousTestResult
        # should already be HTML row strings (not JSON)
        $rowTemplate = ""
        $rowTemplate += $SmokeTestResult
        $rowTemplate += $WDACResult
        $rowTemplate += $QualysScanResult
        $rowTemplate += $CrowdstrikeResult
        $rowTemplate += $ContinuousTestResult
       

        $htmlRows = $rowTemplate
        #Write-Host "App Short-cuts with Test Result for email body" 
        
        # Populate template placeholders
        $emailBody = $emailTemplate -replace '{{BUILD_ID}}', 'N/A'
        $emailBody = $emailBody -replace '{{GENERATED_TIME}}', ([string]$currentDateTime)
        $emailBody = $emailBody -replace '{{TABLE_ROWS}}', ([string]$htmlRows)
        #$emailBody = $emailBody -replace '{{ERROR_LOGS}}', ([string]$TestDetail)
        if ($app.InstallationCheck -eq "Failed"){
            $emailBody = $emailBody -replace '{{ERROR_REMARK}}', ('NOTE:   <strong>{{App_Name}} - {{App_Version}}</strong> Failed to install on the smoke test VM.<br/><br/>')
        }
        else{
          $emailBody = $emailBody -replace '{{ERROR_REMARK}}',(' ')
        }
        $emailBody = $emailBody -replace '{{App_Name}}', ([string]$AppName)
        $emailBody = $emailBody -replace '{{App_ID}}', ([string]$AppID)
        $emailBody = $emailBody -replace '{{App_Version}}', ([string]$AppVersion)
        
        return $emailBody
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_EmailBody_TableContent method, Error : $($_.Exception.Message)"
        exit 1
    }
}
function SendTestResultNotification {
    param (
        #[parameter(Mandatory = $false)]
        [string[]]$Attachment,
 
        [parameter(Mandatory = $true)]
        [string]$Subject,
       
        [parameter(Mandatory = $true)]
        [string]$emailBody,
 
        [parameter(Mandatory = $true)]
        [string[]]$To,  # New: Array for multiple primary recipients
       
        [parameter(Mandatory = $false)]
        [string[]]$Cc   # New: Array for CC recipients (optional)
 
    )
 
    # SMTP Configuration
 
    $SMTPServer = "tmu-cs.mail.allianz"  
    $SMTPPort = 587                      
    $From = $env:SMTP_From
    $Username = $env:SMTP_UserName 
   $Password = $env:Password
   
    #Write-Host "SMTPServer : " $SMTPServer
    #Write-Host "SMTPPort : " $SMTPPort
    #Write-Host "From :" $From
    #Write-Host "Username : " $Username
    #Write-Host "Password : " $Password
    #Write-Host "To :" $To
    # Create secure credential object
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
 
    # Validate Attachments
    $validAttachments = @()
    if ($Attachment) {
        foreach ($file in $Attachment) {
            if (-not [string]::IsNullOrWhiteSpace($file)) {
                if (Test-Path $file) {
                    $validAttachments += $file
                } else {
                    Write-Host " Attachment file does not exist: $file"
                }
            }
        }
    }
 
    if ($validAttachments.Count -eq 0) {
        Write-Host "No valid attachments found."
        # Send email without attachment
        try {
            $mailParams = @{
                From = $From
                To = $To
                Subject = $Subject
                Body = $emailBody
                BodyAsHtml = $true
                SmtpServer = $SMTPServer
                Port = $SMTPPort
                Credential = $Credential
                UseSsl = $true
            }
            if ($Cc.Count -gt 0) {
                $mailParams.Cc = $Cc
            }
            Send-MailMessage @mailParams
            Write-Host " Email sent successfully to $To without attachment."
        }
        catch {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in SendTestResultNotification method, Error : $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        # Send email with attachment
        try {
            $mailParams = @{
                From = $From
                To = $To
                Subject = $Subject
                Body = $emailBody
                BodyAsHtml = $true
                SmtpServer = $SMTPServer
                Port = $SMTPPort
                Credential = $Credential
                UseSsl = $true
                Attachments = $validAttachments
            }
            if ($Cc.Count -gt 0) {
                $mailParams.Cc = $Cc
            }
            Send-MailMessage @mailParams
            Write-Host " Email sent successfully to $To with attachment."
        }
        catch {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in SendTestResultNotification method, Error : $($_.Exception.Message)"
            exit 1
        }
    }
}
function Prepare_Rows_For_SmokeTest {
    param (
        [parameter(Mandatory = $false)]
        [string]$SmokeTestResult     
    )

    # Read and populate email template
    try {
       
        $smokeTestResultData = $SmokeTestResult | ConvertFrom-Json
        $AppName = $smokeTestResultData.IntuneAppName
        $AppID = $smokeTestResultData.AppID
        $AppVersion = $smokeTestResultData.AppSetupVersion
        $FamilyID = $smokeTestResultData.FamilyID
        
        # Generate HTML table rows from data
        
        $rowTemplate = "<tr class='{className}'><td>{AppID}</td><td>{AppName}</td><td>{AppVersion}</td><td>{TestName}</td><td>{ShortcutName}</td><td>{TestStatus}</td><td>{AdditionalDetail}</td></tr>"
        $htmlRows = ""
        
        $Appshortcuts = $smokeTestResultData.ActionsResult
        #Write-Host $Appshortcuts | ConvertTo-Json -Depth 10
        $EventFinishedTitle = $smokeTestResultData.EventFinishedTitle 
        $EventConnectionTitle = $smokeTestResultData.EventConnectionTitle 
        $EventConnectionDescription = $smokeTestResultData.EventConnectionDescription
        $loginState = $smokeTestResultData.LoginState 
        $SessionState = $smokeTestResultData.SessionState
        $className = "no-style"
        foreach ($item in $Appshortcuts) {
                
            #$item.shortcutName
            #$item.shortcutPath
            #$item.ApplicationId
            $EventType = $item.EventApplicationFailureType
            #$item.EventApplicationFailureTitle
            #$item.ApplicationFailureReason
            #$item.ActionStatus

            $Test_Failure_Reason = "<span>"
                  
            if ($item.ActionStatus -eq "Failed") {
                $Test_Failure_Reason = $Test_Failure_Reason + "Login State : $loginState  <br/>"
                $className = "error-header"
                if ($loginState -eq "failed") {
                    $Test_Failure_Reason = $Test_Failure_Reason + "Login Failure Reason : $EventConnectionTitle <br/>  Description : <b> $EventConnectionDescription </b> <br/>"
                }
                if ($EventType -eq "accountCapacityExceeded" -or $EventType -eq "launcherCapacityExceeded" -or $EventType -eq "loginFailure") {
                    $className = "error-header"
                    
                    $Test_Failure_Reason = $Test_Failure_Reason + "Login Failure Reason : $EventConnectionTitle <br/>  Description : <b> $EventConnectionDescription </b> <br/>"
                }
                if ($loginState -eq "succeeded" -and $item.EventApplicationFailureType -eq "applicationFailure") {
                    $className = "error-header"
                    $EventApplicationFailureTitle = $item.EventApplicationFailureTitle
                    $ApplicationFailureReason = $item.ApplicationFailureReason
                    $Test_Failure_Reason = $Test_Failure_Reason + " Failure Reason : $EventApplicationFailureTitle </br> Description : <b> $ApplicationFailureReason </b> <br/>"  
                }
            }
            else {
                $className = "no-style"
                $Test_Failure_Reason = $Test_Failure_Reason + "NA  <br/>"
            }
            $smokeTestResult = ""       
            if($item.ActionStatus -eq "Passed")
            { $smokeTestResult = "Pass" }
            else { $smokeTestResult = $item.ActionStatus}

            $Test_Failure_Reason = $Test_Failure_Reason + "</span>"
                
            #Write-Host "Test_Failure_Reason " $Test_Failure_Reason
            $currentRow = $rowTemplate -replace "{AppID}", ([string]$AppID)
            $currentRow = $currentRow -replace "{className}", ([string]$className) 
            $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
            $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppVersion)
            $currentRow = $currentRow -replace "{TestName}", ([string]"App Smoke Test")
            $currentRow = $currentRow -replace "{ShortcutName}", ([string]$item.shortcutName)
            $currentRow = $currentRow -replace "{TestStatus}", ([string]$smokeTestResult)
            $currentRow = $currentRow -replace "{AdditionalDetail}", ([string]$Test_Failure_Reason)
                
            $htmlRows += $currentRow + "`n"
                

            #Write-Host $htmlRows
        }
        
        return $htmlRows
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Host "runtime Error occurred Prepare Table Row contents for Smoke test exception: $($_.Exception.Message)"
        Exit 1
    }
}
function Prepare_Rows_For_QualysCrowdstrikeContinuousTest {
    param (
        [parameter(Mandatory = $false)]
        [string]$AppName ,
        [parameter(Mandatory = $false)]
        [string]$AppID ,
        [parameter(Mandatory = $false)]
        [string]$AppSetupVersion ,
        [parameter(Mandatory = $false)]
        [string]$Status ,
        [parameter(Mandatory = $false)]
        [string]$Description ,
        [parameter(Mandatory = $false)]
        [string]$ScanType  
    )

    try {
        
        $rowTemplate = "<tr class='{className}'><td>{AppID}</td><td>{AppName}</td><td>{AppVersion}</td><td>{TestName}</td><td>{ShortcutName}</td><td>{TestStatus}</td><td>{AdditionalDetail}</td></tr>"
        $htmlRows = ""
        
        $className = "no-style"
        if($Description -eq $null -or $Description -eq "")
        {
            $Description = "NA"
        }
        if ($Status -eq "Failed") {
            $Test_Failure_Reason += " ${Description}  <br/>"
            $className = "error-header"             
        }
        elseif ($Status -eq "Skipped") {
            $Test_Failure_Reason += "${Description}  <br/>"             
        }
        else {
            # $className = "no-style"
            $Test_Failure_Reason = $Test_Failure_Reason + "NA  <br/>"
        }   
        $Test_Failure_Reason = $Test_Failure_Reason + "</span>"  
        $currentRow = $rowTemplate -replace "{AppID}", ([string]$AppID)
        $currentRow = $currentRow -replace "{className}", ([string]$className) 
        $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
        $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppSetupVersion)
        $currentRow = $currentRow -replace "{TestName}", ([string] $ScanType)
        $currentRow = $currentRow -replace "{ShortcutName}", ([string]"NA")
        $currentRow = $currentRow -replace "{TestStatus}", ([string]$Status)
        if($app.InstallationCheck -eq "Failed"){
            $Test_Failure_Reason = "<span>App Installation Failed</span>"  
            }
        $currentRow = $currentRow -replace "{AdditionalDetail}", ([string]$Test_Failure_Reason)
                
        $htmlRows += $currentRow + "`n"
                
        
        return $htmlRows
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_Rows_For_Qualys_Crowdstrike method, Error : $($_.Exception.Message)"
        exit 1
    }
}
function Prepare_Rows_For_WDAC {
    param (
        [parameter(Mandatory = $false)]
        [string]$IntuneAppName  ,
        [parameter(Mandatory = $false)]
        [string]$AppID ,
        [parameter(Mandatory = $false)]
        [string]$FamilyID ,
        [parameter(Mandatory = $false)]
        [string]$AppVersion ,
        [parameter(Mandatory = $false)]
        [string]$WDACScanResult,
        [parameter(Mandatory = $false)]
        [string]$Description ,
        [parameter(Mandatory = $false)]
        [string]$WDACScanReport 

    )

    try {
        
        
        $AppName = $IntuneAppName
        $AppID =   $AppID
        $FamilyID =  $FamilyID  
        $AppVersion = $AppVersion
        
        $rowTemplate = "<tr class='{className}'><td>{AppID}</td><td>{AppName}</td><td>{AppVersion}</td><td>{TestName}</td><td>{ShortcutName}</td><td>{TestStatus}</td><td>{AdditionalDetail}</td></tr>"
        $htmlRows = ""
        
        $className = "no-style"
        if ($WDACScanResult -eq "Failed") {
            $Test_Failure_Reason += "${Description}  <br/>"
            #$Test_Failure_Reason += "WDAC Report Path : ${WDACScanReport}  "
            $className = "error-header"             
        }
        else {
            $className = "no-style"
            $Test_Failure_Reason = $Test_Failure_Reason + "NA  <br/>"
        }
             
        $Test_Failure_Reason = $Test_Failure_Reason + "</span>"
        
        $currentRow = $rowTemplate -replace "{AppID}", ([string]$AppID)
        $currentRow = $currentRow -replace "{className}", ([string]$className) 
        $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
        $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppVersion)
        $currentRow = $currentRow -replace "{TestName}", ([string]"Application Contol Allowlist Check")
        $currentRow = $currentRow -replace "{ShortcutName}", ([string]"NA")
        $currentRow = $currentRow -replace "{TestStatus}", ([string]$WDACScanResult)
        if($app.InstallationCheck -eq "Failed"){
            $Test_Failure_Reason = "<span>App Installation Failed</span>"
        }
        $currentRow = $currentRow -replace "{AdditionalDetail}", ([string]$Test_Failure_Reason)
                
        $htmlRows += $currentRow + "`n"
                
        
        return $htmlRows
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_Rows_For_WDAC method, Error : $($_.Exception.Message)"
        exit 1
    }
}
# Read and populate email template
    try {

        $owner     = $env:LE_ContiTest_Owner
        $repo      = $env:LE_ContiTest_Repo
        $branch    = $env:LE_ContiTest_Branch
        $JosnFile  = $env:LE_ContiTest_AppListJson 
        $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
        # root folder
        $ScanFolder = $env:ScanFolder
        #Get Deployed Apps Data from IAF
        #$IAF_AppListJsonFile = $env:LEAppListData 
        $IAF_BUILD_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\b" 
        $vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json" # // LE Vm info file
        $IAF_AppListJsonFile = Join-Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName
        
        $appListJsonObject = Get-Content -Path $IAF_AppListJsonFile | ConvertFrom-Json
        
        $ContinuousTestResult_File = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_ContinuousTestResult.json"
        
        $LESmokeTestResultFolder = Join-Path -Path $env:LEScanFolder -ChildPath $IAF_BUILD_TAG
        $SmokeTestResultFile =  Join-Path -Path $LESmokeTestResultFolder -ChildPath $env:LESmokeTestResultFile
        $smokeTestData = Get-Content -Path $SmokeTestResultFile | ConvertFrom-Json
        
        foreach ($app in $appListJsonObject.Apps) { 
        
          $AppName = $app.IntuneAppName
          $FamilyID = $app.FamilyID
          $AppID = $app.AppID
          $AppVersion = $app.AppSetupVersion
          $DeviceName = $app.DeviceName
          $SmokeTest = $currentAppSmokeTestResult.OverAllResult
          $WDACScan = $app.WDACScan     #":"Failed"
          $CrowdstrikeScan = $app.CrowdstrikeScan    #":  "Completed",
          $QualysScan = $app.QualysScan   #":  "Failed",
          
          $ContinuousTestResult = ""
          $Attachement = @()
          $TOEmails = @()
          $CC_Emails = @()
          $currentAppSmokeTestResult =  $smokeTestData.Apps | Where-Object { $_.IntuneAppName -eq $app.IntuneAppName } 
          $SmokeTestResult = $currentAppSmokeTestResult | ConvertTo-Json -Depth 10
          $smokeTestRows = Prepare_Rows_For_SmokeTest -SmokeTestResult $SmokeTestResult

          $EmailRecipients_Success = GetEmailRecipients -NotificationFor "IAFPipelineSuccessNotification" | ConvertFrom-Json
          #Write-Host "Success Email Recipients" $EmailRecipients_Success.To
          $EmailRecipients_Failure = GetEmailRecipients -NotificationFor "IAFPipelineFailureNotification" | ConvertFrom-Json
          
          # call the method to check if app is ao or iat testing
          # passed -> iat or ao based 
          #  fail -> 1 condition or failure template failing

          
          $WDACResultRows = ""
          $pickemailtemplate = ""
          $allPassed = "Yes"
          if($app.InstallationCheck -eq "Failed"){
                $CrowdstrikeScan = "Skipped"
                $QualysScan =  "Skipped"
                $WDACScan = "Skipped"
                $SmokeTest = "Skipped"
                $allPassed = "No"
                $currentAppSmokeTestResult.OverAllResult = "Failed"
            }
          if($currentAppSmokeTestResult.OverAllResult -eq "Passed"){
             # TESTING OVERRIDE: Send all emails to test user
             $TOEmails = @($currentAppSmokeTestResult.AOEmails -split ",") 
             $CC_Emails = @($EmailRecipients_Success.CC -split ",") 
             $Attachement += $currentAppSmokeTestResult.TestReportPath

            # get WDAC signing result 
            $WDACScanResult = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_WDAC_Result.json"
            $WDACResultRows = "" 
            if((-not [string]::IsNullOrWhiteSpace($env:WDACScanResultFolder)) -and (Test-Path $env:WDACScanResultFolder)){
            $WDACScanResultFile= Join-Path -Path $env:WDACScanResultFolder -ChildPath $WDACScanResult
            $WDACResult = Get-Content -Path $WDACScanResultFile | ConvertFrom-Json
            
            $currentAppWDACResult =  $WDACResult.Apps | Where-Object { $_.IntuneAppName -eq $app.IntuneAppName } 
            $currentAppWDACResultJson = $currentAppWDACResult | ConvertTo-Json -Depth 10 
            Write-Host "WDAC Result :- " $currentAppWDACResultJson
            $WDACResult = $currentAppWDACResultJson  | ConvertFrom-Json 
            $WDACResultRows = Prepare_Rows_For_WDAC -IntuneAppName $AppName -AppID $AppID -FamilyID $FamilyID -AppVersion $AppVersion -WDACScanResult $WDACResult.WDACScanResult -Description $WDACResult.Description -WDACScanReport $WDACResult.WDACScanReport
            }
            else {
                $WDACResultRows = Prepare_Rows_For_WDAC -IntuneAppName $AppName -AppID $AppID -FamilyID $FamilyID -AppVersion $AppVersion -WDACScanResult "Skipped" -Description "NA" -WDACScanReport "NA"
            }
            # Check IAT_Testing status to determine template
            $allPassed = "Yes"
            if($app.InstallationCheck -eq "Failed"){
              $allPassed = "No"
             }
            $iatTesting = Get-IATTestingStatus -AppID $AppID
            if ($iatTesting -eq 'Yes' -and $iatTesting.Trim() -ne "") {
                $pickemailtemplate = "IAT"
            } else {
                $pickemailtemplate = "AO"
                $TOEmails = @(Get-AOEmail -IntuneAppName $app.IntuneAppName)
                Write-Host "AO Email" $TOEmails
            }
          }
          else{
            # Test failed - use Failure template
            $allPassed = "No"
            $pickemailtemplate = "Failed"
            # TESTING OVERRIDE: Send all emails to test user
            $TOEmails = @($EmailRecipients_Failure.To -split ",") 
            $CC_Emails = @($EmailRecipients_Failure.CC -split ",")  
            $WDACResultRows = Prepare_Rows_For_WDAC -IntuneAppName $AppName -AppID $AppID -FamilyID $FamilyID -AppVersion $AppVersion -WDACScanResult $WDACScan -Description "NA" -WDACScanReport "NA"
          }
          
          
            if($WDACScan -eq  "Failed")
            {
              $Crowdstrike_Description = "NA"
              # TESTING OVERRIDE: Send all emails to test user
              $TOEmails = @($EmailRecipients_Failure.To -split ",") 
              $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
              $pickemailtemplate = "Failed"
            }
            if(($CrowdstrikeScan -eq "Failed") -or ($null -eq $CrowdstrikeScan))
            {
                $pickemailtemplate = "Failed"
                if ($null -eq $CrowdstrikeScan -and $app.InstallationCheck -ne "Failed"){
                    $Crowdstrike_Description = "Crowdstrike Scan was not completed in time."
                }else{
                    $Crowdstrike_Description = "Malware file found, refer to attached report for more details"
                    $crowdstrikeScanfile = GetFileFromLocation -folderPath "${env:CrowdstrikeScanResult}Results\" -regexPattern  "${DeviceName}-${AppName}-"
                    Write-Host "Crowdstrike scan File - " $crowdstrikeScanfile
                    $Attachement += $crowdstrikeScanfile
                }
                $Qualys_Description = "NA"
                $TOEmails = @($EmailRecipients_Failure.To -split ",") 
                $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
            }
            
            if($QualysScan -eq "Failed")
            {
              $pickemailtemplate = "Failed"
              $qualysScanfile = GetFileFromLocation -folderPath "${env:QualysScanResult}Results\" -regexPattern  "${DeviceName}-${AppName}-"
               Write-Host "qualys scan File - " $qualysScanfile
               $Attachement += $qualysScanfile

               # code to get the QID for the qualys scan
               $qualysScanFile =  Join-Path -Path $env:QualysScanResult -ChildPath "QualysScanDeviceStatus.json"
               $qualysScanStatus = Get-Content -Path $qualysScanFile | ConvertFrom-Json
               $deviceSpecificStatus = $qualysScanStatus.Apps | Where-Object { $_.DeviceName -eq $DeviceName } 
               $deviceSpecific_LatestStatus = $deviceSpecificStatus.vulninfo | Sort-Object { [DateTime]::Parse($_.LAST_PROCESSED_DATETIME) } -Descending | Select-Object -First 1 
               
               $QID = $deviceSpecific_LatestStatus.QID
               Write-Host "QID $QID"
               $Qualys_Description = "Qualys Scan ID - $QID"
               # TESTING OVERRIDE: Send all emails to test user
              $TOEmails = @($EmailRecipients_Failure.To -split ",")  
               $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
            }
          $jsonContent = Get-AppListFromJson -owner $owner -repo $repo -branch $branch -JosnFile $JosnFile
          # Check if the IntuneAppName exists in the JSON data (case-insensitive, trim)
          $appExists = $false
          $appExists = check-AppExistence -FamilyId $FamilyId -IntuneAppName $AppName -JsonContent $JsonContent

          # If the app does not exist, then need to skip the continuous test result row
          if(-not $appExists)
          {
            $ContinuousTestResult = "Skipped"
            $ContinuousTestResultDiscription = "This App '$AppName' is not onboarded on continuous test yet."
            Write-Output "The IntuneAppName '$AppName' is not onboarded on continuous test."
          } 
          else {  
            if ((-not [string]::IsNullOrWhiteSpace($env:ContinuousTestResultPath)) -and (Test-Path $env:ContinuousTestResultPath)) {            
                $ContinuousTestResultFile = Join-Path -Path $env:ContinuousTestResultPath -ChildPath $ContinuousTestResult_File
                Write-Host "continuous test result file :- $ContinuousTestResultFile "
                $ContinuousTestResultData = Get-Content -Path $ContinuousTestResultFile | ConvertFrom-Json

                $CurrentAppContinuousAllTestResult = $ContinuousTestResultData.Apps | Where-Object { $_.IntuneAppName -eq $AppName }
                $T5_1CurrentAppContinuousTestResult = $CurrentAppContinuousAllTestResult.TestDetail | Where-Object{$_.ContinuousTestName -like "*T5.1 continuous testing*"}
                
                if ($T5_1CurrentAppContinuousTestResult){
                    $passRecord = $T5_1CurrentAppContinuousTestResult |
                        Where-Object { $_.Upgrade -eq 'Pass' } |
                        Select-Object -First 1

                    $failRecord = $T5_1CurrentAppContinuousTestResult |
                        Where-Object { $_.Upgrade -eq 'Failed' } |
                        Select-Object -First 1

                    $skipRecord = $T5_1CurrentAppContinuousTestResult |
                        Where-Object { $_.Upgrade -eq 'Skipped' } |
                        Select-Object -First 1

                    if ($passRecord)
                    {
                        $ContinuousTestResult = "Pass"
                        $ContinuousTestResultDiscription = "NA"
                    }
                    elseif ($failRecord)
                    {
                        $ContinuousTestResult = "Failed"
                        $ContinuousTestResultDiscription = $failRecord.Description
                    }
                    elseif ($skipRecord)
                    {
                        $ContinuousTestResult = "Skipped"
                        $ContinuousTestResultDiscription = $skipRecord.Description
                    }
                }
                else
                {
                    $ContinuousTestResult = "Skipped"
                    $ContinuousTestResultDiscription = "This App '$AppName' is not included in any continuous test yet."
                }
            }
            else{
                $ContinuousTestResult ="Skipped"
                $ContinuousTestResultDiscription = "Continuous Test for this App '$AppName' is skipped due to early exit of pipeline."
            }
          }
            $ContinuousTestResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $ContinuousTestResult -Description $ContinuousTestResultDiscription -ScanType "App Upgrade Check"
            $CrowdstrikeResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $CrowdstrikeScan -Description $Crowdstrike_Description -ScanType "Crowdstrike Scan"
            $QualysScanResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $QualysScan -Description $Qualys_Description -ScanType "Qualys Scan"
          
          $emailBody = Prepare_EmailBody_TableContent -AppName $AppName -AppID $AppID -AppVersion $AppVersion -SmokeTestResult $smokeTestRows -WDACResult $WDACResultRows -QualysScanResult $QualysScanResult -CrowdstrikeResult $CrowdstrikeResult -ContinuousTestResult $ContinuousTestResult -pickemailtemplate $pickemailtemplate
          
          # Set subject based on template type
          if ($pickemailtemplate -eq "Failed" -or $allPassed -eq "No") {
              $pickemailtemplate = "Failed"
              $Subject = "Application : $AppName - $AppVersion [AppID : $AppID] failed security scan tests in IAF"
          }
          elseif ($pickemailtemplate -eq "IAT") {
              $pickemailtemplate = "IAT"
              $Subject = "Application : $AppName - $AppVersion [AppID : $AppID] is now ready for IAT testing"
          }
          elseif ($pickemailtemplate -eq "AO") {
              $pickemailtemplate = "AO"
              $Subject = "Application : $AppName - $AppVersion [AppID : $AppID] is now ready for AO testing"
          }
          else {
              # Fallback to default subject
              $Subject = "$AppID : $AppName - Application Onboarding Automated Test results & reports"
          }

        #   #If App fails to install on the VM:
        #   if ($app.InstallationCheck -eq "Failed") {
        #       $pickemailtemplate = "Failed"
        #       $Subject = "Application : $AppName - $AppVersion [AppID : $AppID] failed during Installation on smoke test VM"
        #   }
          
          if($pickemailtemplate -ne "Failed"){
            $TOEmails += "amc-avcc-app-operationalsupport@allianz.com"
          }

          Write-Host "To Email" $TOEmails
          Write-Host "CC Email" $CC_Emails

          SendTestResultNotification -Attachment $Attachement  -Subject $Subject -emailBody $emailBody -To $TOEmails -Cc $CC_Emails
        }
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Host "PS_ERROR_DESC= Runtime error occurred in Sending email notification. Exception: $($_.Exception.Message)"
        Exit 1
    }



