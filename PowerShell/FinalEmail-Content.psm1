
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

        [string]$ContinuousTestResult 
        
    )

    # Read and populate email template
    
    try {
        # if ($emailtemplate -eq "IAT" )   
        # if ($emailtemplate -eq "AO"  )  
        # if ($emailtemplate -eq "Failed")

        $templatePath = "$($env:WORKSPACE)\configs\combined_email.html"
        # Write-Host "Template file path :- " $templatePath
        if (-not (Test-Path $templatePath)) {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_EmailBody_TableContent method. Email template file not found at: $templatePath"
            exit 1
        }
        $emailTemplate = Get-Content $templatePath -Raw -ErrorAction Stop
        # Write-Host "Email tempalte content"
        
        $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Generate HTML table rows from data
        # <td>{CreatedDate}</td>
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
        $emailBody = $emailBody -replace '{{App_Name}}', ([string]$AppName)
        $emailBody = $emailBody -replace '{{App_ID}}', ([string]$AppID)
        
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
    $From = "wpsavcautomation@allianz.de"
    $Username = "TMU-EU-AVC023"
 
   $Password = $env:Password_PSW
   
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
                     
                
            $Test_Failure_Reason = $Test_Failure_Reason + "</span>"
                
            #Write-Host "Test_Failure_Reason " $Test_Failure_Reason
            $currentRow = $rowTemplate -replace "{AppID}", ([string]$AppID)
            $currentRow = $currentRow -replace "{className}", ([string]$className) 
            $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
            $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppVersion)
            $currentRow = $currentRow -replace "{TestName}", ([string]"App Smoke Test")
            $currentRow = $currentRow -replace "{ShortcutName}", ([string]$item.shortcutName)
            $currentRow = $currentRow -replace "{TestStatus}", ([string]$item.ActionStatus)
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
        $AppID =  $FamilyID  #$WDACResult.AppID
        $FamilyID =  $FamilyID  
        $AppVersion = $AppVersion
        # $FamilyID = $WDACResult.FamilyID
        # Generate HTML table rows from data
        
        $rowTemplate = "<tr class='{className}'><td>{AppID}</td><td>{AppName}</td><td>{AppVersion}</td><td>{TestName}</td><td>{ShortcutName}</td><td>{TestStatus}</td><td>{AdditionalDetail}</td></tr>"
        $htmlRows = ""
        
        $className = "no-style"
        if ($WDACResult.WDACScanResult -eq "Failed") {
            $Test_Failure_Reason += "${Description}  <br/>"
            $Test_Failure_Reason += "WDAC Report Path : ${WDACScanReport}  "
            $className = "error-header"             
        }
        else {
            $className = "no-style"
            $Test_Failure_Reason = $Test_Failure_Reason + "NA  <br/>"
        }
             
        $Test_Failure_Reason = $Test_Failure_Reason + "</span>"      
        #Write-Host "Test_Failure_Reason " $Test_Failure_Reason
        
        $currentRow = $rowTemplate -replace "{AppID}", ([string]$AppID)
        $currentRow = $currentRow -replace "{className}", ([string]$className) 
        $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
        $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppVersion)
        $currentRow = $currentRow -replace "{TestName}", ([string]"Application Contol Allowlist Check")
        $currentRow = $currentRow -replace "{ShortcutName}", ([string]"NA")
        $currentRow = $currentRow -replace "{TestStatus}", ([string]$WDACScanResult)
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

function GetEmailRecipients {
    param (
        [parameter(Mandatory = $true)]
        [string]$NotificationFor  
    )

    $EmailRecipientJson = "$($env:WORKSPACE)\configs\EmailRecipients1.json"
    $emailJsonData = Get-Content -Path $EmailRecipientJson -Raw
    # Write-Host $jsonData
    $emailObject = $emailJsonData | ConvertFrom-Json 
    
    $objectDetails = $emailObject.PSObject.Properties | Where-Object { $_.Name -eq $NotificationFor } | Select-Object -ExpandProperty Value

    if ($objectDetails) {
        #Write-Host "Description: $($objectDetails.Description)"
        $recipientsDetail = $objectDetails | ConvertTo-Json -Depth 10
        return $recipientsDetail
    }
    else {
        #Write-Host "Object '$ObjectName' not found in the JSON data."
        return $null
    }
    
}


 function GetFileFromLocation{
param (
        [parameter(Mandatory = $true)]
        [string]$folderPath ,
        [parameter(Mandatory = $true)]
        [string]$regexPattern  
    )
   try {
        #Get the file(s) matching the regex pattern and retrieve the full path
        $matchingFiles = Get-ChildItem -Path $folderPath | Where-Object { $_.Name -match $regexPattern }
        # Sort the matching files by the length of their names to find the nearest match
        $nearestFile = $matchingFiles | Sort-Object { $_.Name.Length } | Select-Object -First 1

        # Output the full path of the nearest matching file
        if ($nearestFile) {
            #Write-Host "Nearest matching file found:"
            return $nearestFile.FullName
        } else {
            Write-Host "No matching files found."
            return ""
        }
    }
    catch {
        Write-Host "PS_ERROR_DESC= Runtime error occurred in GetFileFromLocation method, Error : $($_.Exception.Message)"
        exit 1
    }
}