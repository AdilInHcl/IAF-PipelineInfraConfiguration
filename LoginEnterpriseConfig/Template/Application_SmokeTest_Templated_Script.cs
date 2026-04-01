// TARGET:{TargetPath}
// START_IN:
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.IO;
using LoginPI.Engine.ScriptBase;

public class Application_SmokeTesting_With_LaunchTime : ScriptBase
{
    void Execute()
    {
        // Define the application path
          string applicationPath = @"{App_ExePath}";
        try
        {
            Process process = new Process();
            process.StartInfo.FileName = applicationPath;
            process.StartInfo.UseShellExecute = true; // Depending on the application, you might need this
            process.Start();
        
            StartTimer("Application_Launch_Timer");
            //Wait(2);
           
            var process_Name = Path.GetFileNameWithoutExtension(applicationPath);
            
            var win= FindWindow(processName : "{process_Name}", timeout:60);
            if (win != null)
            {
                Log("Application Launched Successfully.");
                win.Close();
                Log("Application Closed Successfully.");
            }
            else
            {
               Log("Failed Launched Application.");
            }
            
            StopTimer("Application_Launch_Timer");
            
        }
        catch (Exception ex)
        {
            throw ex;
            // Console.WriteLine($"An error occurred: {ex.Message}");
        }
        finally
        {
        //   StopTimer("Application_Launch_Timer");
        }
    }
}
