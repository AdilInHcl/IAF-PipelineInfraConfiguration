// TARGET:{TargetPath}
// START_IN:{TargetPath}

using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using LoginPI.Engine.ScriptBase;
public class LaunchApplication_GetLaunchTime_Close : ScriptBase
{
    void Execute()
    {
        string applicationPath = @"{App_ExePath}";
        //   var processName = Path.GetFileNameWithoutExtension(applicationPath);
          var processName = "{process_Name}";
        // Log($"Starting {processName} launch-and-close test");
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
            StartTimer("Application_Launch_Timer");
            // Launch the shortcut
            Process.Start(new ProcessStartInfo(applicationPath)
            {
                UseShellExecute = true

            });
            Thread.Sleep(2000); // Give time to initialize
            var process = Process.GetProcessesByName(processName).FirstOrDefault();
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

}
 