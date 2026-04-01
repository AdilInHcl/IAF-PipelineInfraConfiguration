function GetPaginatedListOfItemsFromAPIWithAPIName {
    param(
        [parameter(Mandatory = $true)]
        [string]$APIURL,
        [parameter(Mandatory = $true)]
        [string] $authToken
    )
    $headers = @{
        Authorization = "Bearer $authToken"
    }
 
    try {
           
        $response = Invoke-RestMethod -Uri $APIURL -Method Get -Headers $headers
        # Convert the response to JSON and return
        return $response | ConvertTo-Json
    }
    
    catch {
        Write-Host "An unexpected error occurred: $($_.Exception.Message)"
        Write-Output "PS_ERROR_DESC= Error in GetPaginatedListOfItemsFromAPIWithAPIName method in CommonMethodsClass.ps1 script: $_"
        exit 1 
    }
}
# Function to find the nearest match based on substring presence
function ExecuteTestSuiteWithSuiteID {
    param(
        [parameter(Mandatory = $true)]
        [string]$APIURL, 
        [parameter(Mandatory = $true)]
        [string] $authToken
    )     
    try {
 
        $headers = @{
            Authorization = "Bearer $authToken"
        }

        $requestBody = @{
            "comment"     = "executed via API call "
            "testRunName" = "executed via API call"
        }
        $requestJson = $requestBody | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $APIURL -Method Put -Headers $headers -Body $requestJson -ContentType "application/json"
        # Convert the response to JSON and return
        return $response | ConvertTo-Json

    }
   
    catch {

        Write-Host "An unexpected error occurred: $($_.Exception.Message)"
        Write-Output "PS_ERROR_DESC= Error in ExecuteTestSuiteWithSuiteID method in CommonMethodsClass.ps1 script: $_"
        exit 1
    }
 
}

