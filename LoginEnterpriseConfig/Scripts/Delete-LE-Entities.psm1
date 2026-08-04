# Function to call DELETE API
function Delete_LE_Items_By_Id {
    param (
        [Parameter(Mandatory = $true)]
        [string]$APIURL,          # Base URL of your API (without ID)
       
        [Parameter(Mandatory = $true)]
        [string]$authToken,       # Bearer token for authorization
       
        [Parameter(Mandatory = $true)]
        [string]$itemId              # ID of the application to delete
    )
 
    # Set the headers for authorization
    $headers = @{
        Authorization = "Bearer $AuthToken"
    }
 
    # Construct the full URL including the App ID
    #$deleteUrl = "$APIURL/$itemId"
    $deleteUrl = "$APIURL"
    try {
        # Invoke the DELETE method
        $response = Invoke-RestMethod -Uri $deleteUrl -Method Delete -Headers $headers -ContentType "application/json"
 
        # Output success message
        Write-Host "LE Item having ID $itemId deleted successfully."
        return $response | ConvertTo-Json
    }
    catch {
 
        # Write-Host "An error occurred while calling the API to delete LE Entity"
        # Write-Host $_.Exception.Message
        Write-Output "PS_ERROR_DESC= An error occurred while calling the API to delete LE Entity in Delete-LE-Entities.psm1 script: $_"
        #exit 1 
    }
}
 
function Delete_LE_Items_InBulk {
    param (
        [Parameter(Mandatory = $true)]
        [string]$APIURL,          # Base URL of your API (without ID)
       
        [Parameter(Mandatory = $true)]
        [string]$authToken,       # Bearer token for authorization
       
        [Parameter(Mandatory = $true)]
        [string]$items              # ID of the application to delete
    )
 
    # Set the headers for authorization
    $headers = @{
        Authorization = "Bearer $AuthToken"
         ContentType   = "application/json"
    }

    try {
        # Invoke the DELETE method
        Write-Host "APIURL " $APIURL
        Write-Host "authToken " $authToken
        Write-Host "items " $items

        $jsonBody = $items
        $response = Invoke-RestMethod -Uri $APIURL -Method Delete -Headers $headers -Body $jsonBody -ContentType "application/json"
 
        # Output success message
        Write-Host "Items deleted successfully."
        Write-Host $items
        return $response | ConvertTo-Json
    }
    catch {
 
        # Write-Host "An error occurred while calling the API to delete LE Entities in bulk"
        # Write-Host $_.Exception.Message
        Write-Output "PS_ERROR_DESC= An error occurred while calling the API to delete LE Entities in bulk in Delete-LE-Entities.psm1 script: $_"
        #exit 1 
    }
}
 
 
