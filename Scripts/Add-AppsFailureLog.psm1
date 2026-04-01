function Add-AppsFailureLog {
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Log
    )

    # Set the path to your JSON file
    # Intitialize variables
    Write-Host "$AppName : $Log"
    $AppsFailLogFileName = "AppsFailureLog.json"
    $AppsFailLogFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $AppsFailLogFileName

    # If file doesn't exist, create it with an empty users array
    if (-Not (Test-Path $AppsFailLogFilePath)) {
        $initialData = @{ apps = @() }
        $initialData | ConvertTo-Json -Depth 10 | Set-Content -Path $AppsFailLogFilePath
    }

    # Load existing data
    $AppLogData = Get-Content -Path $AppsFailLogFilePath | ConvertFrom-Json

    # Check if app already exists in the log
    $existingApp = $AppLogData.apps | Where-Object { $_.appname -eq $AppName }

    # Create new entry
    if ($existingApp) {
        # Add new log to existing app
        $existingApp.log += $Log
    } else {
        # Add new app with its first error
        $newApp = [PSCustomObject]@{
            appname = $AppName
            log     = @($Log)
        }
        $AppLogData.apps += $newApp
    }

    # Save updated data back to file
    $AppLogData | ConvertTo-Json -Depth 10 | Set-Content -Path $AppsFailLogFilePath

    Write-Output "Log for App: '$AppName' added to the master log file"
}