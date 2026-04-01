Import-Module "$env:WORKSPACE\PowerShell/FinalEmail-Content.psm1"
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppUpgradeDetection.psm1"

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
        #$IAF_AppListJsonFile = Join-Path $env:LESmokeTestVMCreation -ChildPath $env:Input_File_Name_fromVM_Creation
        $IAF_AppListJsonFile = Join-Path $IAF_BUILD_BINARIESDIRECTORY -ChildPath $vmCreationDataFileName
        $appListJsonObject = Get-Content -Path $IAF_AppListJsonFile | ConvertFrom-Json
        #Write-Host "VM Creation Data " 
        #Write-Host $appListJsonObject | ConvertTo-Json
        #smoke test result data
        
        #$WDACScanResult = $env:Input_File_Name_from_WDAC_Scan
        $WDACScanResult = "${env:JOB_NAME}_${env:BUILD_ID}_WDAC_Result_.json"
        $WDACScanResultFile= Join-Path -Path $env:WDACScanResultFolder -ChildPath $WDACScanResult
        
        $ContinuousTestResult_File = "${env:JOB_NAME}_${env:BUILD_ID}_ContinuousTestResult.json"
        
        $LESmokeTestResultFolder = Join-Path -Path $env:LEScanFolder -ChildPath $IAF_BUILD_TAG
        $SmokeTestResultFile =  Join-Path -Path $LESmokeTestResultFolder -ChildPath $env:LESmokeTestResultFile
        $smokeTestData = Get-Content -Path $SmokeTestResultFile | ConvertFrom-Json
        
        foreach ($app in $appListJsonObject.Apps) { 
        
          $AppName = $app.IntuneAppName
          $FamilyID = $app.FamilyID
          $AppID = $app.FamilyID
          $AppVersion = $app.AppSetupVersion
          $DeviceName = $app.DeviceName

          $CrowdstrikeScan = $app.CrowdstrikeScan    #":  "Completed",
          $QualysScan = $app.QualysScan   #":  "Failed",
          $WDACScan = $app.WDACScan     #":"Failed"
          $ContinuousTestResult = ""
          $Attachement = @()
          $TOEmails = @()
          $CC_Emails = @()
          $currentAppSmokeTestResult =  $smokeTestData.Apps | Where-Object { $_.IntuneAppName -eq $app.IntuneAppName } 
          $SmokeTestResult = $currentAppSmokeTestResult | ConvertTo-Json -Depth 10
          #Write-Host "Current App Smoke Test Result " 
          #Write-Host $SmokeTestResult
          $smokeTestRows = Prepare_Rows_For_SmokeTest -SmokeTestResult $SmokeTestResult
          #Write-Host "Smoke Test Result Rows"
          #Write-Host $smokeTestRows

          $EmailRecipients_Success = GetEmailRecipients -NotificationFor "IAFPipelineSuccessNotification" | ConvertFrom-Json
          #Write-Host "Success Email Recipients" $EmailRecipients_Success.To
          $EmailRecipients_Failure = GetEmailRecipients -NotificationFor "IAFPipelineFailureNotification" | ConvertFrom-Json
          
          $WDACResultRows = ""
          if($currentAppSmokeTestResult.OverAllResult -eq "Passed"){
             $TOEmails = @($currentAppSmokeTestResult.AOEmails -split ",") 
             $CC_Emails = @($EmailRecipients_Success.CC -split ",") 
             $Attachement += $currentAppSmokeTestResult.TestReportPath
            #Write-Host "App Short-cuts with Test Result for email body" 

            # get WDAC signing result
            $WDACResult = Get-Content -Path $WDACScanResultFile | ConvertFrom-Json
            
            $currentAppWDACResult =  $WDACResult.Apps | Where-Object { $_.IntuneAppName -eq $app.IntuneAppName } 
            $currentAppWDACResultJson = $currentAppWDACResult | ConvertTo-Json -Depth 10 
            $WDACResult = $currentAppWDACResultJson  | ConvertFrom-Json 
            $WDACResultRows = Prepare_Rows_For_WDAC -IntuneAppName $AppName -AppID $AppID -FamilyID $FamilyID -AppVersion $AppVersion -WDACScanResult $WDACResult.WDACScanResult -Description $WDACResult.Description -WDACScanReport $WDACResult.WDACScanReport
            
          }
          else{
            $TOEmails = @($EmailRecipients_Failure.To -split ",") 
            $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
            $CrowdstrikeScan = "Skipped"
            $QualysScan = "Skipped"
            $WDACScan = "Skipped"
            $WDACResultRows = Prepare_Rows_For_WDAC -IntuneAppName $AppName -AppID $AppID -FamilyID $FamilyID -AppVersion $AppVersion -WDACScanResult $WDACScan -Description "NA" -WDACScanReport "NA"
          }
          
            if($WDACScan -eq  "Failed")
            {
              $CrowdstrikeScan = "Skipped"
              $QualysScan = "Skipped"
              $Crowdstrike_Description = "NA"
              $TOEmails = @($EmailRecipients_Failure.To -split ",") 
              $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
            }
            if($CrowdstrikeScan -eq "Failed")
            {
                 $crowdstrikeScanfile = GetFileFromLocation -folderPath "${env:CrowdstrikeScanResult}Results\" -regexPattern  "${DeviceName}-${AppName}-"
                 Write-Host "qualys scan File - " $crowdstrikeScanfile
                 $Attachement += $crowdstrikeScanfile
                 $Crowdstrike_Description = "Malware file found, refer to attached report for more details"
                 $QualysScan = "Skipped"
                 $Qualys_Description = "NA"
                 $TOEmails = @($EmailRecipients_Failure.To -split ",") 
                 $CC_Emails = @($EmailRecipients_Failure.CC -split ",") 
            }
            
            if($QualysScan -eq "Failed")
            {
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
              $ContinuousTestResultFile = Join-Path -Path $env:ContinuousTestResultPath -ChildPath $ContinuousTestResult_File
              Write-Host "continuous test result file :- $ContinuousTestResultFile "
              $ContinuousTestResultData = Get-Content -Path $ContinuousTestResultFile | ConvertFrom-Json

              $CurrentAppContinuousTestResult = $ContinuousTestResultData.Apps | Where-Object { $_.IntuneAppName -eq $AppName }
              if($CurrentAppContinuousTestResult)
              {
                  $continuousTestPassed = $CurrentAppContinuousTestResult.TestResult | Where-Object { $_.Upgrade -eq "Pass" } | Select-Object -First 1
                  if($continuousTestPassed){
                      $ContinuousTestResult ="Pass"
                  }
                  else { 
                   $skipped = $CurrentAppContinuousTestResult.TestResult | Where-Object { $_.Upgrade -eq "Skipped" } | Select-Object -First 1
                    if($skipped)
                    {
                      $ContinuousTestResult = $skipped.Upgrade
                      $ContinuousTestResultDiscription = $skipped.Description
                    }
                    else {
                       $failed = $CurrentAppContinuousTestResult.TestResult | Where-Object { $_.Upgrade -eq "Failed" } | Select-Object -First 1
                       $ContinuousTestResult = $failed.Upgrade
                       $ContinuousTestResultDiscription = $failed.Description
                    }
                  }
              }
              else { 
                $ContinuousTestResult ="Skipped"
                $ContinuousTestResultDiscription = "This App '$AppName' is not included in any continuous test yet."
              }
              
          }
            $ContinuousTestResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $CrowdstrikeScan -Description $ContinuousTestResultDiscription -ScanType "Application Contol Allowlist Check & App Upgrade Check"
            $CrowdstrikeResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $CrowdstrikeScan -Description $Crowdstrike_Description -ScanType "Crowdstrike Scan"
            $QualysScanResult = Prepare_Rows_For_QualysCrowdstrikeContinuousTest -AppName $AppName -AppID $AppID -AppSetupVersion $AppVersion -Status $QualysScan -Description $Qualys_Description -ScanType "Qualys Scan"
          
          $emailBody = Prepare_EmailBody_TableContent -AppName $AppName -AppID $AppID -AppVersion $AppVersion -SmokeTestResult $smokeTestRows -WDACResult $WDACResultRows -QualysScanResult $QualysScanResult -CrowdstrikeResult $CrowdstrikeResult -ContinuousTestResult $ContinuousTestResult
          $Subject = "$AppID :  $AppName - Application Onboarding Automated Test results & reports"
          #$Subject = "Smoke Test and Continuous Test Result along with Security Scan Result for $AppName "
          SendTestResultNotification -Attachment $Attachement  -Subject $Subject -emailBody $emailBody -To $TOEmails -Cc $CC_Emails
        }
    }
    catch {
        # Fallback to original body if template processing fails
        Write-Output "PS_ERROR_DESC= Runtime error occurred in Sending email notification. Exception: $($_.Exception.Message)"
        Exit 1
    }



