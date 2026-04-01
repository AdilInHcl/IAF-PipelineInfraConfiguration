<#
.SYNOPSIS
This script connects to Microsoft Graph and assigns the apps to the respective AO or IAT test groups based on the flags in the catalogue for IAT_Testing = 'Yes'

.DESCRIPTION
This script connects to Microsoft Graph and assigns the apps to the respective AO or IAT test groups based on the flags in the catalogue for IAT_Testing = 'Yes'

.NOTES
    FileName:    Set-AppIATAO.ps1
    Author:      Daniyal Ahmad/ Adil Ansari
    Created:     2026-03-11

#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$username = $env:APP_CATALOGUE_USERNAME,
    [string]$password = $env:APP_CATALOGUE_SECRET,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$clientId,

    [ValidateNotNullOrEmpty()]
    [string]$clientSecret = $env:CLIENT_SECRET
)
#Returns the Access Token for the Catalogue Sharepoint Access
function Get-CatlogueAccessToken{
    param(
    [string]$username,
    [string]$password
    )
    $body = @{
        username = $username
        password = $password
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Method Post `
        -Uri "$($env:APP_CATALOGUE_BASE_URL)/auth/login" `
        -Headers @{
            "accept" = "application/json"
            "Content-Type" = "application/json"
        } `
        -Body $body

    $access_token = $response.access_token
    return $access_token
}
#IAT Testing for IAF
function Get-IATAppsInfo{
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$AppID,
        [Parameter(Mandatory = $false)]
        [string]$Fields
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"        
    }

    #Set the URI as per the input fields
    #$($env:APP_CATALOGUE_BASE_URL)/applications/3243?fields=IAT_Testing
    if($null -eq $Fields){
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/$($AppID)"
    }else{
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/$($AppID)?fields=$($Fields)"
    }
    
    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers

    return $response
}
#Return IAT Userlist
function Get-IATUser{
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$AppID,
        [Parameter(Mandatory = $false)]
        [string]$Fields
    )

    $headers = @{
        "accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"        
    }

    #Set the URI as per the input fields
    #$($env:APP_CATALOGUE_BASE_URL)/applications/3243?fields=IAT_Testers_details
    if($null -eq $Fields){
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/AppID/$($AppID)"
    }else{
    $uri = "$($env:APP_CATALOGUE_BASE_URL)/applications/$($AppID)?fields=$($Fields)"
    }
    
    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers

    return $response
}
#Fetch the App Test GRoup Info
function Fetch-AppTestGroupInfo{
    param(
        [string]$IntuneAppName,
        [string]$Test
    )
    #Applist.json to fetch the app folder name
    $APPLISTJSONFILENAME = "appList.json"
    $APPLISTJSONFILEPATH = Join-Path -Path $env:BUILD_SOURCESDIRECTORY -ChildPath $APPLISTJSONFILENAME
    $APPLISTJSONFILECONTENT = (Get-Content -Path $APPLISTJSONFILEPATH | ConvertFrom-Json).Apps

    Write-Host "Fetching the [$Test] Testing group details for [App: $($IntuneAppName)]"
    $AppFoldername = ($APPLISTJSONFILECONTENT | Where-Object {$_.IntuneAppName -eq $IntuneAppName}).AppFolderName

    #Declare App.json path for the Intune AppName
    $AppJsonPath = Join-path -Path ( Join-Path -Path $env:BUILD_SOURCESDIRECTORY -child "Apps") -ChildPath ( Join-Path -Path $AppFoldername -child "App.json")
    
    #Check if the App.Json exists
    if(-not(Test-Path $AppJsonPath)){
        Write-Host "App.json is not present on $AppJsonPath. Skipping App [$($IntuneAppName)]"
        return "Failed"
    }

    #################### Fetch the Group INFO ####################
    $AppJsonContent = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json
    $AppAssignment = $AppJsonContent.Assignment | Where-Object {$_.Type -eq "$($Test)Group"}

    if(-not($AppAssignment.GroupID)){
        Write-Host "$Test Group Info not available in Apps/$($AppFoldername)/App.json"
        return "Failed"
    }
    Write-Host "$Test Group Name: [$($AppAssignment.GroupName)] GroupID: [$($AppAssignment.GroupID)]"
    $GroupInfo =  [PSCustomObject]@{
            GroupMode = $AppAssignment.GroupMode
            ID = $null
            GroupID = $AppAssignment.GroupID
            Intent = $AppAssignment.Intent
            ErrorAction = "Stop"
            FilterName = $AppAssignment.FilterName
            FilterMode= $AppAssignment.FilterMode
            Notification = "showAll"
         }

    return $GroupInfo
}
# To associate VM in Device Group 
function Set-IntuneAppGroupAssignment {
    param(
        [Parameter(Mandatory)]
        $App,
        $AssignmentItem
    )

    Write-Output "Preparing assignment parameters for group with ID: '$($AssignmentItem.GroupID)'"

    # Base parameter set
    $AppAssignmentArgs = @{
        ID      = $AssignmentItem.ID
        GroupID = $AssignmentItem.GroupID
        Intent  = $AssignmentItem.Intent
        FilterName =$AssignmentItem.FilterName
        FilterMode =$AssignmentItem.FilterMode
        Notification =$AssignmentItem.Notification
        ErrorAction = 'Stop'
    }

    # Include / Exclude
    switch ($AssignmentItem.GroupMode.ToLower()) {
        "include" { $AppAssignmentArgs.Include = $true }
        "exclude" { $AppAssignmentArgs.Exclude = $true }
        default {
            throw "Invalid GroupMode '$($AssignmentItem.GroupMode)'. Must be 'include' or 'exclude'."
        }
    }

    # EXECUTE ASSIGNMENT
    try {
        Write-Host "Adding '$($AssignmentItem.GroupMode)' assignment with intent '$($AssignmentItem.Intent)' for group '$($AssignmentItem.GroupID)'"

        $appresponse = Add-IntuneWin32AppAssignmentGroup @AppAssignmentArgs

        if ($appresponse.'@odata.context'){
            return @{
                Status = "Success"
                App    = $App
                Group  = $AssignmentItem.GroupID
            }
        }else{
               return @{
                Status = "Failed"
                App    = $App
                Group  = $AssignmentItem.GroupID
            } 
        }
    }
    catch {
        Write-Host "Failed to assign app '$($App.IntuneAppName)' to group '$($AssignmentItem.GroupID)': $($_.Exception.Message)"

        return @{
            Status = "Failed"
            App    = $App
            Group  = $AssignmentItem.GroupID
            Error  = $_.Exception.Message
        }
    }
}

########  Connect MS Intune Graph for App assignation to group #######
$AuthToken = Connect-MSIntuneGraph -TenantID $tenantId -ClientID $clientId -ClientSecret $clientSecret -ErrorAction "Stop"
######################################################################

# Declare Paths for the input file name LEVMCreationData file in binaries folder of IAF
$LEVMCreationJsonPath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $env:Input_File_name

#AppsAssignList.json to fetch the App Object IDs
$APPASSIGNJSONFILENAME = "AppsAssignList.json"
$APPASSIGNFILEPATH = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $APPASSIGNJSONFILENAME
$APPASSIGNFILECONTENT = Get-Content -Path $APPASSIGNFILEPATH | ConvertFrom-Json

try{
    # Check if the JSON file exists
    if (Test-Path $LEVMCreationJsonPath) {

        # Load JSON data (do not overwrite the path variable)
        Write-Host "Reading apps from: $LEVMCreationJsonPath"
        $json = Get-Content -Raw -Path $LEVMCreationJsonPath | ConvertFrom-Json
    
        # Initialize a list to store IntuneAppName and Family I'd
        $AppIDJson = @()

        # Iterate through the Apps array in the JSON
        foreach ($app in $json.Apps) {
            $AppInfo = [PSCustomObject]@{
                IntuneAppName = $app.IntuneAppName
                AppID      = $app.AppID
                CrowdstrikeScan = $app.CrowdstrikeScan
                QualysScan = $app.QualysScan
                WDACScan = $app.WDACScan
            }
            # Append the new object (fix: was appending the array to itself)
            $AppIDJson += $AppInfo
        }

    }
    else {
        Write-Output "PS_ERROR_DESC= JSON file at path '$LEVMCreationJsonPath' does not exist."
        exit 1
    }

    # Genrate Access Token for the Catalogue Access
    $Token = Get-CatlogueAccessToken -username $username -password $password

    #Columns inside the App Catalogue for IAT etsting flag and users
    $IATInfoFields = "IAT_Testing"  
    $IATUserFields = "IAT_Testers_details"

    #List to sotre the Apps corresponding to there testing required
    $AppsTestRequiredList = @()
    $failedApps = @()

    #Fetch the test required for each application based on the Catalogue.
    foreach ($App in $AppIDJson) {
        $AppID = $App.AppID
        $appName  = $App.IntuneAppName
        Write-Host "##### [  Checking Testing requirement for: $appName (AppID: $AppID) ] #####"

        Write-Host "Fetching the Scan Status for [Qualys, Crowdstrike, Wdac]"
        if ($App.CrowdstrikeScan -ne "Pass" -or $App.QualysScan -ne "Pass" -or $App.WDACScan -ne "Pass") {
            Write-Host "The Scans have not been completed successfully for $appName [$AppID]."  
            Write-Host "Skipping App assignation to group."  
            continue
        }

        Write-Host "All 3 Scans Completed Successfully"

        ################## Check if IAT test required for Apps #############
        $IATRequired = Get-IATAppsInfo -AccessToken $token -AppID $AppID -Fields $IATInfoFields

        if ($IATRequired.IAT_Testing -eq "Yes") {

            ############## Fetch the IAT test users required #################
            $UserInfo = Get-IATUser -AccessToken $token -AppID $AppID -Fields $IATUserFields
            $TestingRequired = "IAT"
            Write-Host "Required testing: IAT | User: [$($UserInfo.IAT_Testers_details)]"

        }
        else{
            #Set the App for AO testing
            $UserInfo = $null
            $TestingRequired = "AOT"
            Write-Host "Required testing: AO Testing"
        }

        ############### Fetch the Group Info ###################
        $Group = Fetch-AppTestGroupInfo -IntuneAppName $appName -Test $TestingRequired

        ##################### Fetch the APP OBJECT ID from AppsAssignList.json ####################
        $AppObjectId = ($APPASSIGNFILECONTENT | Where-Object {$_.IntuneAppName -eq $appName}).IntuneAppObjectID

        if(-not($AppObjectId)){
            Write-Output "App Object ID is missing for $($appName)"
            $failedApps += $entry
            continue
        }

        Write-Host "App ObjectID: [$AppObjectId]"
        $Group.ID = $AppObjectId

        ##################### Adding the App to the IAT/AO Test group ####################
        $response = Set-IntuneAppGroupAssignment -App $appName -AssignmentItem $Group

        if ($response.Status -eq "Failed" -or $update_response -eq "Failed") {
            $failedApps += $App
            continue
        }

        #Set testing required flag
        $AppTestRequiredInfo = [PSCustomObject]@{
                IntuneAppName      = $appName
                AppID              = $AppID
                TestingRequired    = $TestingRequired
                Users              = $UserInfo.IAT_Testers_details
                GroupID            = $Group.GroupID
            }
        $AppsTestRequiredList += $AppTestRequiredInfo
        Write-Host ""
    }

    ################## validate and create a json for IAT VM creation ####################

    $IATResults = $AppsTestRequiredList | Where-Object {$_.TestingRequired -eq 'IAT'}
    if (@($IATResults).Count -gt 0){
        # Wrap in top-level structure
        $finalOutputObject = [PSCustomObject]@{
            Apps = $IATResults
        }

        # Save the result
        $OutFileName = "APP_IAT.json"
        $OutputFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $OutFileName

        Write-Host "APP_IAT.json generated successfully at:  $OutputFilePath"
        $finalOutputObject | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputFilePath -Encoding UTF8
    }
    else{
        Write-Output "No Apps detected for IAT Testing. !!"
    }

}
catch{
     Write-Output "PS_ERROR_DESC= $_"
     exit 1
}