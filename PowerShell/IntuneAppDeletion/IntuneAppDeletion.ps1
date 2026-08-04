<#
.SYNOPSIS
    This script deletes multiple Intune Apps from the Intune App Portal.
 
.DESCRIPTION
    This script takes multiple app names as input and deletes them from Microsoft Intune using Microsoft Graph API.


.NOTES
    FileName:    IntuneAppDeletion.ps1
    Author:      Daniyal Ahmad     
#>
# Input Parameters
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,
    
    [ValidateNotNullOrEmpty()]
    [string]$ClientSecret = $env:CLIENT_SECRET,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AppName, # Accepts multiple app names

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$IntuneAppID, # Accepts multiple app names

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserId # Accepts multiple app names
)

# Returns Family ID 
function Get-TestCheckFlag {
    param (
        [string]$Notes = $app.notes
    )

    if ($Notes -match 'TestApp:\s*Yes') {
        return $true
    }
    
    return $false
    
}

function Fetch-GroupName {
    param (
        [parameter(Mandatory = $true)]
        [string]$appid
    )
    $assignments = Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps/$($appid)/assignments"
    $assignedGroups = foreach ($assignment in $assignments) {

        # Skip assignments like All Devices / All Users
        if ($assignment.target.groupId) {

            $group = Invoke-MSGraphOperation `
                -Get `
                -APIVersion "v1.0" `
                -Resource "groups/$($assignment.target.groupId)"

            [PSCustomObject]@{
                AppName   = $app.displayName
                Intent    = $assignment.intent
                GroupName = $group.displayName
                GroupId   = $group.id
            }
        }
    }

    return $assignedGroups
}

function Send-ScriptNotificationEmail {
    param(
        [Parameter(Mandatory = $true)]$Subject,
        [Parameter(Mandatory = $true)]$Recipient,
        [Parameter(Mandatory = $true)]$Body,
        [Parameter(Mandatory = $true)]$TMUusername,
        [Parameter(Mandatory = $true)]$TMUpassword
    )
    #Set Variables
    $smtpServer = "tmu-cs.mail.allianz"
    $smtpFrom = "APP-CONVERSION@allianz.com"
    $messageSubject = $Subject
 
    $UserName = $TMUusername
    $Password = ConvertTo-SecureString $TMUpassword -AsPlainText -Force
 
    $credentials = New-Object System.Management.Automation.PSCredential($UserName, $Password)
 
    Send-MailMessage -SmtpServer $smtpServer -Credential $credentials -Port "587" -From $smtpFrom -To $Recipient -Subject $messageSubject -Body $Body -BodyAsHtml -UseSsl -Priority High
}


# Define Microsoft Graph API URLs
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$graphApiUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"

# Get Authentication Token
$body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
    grant_type    = "client_credentials"
}

Write-Host "Generating Authentication Token..."

# Retrieve authentication token using client secret from key vault
$AuthToken = Get-AccessToken -TenantID $TenantId -ClientID $ClientId -ClientSecret $ClientSecret -ErrorAction "Stop"

#Connect to intune
$connectMSIntune = Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction "Stop"


#Fetching Intune App Data
$MaxRetries  = 5
$RetryDelay  = 30      # seconds, doubled each attempt: 30, 60, 120, 240, 480
$Attempt     = 0
$Win32AppResources    = $null
while ($Attempt -lt $MaxRetries -and $null -eq $Win32AppResources) {
    $Attempt++
    try {
        $Win32AppResources = Invoke-MSGraphOperation -Get -APIVersion "Beta" -Resource "deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"
    }
    catch {
        Write-Output "$_"
        Write-Output -InputObject "Failed to upload to inutne on attempt $Attempt/$MaxRetries for '$($App.IntuneAppName)': ErrMsg. Retrying in $RetryDelay seconds..."
        Start-Sleep -Seconds $RetryDelay
    }
}

try{
    $response  = Invoke-RestMethod -Method Post -Uri $tokenUrl -ContentType "application/x-www-form-urlencoded" -Body $body

    $accessToken = $response.access_token
    $headers = @{Authorization = "Bearer $accessToken"}
    Write-Host "Token Generated Successfully"

    Write-Host "============================================"

    #Check based on app name and IntuneAppID
    $app = $Win32AppResources | Where-Object { $PSItem.displayName -eq "$($AppName)" }
    $IntuneAppIDcheck = $Win32AppResources | Where-Object { $PSItem.id -eq "$($IntuneAppID)" }
    $result = $null

    if ($app.id -eq $IntuneAppIDcheck.id) {

        Write-Host "Found application: $($app.displayName) (ID: $($app.id))" 

        $TestApp = Get-TestCheckFlag -Notes $app.notes

        if($TestApp){
            $GroupsAssigned = Fetch-GroupName -appid $app.id
            $PGroups = @($GroupsAssigned | Where-Object { $_.GroupName -like '*-P-*' } | Select-Object -ExpandProperty GroupName)
            if($PGroups.Count -gt 0){
                Write-Output "PS_ERROR_DESC= Error message: Application $($AppName) is a production application with group (-P-) assigned to it. Skipping deletion!" 
                exit 1
            }

            #Remove the Supersedence if any
            Remove-IntuneWin32AppSupersedence -ID $app.id -WhatIf

            # Remove the App
            Write-Host "Deleting Application:$AppName from Intune."
            $deleteUrl = "$graphApiUrl/$($app.id)"

            #Remove App From Intune
            Invoke-RestMethod -Uri $deleteUrl -Headers $headers -Method Delete
            Write-Host "Application '$AppName' has been removed successfully!"      
            $result = "Success"        
        }
        else{
            Write-Output "PS_ERROR_DESC= Error message: Application $($AppName) is not a Test Application. Skipping deletion!" 
            $result =  "<strong>Error:</strong> Application $($AppName) is not a Test Application. Skipping deletion!" 
        }
        
    } 
    else {
        Write-Output "PS_ERROR_DESC= Error message: Intune App ID is incorrect for the given Application Name. Please validate the parameters and retry." 
        $result = "<strong>Error:</strong> Intune App ID is incorrect for the given Application Name. Please validate the parameters and retry." 
    }

    Write-Host "============================================"

}
catch {
    Write-Output "PS_ERROR_DESC= Error message: $_ "
    $result = "<strong>Error:</strong> $_ "
}


# Load Email Template
$DeletionHtmlReportPath = Join-Path -Path $env:WORKSPACE -ChildPath "configs\EmailTemplates\DeletionEmail_Template.html"
$template = Get-Content -Path $DeletionHtmlReportPath -Raw

if ($result -eq "Success") {
    $Subject = "IAF-Application Deletion Completed for $AppName"
    $STATUS = "SUCCESS"
    $STATUS_MESSAGE = "Application deleted successfully."
    $STATUS_COLOR = "#107c10"
    $STATUS_BG = "#f3f9f1"
    $STATUS_BORDER = "#c8e6c9"
    $RESULT_DESCRIPTION = "The application has been successfully removed from Microsoft Intune and is no longer available for assignment or deployment."
}
else {
    $Subject = "IAF-Application Deletion Failed for $AppName"
    $STATUS = "FAILED"
    $STATUS_MESSAGE = "Application deletion failed."
    $STATUS_COLOR = "#d13438"
    $STATUS_BG = "#fdf3f4"
    $STATUS_BORDER = "#f3c7c9"
    $RESULT_DESCRIPTION = $result
}

# Status Banner
$status_banner = @"
<div style="background-color:$STATUS_BG;border:1px solid $STATUS_BORDER;border-radius:6px;padding:12px 16px;margin-bottom:24px;">
    <span style="color:$STATUS_COLOR;font-weight:600;">
        $STATUS_MESSAGE
    </span>
</div>
"@

# Replace placeholders in HTML template
$template = $template.Replace('{{StatusBanner}}', $status_banner)
$template = $template.Replace('{{AppName}}', $AppName)
$template = $template.Replace('{{IntuneAppId}}', $IntuneAppID)
$template = $template.Replace('{{STATUS}}', $STATUS)
$template = $template.Replace('{{UserId}}', $UserId)
$template = $template.Replace('{{DATE}}', (Get-Date).ToString('dd-MMM-yyyy HH:mm:ss'))
$template = $template.Replace('{{RESULT_DESCRIPTION}}', $RESULT_DESCRIPTION)

# Load JSON from Recipient file
$EmailjsonPath = Join-Path -Path (Join-Path -Path $env:WORKSPACE -ChildPath "configs") -ChildPath "EmailRecipients.json"

$data = Get-Content -Path $EmailjsonPath | ConvertFrom-Json

$DeletionTo = $data.DeletionEmailStatus.To

# Send Email
Send-ScriptNotificationEmail -Subject $Subject -Recipient $DeletionTo -Body $template -TMUusername $env:SMTP_USERNAME -TMUpassword $env:SMTP_PASSWORD