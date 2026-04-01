Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1" -Force
Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\AppCatalogueManager.psm1" -Force
function CreateApplicationwithScript {
    param(
        [parameter(Mandatory = $true)]
        [string]$IntuneAppName,
        [parameter(Mandatory = $true)]
        [string]$ShortcutPath,
        [parameter(Mandatory = $true)]
        [string]$ProcessName,
        [parameter(Mandatory = $true)]
        [string]$PackageName,
        [parameter(Mandatory = $true)]
        [string]$AppId,
        [parameter(Mandatory = $true)]
        [string]$AppSetupVersion
    )
    # Add System.Web for URL encoding
    Add-Type -AssemblyName System.Web
    # ============================================================
    # TEMPLATE SCRIPT PREPARATION
    # ============================================================
    $CsFilePath = "$env:WORKSPACE\LoginEnterpriseConfig\Template\Application_Install_Version_Lanuch_Timer_Close.cs"
    $ApiBaseUrl = $env:LE_API_Base_Url
    $AuthTokenWithConfigAccess = $env:LE_Config_Token
    $AuthTokenWithReadAccess   = $env:LE_Read_Token

    $csContent = Get-Content -Path $CsFilePath -Raw

    if (-not $ShortcutPath -or $ShortcutPath -eq '' -or $ShortcutPath -eq 'NA') {
        $ShortcutPath = "No_shortcut_Available"
    }

    $placeholders = @{
        "{TargetPath}"          = $ShortcutPath
        "{App_ExePath}"         = $ShortcutPath
        "{process_Name}"        = $ProcessName
        "{intune_Package_Name}" = $PackageName
        "{intune_App_Version}"  = $AppSetupVersion
        "{intune_App_Name}"     = $IntuneAppName
    }

    foreach ($placeholder in $placeholders.Keys) {
        $csContent = $csContent -replace $placeholder, $placeholders[$placeholder]
    }

    Write-Host "Test Script created for $IntuneAppName"
    
    # ============================================================
    # ROLE LOOKUP
    # ============================================================
    $RolesURL = $ApiBaseUrl + "auth/roles"
    $RolesAPI_Response = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $RolesURL -authToken $AuthTokenWithReadAccess
    $ListOfRoles = $RolesAPI_Response | ConvertFrom-Json
    $role = $ListOfRoles.items | Where-Object { $_.name -eq $env:LE_UserRole }

        # ============================================================
    # APPLICATION NAME GENERATION
    # ============================================================
    # Generate unique app name with timestamp and random component
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $random = Get-Random -Minimum 1000 -Maximum 9999
    $baseAppName = Final-AppName -IntuneAppName $IntuneAppName -ProcessName $ProcessName
    $AppName = "T_51_ST_${baseAppName}_${timestamp}_${random}"
    
    # Ensure name doesn't exceed 64 characters
    if ($AppName.Length -gt 64) {
        $AppName = $AppName.Substring(0, 64)
    }

    # ============================================================
    # REQUEST BODY
    # ============================================================
    $requestBody = [PSCustomObject]@{
        commandLine      = $ShortcutPath
        workingDirectory = $ShortcutPath
        type             = "WindowsApp"
        name             = $AppName
        description      = "Transformation Project (T5.1) Smoke Test for $IntuneAppName for shortcut $ProcessName having version $AppSetupVersion for AppId: $AppId"
        takeScreenshots  = $true
        roles            = @($role.id)
        scriptContent    = $csContent
    }

    $jsonBody = $requestBody | ConvertTo-Json
    # Write-Host "Create Application Request-Body for $IntuneAppName"
    # Write-Host $jsonBody

    $headers = @{
        Authorization = "Bearer " + $AuthTokenWithConfigAccess
        ContentType   = "application/json"
    }
    # ============================================================
    # API CALL
    # ============================================================
    try {
        $complete_APIURL = $ApiBaseUrl + "applications"
        $createAppAPIResponse = Invoke-RestMethod -Uri $complete_APIURL -Method Post -Headers $headers -Body $jsonBody -ContentType "application/json"

        Write-Host "Application created successfully. ID: $($createAppAPIResponse.id)"

        return $createAppAPIResponse.id
    }
        catch {
        $errorMessage = $_.Exception.Message
       
        # For other errors, update App Catalogue and exit
        $Reason = "LE Smoke Test script creation failed"
        $username = $env:APP_CATALOGUE_USERNAME 
        $password = $env:APP_CATALOGUE_SECRET
        $catlogueToken = Get-CatalogueAccessToken -username $username -password $password
        AppCatalogueUpdate -AccessToken $catlogueToken -IntuneAppName $IntuneAppName -AppID $AppId -Reason $Reason -Comment $Comment = $errorMessage
        Write-Output "PS_ERROR_DESC= Error while Creating Application in CreateApplicationwithScript: $_"
        exit 1      
    }
}
function Get-CleanProcessName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return "" }

    # Remove .exe ending
    return ($Name -replace "\.exe$", "")
}
function Build-AppName {
    param(
        [string]$IntuneAppName,
        [string]$ProcessName,
        [string]$DateStamp
    )

    if ([string]::IsNullOrWhiteSpace($ProcessName)) {
        return "T_51_ST_{0}_{1}" -f $IntuneAppName, $DateStamp
    }
    else {
        return "T_51_ST_{0}_{1}_{2}" -f $IntuneAppName, $ProcessName, $DateStamp
    }
}
function Final-AppName {
    param(
        [string]$IntuneAppName,
        [string]$ProcessName,
        [string]$DateStamp,
        [int]$MaxLimit =60
    )
   try {
    
    # --- SANITIZE ProcessName ---

    # Normalize whitespace
    $ProcessName = ($ProcessName -replace '\s+', ' ').Trim()

    # Remove accidental duplication e.g. "abcd abcd"
    $tokens = $ProcessName.Split(" ")
    if ($tokens.Count -gt 1 -and ($tokens | Select-Object -Unique).Count -eq 1) {
        $ProcessName = $tokens[0]    # keep only first unique
    }

    # Remove .exe
    $ProcessName = Get-CleanProcessName -Name $ProcessName


    # Initial build
    $AppName = Build-AppName -IntuneAppName $IntuneAppName -ProcessName $ProcessName -DateStamp $DateStamp

    # ---- MAIN LENGTH CONTROL LOOP ----
    while ($AppName.Length -gt $MaxLimit) {

        # RULE 1 — If IntuneAppName equals ProcessName, drop ProcessName (dup)
        if ($IntuneAppName -eq $ProcessName) {
            $ProcessName = ""
            $AppName = Build-AppName -IntuneAppName $IntuneAppName -ProcessName $ProcessName -DateStamp $DateStamp
            continue
        }

        # RULE 2 — Trim the process name one character at a time
        if ($ProcessName.Length -gt 0) {
            $ProcessName = $ProcessName.Substring(0, $ProcessName.Length - 1)
            $AppName = Build-AppName -IntuneAppName $IntuneAppName -ProcessName $ProcessName -DateStamp $DateStamp
            continue
        }
        break
    }
      return $AppName
    }
   catch {
    Write-Output "PS_ERROR_DESC= Error in Final-AppName method in CreateApplication.psm1 script: $_"
    exit 1
   }
}

