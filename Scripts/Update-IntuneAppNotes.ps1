function Normalize-Name {
    param([string]$name)
    if (-not $name) { return "" }

    # Convert ++ to plusplus
    $name = $name -replace '\+\+', 'plusplus'

    # Remove all non-alphanumeric characters
    $name = $name -replace '[^a-zA-Z0-9]', ''

    return $name.ToLower()
}

function Update-AppIdInNotes {
    param([Parameter(Mandatory)] $AppJson, [string]$AppId)
    if ([string]::IsNullOrWhiteSpace($AppId)) { return $AppJson }
    if ($null -eq $AppJson.Information -or -not ($AppJson.Information.Notes -is [System.Collections.IEnumerable])) { return $AppJson }

    $notes = @(); $found = $false
    foreach ($n in $AppJson.Information.Notes) {
        if ($n -match '^\s*AppID\s*:') {
            $notes += "AppID: $AppId"
            $found = $true
        } else {
            $notes += $n
        }
    }
    if (-not $found) { $notes += "AppID: $AppId" }

    $AppJson.Information.Notes = $notes
    return $AppJson
}

function Update-AppVersionInNotes {
    param([Parameter(Mandatory)] $AppJson, [string]$AppId, [Parameter(Mandatory)][string]$AppName, [Parameter(Mandatory)] $AppVersions)

    if ($null -eq $AppJson.Information -or -not ($AppJson.Information.Notes -is [System.Collections.IEnumerable])) { return $AppJson }

    $notes = @()
    foreach ($n in $AppJson.Information.Notes) {
        if ($n -match '^\s*Package Name\s*:') {

            $val = $n -replace '^\s*Package Name\s*:\s*',''
            $ver = if ($AppVersions -and $AppVersions.ContainsKey($AppName)) { 
                $AppVersions[$AppName] 
            } else { 
                $AppJson.Information.AppVersion 
            }

            if ($ver) {
                if ($val -match '<Version>') {
                    $val = $val -replace '<Version>', $ver
                }
                elseif ($AppJson.Information.AppVersion -and $val -match [regex]::Escape($AppJson.Information.AppVersion)) {
                    $val = $val -replace [regex]::Escape($AppJson.Information.AppVersion), $ver
                }
            }

            if ($AppId) { $val = $val -replace '<AppID>', $AppId }

            $notes += "Package Name: $val"
        }
        else {
            $notes += $n
        }
    }

    $AppJson.Information.Notes = $notes
    return $AppJson
}

function Update-AppJsonNotes {
    try {
        $appsList = Join-Path (Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY "AppsDownloadList") "AppsDownloadList.json"
        $appIdFile = Join-Path $env:BUILD_BINARIESDIRECTORY "AppId.json"
        $appsRoot  = Join-Path $env:BUILD_SOURCESDIRECTORY "Apps"

        if (-not (Test-Path $appsList) -or -not (Test-Path $appsRoot)) { 
            Write-Host "PS_ERROR_DESC=Missing AppsDownloadList or Apps root"; 
            exit 1 
        }

        $list = Get-Content -Raw -Path $appsList | ConvertFrom-Json

        $appIdData = if (Test-Path $appIdFile) {
            try {
                $data = Get-Content -Raw $appIdFile | ConvertFrom-Json
                Write-Host "DEBUG: Loaded AppId.json from $appIdFile"
                $data
            } catch {
                Write-Host "DEBUG: Failed to parse AppId.json: $_"
                $null
            }
        } else {
            Write-Host "DEBUG: AppId.json not found at $appIdFile"
            $null
        }

        $versions = @{}
        foreach ($e in $list) {
            if ($e.IntuneAppName -and $e.AppSetupVersion) {
                $versions[$e.IntuneAppName] = $e.AppSetupVersion
            }
        }

        $failed = $false; $updated = 0; $skipped = 0

        foreach ($entry in $list) {

            $name = $entry.IntuneAppName
            $normalizedTarget = Normalize-Name $name

            # FIXED FOLDER MATCHING LOGIC
            $folder = Get-ChildItem -Path $appsRoot -Directory -ErrorAction SilentlyContinue |
                      Where-Object { (Normalize-Name $_.Name) -eq $normalizedTarget } |
                      Select-Object -First 1

            if (-not $folder) { 
                $skipped++; 
                continue 
            }

            $appJsonPath = Join-Path $folder.FullName "App.json"
            if (-not (Test-Path $appJsonPath)) { 
                $skipped++; 
                continue 
            }

            try { 
                $appJson = Get-Content -Raw -Path $appJsonPath | ConvertFrom-Json 
            } catch { 
                Write-Host "PS_ERROR_DESC=Parse failed for $name"; 
                $failed = $true; 
                $skipped++; 
                continue 
            }

            $appId = $null
            if ($appIdData -and $appIdData.Apps) {
                $m = @($appIdData.Apps) | Where-Object { $_.IntuneAppName -ieq $name } | Select-Object -First 1
                if ($m) {
                    $appId = $m.AppId
                    Write-Host "DEBUG: Found AppID '$appId' for '$name'"
                } else {
                    Write-Host "DEBUG: No AppID match for '$name' in AppId.json"
                }
            }

            # Update Notes
            $appJson = Update-AppIdInNotes      -AppJson $appJson -AppId $appId
            $appJson = Update-AppVersionInNotes -AppJson $appJson -AppId $appId -AppName $name -AppVersions $versions

            try {
                $out = $appJson | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($appJsonPath, $out, [System.Text.UTF8Encoding]::new($false))
                $updated++
            } catch { 
                Write-Host "PS_ERROR_DESC=Save failed for $name"; 
                $failed = $true; 
                $skipped++; 
                continue 
            }
        }

        if ($failed) { 
            Write-Host "PS_ERROR_DESC=One or more updates failed. Updated=$updated; Skipped=$skipped"; 
            exit 1 
        }

        Write-Host "SUCCESS: Updated=$updated; Skipped=$skipped"; 
        exit 0

    } catch { 
        Write-Host "PS_ERROR_DESC=Unhandled error: $($_.Exception.Message)"; 
        exit 1 
    }
}

Update-AppJsonNotes
