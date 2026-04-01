// TARGET:{TargetPath}
// START_IN:{TargetPath}
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using LoginPI.Engine.ScriptBase;
using System.Collections.Generic;

public class LaunchApplication_GetLaunchTime_Close : ScriptBase
{
    bool isPassed = false;
    string intuneAppVersion = "{intune_App_Version}";
    string processName = "{process_Name}";
    string intunePackageName = "{intune_Package_Name}";
    string intuneAppName = "{intune_App_Name}";
    void Execute()
    {
        string applicationPath = @"{App_ExePath}";
        //   var processName = Path.GetFileNameWithoutExtension(applicationPath);
        
        try
        {
            // Kill any existing {processName} process
            var existing = Process.GetProcessesByName(processName);
            foreach (var proc in existing)
            {
                Log($"Terminating existing {processName} process...");
                proc.Kill();
                proc.WaitForExit();
            }
            isPassed = checkPackageWithPackageName(intunePackageName);
            if (!isPassed)
            {   
                //ABORT("Installation checked failed. Aborting script execution without checking further testcases. ");
                  Log("Installation checked failed. Aborting script execution without checking further testcases. ");
                  return;
            }
            if(applicationPath == "No_shortcut_Available")
            {
              Log("Short-cut not Available");
              return;
            }
            StartTimer("Application_Launch_Timer");
            // Launch the shortcut
            Process.Start(new ProcessStartInfo(applicationPath)
            {
                UseShellExecute = true

            });
            // Code check process with process name in iterative way within given time and interval
            int elapsedTime = 0;
            int iterationCount = 0;
            int maxWaitTimeInSeconds=15;
            int checkIntervalInMilliseconds= 100;
            int maxIterations = (maxWaitTimeInSeconds * 1000)/checkIntervalInMilliseconds;
            
            Process process = null;
    
            while (elapsedTime < maxWaitTimeInSeconds * 1000 && iterationCount < maxIterations)
            {
                process = Process.GetProcessesByName(processName).FirstOrDefault();
                if (process != null)
                {
                    break;
                }
    
                Thread.Sleep(checkIntervalInMilliseconds);
                elapsedTime += checkIntervalInMilliseconds;
                iterationCount++;
            }

            // Thread.Sleep(2000); // Give time to initialize
            // var process = Process.GetProcessesByName(processName).FirstOrDefault();
            if (process != null)
            {
                string commandLine = GetCommandLine(process.Id);
                if (!string.IsNullOrEmpty(commandLine))
                {
                    Log($"Process launched with command line: '{commandLine.Trim()}'");
                }
                StopTimer("Application_Launch_Timer");
                Log($"{processName} launched successfully.");
                // Close the process
                Log($"Closing {processName}...");
                process.Kill();
                process.WaitForExit();
                Log($"{processName} closed successfully.");
            }
            else
            {
                StopTimer("Application_Launch_Timer");
                Log($"Failed to find {processName} process after launch.");
            }
        }
        catch (Exception ex)
        {
            Log($"An error occurred: {ex.Message}");
            throw;
        }
    }

    private string GetCommandLine(int pid)
    {
        try
        {
            string psCommand = $"(Get-CimInstance Win32_Process -Filter \\\"ProcessId={pid}\\\").CommandLine";
            Log($"Executing PowerShell: {psCommand}");
            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-noprofile -command \"{psCommand}\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (var proc = Process.Start(psi))
            {
                string result = proc.StandardOutput.ReadToEnd();
                proc.WaitForExit();
                return result.Trim();
            }
        }
        catch (Exception ex)
        {
            Log($"Failed to get command line via PowerShell: {ex.Message}");
            return null;
        }

    }
    
    bool checkPackageWithPackageName(string packageName)
    {
        bool isVersionMactched = false;
        bool isInstalled = false;
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
          Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"& {{ " +
            $"$path = 'HKLM:\\SOFTWARE\\AllianzPackages\\{packageName}'; " +
            "$props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue; " +
            "if ($props -ne $null) { " +
            "  $output = [PSCustomObject]@{ " +
            $"    PackageName = '{packageName}'; " +
            "    Installed = $props.Installed; " +
            "    PackageMode = $props.PackageMode; " +
            "    InstallDate = $props.InstallDate; " +
            "    Revision = $props.PackageRevision; " +
            "    Platform = $props.Platform; " +
            "    Version = $props.Version; "+
            "    PSADTVersion = $props.'PSADT Version' " +
            "  }; " +
            "  $output | ConvertTo-Json -Compress " +
            "} else { Write-Output '{\"Error\": \"Package not found or missing properties.\"}' } }\"",                    
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            using (var process = Process.Start(psi))
            {
                if (process == null)
                {
                    Log("Failed to start PowerShell process.");
                    return false;
                }
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                string keyToCheck = "Error";
                Log(output);
                Dictionary<string, string> properties = GetPackageProperties(output);
                if (properties.ContainsKey(keyToCheck))
                {
                    isInstalled = false;
                    Log(properties[keyToCheck]);
                    CreateEvent(title:$"Package Not Found for {intuneAppName}", description:$"{intunePackageName}");
                }
                else
                {
                    foreach (var kvp in properties)
                    {
                        Log($"{kvp.Key}, {kvp.Value}");
                    }
                  
                    var PackageMode = properties["PackageMode"];
                    var Installed = properties["Installed"];
                    var Version = properties["Version"];
                    if (PackageMode == "IAF" && Installed == "Yes")
                    {
                        isInstalled = true;
                       // Log("Application is installed. Installation check is passed.");
                         Log("Application is installed. Installation check is passed.");
                        if (Version == intuneAppVersion)
                        {
                            isVersionMactched = true;
                            Log("Version check passed.");
                            
                        }
                        else
                        {
                            isVersionMactched = false;
                            Log("Version check failed.");
                            //CreateEvent(title:"FAILED: Version check", description:$"{Version});
                        }
                    }
                    process.WaitForExit();
                    CreateEvent(title:$"Current Version for {intuneAppName}", description:$"{Version}");
                    CreateEvent(title:$"IAF Version Pushed from {intuneAppName}", description:$"{intuneAppVersion}");
                }
                if (!string.IsNullOrWhiteSpace(error))
                {
                    isPassed = false;
                      ABORT("PowerShell error: " + error);
                }
                if (string.IsNullOrWhiteSpace(output))
                {
                    isPassed = false;
                    ABORT("No output received from PowerShell.");
                }
            }
            if(isInstalled && isVersionMactched)
              isPassed= true;

            return isPassed;
        }
        catch (Exception ex)
        {
             ABORT("Exception occurred: " + ex.Message);
            return false;
        }
    }
 
    Dictionary<string, string> GetPackageProperties(string output)
   {
    string jsonString = output.Trim('{', '}');
                string[] keyValuePairs = jsonString.Split(',');
                // Dictionary to store properties and values       
                Dictionary<string, string> properties = new Dictionary<string, string>();
                // Iterate through each key-value pair
                foreach (string pair in keyValuePairs)
                {            // Split by colon to separate key and value
                    string[] keyValue = pair.Split(':');
                                // Trim quotes and spaces
                    string key = keyValue[0].Trim().Trim('"');
                    string value = keyValue[1].Trim().Trim('"');
                    // Handle null values
                    if (value.Equals("null", StringComparison.OrdinalIgnoreCase))
                    {               
                    value = null;
                    }
                    // Add to dictionary
                    properties[key] = value;
                }
               
                return properties;
   }

}
 
