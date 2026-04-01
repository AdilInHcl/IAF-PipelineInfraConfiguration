[CmdletBinding(SupportsShouldProcess = $true)]
param (

  [parameter(Mandatory = $false)]

  [string]$LE_Test_Re_Run_MaxLimit,
 
  [parameter(Mandatory = $false)]

  [string]$LE_Test__CurrentRun
)
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1"
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\Send-ContinuousTestResultNotification.psm1"
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppUpgradeDetection.psm1"
try {

  $ApiBaseUrl = $env:LE_API_Base_Url
  $AuthTokenWithReadAccess = $env:LE_Read_Token
  $github_owner = $env:LE_ContiTest_Owner
  $repo_name = $env:LE_ContiTest_Repo
  $branch_Name = $env:LE_ContiTest_Branch
  $continuousTest_AppListFile = $env:LE_ContiTest_AppListJson   #"ContinuousTest_AppList.json"
  
  #vm creation pipeline result data
  $IAF_BUILD_BINARIESDIRECTORY = "C:\\IntuneAPPFactory\\_work\\$env:IAF_JOBNAME\\$env:IAF_BUILD\\b" 
  $vmCreationDataFileName = "LEVMCreationData_$env:IAF_JOBNAME`_$env:IAF_BUILD.json" # // LE Vm info file
  #$IAF_AppListJsonFile = Join-Path $env:LESmokeTestVMCreation -ChildPath $env:Input_File_Name_fromVM_Creation
  $IAF_AppListJsonFile = Join-Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName
  $jsonObject = Get-Content -Path $IAF_AppListJsonFile | ConvertFrom-Json
  #Write-Host "IAF App List Json " 
  #Write-Host $jsonObject | ConvertTo-Json -Depth 10
  #reading the continuous test app list json
  $continuousTestAppListJson = Get-AppListFromJson -owner $github_owner -repo $repo_name -branch $branch_Name -JosnFile $continuousTest_AppListFile
  #$appListJson = ReadGitHubFile -github_owner $github_owner -repo_name $repo_name -NewAppListName $NewAppListName
  #Write-Host "Apps list for Continuous Test" $continuousTestAppListJson 
  $continuousTestAppList = $continuousTestAppListJson | ConvertFrom-Json
  #$appsList = $jsonObject.Apps   
  $continuousTestResult = [PSCustomObject]@{
    Apps = @()
  }
  foreach ($app in $jsonObject.Apps) 
  { 
    $intuneAppName = $app.IntuneAppName
    $FamilyID = $app.FamilyID
    $AppID = $app.AppID
    $currentResult = [PSCustomObject]@{

          IntuneAppName     = $intuneAppName
          AppSetupVersion   = $app.AppSetupVersion
          FamilyID          = $FamilyID
          AppId             = $AppId
          AOEmail           = ""
          TestDetail        = @()
          #OverAllResult     = ""
          Description       = ""
    }
    $TestList        = @()
    $appNotOnboarded_Description = "App is not onboarded to the continuous test as there no app detail found for $intuneAppName in LE Continous test JSON file."
    $testNotAdded_Description = "LE Continous Test suite name(s) not found in LE Continous test JSON file)"
    #use the actual product version here>
    $actaulProductVerion = ""
    $upgradeFailed_Description = "Latest version @actaulProductVerion not found in LE Continous test environment"
    $appContinuousTest = $continuousTestAppList.Apps | Where-Object {$_.IntuneAppName -eq $intuneAppName -and $_.FamilyID -eq $FamilyID}
    #$appContinuousTest = $continuousTestAppList.Apps | Where-Object {$_.IntuneAppName -eq $intuneAppName -and $_.FamilyID -eq $FamilyID}
    #Write-Host "App detail - " ($appContinuousTest | ConvertTo-Json -Depth 10)
    if($appContinuousTest)
    {
      foreach($TestDetail in $appContinuousTest.TestDetail)
      {
        $TestSuiteName = $TestDetail.ContinuousTestName 
        $testDetail = [PSCustomObject]@{

            ContinuousTestName = $TestSuiteName
            VersionOnVM   = ""
            Upgrade = ""
            Description       = ""
          }
        
          Write-Host "App Name fron Json file" $intuneAppName
          Write-Host "Continuous Test Suite Name For App from Json file '$TestSuiteName'" 
          #$APIName = "tests/test-runs"
          $TestSuite_FullURL = $ApiBaseUrl + "tests?orderBy=name&direction=asc&count=100&testType=continuousTest&include=all&filter=" + $TestSuiteName

          $ContinuousTestSuites = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $TestSuite_FullURL -authToken $AuthTokenWithReadAccess

          #Write-Host "result of api call to get continuous test detail with test suite name" 

          #Write-Host $ContinuousTestSuites | ConvertTo-Json
          
          
          $TestSuites = $ContinuousTestSuites | ConvertFrom-Json
          if($TestSuites.items.Count -gt 0)
          {
          $ContinuousTestSuite = $TestSuites.items | Where-Object { $_.name.trim() -eq $TestSuiteName.trim() } | Select-Object -First 1

          Write-Host "test suite detail after filtering with test suite name" 

          Write-Host $ContinuousTestSuite | ConvertTo-Json -Depth 7

          $TestSuiteId = $ContinuousTestSuite.id
          Write-Host "Continuous Test Suite Id " 
          Write-Host $TestSuiteId

          # URL to get All Test Runs by Test Id 
          
          $TestSuite_RunsURL = $ApiBaseUrl + "tests/" + $TestSuiteId + "/test-runs?orderBy=created&direction=desc&count=720&offset=0&includeTotalCount=false&include=all"

          $ContinuousTestSuite = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $TestSuite_RunsURL -authToken  $AuthTokenWithReadAccess
          Write-Host $ContinuousTestSuite

          $TestSuite = $ContinuousTestSuite | ConvertFrom-Json 
          Write-Host $TestSuite
          

          $TesRunObject = $TestSuite.items | Where-Object { $_.testName.trim() -eq $TestSuiteName.trim() } | Select-Object -First 1
          $TesRunId = $TesRunObject.id
          Write-Host $TesRunId
          $EventURL = $APIBaseURL + "test-runs/$TesRunId/events?orderBy=timestamp&direction=desc&count=720&offset=0&includeTotalCount=false&include=all"
              
          $EventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $AuthTokenWithReadAccess
          #Write-Host "continuous Test Events"
          #Write-Host $EventAPIResult
       

          $EventsObject = $EventAPIResult | ConvertFrom-Json
          $currentVersionEvent = $EventsObject.items | Where-Object { $_.eventType -eq "scriptEvent" -and  $_.title -eq "Current Version for $intuneAppName" } 
          $currentVersionEventJson = $currentVersionEvent | ConvertTo-Json -Depth 10
          Write-Host "Events for Versions of $intuneAppName"
          Write-Host $currentVersionEventJson
          
        
          # Sort by timestamp descending (latest first)
          $sortedEvents = $currentVersionEvent | Sort-Object { [datetime]$_.timestamp } -Descending
          $sortedEventsJson = $sortedEvents | ConvertTo-Json -Depth 10
          Write-Host "Events shorted by timestamp for $intuneAppName"
          Write-Host $sortedEventsJson 
        
          # Add a rank to each event

          # Initialize rank counter
          $rank = 0
          # Assign rank property and output the ranked events
          $rankedEvents = $sortedEvents | ForEach-Object {
              $rank++
              $customObject = [PSCustomObject]@{}
              # Copy existing properties
              foreach ($prop in $_.PSObject.Properties) {
                  $customObject | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
              }
              # Add the Rank property
              $customObject | Add-Member -NotePropertyName 'Rank' -NotePropertyValue $rank
              # Output the new object
              $customObject
          }

          $rankedEventsJson = $rankedEvents | ConvertTo-Json -Depth 10
          Write-Host "Events with assigned Ranks as per the timestamp for $intuneAppName"
          Write-Host $rankedEventsJson
         
          # Get top 10 ranked events
          #$topRankedEvents = $rankedEvents | Select-Object -First 10
          $topRankedEvents = $rankedEvents 
          $topRankedEventsJson = $topRankedEvents | ConvertTo-Json
          Write-Host $topRankedEventsJson

          # Get the latest (rank 1) event
          $latestEventRank1 = $topRankedEvents | Where-Object { $_.Rank -eq 1 }

          # Output (for debug/logging if needed)
          $currentVersionLatestEvent = $latestEventRank1 | ConvertTo-Json
          Write-Host "current Version Latest Event on LE VM"
          Write-Host $currentVersionLatestEvent 

          $EventID = $latestEventRank1.id
          
          $EventURL = $APIBaseURL + "events/$EventID" + "?include=all"
          Write-Host $EventURL
          $CurrentEventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $AuthTokenWithReadAccess
          $currentEventData = $CurrentEventAPIResult | ConvertFrom-Json
          $EventProperties = $currentEventData.properties
          $CurrentEventDescription = $EventProperties | Where-Object { $_.propertyId -eq "Description" }
          $CurrentVerionEventDescription = $CurrentEventDescription.value

          Write-Host "Current Version on Machine is : " $CurrentVerionEventDescription
          $currentVersion = $CurrentVerionEventDescription

          $latestEventRank2 = $topRankedEvents | Where-Object { $_.Rank -eq 2 }
          $previousVersionLatestEvent = $latestEventRank2 | ConvertTo-Json -Depth 10
          Write-Host $previousVersionLatestEvent 
          $EventID = $latestEventRank2.id
          $EventURL = $APIBaseURL + "events/$EventID" + "?include=all"
          Write-Host $EventURL
          $CurrentEventAPIResult = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $EventURL -authToken $AuthTokenWithReadAccess
          $currentEventData = $CurrentEventAPIResult | ConvertFrom-Json
          $EventProperties = $currentEventData.properties
          $CurrentEventDescription = $EventProperties | Where-Object { $_.propertyId -eq "Description" }
          $PreviousVerionEventDescription = $CurrentEventDescription.value

          Write-Host "Previous Version on Machine  : " $PreviousVerionEventDescription
          $PreviousVersion = $PreviousVerionEventDescription
          
          $testDetail.VersionOnVM   = $currentVersion
          $actaulProductVerion = $currentVersion
          $upgrageFailed_Description_ = $upgradeFailed_Description.Replace('@actaulProductVerion',$actaulProductVerion) 
          Write-Host "Current App Version : " $currentVersion
          Write-Host "Previous App Version : " $PreviousVersion

          if($PreviousVersion -eq $currentVersion ) { 
            $testDetail.Upgrade = "Failed" 
            $testDetail.Description = $upgrageFailed_Description_
          }
          else  { 
            $testDetail.Upgrade = "Pass" 
            $testDetail.Description = "NA"
          }
          $TestList  += $testDetail
          }
          else {
            # here we need to mention and log that the continuous test added in continuous test json with (specific name) is not presend in LE appliance
            Write-Host "No Continuous Test found in LE appliance with name :- $TestSuiteName"
            $testDetail.Upgrade = "Skipped" 
            $testDetail.Description = $testNotAdded_Description
            $TestList  += $testDetail
          }
         $currentResult.TestDetail = $TestList
         $currentResult.Description = $testNotAdded_Description
      }
    }
    else {
      $testDetail = [PSCustomObject]@{
            ContinuousTestName = ""
            VersionOnVM   = ""
            Upgrade = "Skipped"
            Description       = $appNotOnboarded_Description
          }
          $TestList  += $testDetail
          $currentResult.TestDetail = $TestList
    }
    
    # check if any continuous test got passed for the current App
    # $anyTestPassed = $TestList | Where-Object { $_.Upgrade -eq "Pass" }
    # if($anyTestPassed)
    # {
    #   $currentResult.OverAllResult  = "Pass"
    #   $currentResult.Description = "NA"
    # }
    # else{
    #   $currentResult.OverAllResult  = "Failed"
    #   $currentResult.Description = $upgradeFailed_Description
    # }
    $continuousTestResult.Apps += $currentResult
  } 
    $FinalResult = $continuousTestResult | ConvertTo-Json -Depth 10
      # save continuous test result for each iteration within pipeline path
      $TestRunResultPath = "${env:JOB_NAME}_${env:BUILD_ID}_ContinuousTestResult_${LE_Test__CurrentRun}.json"
      $TestResultJsonDataPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $TestRunResultPath
      Write-Host "Test Result Data file path $TestResultJsonDataPath"
      Write-Host "Smoke Test Result Json Data "
      Write-Host $FinalResult 
      Set-Content -Path $TestResultJsonDataPath -Value $FinalResult
      
      if($LE_Test_Re_Run_MaxLimit -eq $LE_Test__CurrentRun)
      {
        # save continuous test for final iteration out-of pipeline directory
        $continuousTestResult_File = "${env:JOB_NAME}_${env:BUILD_ID}_ContinuousTestResult.json"
        Write-Host "Continuous Test result file $continuousTestResult_File"
        if(-not(Test-Path $env:ContinuousTestResultPath)){New-Item -Path $env:ContinuousTestResultPath -ItemType Directory | Out-Null}
        $resultFilePath = Join-Path -Path $env:ContinuousTestResultPath -ChildPath $continuousTestResult_File
        #Write-Host "continuous test result path :- " $resultFilePath
        Set-Content -Path $resultFilePath -Value $FinalResult
      }
}
catch {
   Write-Host "PS_ERROR_DESC= Runtime error occurred in while polling continuous test result. Exception: $($_.Exception.Message)"
   Exit 1
}
 


