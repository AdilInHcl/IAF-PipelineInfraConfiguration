# Import required modules
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1" -Force

function GetEmailRecipients {
    param (
        [parameter(Mandatory = $true)]
        [string]$NotificationFor  
    )

    $EmailRecipientJson = "$($env:WORKSPACE)\configs\EmailRecipients.json"
    $emailJsonData = Get-Content -Path $EmailRecipientJson -Raw
    # Write-Host $jsonData
    $emailObject = $emailJsonData | ConvertFrom-Json 
    
    $objectDetails = $emailObject.PSObject.Properties | Where-Object { $_.Name -eq $NotificationFor } | Select-Object -ExpandProperty Value

    if ($objectDetails) {
        #Write-Host "Description: $($objectDetails.Description)"
        $recipientsDetail = $objectDetails | ConvertTo-Json -Depth 10
        return $recipientsDetail
    }
    else {
        #Write-Host "Object '$ObjectName' not found in the JSON data."
        return $null
    }
    
}

 function GetFileFromLocation{
param (
        [parameter(Mandatory = $true)]
        [string]$folderPath ,
        [parameter(Mandatory = $true)]
        [string]$regexPattern  
    )
   try {
        # Escape the regex pattern to handle special characters
        $escapedPattern = [regex]::Escape($regexPattern)
        #Get the file(s) matching the regex pattern and retrieve the full path
        $matchingFiles = Get-ChildItem -Path $folderPath | Where-Object { $_.Name -match $escapedPattern }
        # Sort the matching files by the length of their names to find the nearest match
        $nearestFile = $matchingFiles | Sort-Object { $_.Name.Length } | Select-Object -First 1

        # Output the full path of the nearest matching file
        if ($nearestFile) {
            #Write-Host "Nearest matching file found:"
            return $nearestFile.FullName
        } else {
            Write-Host "No matching files found."
            return ""
        }
    }
    catch {
        Write-Host "PS_ERROR_DESC= Runtime error occurred in GetFileFromLocation method, Error : $($_.Exception.Message)"
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
      Write-Output "PS_ERROR_DESC= Error in while reading AO e-mail for Application from applist json in Create_TestSuite_Steps.ps1 script: $_"
      #exit 1 
    }
        
}



