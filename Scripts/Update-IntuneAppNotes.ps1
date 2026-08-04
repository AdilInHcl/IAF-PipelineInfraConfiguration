<#
.SYNOPSIS
    Updates the Intune App Notes with the AppID and Version

.DESCRIPTION
    This Script will update the APPID and Version in the notes section of the App.json

.NOTES
    FileName: Update-IntuneAppNotes.ps1
    Author: Daniyal Ahmad
    Version: 1.0
#>
#Update the APPID in Invoke-AppDeployToolKit.ps1
function Update-DeployKitInvokeAppID{
    param(
        $AppID,
        $AppFolder
    )
    $AppID
    $AppFolder

    $fileName = "Invoke-AppDeployToolkit.ps1"
    $AppDeployKitBaseFolder = Join-Path -Path $appsRootPath -ChildPath $AppFolder
    $AppDeployKitFile = Join-Path -Path $AppDeployKitBaseFolder -ChildPath $fileName

    try{
        (Get-Content -Path $AppDeployKitFile) -replace '###APPID###', $AppID | Set-Content $AppDeployKitFile -Force
        return $true
    }
    catch{
        return $false
    }
    
}


$appsdownloadedList = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -Childpath "AppsPrepareList.json"
$appIdFile = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -Childpath "AppId.json"
$appsRootPath  = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "Apps"
$applistjson = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath "appList.json"

try {
    $appdownloadedcontent = Get-Content -Path $appsdownloadedList | ConvertFrom-Json
    $appidjsoncontent = (Get-Content -Path $appIdFile | ConvertFrom-Json).Apps
    $applistjsoncontent = (Get-Content -Path $applistjson | ConvertFrom-Json).Apps
    
    Write-Host "Updating the notes section in App.Json for each app"
    foreach($app in $appdownloadedcontent){

        # Create the App.Josn Path for each App
        Write-Host "[$($app.IntuneAppName)]"
        $AppJsonPath = Join-Path -Path (Join-Path $appsRootPath -ChildPath $app.AppFolderName) -ChildPath "App.Json"
        $AppID = ($appidjsoncontent | Where-Object {$_.IntuneAppName -eq $app.IntuneAppName}).AppId 

        $AppJsoncontent = Get-Content -Path $AppJsonPath | ConvertFrom-Json
        $AppNotes= $AppJsoncontent.Information.Notes

        # Update Intune App Notes for AppID
        $AppNotes = $AppNotes -replace "(?i)<AppID>", $AppID

        # Update Intune App Notes for Version
        $AppNotes = $AppNotes -replace "(?i)<Version>", $app.AppSetupVersion

        # Add a TestFlag incase of test onboarding:
        if($env:PIPELINE_TYPE -eq "TEST"){
            $AppNotes += "`r`nTestApp: Yes"
        }

        #Update the App.Json with notes containing AppID
        $AppJsoncontent.Information.Notes = $AppNotes
        $AppJsoncontent = $AppJsoncontent | ConvertTo-Json -Depth 10
        Out-File -InputObject $AppJsoncontent -FilePath $AppJsonPath
        Write-Host "UPDATED NOTES - AppID: $AppID and Version: $($app.AppSetupVersion)"

        #Update the Invoke
        $AppFolder = ($applistjsoncontent | Where-Object {$_.IntuneAppName -eq $app.IntuneAppName}).AppFoldername
        $DeployKitUpdatestatus = Update-DeployKitInvokeAppID -AppID $AppID -AppFolder $AppFolder

        if ($DeployKitUpdatestatus){
            Write-Host "UPDATED DEPLOYMENT KIT - AppID: $AppID"
        }
        else{
            Write-Host "Failed to update the Deployment Kit."
        }

    }    
}
catch{
    Write-Output "PS_ERROR_DESC= [$($app.IntuneAppName)] - $_"
    
}