function Find_NearestMatch {
    param (
        [string]$searchName,
        [array]$data
    )
 
    $matches = $data | Where-Object { $_.applicationName -like "*$searchName*" }
    if ($matches) {
        return $matches
    }
    else {
        return $null
    }
}
# Define the log file path
# function to check if file is not being used by another process before doing any operation
function Test-FileLocked {
    param ([string]$Path)

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        if ($stream) {
            $stream.Close()
            return $false  # File is not locked
        }
    } catch {
        return $true  # File is locked
    }
}
# Function to write a log entry with a line break
function Write-Log {
    param (
        [string]$message
    )
    try {      
        # Append the message to the log file with a line break
        $logFileName = "LEAPILogs\LogFile.txt"
        $logFilePath = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath $logFileName

        # Wait until file is not locked
        # Write-Host "Checking if file is locked..."
        # while (Test-FileLocked -Path $logFilePath) {
            #    Start-Sleep -Seconds 1
            #}
        
        # Write-Host "File is now available."
        Add-Content -Path $logFilePath -Value "$message`r`n"
    }
    catch {
        Write-Host "PS_ERROR_DESC= Error in Write-Log method in CommonMethodsClass.ps1 script: $_"
        exit 1
    }
}