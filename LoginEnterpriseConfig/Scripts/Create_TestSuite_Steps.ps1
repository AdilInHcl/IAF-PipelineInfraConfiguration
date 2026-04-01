Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\API_RequestFormat_Classes.ps1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\CreateApplication.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\CreateAccountGroup.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1" -Force -Global

function Write-Log {
    param (
        [string]$message
    )
    try {      
        # Append the message to the log file with a line break
        $logFileName = "LEAPILogs\LogFile.txt"
        $logFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $logFileName

        # Wait until file is not locked
        # Write-Host "Checking if file is locked..."
        # while (Test-FileLocked -Path $logFilePath) {
            #    Start-Sleep -Seconds 1
            #}
        
        # Write-Host "File is now available."
        Add-Content -Path $logFilePath -Value "$message`r`n"
    }
    catch {
        Write-Host "PS_ERROR_DESC= Error in Write-Log method in CommonMethodsClass.ps1 script: $_"
        exit 1
    }
}
function GetPaginatedListOfItemsFromAPIWithAPIName {
    param(
        [parameter(Mandatory = $true)]
        [string]$APIURL,
        [parameter(Mandatory = $true)]
        [string] $authToken
    )
    $headers = @{
        Authorization = "Bearer $authToken"
    }
 
    try {
           
        $response = Invoke-RestMethod -Uri $APIURL -Method Get -Headers $headers
        # Convert the response to JSON and return
        return $response | ConvertTo-Json
    }
    
    catch {
        Write-Log "An unexpected error occurred: $($_.Exception.Message)"
        Write-Host "PS_ERROR_DESC= Error in GetPaginatedListOfItemsFromAPIWithAPIName method in CommonMethodsClass.ps1 script: $_"
        exit 1 
    }
}
function Get-AOEmail 
{
   param(
        [parameter(Mandatory = $true)]
        [string]$IntuneAppName
    )

    try {
      #Applist.json to fetch the app folder name
        $APPLISTJSONFILENAME = "appList.json"
        $IAF_Source_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\s" 
        Write-Host "IAF Source Directory : $IAF_Source_BINARIESDIRECTORY"
        $APPLISTJSONFILEPATH = Join-Path -Path $IAF_Source_BINARIESDIRECTORY -ChildPath $APPLISTJSONFILENAME

        $APPLISTJSONFILECONTENT = (Get-Content -Path $APPLISTJSONFILEPATH | ConvertFrom-Json).Apps
        
        #============= Put inside Loop =========
        
        $AppFoldername = ($APPLISTJSONFILECONTENT | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppFolderName

        $AppJsonPath = Join-path -Path ( Join-Path -Path $IAF_Source_BINARIESDIRECTORY -child "Apps") -ChildPath ( Join-Path -Path $AppFoldername -child "App.json")

        $AppJson = Get-Content -Path $AppJsonPath | ConvertFrom-Json

        $AppOwnerEmail= $AppJson.Information.Owner

        $ToEmail = $AppOwnerEmail -split ';'
        return $ToEmail
    }
    catch {
      #Write-Log "An error occurred while reading AO e-mail for Application from applist json. Error :- $_"
      Write-Output "PS_ERROR_DESC= Error in while reading AO e-mail for Application from applist json in Create_TestSuite_Steps.ps1 script: $_"
      #exit 1 
    }
        
}
try {
  
  $ApiBaseUrl = $env:LE_API_Base_Url

  $AuthTokenWithConfigAccess = $env:LE_Config_Token

  $AuthTokenWithReadAccess = $env:LE_Read_Token 

  $LETestVMURL = $env:LETestVM

  #$TestSuite_EmailRecipient =  $app.AOEmail
  
  $jsonContentPath = Join-Path -Path $env:LEConfigJsonPath -ChildPath $env:LE_VM_inputFileName
  Write-Host "final apps json Content path" $jsonContentPath
  #try { Write-Log "final apps json Content path $jsonContentPath" } catch {}

  $jsonObject = Get-Content -Path $jsonContentPath | ConvertFrom-Json

  $appsList = $jsonObject.Apps   
  Write-Host "applist from prev stage" $appsList | ConvertTo-Json -Depth 10
  Write-Log "applist from prev stage"
  Write-Log $($appsList | ConvertTo-Json -Depth 10)

  # declare variable to store the result of the stages in process
  $stagesResult = @()

  foreach ($app in $jsonObject.Apps) { 

    $TUAccount = $app.TUAccount
    $FamilyID  = $app.FamilyID
    $AppId     =  $app.AppID  # $app.AppId
    $IntuneAppName = $app.IntuneAppName
    $AOEmail =  Get-AOEmail -IntuneAppName $app.IntuneAppName 
    $AOEmails = @()
    if($AOEmail.Count -eq 1)
    {
      $AOEmails =  @($AOEmail)
    }
    else {
      $AOEmails += $AOEmail
    }
    # Create a StagesResult-like object using PSCustomObject
    $currentResult = [PSCustomObject]@{

      IntuneAppName     = $app.IntuneAppName
      AppSetupVersion   = $app.AppSetupVersion
      FamilyID          = $FamilyID
      AppId            =  $AppId
      VMName            = $app.DeviceName
      TUAccount         = $app.TUAccount
      AOEmails          = $AOEmails
      steps             = @()
      AppTestSuiteId    = ""
      AppTestUserId     = ""
      AppAccountGroupId = ""
      AppTestSuiteRunId = ""
    }
 
    $actionSteps = @()
    foreach ($path in $app.AppPath) {  
      try {
        $IntuneAppName = $app.IntuneAppName
        # code to check if application do not short-cut path
        if (-not $path.ShortcutPath -or $path.ShortcutPath -eq '') {
           $ShortcutPath = "No_shortcut_Available"
        }
        else {
            $ShortcutPath = $path.ShortcutPath
        }
        $ProcessName = $path.ProcessName
        $PackageName = $app.PackageName
        $AppSetupVersion = $app.AppSetupVersion
        
        $Application = CreateApplicationwithScript -IntuneAppName "$IntuneAppName" -AppId "$AppId" -ShortcutPath "$ShortcutPath" -ProcessName "$ProcessName" -PackageName "$PackageName" -AppSetupVersion "$AppSetupVersion"

        # Call the API using the POST method
        
        $ApplicationID = $Application
        Write-Host "Application is created. Application ID is : " $ApplicationID
        Write-Log "Application is created. Application ID is :  $ApplicationID"
        Write-Host "Application Name" $IntuneAppName
        Write-Log "Application Name $IntuneAppName"
        Write-Host "Short-cut Path" $ShortcutPath
        Write-Log "Short-cut Path $ShortcutPath"
        Write-Host "Process Name" $ProcessName
        Write-Log "Process Name $ProcessName"

        $currentActionStep = [PSCustomObject]@{
          shortcutName  = $path.ProcessName
          shortcutPath  = $path.ShortcutPath
          ApplicationId = $ApplicationID
        }
        $actionSteps += $currentActionStep
       
      } 

      catch {
        $errorTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $errorMessage = $_.Exception.Message
        $fullErrorComment = "Failed to create app '$IntuneAppName' (ID: $AppId): $errorMessage on $errorTimestamp"
        # For other errors, update App Catalogue and exit
        $Reason = "LE Smoke Test script creation failed"
        $username = $env:APP_CATALOGUE_USERNAME 
        $password = $env:APP_CATALOGUE_SECRET
        $catlogueToken = Get-CatalogueAccessToken -username $username -password $password
        AppCatalogueUpdate -AccessToken $catlogueToken -IntuneAppName $IntuneAppName -AppID $AppId -Reason $Reason -Comment $Comment = $errorMessage
        Write-Output "PS_ERROR_DESC= Error in while Creating Accout-Group in Create_TestSuite_Steps.ps1 script: $_"
        exit 1
      }
    }
    
    $currentResult.steps = $currentResult.steps + $actionSteps
    Write-Log "Action Steps for Application $IntuneAppName"
    Write-Log $($actionSteps | ConvertTo-Json)
    
    Write-Host "stage result for " $IntuneAppName
    Write-Host $currentResult | ConvertTo-Json
    Write-Log $currentResult


    try {
    
      $AccountGroup = CreateAccountGroupWithMember -IntuneAppName $app.IntuneAppName -AppId $AppId -TUAccount $TUAccount 
      $AccountGroupID = $AccountGroup
      Write-Host "account group is created.Account group id is : " $AccountGroupID
      Write-Log "account group is created.Account group id is : $AccountGroupID" 

      $currentResult.AppAccountGroupId = $AccountGroupID
      $currentResult.AppTestUserId = $TUAccount
      
    }

    catch {
      Write-Log "An error occurred while Create Account-Group :"
      Write-Log $_.Exception.Message
      $errorMessage = $_.Exception.Message
      $Reason = "LE Smoke Test script creation failed"
      $username = $env:APP_CATALOGUE_USERNAME 
      $password = $env:APP_CATALOGUE_SECRET
      $catlogueToken = Get-CatalogueAccessToken -username $username -password $password
      AppCatalogueUpdate -AccessToken $catlogueToken -IntuneAppName $IntuneAppName -AppID $AppId -Reason $Reason -Comment $Comment = $errorMessage

      Write-Output "PS_ERROR_DESC= Error in while Creating Accout-Group in Create_TestSuite_Steps.ps1 script: $_"
      exit 1 
    }
 
    try {
      #define test suite request body
      $TestSuite_RequestBody = [ApplicationTestSuite]::new()

      $TestSuite_RequestBody.create = $true
      # $currentResult.AppAccountGroupId = "5992ccf4-4f9c-493b-aa3c-8459419148b2"

      $TestSuite_RequestBody.accountGroups = @($AccountGroupID) 

      $displayResolution = [DisplayResolution]::new()

      $displayResolution.width = 1024

      $displayResolution.height = 768
 
      #Write-Host $displayResolution | ConvertTo-Json

      $connector = [Connector]::new()

      $connector.type = "Storefront"

      $connector.serverUrl = $LETestVMURL

      $connector.resource = "LE Client" #$app.DeviceName    #hardcoded as of now

      $connector.displayResolution = $displayResolution


      #older command version 
#       $commandLine = @'
# "C:\Program Files\Login VSI\Universal Web Connector\UniversalWebConnector.exe" --url "{host}" --scripts-path "C:\ProgramData\Login VSI\UWC\Scripts\uwc-6-aug-25" --username "{email}" --password "{password}" --domain "{domain}" --email "{email}" --pin "{custom1}" --secret "{custom2}" --resource "{custom3}" --maximized --timeout 0
# '@

#older command version
# $commandLine = @'
# "C:\Program Files\Login VSI\Universal Web Connector\UniversalWebConnector.exe" --url "{host}" --scripts-path "C:\ProgramData\Login VSI\UWC\Scripts\uwc-ocr-connector-prod-4.4.7" --username "{email}" --password "{password}" --domain "{domain}" --email "{email}" --pin "{custom1}" --secret "{custom2}" --resource "{custom3}" --maximized --timeout 700 --apikey "{custom4}" --apiurl "{custom5}" --sessionid "{sessionId}" --usebrokerlessscheduler "true"
# '@
$commandLine = @'
"C:\Program Files\Login VSI\Universal Web Connector\UniversalWebConnector.exe" --url "{host}" --scripts-path "C:\ProgramData\Login VSI\UWC\Scripts\uwc-ocr-connector-SSO-4.4.9" --username "{email}" --password "{password}" --domain "{domain}" --email "{email}" --pin "{custom1}" --secret "{custom2}" --resource "{Resource}" --maximized --timeout 700 --apikey "{custom4}" --apiurl "{custom5}" --sessionid "{sessionId}" --usebrokerlessscheduler "true"
'@
      $customConnector = [CustomConnector]::new()

      $customConnector.type = "Custom"

      $customConnector.host = $env:LETestVM  

      $customConnector.commandLine = $commandLine

      $customConnector.resource = "LE Client" #$app.DeviceName

      $Roles_FullURL = $ApiBaseUrl + "auth/roles"

      $RolesAPI_Response = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $Roles_FullURL -authToken $AuthTokenWithReadAccess

      $ListOfRoles = $RolesAPI_Response | ConvertFrom-Json

      $role = $ListOfRoles.items | Where-Object { $_.name -eq $env:LE_UserRole }

      #code to get the launcher groups           
      $LauncherGroup_FullURL = $ApiBaseUrl + "launcher-groups"

      $LauncherGroups_API_Response = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $LauncherGroup_FullURL -authToken $AuthTokenWithReadAccess

      $ListOfLauncherGroups = $LauncherGroups_API_Response | ConvertFrom-Json

      $launcherGroup = $ListOfLauncherGroups.items | Where-Object { $_.name -eq $env:LE_Launcher }

      $TestSuite_RequestBody.type = "ApplicationTest"
      $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss_fff"
      $TestSuite_RequestBody.name = "T_51_ST_Suite_" + $app.IntuneAppName + "_$currentDateTime"

      $TestSuite_RequestBody.description = "Transformation Project (T5.1) Smoke Test(ST) Test Suite for " + $app.IntuneAppName +" AppId $AppId"  

      $TestSuite_RequestBody.connector = $customConnector
 
      $TestSuite_RequestBody.launcherGroups = @($launcherGroup.id)  

      $TestSuite_RequestBody.applicationDebugModeEnabled = $true
      
      $TestSuite_RequestBody.applicationDebugModeEnabled = $true

      $TestSuite_RequestBody.engineStartTimeout = 120

      $TestSuite_RequestBody.engineMinLogLevel = "verbose"

      $TestSuite_RequestBody.sendConnectionEndedAfter = 120
 
      # prepare step object and to the steps list

      #add wait time in test suite to wait before start test scripts
      $delayInMinutes = 5
      $delayInSeconds = $delayInMinutes * 60

      $delayActionStep = @{
          type = "WorkloadDelayStep"
          isEnabled =$true
          delayInSeconds = $delayInSeconds
      }
      $TestSuite_RequestBody.steps = $TestSuite_RequestBody.steps + $delayActionStep
      
      
      foreach ($action in $actionSteps) {    

        $step = [Step]::new()

        $step.type = "WorkloadScriptStep"

        #here we need to pass the array of steps

        $step.applicationId = $action.ApplicationId #stageResult.AppTestId

        $step.isEnabled = $true

        $step.runOnce = $false

        $step.leaveRunning = $false
 
        $TestSuite_RequestBody.steps = $TestSuite_RequestBody.steps + $step

      }

      #$TestSuite_RequestBody.steps.Add($step)

      $TestSuite_RequestBody.roles = @($role.id) 

      $TestSuite_RequestBody.isEmailEnabled = $true

      #$TestSuite_RequestBody.emailRecipient = $TestSuite_EmailRecipient

      $TestSuite_RequestBody.includeSuccessfulApplications = $true

      $TestSuite_RequestBody.restartOnComplete = $false
      
      $headers = @{
        Authorization = "Bearer " + $AuthTokenWithConfigAccess
        ContentType   = "application/json"
      }
      $CreateTestTuiteAPIURL = $ApiBaseUrl + "tests"
 
      # Convert the request body to JSON format

      $jsonBody = $TestSuite_RequestBody | ConvertTo-Json

      Write-Host $jsonBody
      Write-Log "Request Body to create TestSuite"
      Write-Log $jsonBody
 
      $CreateTestSuiteResponse = Invoke-RestMethod -Uri $CreateTestTuiteAPIURL -Method Post -Headers $headers -Body $jsonBody -ContentType "application/json"

      $currentResult.AppTestSuiteId = $CreateTestSuiteResponse.id
 
      $stagesResult = $stagesResult + $currentResult
      # $stagesResult += $currentResult
      Write-Host "Test Suite is created. Test Suite ID is : " $CreateTestSuiteResponse.id
      Write-Host "result of test suite creation stage "
      Write-Log "Test Suite is created. Test Suite ID is : $CreateTestSuiteResponse" 
      $CreateTestSuiteResult = [PSCustomObject]@{
        Apps = $stagesResult
      }
 
      $FinalResult = $CreateTestSuiteResult | ConvertTo-Json -Depth 7 
      Write-Host $FinalResult
      Write-Log "result of test suite creation stage"
 
      # saving stage result file inside of the pipeline
      $stageResult = "LEAPILogs\${env:JOB_NAME}_${env:BUILD_ID}_StageResult.json"
      $logFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $stageResult
      Set-Content -Path $logFilePath -Value $FinalResult

      # saving stage result file outside of the pipeline
      $stageResult = "StageResult\${env:JOB_NAME}_${env:BUILD_ID}_StageResult.json"
      $logFilePath = Join-Path -Path $env:LEConfigJsonPath -ChildPath $stageResult
      Set-Content -Path $logFilePath -Value $FinalResult
      Write-Log $FinalResult

    }

    catch {
      Write-Log "An Error occured while creating test suite in Create_TestSuite_Stesps.ps1"
      Write-Log $_.Exception.Message
      $errorMessage = $_.Exception.Message
      $Reason = "LE Smoke Test script creation failed"
      $username = $env:APP_CATALOGUE_USERNAME 
      $password = $env:APP_CATALOGUE_SECRET
      $catlogueToken = Get-CatalogueAccessToken -username $username -password $password
      AppCatalogueUpdate -AccessToken $catlogueToken -IntuneAppName $IntuneAppName -AppID $AppId -Reason $Reason -Comment $Comment = $errorMessage
      Write-Output "PS_ERROR_DESC= Error in while Creating TestSuite with Steps in Create_TestSuite_Steps.ps1 script: $_"
      exit 1 
    }
  }
}
catch {
  Write-Output "PS_ERROR_DESC= Error in while Creating TestSuite with Steps in Create_TestSuite_Steps.ps1 script: $_"
  exit 1
}