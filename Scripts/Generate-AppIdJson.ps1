<#
.SYNOPSIS
    This script parses AppName:AppId input, validates it, and generates an AppId.json file.
 
.DESCRIPTION
    This script accepts a semicolon-separated string of AppName:AppId pairs,
    validates null entries, missing values, and duplicates, and then produces
    a structured JSON file (AppId.json) containing the unique application mappings.

.NOTES
    FileName:    Generate-AppIdJson.ps1
    Author:      Mo Adil Ansari
    Created:     19 Dec 2025
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AppInputString
)

# ===== Validate Input =====
if ([string]::IsNullOrWhiteSpace($AppInputString)) {
    Write-Output "PS_ERROR_DESC= No AppId input found."
    exit 1
}

# ===== Process Input =====
$apps = @()
$seen = @{}

foreach ($item in $AppInputString -split ';') {

    if ([string]::IsNullOrWhiteSpace($item)) { continue }

    $parts = $item -split ':'
    if ($parts.Count -ne 2) { 
        Write-Warning "Invalid entry: $item"
        continue
    }

    $name, $id = $parts
    if (-not $name -or -not $id) { 
        Write-Warning "Missing AppName or AppId in: $item"
        continue
    }

    $key = "$name|$id"
    if ($seen[$key]) { 
        Write-Warning "Duplicate entry skipped: $item"
        continue
    }
    $seen[$key] = $true
    $apps += [PSCustomObject]@{
        IntuneAppName = $name
        AppId         = $id
    }
}

# ===== Build JSON Output =====
$ResultObject = @{
    Apps = $apps
}

$JsonOutput = $ResultObject | ConvertTo-Json -Depth 5

# ===== Save to File =====
$FileName = "AppId.json"
$OutputFileName = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $FileName
$JsonOutput | Out-File -FilePath $OutputFileName -Encoding UTF8
Write-Output "AppId.json generated successfully."

