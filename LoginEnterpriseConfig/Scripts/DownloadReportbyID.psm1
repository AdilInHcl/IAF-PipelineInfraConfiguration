function DownloadTestReportbyId {
    param(
        [parameter(Mandatory = $true)]
        [string]$APIURL ,

        [parameter(Mandatory = $true)]
        [string]$authToken ,
 
        [parameter(Mandatory = $true)]
        [string]$testRunId,
 
        [parameter(Mandatory = $true)]
        [string]$FamilyID,
 
        [parameter(Mandatory = $true)]
        [string]$IntuneAppName,

        [parameter(Mandatory = $true)]
        [string]$AppId,
 
        [parameter(Mandatory = $true)]
        [string]$AppSetupVersion
 
    )
    
   
    $outputPath = "$env:WORKSPACE\LoginEnterpriseConfig\LEReports\"

    #this will come from jenkins pipeline
    $headers = @{
        Authorization = "Bearer $authToken"
    }
    try {
        
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        $ReportFileName = $AppId +"_"+ $FamilyID +"_"+ $IntuneAppName +"_"+ $AppSetupVersion +"_"+ $currentDateTime + "_($testRunId).pdf"
        $stageResult = "LEAPILogs\$ReportFileName"
        Write-Host "Test Report download directory with in pipeline :  $env:BUILD_ARTIFACTSTAGINGDIRECTORY"
        Write-Host "child path with file name :  $stageResult"
        $ReportFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $stageResult
        Invoke-RestMethod -Uri $APIURL -Method Get -Headers $headers -OutFile $ReportFilePath
        Write-Host "Downloaded item with ID $testRunId to $ReportFilePath"
        return $ReportFilePath
    }
    catch {
 
        # Write-Host "An error occurred while calling the LE API to download smoke test report"
        # Write-Host $_.Exception.Message
        Write-Output "PS_ERROR_DESC= An error occurred while calling the API to download smoke test report in DownloadReportbyID.psm1 script: $_"
        exit 1 
    }
}

 
