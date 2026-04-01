function CreateAccountGroupWithMember {
    param(
        [parameter(Mandatory = $true)]
        [string]$IntuneAppName ,
        [parameter(Mandatory = $true)]
        [string]$AppId ,
        [parameter(Mandatory = $true)]
        [string]$TUAccount
    )
    
    Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\API_RequestFormat_Classes.ps1"
    Import-Module "$env:WORKSPACE\LoginEnterpriseConfig\Scripts\CommonMethodsClass.psm1"
   
    $ApiBaseUrl = $env:LE_API_Base_Url
    # Write-Host "Apibase url" $ApiBaseUrl  
    $AuthTokenWithConfigAccess = $env:LE_Config_Token
    # Write-Host "Token" $AuthTokenWithConfigAccess  
    $AuthTokenWithReadAccess = $env:LE_Read_Token
    # Write-Host "Token" $AuthTokenWithReadAccess
 
    try {
       
        $TUAccounts_FullURL = $ApiBaseUrl + "accounts?orderBy=username&direction=asc&count=100&filter=" + $TUAccount
 
        $Account_API_Response = GetPaginatedListOfItemsFromAPIWithAPIName -APIURL $TUAccounts_FullURL -authToken $AuthTokenWithReadAccess
 
        Write-Host "Account Detail for TU Account : $TUAccount"
        
        $ListOfAccounts = $Account_API_Response | ConvertFrom-Json
 
        $Account = $ListOfAccounts |  Select-Object -First 1    
 
        Write-Host $Account.items | ConvertTo-Json -Depth 10
        
        #Write-Host "Account ID" $Account.items.id
        $AccountID = $Account.items.id 
        Write-Host "Account ID for current TU Account is : " $AccountID
        
        if ($Account.items.enabled) {
            Write-Host "account is already in enabled state"
           
        }
 
        else {

           $jsonBody = $true | ConvertTo-Json
           $AccountID = $Account.items.id
           $PutMethodFullURL = $ApiBaseUrl + "accounts/" + $AccountID + "/enabled"
            # Write-Host "Enable Account API URL " $PutMethodFullURL
           $AccoutUpdateResponse = Call_PUTMethod -APIURL $PutMethodFullURL -authToken $LE_Config_Token -jsonBody $jsonBody
            Write-Host "Account enabled" $AccoutUpdateResponse
        }
        $headers = @{
            Authorization = "Bearer " + $AuthTokenWithConfigAccess
            ContentType   = "application/json"
        }
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        $accountGroup_RequestBody = [CreateAccountGroup]::new()
 
        $accountGroup_RequestBody.type = "Selection"
 
        $accountGroup_RequestBody.name = "T_51_ST_AccGrp_" + $IntuneAppName + "_"+ $currentDateTime
 
        $accountGroup_RequestBody.description = "T_51_Smoke Test(ST) AccountGroup for " + $IntuneAppName + " and AppId - $AppId"
 
        $accountGroup_RequestBody.memberIds = @($Account.items.id)
 
        $CreateAccountGroupURL = $ApiBaseUrl + "account-groups"
 
        $jsonBody = $accountGroup_RequestBody | ConvertTo-Json
 
        Write-Host "Request Body To Create Account Group"
        Write-Host $jsonBody

        $reateAccountGroupResponse = Invoke-RestMethod -Uri $CreateAccountGroupURL -Method Post -Headers $headers -Body $jsonBody -ContentType "application/json"
 
        Write-Host "account group is created.Account group detail is : " $reateAccountGroupResponse
        return $reateAccountGroupResponse.id
    }
 
    catch {
 
        Write-Host "An error occurred while calling the Create Application API:"
        Write-Host $_.Exception.Message
        $errorMessage = $_.Exception.Message
        $Reason = "LE Smoke Test script creation failed"
        $username = $env:APP_CATALOGUE_USERNAME 
        $password = $env:APP_CATALOGUE_SECRET
        $catlogueToken = Get-CatalogueAccessToken -username $username -password $password
        AppCatalogueUpdate -AccessToken $catlogueToken -IntuneAppName $IntuneAppName -AppID $AppId -Reason $Reason -Comment $Comment $errorMessage
        Write-Output "PS_ERROR_DESC= Error in while Creating account group in createAccountGroup.psm1 script: $_"
        exit 1 
    }
 
}
function Call_PUTMethod {
    param(
        [parameter(Mandatory = $true)]
        [string]$APIURL,
        [parameter(Mandatory = $true)]
        [string] $authToken, 
        [parameter(Mandatory = $true)]
        [string] $jsonBody
    )  
    $headers = @{
        Authorization = "Bearer $authToken"
    }

    try {
        Write-Host $APIURL
        Write-Host $jsonBody
        $response = Invoke-RestMethod -Uri $APIURL -Method Put -Headers $headers -Body $jsonBody -ContentType "application/json"
        # Convert the response to JSON and return
        return $response.statusDescription | ConvertTo-Json
    }
    
    catch {
        Write-Host "An unexpected error occurred: $($_.Exception.Message)"
        Write-Output "PS_ERROR_DESC= Error in Call_PUTMethod method in CommonMethodsClass.ps1 script: $_"
        exit 1
    }

}
 
