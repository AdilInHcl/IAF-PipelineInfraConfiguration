#-------------------------------  Test Suite related classes ------------------------------------------

#Define display resolution of Test VM
class DisplayResolution {
  [int]$width
  [int]$height
  DisplayResolution() {
    $this.width = 1024
    $this.height = 768
  }
}
# Define the Connector class
class Connector {
  [string]$type
  [string]$serverUrl
  [string]$resource
  [DisplayResolution]$displayResolution 

  Connector() {
    $this.displayResolution = [DisplayResolution]::new()
  }

}
class CustomConnector {
  [string]$type        
  [string]$host        
  [string]$commandLine 
  [string]$resource    
}

# Define the Step class

class Step {
  [string]$type
  [string]$applicationId
  [bool]$isEnabled
  [bool]$runOnce
  [bool]$leaveRunning    
}

# Define the AppThreshold class
class AppThreshold {
  [bool]$isEnabled
  [int]$value
  [string]$applicationId
  [string]$timer
}

# Define the Threshold class
class Threshold {
  [bool]$isEnabled
  [int]$value
}

# Define the main ApplicationTest class
class ApplicationTestSuite {
  [bool]$create
  [string]$type
  [string]$name
  [string]$description
  # [Connector]$connector
  [CustomConnector]$connector
  [string[]]$accountGroups
  [string[]]$launcherGroups
  [string]$environmentId
  [bool]$applicationDebugModeEnabled
  [string]$logonTimeTrackingProcess
  [int]$engineStartTimeout
  [string]$engineMinLogLevel
  [int]$sendConnectionEndedAfter
  [object[]]$steps  # Changed from [Step[]] to [object[]]
  #[Step[]]$steps
  [string[]]$roles
  [bool]$isEmailEnabled
  [string]$emailRecipient
  [bool]$includeSuccessfulApplications
  [bool]$restartOnComplete
  [AppThreshold[]]$appThresholds
  [Threshold]$latencyThreshold
  [Threshold]$loginTimeThreshold

  ApplicationTestSuite() {
    $this.steps = @() #[System.Collections.Generic.List[Step]]::new()
  }
}

class TestSuiteSteps {
  [string]$shortcutName
  [string]$shortcutPath
  [string]$ApplicationId
}
class StagesResult {
  [string]$appName
  [string]$appVersion
  [string]$FamilyID
  [TestSuiteSteps[]]$steps
  # [string]$AppTestId  
  [string]$AppTestSuiteId
  [string]$AppTestUserId
  [string]$AppAccountGroupId

  StagesResult() {
    $this.steps = @() #[System.Collections.Generic.List[Step]]::new()
  }
}

#-------------------------------  Test Suite related classes ------------------------------------------

#------------------------------- Create Application (Test Script) -------------------------------------
class CreateApplication {
  [string]$commandLine 
  [string]$workingDirectory 
  [string]$type 
  [string]$name 
  [string]$description 
  [string]$takeScreenshots 
  [string]$scriptContent 
  [string[]]$roles
 
}
 
class CreateAccountGroup {
  [string]$type
  [string]$name
  [string]$description
  [string[]]$memberIds

}
