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
  
  $IAF_AppListJsonFile = Join-Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName
  $jsonObject = Get-Content -Path $IAF_AppListJsonFile | ConvertFrom-Json

  $continuousTestAppListJson = Get-AppListFromJson -owner $github_owner -repo $repo_name -branch $branch_Name -JosnFile $continuousTest_AppListFile
  $continuousTestAppList = $continuousTestAppListJson | ConvertFrom-Json
  
  $continuousTestResult = [PSCustomObject]@{
    Apps = @()
  }

  $PassedApps = 0

  foreach ($app in $jsonObject.Apps){ 
    $intuneAppName = $app.IntuneAppName
    $FamilyID = $app.FamilyID
    $AppID = $app.AppID
    $AppSetupVersion = $app.AppSetupVersion
    $currentResult = [PSCustomObject]@{

          IntuneAppName     = $intuneAppName
          AppSetupVersion   = $AppSetupVersion
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

    if($appContinuousTest){
      foreach($TestDetail in $appContinuousTest.TestDetail){
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
                    
          $TestSuites = $ContinuousTestSuites | ConvertFrom-Json
          if($TestSuites.items.Count -gt 0){
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
       

              $EventsObject = $EventAPIResult | ConvertFrom-Json
              $currentVersionEvent = $EventsObject.items | Where-Object { $_.eventType -eq "scriptEvent" -and  $_.title -eq "Current Version for $intuneAppName" } 
              $currentVersionEventJson = $currentVersionEvent | ConvertTo-Json -Depth 10
          
        
              # Sort by timestamp descending (latest first)
              $sortedEvents = $currentVersionEvent | Sort-Object { [datetime]$_.timestamp } -Descending
              $sortedEventsJson = $sortedEvents | ConvertTo-Json -Depth 10
        
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
         
              # Get top 10 ranked events
              $topRankedEvents = $rankedEvents 
              $topRankedEventsJson = $topRankedEvents | ConvertTo-Json

              # Get the latest (rank 1) event
              $latestEventRank1 = $topRankedEvents | Where-Object { $_.Rank -eq 1 }

              # Output (for debug/logging if needed)
              $currentVersionLatestEvent = $latestEventRank1 | ConvertTo-Json

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

              #Write-Host "Previous Version on Machine  : " $PreviousVerionEventDescription
              $PreviousVersion = $PreviousVerionEventDescription
          
              $testDetail.VersionOnVM   = $currentVersion
              #$actaulProductVerion = $currentVersion
              $actaulProductVerion = $AppSetupVersion
              $upgrageFailed_Description_ = $upgradeFailed_Description.Replace('@actaulProductVerion',$actaulProductVerion) 
              Write-Host "Current App Version : " $currentVersion
              
              if($AppSetupVersion -eq $currentVersion ) { 
                $testDetail.Upgrade = "Pass" 
                $testDetail.Description = "NA"
                $PassedApps += 1
              }
              else  { 
            
                $testDetail.Upgrade = "Failed" 
                $testDetail.Description = $upgrageFailed_Description_
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
    
    $continuousTestResult.Apps += $currentResult
  }

    $FinalResult = $continuousTestResult | ConvertTo-Json -Depth 10
    
    <#
    # save continuous test result for each iteration within pipeline path
    $TestRunResultPath = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_ContinuousTestResult_${LE_Test__CurrentRun}.json"
    $TestResultJsonDataPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $TestRunResultPath
    Write-Host "Test Result Data file path $TestResultJsonDataPath"
    Write-Host "Smoke Test Result Json Data "
    Write-Host $FinalResult 
    Set-Content -Path $TestResultJsonDataPath -Value $FinalResult
    #>

    # save continuous test for final iteration out-of pipeline directory
    $continuousTestResult_File = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_ContinuousTestResult.json"
    Write-Host "Continuous Test result file $continuousTestResult_File"
    if(-not(Test-Path $env:ContinuousTestResultPath)){New-Item -Path $env:ContinuousTestResultPath -ItemType Directory | Out-Null}
    $resultFilePath = Join-Path -Path $env:ContinuousTestResultPath -ChildPath $continuousTestResult_File
    Write-Host "continuous test result path :- " $resultFilePath
    Set-Content -Path $resultFilePath -Value $FinalResult -Force

    #Fetch total Apps
    $totalApps = @($jsonObject.Apps).Count
    $BlankTestDetails = @($continuousTestResult.Apps | Where-Object {@($_.TestDetail).Count -eq 0}).Count

    #Exit the Loop Once the Results are set
    if($totalApps -eq $BlankTestDetails){
       Write-Output "Skip_Continous_Test"
    }

    if($totalApps -eq $PassedApps){
       Write-Output "All_Continous_Test_Pass"
    }
      
    <#
    if($LE_Test_Re_Run_MaxLimit -eq $LE_Test__CurrentRun)
    {
        # save continuous test for final iteration out-of pipeline directory
        $continuousTestResult_File = "${env:IAF_JOBNAME}_${env:IAF_BUILD}_ContinuousTestResult.json"
        Write-Host "Continuous Test result file $continuousTestResult_File"
        if(-not(Test-Path $env:ContinuousTestResultPath)){New-Item -Path $env:ContinuousTestResultPath -ItemType Directory | Out-Null}
        $resultFilePath = Join-Path -Path $env:ContinuousTestResultPath -ChildPath $continuousTestResult_File
        #Write-Host "continuous test result path :- " $resultFilePath
        Set-Content -Path $resultFilePath -Value $FinalResult

    }
    #>

}
catch {
   Write-Host "PS_ERROR_DESC= Runtime error occurred in while polling continuous test result. Exception: $($_.Exception.Message)"
   Exit 1
}