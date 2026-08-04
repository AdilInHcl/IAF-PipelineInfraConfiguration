<#
.SYNOPSIS
    This script is responsible for installing custom Files from GitHub Repository to the Evergreen Latest version.
 
.DESCRIPTION
     This script is responsible for installing custom Files from GitHub Repository to the Evergreen Latest version.

.NOTES
    FileName:    CopyCustomEvergreen-Module.ps1
    Author:      Daniyal Ahmad
    Contact:     
    Created:     
#>
#Input Parameters for repo and owner of the github
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$evergreenrepository,
	
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$appsrepository,

    [ValidateNotNullOrEmpty()]
    [string]$githubtoken = $env:GIT_PAT_PSW
)
# Check if the folder exists and Fetch the latest folder name
#####################################################################################################
function Set-EvergreenLatestModule {   

    param(
        [parameter(Mandatory = $true, HelpMessage = "Path of the Evergreen Module on local machine.")]
        [ValidateNotNullOrEmpty()]
        [string]$evergreenPath
        )   

    try{
        if (Test-Path $evergreenPath) {
            # Get all directories (folders) inside Evergreen
            $folders = Get-ChildItem -Path $evergreenPath -Directory | Select-Object -ExpandProperty Name

            if ($folders) {
                # Sort folders by version (splitting major.minor numbers and converting to integers)
                $latestVersion = $folders | Sort-Object {
                    # Split version parts and convert to numbers
                    ($_ -split '\.') | ForEach-Object { [int]$_ }
                } -Descending | Select-Object -First 1

                # Output the latest version folder
                Write-Host "Evergreen Latest Version: $latestVersion"
                return $latestVersion

            } else {
                Write-Host "No valid version folders found in '$evergreenPath'."
            }
        } else {
            Write-Host "Error: The folder path '$evergreenPath' does not exist."
        }
    }
    catch{
            $hsh_result.status = "Failure"  
            $hsh_result.description = "Error: $_ "
            Write-Host $hsh_result
            exit 1
    }
}

