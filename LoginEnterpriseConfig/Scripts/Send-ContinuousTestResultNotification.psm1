# prepare email body to notifiy the HCL test team so they can perform their set of actions to onboard the app in continuous test
function PrepareEmailBody_ForAppOnboard {
    param (
        [parameter(Mandatory = $true)]
        [string]$AppName,  

        #[parameter(Mandatory = $false)]
        [string]$AppID,  

        #[parameter(Mandatory = $false)]
        [string]$FamilyID, 

        # [parameter(Mandatory = $true)]
        [string]$AppVersion,  
       
        [string]$TestScriptFile,  

        # [parameter(Mandatory = $true)]
        [string]$TestResult  
 
    )

    # Read and populate email template
    try {
        $templatePath = "$($env:WORKSPACE)/LoginEnterpriseConfig/Template/continuoustest_apponboard.html"
        if (-not (Test-Path $templatePath)) {
            Write-Host "PS_ERROR_DESC= Runtime error occurred in Prepare_EmailBody_TableContent method. Email template file not found at: $templatePath"
            exit 1
        }
        $emailTemplate = Get-Content $templatePath -Raw -ErrorAction Stop
        # Generate HTML table rows from data
    
        $rowTemplate = "<tr><td>{SNO}</td><td>{AppID}</td><td>{AppName}</td><td>{FamilyID}</td><td>{AppVersion}</td><td>{TestResult}</td><td>{TestScriptFile}</td></tr>"    #
         
        
        $SNO = 1
        $htmlRows = ""   
        $currentRow = $rowTemplate -replace "{SNO}", ([string]$SNO)
        $currentRow = $currentRow -replace "{AppID}", ([string]$AppID)
        $currentRow = $currentRow -replace "{AppName}", ([string]$AppName)
        $currentRow = $currentRow -replace "{FamilyID}", ([string]$FamilyID)
        $currentRow = $currentRow -replace "{AppVersion}", ([string]$AppVersion)
        $currentRow = $currentRow -replace "{TestResult}", ([string]$TestResult)
        $currentRow = $currentRow -replace "{TestScriptFile}", ([string]$TestScriptFile)
        $htmlRows += $currentRow + "`n"
        $SNO++
        

        # Populate template placeholders
        
        #$emailBody = $emailTemplate -replace '{{BUILD_ID}}', 'N/A'
        $emailBody = $emailTemplate -replace '{{TABLE_ROWS}}', ([string]$htmlRows)
        $emailBody = $emailBody -replace '{{ERROR_LOGS}}', ([string]$TestDetail)
        $emailBody = $emailBody -replace '{{App_Name}}', ([string]$AppName)
        $emailBody = $emailBody -replace '{{App_ID}}', ([string]$AppID)

        return $emailBody
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Output "PS_ERROR_DESC= Error occurred in PrepareEmailBody method in AppUpgradeDetection.pms1 script: $_"
        exit 1
    }
}
# email to notify HCL test team for continuous test app onboard
function SendContinuousTestOnboardingEmail {
    param (
        #[parameter(Mandatory = $false)]
        [string]$Attachment,

        [parameter(Mandatory = $true)]
        [string]$Subject,

        [parameter(Mandatory = $true)]
        [string]$emailBody,

        [parameter(Mandatory = $false)]
        [array]$To,

        [parameter(Mandatory = $false)]
        [array]$CopyEmail

        # [parameter(Mandatory = $false)]
        # [string]$To

    )

    # SMTP Configuration
    $SMTPServer = "tmu-cs.mail.allianz"  
    $SMTPPort = 587                       
    $From = "wpsavcautomation@allianz.de" 
    $Username = "TMU-EU-AVC023"
    $Password = $env:Password_PSW
    
    # Create secure credential object
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

    #Write-Host "App version has changed (Current: $CurrentVersion, IAF: $IAFVersion). Sending notification."
    #Write-Host "Attachment file does not exist: $Attachment"
    # Send email without attachment
    try {
        Send-MailMessage -From $From -To $To -Cc $CopyEmail -Subject $Subject -Body $emailBody -BodyAsHtml:$true -SmtpServer $SMTPServer -Port $SMTPPort -Credential $Credential -UseSsl
        #Write-Host "Email sent successfully to $To without attachment (file not found)."
        Write-Host "Email sent successfully to $To ."
    }
    catch {
        #Write-Host "Failed to send email: $($_.Exception.Message)"
        Write-Output "PS_ERROR_DESC= Error occurred in SendContinuousTestOnboardingEmail method in AppUpgradeDetection.pms1 script: $_"
        exit 1
    }
}
function Send-ScriptNotificationEmail {
    param(
        [Parameter(Mandatory = $true)]$Subject,
        [Parameter(Mandatory = $true)]$Recipient,
        [Parameter(Mandatory = $true)]$Cc,
        [Parameter(Mandatory = $true)]$Body,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword,
        [Parameter(Mandatory = $false)]$AttachmentPath
    )
 
    # Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "noreply-wps-app@allianz.com"
    $messageSubject = $Subject
 
    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    # Build parameters dynamically
    $mailParams = @{
        SmtpServer = $smtpServer
        Credential = $credentials
        Port       = 587
        From       = $smtpFrom
        To         = $Recipient
        Cc         = $Cc
        Subject    = $messageSubject
        Body       = $Body
        BodyAsHtml = $true
        UseSsl     = $true
        Priority   = 'High'
    }
 
    if ($AttachmentPath) {
        $mailParams.Add("Attachments", $AttachmentPath)
    }
 
    Send-MailMessage @mailParams
}
