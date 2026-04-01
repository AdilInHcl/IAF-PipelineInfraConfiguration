[CmdletBinding(SupportsShouldProcess = $true)]
param (

  [parameter(Mandatory = $false)]

  [int]$LE_Test_Re_Run_MaxLimit,
 
  [parameter(Mandatory = $false)]

  [int]$LE_Test__CurrentRun
)
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1"
function CheckStatus{
     param(
        [int]$totalCount,
        [int]$successCount
    )
    $status = $false
    if(($successCount -gt 0) -and  ($totalCount -gt 0))
     {
       if($successCount -eq $totalCount)  
               { $status = $false}
         else { $status = $true}
     }
     else { $status = $true }
   return $status
}
$ApiBaseUrl = $env:LE_API_Base_Url
Write-Host "Apibase url" $ApiBaseUrl  
$AuthTokenWithConfigAccess = $env:LE_Config_Token
Write-Host "Token" $AuthTokenWithConfigAccess  
$AuthTokenWithReadAccess = $env:LE_Read_Token
Write-Host "Token" $AuthTokenWithReadAccess  

try {

   Write-Host "Max Limit : " $LE_Test_Re_Run_MaxLimit,
   Write-Host "current Run Count : " $LE_Test__CurrentRun
    # $env:LETestSuiteJsonFile is input file for this stage, we will update the testsuiteId in this file only
    # which is created as output of test suite creation pipeline, 
    # reading create testsuite stage result[output] file, which is saved outside of the pipeline build path  
    $latestJsonFile = $env:LETestSuiteJsonFile
    Write-Host "Json file : $latestJsonFile" 
    $jsonData = Get-Content -Path $latestJsonFile -Raw
    #Write-Host "Test Suite Detail : " $jsonData
    $jsonObject = $jsonData | ConvertFrom-Json
    $prevTestRunResultObject =$null
   if($LE_Test__CurrentRun -gt 1)
   {
      $prev= $LE_Test__CurrentRun-1
      # reading TestRun stage result from the file  
      $lastRunResultJsonFile = "LEAPILogs\TestRun_StatusResult_${prev}.json"  
      $lastRunTestResultJsonPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $lastRunResultJsonFile
      $pre_Run_Result_Data = Get-Content -Path $lastRunTestResultJsonPath -Raw
      #Write-Host "Re Run data for Test Run Result Json file path" $JsonFilePath
      #Write-Host $NewJson_Data
      $prevTestRunResultObject = $pre_Run_Result_Data | ConvertFrom-Json
      
      #Write-Host "New Json Object " $New_JsonObject.Apps | ConvertTo-Json -Depth 7
    }
    
    foreach ($currentItem in $jsonObject.Apps) {
        
        $TestSuiteId = $currentItem.AppTestSuiteId
        $APIURL = $APIBaseURL + "tests/" + $TestSuiteId + "/start"
        $re_Run= $true
        if($LE_Test__CurrentRun -gt 1)
        {  
           #$New_JsonObject.Apps where | Where-Object { $_.TestResult -eq "successful" -and $_.AppTestSuiteId -eq $TestSuiteId}
           $currentTestRun = $prevTestRunResultObject.Apps | Where-Object { $_.AppTestSuiteId -eq $TestSuiteId}
           $TestResult = $currentTestRun.TestResult
           $AppFailureResults = $currentTestRun.AppFailureResults
           $totalCount = [int]$AppFailureResults.totalCount
           $successCount = [int]$AppFailureResults.successCount
           $re_Run = CheckStatus -totalCount $totalCount -successCount $successCount
           #Write-Host "checked status for re-run $re_Run"
           if ($currentTestRun.OverAllResult -eq "Passed") { $re_Run = $false }
           else {  $re_Run = $true }
           Write-Host "checked status for re-run before execution:- $re_Run"
        }
        # code to force the re-run to the test even if it is passed, for testing perpuse to see if reboot logic is working on or not
        #$re_Run= $true
        if($re_Run)
        {
          $TestRun = ExecuteTestSuiteWithSuiteID -APIURL $APIURL -authToken $AuthTokenWithConfigAccess
          Write-Host $TestRun
          $TestRunId = $TestRun | ConvertFrom-Json
          $currentItem.AppTestSuiteRunId = $TestRunId.id
        }
    }
   
    $stageResult = $jsonObject.Apps
    #Write-Host $stageResult | ConvertTo-Json -Depth 7
    $FinalResult = $jsonObject | ConvertTo-Json -Depth 10
    #Write-Host "Execution Result :-"
    #Write-Host $FinalResult
    # save the stage result with updated TestRunId in same stage result json file
    Set-Content -Path $latestJsonFile -Value $FinalResult
}

catch [System.Net.WebException] {

    #Write-Error "Network error occurred: $($_.Exception.Message)"
    #throw 
    Write-Output "PS_ERROR_DESC= Runtime error occurred in ExecuteTestSuite_Re_Run.ps1 script: $_"
    exit 1
    
}

catch [System.Management.Automation.RuntimeException] {

    # Write-Error "Runtime error occurred: $($_.Exception.Message)"
    # throw 
   Write-Output "PS_ERROR_DESC= Runtime error occurred in ExecuteTestSuite_Re_Run.ps1 script: $_"
   exit 1
}

catch {

    #Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    #throw 
    Write-Output "PS_ERROR_DESC= An unexpected error occurred in ExecuteTestSuite_Re_Run.ps1 script: $_"
    exit 1
}
