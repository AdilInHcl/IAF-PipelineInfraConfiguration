function SaveApplicationScript {
    param (
        [parameter(Mandatory = $true)]
        [string]$ApplicationID,

        [parameter(Mandatory = $false)]
        [string]$FamilyID,

        [parameter(Mandatory = $false)]
        [string]$IntuneAppName,

        [parameter(Mandatory = $false)]
        [string]$AppId,

        [parameter(Mandatory = $false)]
        [string]$AppSetupVersion

    )
    Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1"
    try {
        $ApiBaseUrl = $env:LE_API_Base_Url
        # Write-Host "Apibase url" $ApiBaseUrl  
        $AuthTokenWithReadAccess = $env:LE_Read_Token
        # Write-Host "Auth Token With Read-Access" $AuthTokenWithReadAccess

        $applicationId = $ApplicationID 
        $Application_FullURL = $ApiBaseUrl + "applications/" + $applicationId + "?include=all"
        $Application = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $Application_FullURL -authToken $AuthTokenWithReadAccess
        $ApplicationDetails = $Application | ConvertFrom-Json


        #Prepare script file Name and File Path 
        #$ApplicationScriptName = $ApplicationDetails.Name
        #$TestScriptFileName =   $ApplicationScriptName +"_"+ $AppSetupVersion + ".cs"
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        $TestScriptFileName = $AppId +"_"+ $FamilyID +"_"+ $IntuneAppName +"_"+ $AppSetupVersion +"_"+ $currentDateTime + "_"+ $step.ApplicationId
        
        $TestScriptFileSubPath = "LEAPILogs\$TestScriptFileName.cs"
        $TestScriptFile_FullPath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $TestScriptFileSubPath
        
        #full path coming in param
        $csFilePath = $TestScriptFile_FullPath   
        # Write the C# code content to the .cs file
        $ApplicationDetails.script | Out-File -FilePath $csFilePath -Encoding UTF8
        return $csFilePath
    }
    catch {
    # Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    # throw 
    Write-Output "PS_ERROR_DESC= An unexpected error occurred in Save_Application_TestScript.psm1 script: $_"
    exit 1
}
}