# Check for the Custom files present on GitHUB and Evergreen Latest Version Download
#####################################################################################################
function Set-EvergreenCustomFiles{
param(
        [parameter(Mandatory = $true, HelpMessage = "Path of the Evergreen Module Github.")]
        [ValidateNotNullOrEmpty()]
        [string]$evergreenrepository,
        [parameter(Mandatory = $true, HelpMessage = "Path of the Custom Apps on Github.")]
        [ValidateNotNullOrEmpty()]
        [string]$appsrepository,
        [parameter(Mandatory = $true, HelpMessage = "Path of the Evergreen Module on local machine.")]
        [ValidateNotNullOrEmpty()]
        [string]$evergreenPath,
        [parameter(Mandatory = $true, HelpMessage = "Path of the Evergreen Module on local machine.")]
        [ValidateNotNullOrEmpty()]
        [string]$EvergreenAppDataPath,
        [parameter(Mandatory = $true, HelpMessage = "Latest Version of Evergreen Module")]
        [ValidateNotNullOrEmpty()]
        [string]$latestVersion
        ) 

        #Folders to be checked
        $folderList = @("Apps", "Manifests", "Shared", "Private","Public")
        # Define the GitHub API URL for the root folder
        $RootEvergeenApiUrl = "https://github.developer.allianz.io/api/v3/repos/$($env:GITHUB_OWNER_APPFACTORY)/$evergreenrepository/contents"
        $RootAllianzAppsApiUrl = "https://github.developer.allianz.io/api/v3/repos/$($env:GITHUB_OWNER_APPPACKAGING)/$appsrepository/contents/Allianz_CustomApp_Configuration"

        foreach ($folder in $folderList) {
                
                #Set up base API url for github based on the folders
                if ($folder -in @("Apps", "Manifests") )
                {
                    #Set the local path to AppData and the Github API URL to 'IAF-App-Onboarding-ADT'
                    $RootApiUrl = $RootAllianzAppsApiUrl
                    $folderPath_Version = $EvergreenAppDataPath
                    $branch = $env:GITHUB_ONBOARDING_REPO_BRANCH
                    if (-not (Test-Path $folderPath_Version)){
                        Update-Evergreen #Download the Apps and manifests folders in  C:\Users\user\AppData\Local\Evergreen  
                     }
                 }
                else{
                    #Set the local path to Evergreen latest module and the Github API URL to 'EvergreenModule-ADT'
                    $RootApiUrl = $RootEvergeenApiUrl
                    $folderPath_Version = Join-Path -Path $evergreenPath -ChildPath $latestVersion
                    $branch = 'main'
                }

                #Checkin Files In GitHub/$folder"
                $ApiUrl = "$RootApiUrl/$($folder)?ref=$($branch)"
                $Headers = @{
                            "Authorization" = "Bearer $githubtoken"
                        }
                

                #Folder Location in local machine
                $filePathRoot = Join-Path -Path $folderPath_Version -ChildPath $folder
                
                try {
                    # Make the API request to fetch the contents
                    $Response = Invoke-WebRequest -Uri $ApiUrl -Headers $Headers -UseBasicParsing
                    $JsonContent = $Response.Content | ConvertFrom-Json
                    
        
                    # Check if we got any contents back
                    if ($JsonContent) {           
                        # Iterate over the contents and display folder/file names
                        foreach ($item in $JsonContent) {
                            
                            $fileName = $item.name
                            $filePath = Join-Path -Path $filePathRoot -ChildPath $fileName
                            $ApiUrlFile = "$($RootApiUrl)/$($folder)/$($fileName)?ref=$($branch)"

                            #Remove Save-EvergreenApp.ps1 incase found to replace it with updated one from GitHub
                            if ($fileName -eq "Save-EvergreenApp.ps1"){
                                Remove-Item -Path $filePath -Recurse -Force
                            }

                            # if (-not (Test-Path $filePath)){

                            #     Write-Host "File Not Found :$filePath"
                                #Write-Host "Copying Files to :$filePathRoot from GitHub"

                                # Send a request to get the file content
			                    $response = Invoke-WebRequest -Uri $ApiUrlFile -Headers $Headers -Method Get -ErrorAction Stop -UseBasicParsing
			                    
			                    # Parse the JSON response
			                    $content = $response | ConvertFrom-Json

                                if ($content.content) {
                                    # Decode the content from Base64 if it's provided
			                        $fileContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($content.content))

                                    # Save the content to the file, replacing it if it exists
			                        Set-Content -Path $filePath -Value $fileContent
                                    #Write-Host "Files Successfully Moved to the location $filePathRoot"

                                    
                                }else{
                                    Write-Host "Unable to fetch Contents of $fileName from GitHub"
                                }

                            # }
                            # else {
                            #     Write-Host "File Already Exists: $folder/$filename"
                            # }

                        }
                    } else {
                        Write-Output "No contents found or unable to fetch data from $ApiUrl."
                    }
                }
                catch {
                    Write-Output "PS_ERROR_DESC= Error fetching data from $ApiUrl $_"
                    exit 1
                }
        }


}

#Set Evergreen Module Path in Local
$evergreenPath = "C:\Program Files\WindowsPowerShell\Modules\Evergreen"
$EvergreenAppDataPath = "$env:LOCALAPPDATA\Evergreen"
$latestVersion = Set-EvergreenLatestModule -evergreenPath $evergreenPath -ErrorAction "Stop"
try{
    Set-EvergreenCustomFiles -evergreenrepository $evergreenrepository -appsrepository $appsrepository  -evergreenPath $evergreenPath -EvergreenAppDataPath $EvergreenAppDataPath -latestVersion $latestVersion -ErrorAction "Stop"
}
catch {
    Write-Output "PS_ERROR_DESC= Unable to download the required custom files from github. Error: $_"
    exit 1
}