[CmdletBinding(SupportsShouldProcess = $true)]
param (

  [parameter(Mandatory = $false)]

  [int]$LE_Test_Re_Run_MaxLimit,
 
  [parameter(Mandatory = $false)]

  [int]$LE_Test__CurrentRun
)
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\DownloadReportbyID.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\Delete-LE-Entities.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig\Scripts\Save_SmokeTest_Report.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig/Scripts/Save_Application_TestScript.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig/Scripts/AppUpgradeDetection.psm1"
Import-Module "$($env:WORKSPACE)\PowerShell/FinalEmail-Content.psm1"
Import-Module "$($env:WORKSPACE)\LoginEnterpriseConfig/Scripts/Write_TextLog.psm1"
$ApiBaseUrl = $env:LE_API_Base_Url
$AuthTokenWithConfigAccess = $env:LE_Config_Token
$AuthTokenWithReadAccess = $env:LE_Read_Token
function GetDetailedTestResult {
  param (
    [parameter(Mandatory = $true)]
    [string]$APIBaseURL,
    [parameter(Mandatory = $true)]
    [string] $authToken,
    [parameter(Mandatory = $true)]
    [string] $testRunId,
    [parameter(Mandatory = $true)]
    [string] $Shortcuts
  )
    
  #code to call user-sessions API
    
  $ErrorObject = [PSCustomObject]@{
    loginState                 = ""      
    sessionState               = "" 
    EventType                  = ""
    EventFinishedTitle         = ""
    EventConnectionTitle       = ""
    EventConnectionDescription = ""
    ActionsFailureReason       = @()
  }
  try {
    $UserSessionURL = $APIBaseURL + "test-runs/$testRunId/user-sessions"
    $UserSessionResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $UserSessionURL -authToken $authToken
    Write-Host $UserSessionResult
    #Write-Host "User Session API call response for Test-Run-Id : $testRunId"
    #Write-Host $UserSessionResult
    $UserSessionData = $UserSessionResult | ConvertFrom-Json
    $UserSessionData = $UserSessionData.items | Where-Object { $_.testRunId -eq $testRunId }
    #Write-Host "user session data"
    #Write-Host $UserSessionData | ConvertTo-Json -Depth 5
    Write-Host "user session data for Test-Run-Id : $testRunId"
    Write-Host $($UserSessionData | ConvertTo-Json -Depth 5)
    $ErrorObject.loginState = $UserSessionData.loginState
    $ErrorObject.sessionState = $UserSessionData.sessionState
 
    #code to call events API
      
    $EventURL = $APIBaseURL + "test-runs/$testRunId/events"
    $EventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $authToken
    #Write-Host "event api result"
    #Write-Host $EventAPIResult
    #Write-Host "'event api result' for Test-Run-Id : $testRunId"
    #Write-Host $EventAPIResult
    $EventData = $EventAPIResult | ConvertFrom-Json
    $EventFinishedData = $EventData.items | Where-Object { $_.eventType -eq "testRunFinished" }
    # $EventFinishedType = $EventFinishedData.eventType
    $ErrorObject.EventFinishedTitle = $EventFinishedData.title
    Write-Host $EventFinishedTitle

    #Write-Host "shortcuts in comman methods"
    #Write-Host $Shortcuts
    $Appshortcuts = $Shortcuts | ConvertFrom-Json
    $Actions = @()

    $EventsData = ""
    if ($ErrorObject.loginState -eq "failed" ) {
      $EventsData = $EventData.items | Where-Object { $_.eventType -eq "connectionInitializationTimeout" }
    }
    $EventLoginFailure = $EventData.items | Where-Object { $_.eventType -eq "loginFailure" }
    if ($EventLoginFailure) {
      $EventsData = $EventLoginFailure
    }
    $EventLaunchers = $EventData.items | Where-Object { $_.eventType -eq "launcherCapacityExceeded" }
    if ($EventLaunchers) {
      $EventsData = $EventLaunchers
    }
    $Eventaccounts = $EventData.items | Where-Object { $_.eventType -eq "accountCapacityExceeded" }
    if ($Eventaccounts) {
      $EventsData = $Eventaccounts
    }
    if ($EventsData) {
      #"Package Not Found for {intuneAppName}
      $ErrorObject.EventType = $EventsData.eventType
      $ErrorObject.EventConnectionTitle = $EventsData.title
      $EventID = $EventsData.id
      $EventURL = $APIBaseURL + "events/$EventID" + "?include=all"
      Write-Host "Event URL " $EventURL
      $CurrentEventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $authToken
      $currentEventData = $CurrentEventAPIResult | ConvertFrom-Json
      $EventProperties = $currentEventData.properties
      $CurrentEventDescription = $EventProperties | Where-Object { $_.propertyId -eq "Description" }
      $ErrorObject.EventConnectionDescription = $CurrentEventDescription.value
            
      foreach ($shortcut in $Appshortcuts) {
        $AppErrorObject = [PSCustomObject]@{
          shortcutName                 = $shortcut.shortcutName
          shortcutPath                 = $shortcut.shortcutPath
          ApplicationId                = $shortcut.ApplicationId

          EventApplicationFailureType  = ""
          EventApplicationFailureTitle = ""
          ApplicationFailureReason     = ""
          ActionStatus                 = "Failed" 
          ApplicationTestScriptPath    = ""
        }
        $Actions = $Actions + $AppErrorObject
      }
    }
    else {
          
      foreach ($shortcut in $Appshortcuts) {
        $AppErrorObject = [PSCustomObject]@{
          shortcutName                 = $shortcut.shortcutName
          shortcutPath                 = $shortcut.shortcutPath
          ApplicationId                = $shortcut.ApplicationId

          EventApplicationFailureType  = ""
          EventApplicationFailureTitle = ""
          ApplicationFailureReason     = ""
          ActionStatus                 = "Failed" 
          ApplicationTestScriptPath    = ""
        }
        $Actions = $Actions + $AppErrorObject
      }
    }
    if ($ErrorObject.loginState -eq "succeeded" -and $ErrorObject.sessionState -eq "completed") {
      $Actions = @()
      foreach ($shortcut in $Appshortcuts) {
                
        #$EventApplicationFailure = $EventData.items | Where-Object { $_.eventType -eq "applicationFailure" }
        #$ApplicationFailure = $EventApplicationFailure | Where-Object { $_.applicationId -eq $shortcut.ApplicationId }
        # event type which we write in test script "scriptEvent" 
        $ApplicationFailure = $EventData.items | Where-Object { $_.applicationId -eq $shortcut.ApplicationId -and $_.eventType -eq "applicationFailure" }
                
        $EventApplicationFailureType = $ApplicationFailure.eventType
        $EventApplicationFailureTitle = $ApplicationFailure.title
        $EventID = $ApplicationFailure.id
        $EventURL = $APIBaseURL + "events/$EventID" + "?include=all"
        Write-Host "Event URL with EventId " $EventURL
        $AppFailureEventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $authToken
        $EventAppFailureData = $AppFailureEventAPIResult | ConvertFrom-Json
        $EventProperties = $EventAppFailureData.properties
        $EventAppFailureDescription = $EventProperties | Where-Object { $_.propertyId -eq "Description" }
        $ApplicationFailureReason = $EventAppFailureDescription.value
        $ActionStatus = if ($EventApplicationFailureType) { "Failed" } else { "Passed" }
        $AppErrorObject = [PSCustomObject]@{
          shortcutName                 = $shortcut.shortcutName
          shortcutPath                 = $shortcut.shortcutPath
          ApplicationId                = $shortcut.ApplicationId
          EventApplicationFailureType  = $EventApplicationFailureType
          EventApplicationFailureTitle = $EventApplicationFailureTitle
          ApplicationFailureReason     = $ApplicationFailureReason
          ActionStatus                 = $ActionStatus
          ApplicationTestScriptPath    = ""
        }
        $Actions = $Actions + $AppErrorObject
        #Write-Host "error object for action"
        #Write-Host $Actions | ConvertTo-Json -Depth 5
      }
    }
    #$ErrorObject.ActionsFailureReason = $ErrorObject.ActionsFailureReason + ,$Actions   
    $ErrorObject.ActionsFailureReason = $ErrorObject.ActionsFailureReason + $Actions 

    Write-Host "Test Result Object"
    Write-Host $ErrorObject | ConvertTo-Json -Depth 10
    return $ErrorObject

  }

  catch {
    Write-Host "An unexpected error occurred: $($_.Exception.Message)"
    Write-Output "PS_ERROR_DESC= Error in GetDetailedTestResult method in PollLEResult_Re_Run.ps1 script: $_"
    exit 1
  }
}
function CheckStatus {
  param(
    [int]$totalCount,
    [int]$successCount
  )
  $status = $false
  if (($successCount -gt 0) -and ($totalCount -gt 0)) {
    if ($successCount -eq $totalCount)  
    { $status = $false }
    else { $status = $true }
  }
  else { $status = $true }
  return $status
}
function Update-AppCatalogueStatus {
    param(
        [Parameter(Mandatory = $true)]
        $Data
    )
    try {
        $AccessToken = Get-CatalogueAccessToken -username $env:APP_CATALOGUE_USERNAME -password $env:APP_CATALOGUE_SECRET

        foreach ($app in $Data.Apps) {
            $AppID = $app.AppID
            $IntuneAppName = $app.IntuneAppName
            $OverAllResult = $app.OverAllResult

            if ([string]::IsNullOrWhiteSpace($AppID)) {
                Write-Host "Skipping catalogue update - FamilyID is empty"
                continue
            }

            if ($OverAllResult -eq "Failed") {
                $loginState   = $app.LoginState
                $testResult   = $app.TestResult
                $sessionState = $app.SessionState
                $reason = "LE Smoke Test execution failed"
                $comment = "SmokeTest failed for '$($app.IntuneAppName)' (ID: $AppID): LoginState=$loginState, TestResult=$testResult, SessionState=$sessionState"

                Write-Host "Updating catalogue to On Hold for AppID: $AppID - Reason: $reason"
                AppCatalogueUpdate -AccessToken $AccessToken -IntuneAppName $IntuneAppName -AppID $AppID -Reason $reason -Comment $comment
            }
            elseif ($OverAllResult -eq "Passed") {
                Write-Host "Smoke test passed for AppID: $AppID - no catalogue update needed"
            }
            else {
                Write-Host "OverAllResult not set for AppID: $AppID - skipping catalogue update"
            }
        }
    }
    catch {
        Write-Host "WARNING: Update-AppCatalogueStatus failed: $_"
    }
}
function Delete-LE-Items{
  param(
        [Parameter(Mandatory = $true)]
        $currentItem
    )
   
  try { 
    #decommision LE entities    
        $items = @()
        foreach ($step in $currentItem.steps) {
          $items = $items + $step.ApplicationId     
        }
        $appIds = $items | ConvertTo-Json 
        Write-Host "applicationIds " $appIds 

        $testId = $currentItem.AppTestSuiteId
        $APIURL = $ApiBaseUrl + "tests/" + $testId
        Write-Host " tests " $APIURL
        #below line is to delete the test suite by id
        Delete_LE_Items_By_Id -APIURL $APIURL -authToken $AuthTokenWithConfigAccess -itemId  $testId 
                    
        #delete account group by id
        $AppAccountGroupId = $currentItem.AppAccountGroupId
        $APIURL = $ApiBaseUrl + "account-groups/" + $AppAccountGroupId
        Write-Host " account-groups " $APIURL 
        Delete_LE_Items_By_Id -APIURL $APIURL -authToken $AuthTokenWithConfigAccess -itemId  $AppAccountGroupId 
        $steps = @($currentItem.steps)
        if ($steps.Count -eq 1) {
          #below line is to delete the application by id
          $appId = $items
          $APIURL = $ApiBaseUrl + "applications/" + $appId
          Write-Host " applications " $APIURL
          Delete_LE_Items_By_Id -APIURL $APIURL -authToken $AuthTokenWithConfigAccess -itemId  $appIds 
        }
        else {
          #bulk delete applications from LE console by application ids 
          $APIURL = $ApiBaseUrl + "applications/"            
          Delete_LE_Items_InBulk -APIURL $APIURL -authToken $AuthTokenWithConfigAccess -items $appIds 
        }
      
  }
  catch {
    Write-Output "PS_ERROR_DESC= Network error occurred in Delete-LE-Items method in PollLEResult_Re_Run.ps1 script: $_"
    exit 1
  }
  
      
}
try {
  Write-Host "Max Limit : " $LE_Test_Re_Run_MaxLimit,
  Write-Host "current Run Count : " $LE_Test__CurrentRun 

  #$TestRunResultPath = Join-Path -Path $env:LEConfigJsonPath -ChildPath "StageResult\"
  #$latestTestRunResultFile= Join-Path -Path $TestRunResultPath -ChildPath "${env:JOB_NAME}_${env:BUILD_ID}_StageResult.json"
  $latestTestRunResultFile = $env:LETestSuiteJsonFile
  $latestTestRunResultFilePath = $latestTestRunResultFile
  Write-Host "Stage Result Json file path" $latestTestRunResultFilePath
  #Write-Log "Stage Result Json file path $latestTestRunResultFilePath" 
  $jsonData = Get-Content -Path $latestTestRunResultFilePath -Raw
  # Write-Host $jsonData
  $jsonObject = $jsonData | ConvertFrom-Json
  #Write-Log "json Data from previous stage" 
  #Write-Log $jsonData
  #Re-Run Case starts here
  $New_JsonObject = ""
  $prevRunResultObj = $null
  if ($LE_Test__CurrentRun -gt 1) {
    # reading TestRun stage result from the file within the pipeline path   
    $prev = $LE_Test__CurrentRun - 1
    $prevTestRunResultFile = "LEAPILogs\TestRun_StatusResult_${prev}.json"
    $prevTestRunResultJsonPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $prevTestRunResultFile
    #Write-Host "Re Run data for Test Run Result Json file path" $prevTestRunResultJsonPath
    $NewJson_Data = Get-Content -Path $prevTestRunResultJsonPath -Raw
    #Write-Host $NewJson_Data
    $New_JsonObject = $NewJson_Data | ConvertFrom-Json
    $prevRunResultObj = $NewJson_Data | ConvertFrom-Json
    #Write-Host "New Json Object " $New_JsonObject.Apps | ConvertTo-Json -Depth 7
  }
  #Re-Run Case ends here
      
  $TestAppList = @()
  foreach ($currentItem in $jsonObject.Apps) {    
    # object to contain all the information about the test suite and its execution result
    $IntuneAppName = $currentItem.IntuneAppName
    $FamilyID = $currentItem.FamilyID
    $AppID = $currentItem.AppId
    $AppSetupVersion = $currentItem.AppSetupVersion 
    $AOEmails = $currentItem.AOEmails
    $CrrentTestResultObject = [PSCustomObject]@{
      IntuneAppName              = $IntuneAppName
      FamilyID                   = $FamilyID
      AppID                      = $AppID
      AppSetupVersion            = $AppSetupVersion
      AOEmails                   = $AOEmails 
      VMName                     = $currentItem.VMName
      TUAccount                  = $currentItem.AppTestUserId
      AppTestUserId              = $currentItem.AppTestUserId
      AppTestSuiteId             = $currentItem.AppTestSuiteId
      AppAccountGroupId          = $currentItem.AppAccountGroupId
      AppTestSuiteRunId          = $currentItem.AppTestSuiteRunId
      steps                      = $currentItem.steps 
      LoginState                 = ""      
      SessionState               = ""  
      TestResult                 = ""
      TestStatus                 = ""
      OverAllResult              = ""
      AppFailureResults          = ""
      AppPerformanceResults      = ""
      EventFinishedTitle         = ""
      EventConnectionTitle       = ""
      EventConnectionDescription = ""
      #ActionsResult = @()
      ActionsResult              = ""
      TestReportPath             = ""
            
    }
        
    $Run = $true 
    $TestSuiteId = $currentItem.AppTestSuiteId  
    $testRunId = $currentItem.AppTestSuiteRunId       
    if ($LE_Test__CurrentRun -gt 1) {       
      $prevTestRun = $null
      if ($prevRunResultObj) {               
        $prevTestRun = $prevRunResultObj.Apps | Where-Object { $_.AppTestSuiteId -eq $TestSuiteId }
        $AppFailureResults = $prevTestRun.AppFailureResults
        if ($prevTestRun.OverAllResult -eq "Passed") {
          #if($AppFailureResults.successCount -eq $AppFailureResults.totalCount)
          $Run = $false
          $CrrentTestResultObject.LoginState = $prevTestRun.LoginState     
          $CrrentTestResultObject.SessionState = $prevTestRun.SessionState
          $CrrentTestResultObject.TestResult = $prevTestRun.TestResult
          $CrrentTestResultObject.TestStatus = $prevTestRun.TestStatus
          $CrrentTestResultObject.OverAllResult = $prevTestRun.OverAllResult
          $CrrentTestResultObject.AppFailureResults = $prevTestRun.AppFailureResults
          $CrrentTestResultObject.AppPerformanceResults = $prevTestRun.AppPerformanceResults
          $CrrentTestResultObject.EventFinishedTitle = $prevTestRun.EventFinishedTitle
          $CrrentTestResultObject.EventConnectionTitle = $prevTestRun.EventConnectionTitle
          $CrrentTestResultObject.EventConnectionDescription = $prevTestRun.EventConnectionDescription
          $CrrentTestResultObject.ActionsResult = $prevTestRun.ActionsResult
          $CrrentTestResultObject.steps = $prevTestRun.steps
          $CrrentTestResultObject.TestReportPath = $prevTestRun.TestReportPath
                  
        }
      }       
    }
    if ($Run) {
      $status = "created"
      $result = $null
      $Shortcuts = $currentItem.steps | ConvertTo-Json -Depth 3
      
      Write-Host "IntuneAppName " $IntuneAppName
      Write-Host "FamilyID " $FamilyID
      Write-Host "AppSetupVersion " $AppSetupVersion
      Write-Host "Shortcuts " $Shortcuts
          
      while ($status -eq "created") {
        $APIURL = $APIBaseURL + "test-runs/" + $testRunId + "?include=all"
        Write-Host "Test Run URL : " $APIURL
        
        $TestRun = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $APIURL -authToken $AuthTokenWithReadAccess
        Write-Host "Test Run Result :- " 
        
        $TestRunObject = $TestRun | ConvertFrom-Json
           
        $status = $TestRunObject.state
        $result = $TestRunObject.result
        $TestDetail = $TestRunObject.result
        $TestResult = $TestRunObject.result
        $TestStatus = $TestRunObject.state
        Write-Host "Test result " $TestResult
        Write-Host "Test Status " $TestStatus
        Write-Host "test status " $status
            
        #if ($status -eq "completed" ) {   
        if ($status -eq "completed" -or $status -eq "testRunEnded") {
          #Write-Host "test status inside if block" $status     
                
          $ErrorResult = GetDetailedTestResult -APIBaseURL $APIBaseURL -authToken $AuthTokenWithReadAccess -testRunId $testRunId -Shortcuts $Shortcuts
                   
          Write-Host "Login State" $ErrorResult.loginState
          Write-Host "Session State" $ErrorResult.sessionState
                    
          $appFailureResults = $TestRunObject.appFailureResults
          $totalCount = [int]$AppFailureResults.totalCount
          $successCount = [int]$AppFailureResults.successCount
          $reRun = CheckStatus -totalCount $totalCount -successCount $successCount
          Write-Host "re-run Status :- $reRun"
          if ($reRun)
          { $CrrentTestResultObject.OverAllResult = "Failed" }
          else { $CrrentTestResultObject.OverAllResult = "Passed" }
          $CrrentTestResultObject.LoginState = $ErrorResult.loginState     
          $CrrentTestResultObject.SessionState = $ErrorResult.sessionState
          $CrrentTestResultObject.SessionState = $ErrorResult.sessionState
          $CrrentTestResultObject.EventFinishedTitle = $ErrorResult.EventFinishedTitle
          $CrrentTestResultObject.EventConnectionTitle = $ErrorResult.EventConnectionTitle
          $CrrentTestResultObject.EventConnectionDescription = $ErrorResult.EventConnectionDescription
          $CrrentTestResultObject.ActionsResult = $ErrorResult.ActionsFailureReason
          $CrrentTestResultObject.AppPerformanceResults = $TestRunObject.appPerformanceResults
          $CrrentTestResultObject.TestResult = $TestRunObject.result
          $CrrentTestResultObject.TestStatus = $TestRunObject.state  
          $Attachment = ""
          #-and  ($reRun)
          if ($TestRunObject.result -eq "successful" -or $status -eq "testRunEnded") {
            Write-Host "test result is ${TestRunObject.result} " 
            $apiurl = $ApiBaseUrl + "test-runs/" + $testRunId + "/reports/pdf"
            Write-Host $APIURL
            Start-Sleep -Seconds 30
            $ReportFilePath = DownloadTestReportbyId -APIURL $APIURL -authToken $AuthTokenWithConfigAccess -testRunId $testRunId -FamilyID $FamilyID -IntuneAppName $IntuneAppName -AppId $AppID -AppSetupVersion $AppSetupVersion
            $CrrentTestResultObject.TestReportPath = $ReportFilePath
            # Write-Host $TestRunId
            #send email notification with test report
            $Attachment = $ReportFilePath
            #method to save LE smoke test report over azure storage account
            Save_ApplicationTestReport -FilePath $Attachment
            Write-Host "save file over azure storage"
          }
          $AppShortcuts = $ErrorResult.ActionsFailureReason | ConvertTo-Json -Depth 10
          Write-Host "App Short-cuts with Test Result for $IntuneAppName" 
          Write-Host $AppShortcuts
          #logic to prepare array of application ids    
          $items = @()
          $ApplicationScriptPath = ""
          foreach ($step in $currentItem.steps) {
            $items = $items + $step.ApplicationId 
            #method to save LE smoke test script generated for single smoke test inside pipeline path
            $ApplicationScriptPath = SaveApplicationScript -ApplicationID $step.ApplicationId -FamilyID $FamilyID -AppId $AppID -IntuneAppName $IntuneAppName -AppSetupVersion $AppSetupVersion
                     
            #logic to detect if App is New or upgrade  
            $currentAction = $CrrentTestResultObject.ActionsResult | Where-Object { $_.ApplicationId -eq $step.ApplicationId }
            Write-Host "Action result for Test script :" 
            Write-Host $currentAction | ConvertTo-Json -Depth 5
            if($currentAction){
             $currentAction.ApplicationTestScriptPath = $ApplicationScriptPath
            }
          }
          $appIds = $items | ConvertTo-Json 
          Write-Host "applicationIds " $appIds 
          if ($CrrentTestResultObject.OverAllResult -eq "Passed") {
            #method to save LE smoke test script generated for single smoke test over azure storage account
            if ($ApplicationScriptPath) {
              Save_ApplicationTestScript -FilePath $ApplicationScriptPath 
              $TestScriptFileName = [System.IO.Path]::GetFileName($ApplicationScriptPath)        
              #detect_Onboard_NewApp -FamilyId $FamilyID -IntuneAppName $IntuneAppName -AOEmail $AOEmails -Attachment $ApplicationScriptPath -TestScriptPath $ApplicationScriptPath -Shortcuts $AppShortcuts -TestResult $TestStatus
              detect_Onboard_NewApp -AppID $AppID -FamilyId $FamilyID -IntuneAppName $IntuneAppName -AppVersion $AppSetupVersion -AOEmail $AOEmails -TestResult $TestStatus  -TestScriptFile $TestScriptFileName     
            }   
                  
          }
          #decommision LE entities
          
        }
        else {
          Write-Host "Current Status is :- $status"
        }
        Start-Sleep -Seconds 30
      }
    }       
    
    $TestAppList = $TestAppList + $CrrentTestResultObject
  }
    
  $TestRunResult = [PSCustomObject]@{
    Apps = $TestAppList
  }
  #code to save Test Run Result data for each iteration 
  $TestRunResultPath = "LEAPILogs\TestRun_StatusResult_${LE_Test__CurrentRun}.json"
  $TestResultJsonDataPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $TestRunResultPath
  
  $FinalResult = $TestRunResult | ConvertTo-Json -Depth 10 
  Set-Content -Path $TestResultJsonDataPath -Value $FinalResult

  #check if smoke test passed for all given apps
  $AllAppSmokeTest = "Failed"  
  $testResult = $TestRunResult.Apps | Where-Object { $_.OverAllResult -eq "Failed" }
  if($testResult){$AllAppSmokeTest = "Failed"}
  else {$AllAppSmokeTest = "Passed"}
  
  if ($LE_Test_Re_Run_MaxLimit -eq $LE_Test__CurrentRun -or $AllAppSmokeTest -eq "Passed") { 
    
    # vmcreation json file path
    $VMInfoFileName = $env:Input_File_name
    $VMCreation_JSONFilePath = Join-Path -Path $env:IAF_BUILD_BINARIESDIRECTORY -ChildPath $VMInfoFileName
    
    foreach($currentItem in $TestRunResult.Apps)
    {   
      #decommision LE entities
      Delete-LE-Items -currentItem $currentItem

      # update flag for SmokeTest in vmcreation json file
      if (Test-Path $VMCreation_JSONFilePath) {   
        # Load LE VMCreation JSON data 
        $VMCreation_JSONObject = Get-Content -Path $VMCreation_JSONFilePath | ConvertFrom-Json
        $currentApp= $VMCreation_JSONObject.Apps | Where-Object { $_.IntuneAppName -eq $currentItem.IntuneAppName } 

          if($currentItem.OverAllResult -eq "Passed")
          {
           $currentApp | Add-Member -NotePropertyName "SmokeTest" -NotePropertyValue "Pass" -Force
          }
          else {
            $currentApp | Add-Member -NotePropertyName "SmokeTest" -NotePropertyValue "Failed" -Force
          }
          #reload updated json data in VM creation json file
          $VMCreation_JSONObject | ConvertTo-Json -Depth 10 | Set-Content -Path $VMCreation_JSONFilePath -Encoding UTF8     
      } 
       else {
        Write-Output "PS_ERROR_DESC= JSON file at path '$VMCreation_JSONFilePath' does not exist."
        exit 1
      }
    }
    #save final data of Test Run Result
    $IAF_BUILD_TAG = "$($env:IAF_JOBNAME)_$($env:IAF_BUILD)"
    $ScanFolder = Join-Path -path $env:LEScanFolder -ChildPath $IAF_BUILD_TAG
    if (-not(Test-Path $ScanFolder)) { New-Item -Path $ScanFolder -ItemType Directory | Out-Null }
    $TestResult_Final_Data_FilePath = Join-Path -Path $ScanFolder -ChildPath $env:LESmokeTestResultFile 
    Set-Content -Path $TestResult_Final_Data_FilePath -Value $FinalResult

    #update app -catalogue status for each app regarding smoke test
    Update-AppCatalogueStatus -Data $TestRunResult
    
    Write-Output "All App Smoke Test Passed"
  }
  
}
 
catch [System.Net.WebException] {
  Write-Output "PS_ERROR_DESC= Network error occurred in PollLEResult_Re_Run.ps1 script: $_"
  exit 1
}

catch [System.Management.Automation.RuntimeException] {
  Write-Output "PS_ERROR_DESC= Network error occurred in PollLEResult_Re_Run.ps1 script: $_"
  exit 1
}

catch {
  Write-Output "PS_ERROR_DESC= An unexpected error occurred in PollLEResult_Re_Run.ps1 script: $_"
  exit 1
}

 
