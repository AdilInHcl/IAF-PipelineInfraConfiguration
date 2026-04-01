#method to add App details in AppList json to onboard app in continuous test
Import-Module -Name "$env:WORKSPACE\PowerShell/FinalEmail-Content_test.psm1"

function Add-AppToJson {
    param(
        [string]$FamilyId, 
        [string]$IntuneAppName, 
        [array]$AOEmail, 
        [string]$jsonContent
        )
    try {
        Write-Host "Checking if '$IntuneAppName' exists in JSON..."
        $appExists = check-AppExistence -FamilyId $FamilyId -IntuneAppName $IntuneAppName -JsonContent $jsonContent
 
        if (-not $appExists) {
            Write-Host "'$IntuneAppName' not found. Preparing to add..."
 
            try {
                $jsonData = $jsonContent | ConvertFrom-Json
                if ($jsonData.IntuneAppName) {
                    $jsonData = @{ Apps = @($jsonData) }
                } elseif (-not $jsonData.Apps) {
                    $jsonData | Add-Member -NotePropertyName Apps -NotePropertyValue @()
                }
            } catch {
                Write-Host "Failed to parse JSON. Initializing empty structure."
                $jsonData = @{ Apps = @() }
            }
 
            $jsonData.Apps += [PSCustomObject]@{
                FamilyId      = $FamilyId
                IntuneAppName = $IntuneAppName
                AOEmail       = $AOEmail
                TestDetail    = @()
            }
            # Add to JSON structure
            #$jsonData.Apps += $newApp
            # Prepare GitHub update
            $token     = $env:GIT_PAT
            $owner     = $env:LE_ContiTest_Owner
            $repo      = $env:LE_ContiTest_Repo
            $branch    = $env:LE_ContiTest_Branch
            $filePath  = $env:LE_ContiTest_AppListJson 
            $apiUrl        = "https://github.developer.allianz.io/api/v3/repos/$owner/$repo/contents/$filePath"
            $encodedBranch = [Uri]::EscapeDataString($branch)
            $headers       = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github.v3+json" }
 
            $maxRetries = 3
            $retryCount = 0
            $success    = $false
 
            while (-not $success -and $retryCount -lt $maxRetries) {
                try {
                    # GET with URL-encoded branch to get correct SHA
                    $currentFile = Invoke-RestMethod -Uri "$apiUrl`?ref=$encodedBranch" -Headers $headers -Method Get
                    $sha         = $currentFile.sha
                    Write-Host "SHA: $sha"
 
                    $base64 = [Convert]::ToBase64String(
                        [Text.Encoding]::UTF8.GetBytes(($jsonData | ConvertTo-Json -Depth 5))
                    )
 
                    $body = @{
                        message = "Add '$IntuneAppName' entry with TestDetail"
                        content = $base64
                        branch  = $branch   # original (not encoded) in body
                        sha     = $sha
                    } | ConvertTo-Json -Depth 5
 
                    Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Put -Body $body -ContentType "application/json"
                    Write-Host "'$IntuneAppName' successfully added and pushed to GitHub."
                    $success = $true
 
                } catch {
                    if ($_.Exception.Response.StatusCode -eq 409) {
                        $retryCount++
                        Write-Host "Conflict (409). Retrying... ($retryCount/$maxRetries)"
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Output "PS_ERROR_DESC= Error in Add-AppToJson while pushing: $_"
                        
                    }
                }
            }
 
            if (-not $success) {
                Write-Output "PS_ERROR_DESC= Failed to push after $maxRetries retries in Add-AppToJson"
            }
 
        } else {
            Write-Host "'$IntuneAppName' already exists. No update needed."
        }
    } catch {
        Write-Output "PS_ERROR_DESC= Error in Add-AppToJson: $_"
        Exit 1_
    }
}
# read json from continuous test App list json file saved on github
function Get-AppListFromJson {
 param(
        [string]$owner,
        [string]$repo,
        [string]$branch,
        [string]$JosnFile
    )

    try {
        # Read the current JSON from GitHub
        $token = $env:GIT_PAT
        $apiUrl = "https://github.developer.allianz.io/api/v3/repos/$owner/$repo/contents/$($JosnFile)?ref=$branch"
        $headers = @{
            "Authorization" = "Bearer $token"
            "Accept"        = "application/vnd.github.v3+json"
        }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        $jsonContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($response.content))
        
        #Write-Output "Json file [$JosnFile] data : $jsonContent"
        #$jsonData = $jsonContent | ConvertFrom-Json
        return $jsonContent
    } catch {
         Write-Output "PS_ERROR_DESC= Error occurred in Get-AppListFromJson method in AppUpgradeDetection.pms1 script: $_"
         exit 1
    }
}
# Check if the IntuneAppName exists in the JSON data (case-insensitive, trim)
function check-AppExistence {
    param(
        [string]$FamilyId,
        [string]$IntuneAppName,
        [string]$JsonContent
    )

    try {
        $jsonData = $jsonContent | ConvertFrom-Json
        $appExists = $false
        $intuneAppName = $IntuneAppName.ToLower().Trim()
        $familyID = $FamilyId.ToLower().Trim()

        # foreach ($app in $jsonData.Apps) {
        #     $existingAppName = $app.IntuneAppName.ToLower().Trim()
        #     $existingFamilyID = $app.FamilyId.ToLower().Trim()
        #     if ($normalizedExisting -eq $normalizedInput) {
        #         $appExists = $true
        #         break
        #     }
        # }
        $currentApp = $jsonData.Apps | Where-Object { $_.FamilyId.ToLower().Trim() -eq $familyID -and $_.IntuneAppName.ToLower().Trim() -eq $intuneAppName }
        if($currentApp) {$appExists = $true}
        else {$appExists = $false}
        return $appExists
    }
    catch {
        Write-Output "PS_ERROR_DESC= Error occurred in to parse JSON in check-AppExistence method in AppUpgradeDetection.pms1 script: $_"
        exit 1
    }
}
function Add_ContinuousTest_To_App {
    param(
        [string]$FamilyId,
        [string]$IntuneAppName,
        # [string]$OEName,
        [string]$ContinuousTestName
        
    )

    try {
        # If the app does not exist, create a new item and add it to the JSON data
         $token = $env:GIT_PAT
         $owner     = $env:LE_ContiTest_Owner
         $repo      = $env:LE_ContiTest_Repo
         $branch    = $env:LE_ContiTest_Branch
         $JosnFile  = $env:LE_ContiTest_AppListJson 
         #Write-Host "owner $owner , repo $repo , branch $branch , Json file $JosnFile"
         $jsonContent = Get-AppListFromJson -owner $owner -repo $repo -branch $branch -JosnFile $JosnFile
         Write-Host "Json content from as of now before adding this continuous test."
         Write-Host $jsonContent
         $jsonData = $jsonContent | ConvertFrom-Json
        
        $appExists = $false
        $appExists = check-AppExistence -FamilyId $FamilyId -IntuneAppName $IntuneAppName -JsonContent $JsonContent

        #$testExists = $false
        if($appExists)
        {  
            $currentApp = $jsonData.Apps | Where-Object { $_.FamilyId.ToLower().Trim() -eq $FamilyId.ToLower().Trim() -and $_.IntuneAppName.ToLower().Trim() -eq $IntuneAppName.ToLower().Trim() }
    
            $testExists = $currentApp.TestDetail | Where-Object { $_.ContinuousTestName.ToLower().Trim() -eq $ContinuousTestName.ToLower().Trim() }
            
            if ($testExists) {
                Write-Host "Continuous Test already added with this name '$ContinuousTestName' for the App '$IntuneAppName'." 
                return #"Continuous Test already added with this name '$ContinuousTestName' for the App '$IntuneAppName'." 
            } else {
                # Create timestamp
                $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                
                # Create new test entry as PSCustomObject
                $NewTestDetail = [PSCustomObject]@{
                    ContinuousTestName = $ContinuousTestName
                    AddedOn = $timestamp
                }
                
                # Add the new test detail to the TestDetail array
                $currentApp.TestDetail+=$NewTestDetail
                
                Write-Host "The Continuous test onboarded in given App successfully." 
            }
        }
        else {
            Write-Host "App does not onboarded to the continuous test yet, please check once if you have passed correct IntuneAppName or FamilyId."
            return #"App does not onboarded to the continuous test yet, please check once if you have passed correct IntuneAppName or FamilyId."
        }

        $jsonString = $jsonData | ConvertTo-Json -Depth 10
        Write-Host "json data after adding continuous test " $jsonString

        # Update the JSON on GitHub using API
            
            $apiUrl        = "https://github.developer.allianz.io/api/v3/repos/$owner/$repo/contents/$JosnFile"
            $encodedBranch = [Uri]::EscapeDataString($branch)
            $headers       = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github.v3+json" }
 
            $maxRetries = 3
            $retryCount = 0
            $success    = $false
 
            while (-not $success -and $retryCount -lt $maxRetries) {
                try {
                    # GET with URL-encoded branch to get correct SHA
                    $currentFile = Invoke-RestMethod -Uri "$apiUrl`?ref=$encodedBranch" -Headers $headers -Method Get
                    $sha         = $currentFile.sha
                    #Write-Host "SHA: $sha"
 
                    $base64 = [Convert]::ToBase64String(
                        [Text.Encoding]::UTF8.GetBytes(($jsonData | ConvertTo-Json -Depth 5))
                    )
 
                    $body = @{
                        message = "Add new Continuous Test Name [$ContinuousTestName] inside $IntuneAppName App to JSON"
                        content = $base64
                        branch  = $branch   # original (not encoded) in body
                        sha     = $sha
                    } | ConvertTo-Json -Depth 5
 
                    Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Put -Body $body -ContentType "application/json"
                    Write-Output "Continuous Test Name [$ContinuousTestName] was added to the JSON file and pushed to GitHub."
                    $success = $true
 
                } catch {
                    if ($_.Exception.Response.StatusCode -eq 409) {
                        $retryCount++
                        Write-Host "Conflict (409). Retrying... ($retryCount/$maxRetries)"
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Output "PS_ERROR_DESC= Error in Add_ContinuousTest_To_App while pushing: $_"
                        
                    }
                }
            }
 
            if (-not $success) {
                Write-Output "PS_ERROR_DESC= Failed to push after $maxRetries retries in Add_ContinuousTest_To_App"
            }
    } catch {
        Write-Output "PS_ERROR_DESC= Error occurred in Add_ContinuousTest_To_App method in AppUpgradeDetection.pms1 script: $_"
        exit 1
    }
}
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
function detect_Onboard_NewApp {
    param(
        [string]$AppID,
        [string]$FamilyId,
        [string]$IntuneAppName,
        [string]$AppVersion,
        [array]$AOEmail,
        [string]$TestScriptFile,
        [string]$TestResult
    )
  try {
     # Read the current JSON from GitHub
      $owner     = $env:LE_ContiTest_Owner
      $repo      = $env:LE_ContiTest_Repo
      $branch    = $env:LE_ContiTest_Branch
      $JosnFile  = $env:LE_ContiTest_AppListJson 

      
      $HCLWPSTestTeam = GetEmailRecipients -NotificationFor "HCLWPSTestTeam" | ConvertFrom-Json   
      $To = @($HCLWPSTestTeam.To -split ",") 
      $CC = @($HCLWPSTestTeam.CC -split ",")
      #Write-Host "HCLWPSTestTeam email To $To" 
      #Write-Host "HCLWPSTestTeam email To $CC"  
            
      $jsonContent = Get-AppListFromJson -owner $owner -repo $repo -branch $branch -JosnFile $JosnFile
      # Check if the IntuneAppName exists in the JSON data (case-insensitive, trim)
      $appExists = $false
      $appExists = check-AppExistence -FamilyId $FamilyId -IntuneAppName $IntuneAppName -JsonContent $JsonContent

      # If the app does not exist, create a new item and add it to the JSON data
      #$jsonData = $jsonContent | ConvertFrom-Json
      if(-not $appExists)
      {
        Add-AppToJson -FamilyId $FamilyId -IntuneAppName $IntuneAppName -AOEmail $AOEmail -jsonContent $jsonContent
        # wrtie code to send email to testing team to onboard new app in continous test
        $Subject = "$AppID - $IntuneAppName : Notification to Onboard Application  in Continuous Test"
        $emailBody = PrepareEmailBody_ForAppOnboard -AppName $IntuneAppName -AppID $AppID -FamilyID $FamilyId -AppVersion $AppVersion -TestResult $TestResult -TestScriptFile $TestScriptFile
        SendContinuousTestOnboardingEmail -Attachment "No Attachment" -Subject $Subject -emailBody $emailBody -To $To -CopyEmail $CC
      } 
      else {
          Write-Output "The IntuneAppName '$IntuneAppName' already part of continuous test."
      }
  }
  catch {
    <#Do this if a terminating exception happens#>
    Write-Output "PS_ERROR_DESC= An unexpected error occurred in AppUpgradeDetection.ps1 script while App App detect, onboard : $_"
    exit 1
  }
     
}
