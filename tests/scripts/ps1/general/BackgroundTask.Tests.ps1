BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'BackgroundTask' {
    BeforeEach {
        Invoke-Expression @'
class MockedBackgroundTask: BackgroundTask {
    MockedBackgroundTask([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
}
'@
    }

    Context 'Task creation' -Tag TaskCreation -ForEach @(
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "BasicTask"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "t"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "T"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "T1"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "t1"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "T_1"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "t_1"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = 1
        }; Name = "BasicTaskWithCustomStandardStopTimeout"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "" }
        
        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = 1
        }; Name = "BasicTaskWithCustomTimeout"; TemporaryFileCheckEnabled = $false; ExpectedTaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = 1
        }; TemporaryFileNameRegex = "" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = 1
        }; Name = "BasicTaskWithCustomStandardStopTimeoutAndTemporaryFileCheckEnabled"; TemporaryFileCheckEnabled = $true; ExpectedTaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = [BackgroundTask]::KillTimeout
        }; TemporaryFileNameRegex = "^[a-zA-Z][a-zA-Z0-9_]*_([0-9A-Fa-f]{8}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{12})$" }

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = 1
        }; Name = "BasicTaskWithCustomTimeoutAndTemporaryFileCheckEnabled"; TemporaryFileCheckEnabled = $true; ExpectedTaskStopInfo = @{
            StandardStopTimeout = 1
            KillTimeout = 1
        }; TemporaryFileNameRegex = "^[a-zA-Z][a-zA-Z0-9_]*_([0-9A-Fa-f]{8}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{4}[-]?[0-9A-Fa-f]{12})$" }
        
    ) {
        BeforeEach {
            $BackgroundTask = [MockedBackgroundTask]::new($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled)
        }

        It "creates a background task <name> : standard timeout = <taskstartinfo.standardstoptimeout> ; force kill timeout = <taskstartinfo.killtimeout>; temporary file check = <temporaryfilecheckenabled>" {
            $BackgroundTask.TaskStopInfo.StandardStopTimeout | Should -BeExactly $ExpectedTaskStopInfo.StandardStopTimeout
            $BackgroundTask.TaskStopInfo.KillTimeout | Should -BeExactly $ExpectedTaskStopInfo.KillTimeout
            $BackgroundTask.TemporaryFileCheckEnabled | Should -BeExactly $TemporaryFileCheckEnabled
            $BackgroundTask.TemporaryFileName | Should -Match $TemporaryFileNameRegex
            $BackgroundTask.CheckedTemporaryFileExistence | Should -BeFalse
            $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitUncompleted)
        }
    }

    Context 'Temporary file synchronization' -Tag TemporaryFileSynchronization {
        BeforeEach {
            Reset-TestOutput
        }

        Context 'Successful temporary file creation' {
            BeforeEach {
                Invoke-Expression @'
class MockedBackgroundTaskTwo: BackgroundTask {
    MockedBackgroundTaskTwo([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Boolean] IsAlive() {
        return $true
    }
}
'@

                $BackgroundTask = [MockedBackgroundTaskTwo]::new(@{}, @{}, "SuccessfulTemporaryFileCreationTest", $true)
                Start-Job { Start-Sleep 5; New-Item -Path "$env:TEMP\$( $args[0] )" -Type File } -ArgumentList $BackgroundTask.TemporaryFileName
            }

            It "synchronizes with the temporary file until it is created, then deletes it" {
                $BackgroundTask.SyncWithTemporaryFile() | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitCompleted)
                $BackgroundTask.CheckedTemporaryFileExistence | Should -BeTrue
                $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitCompleted)
                "$env:TEMP\$($BackgroundTask.TemporaryFileName)" | Should -Not -Exist
                $TestOutput | Should -BeExactly "Waiting for $( $BackgroundTask.Name ) to create the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }

        Context 'Process has already exited' {
            BeforeEach {
                $global:TestPathExecutionCount = 0

                Mock Test-Path {
                    $global:TestPathExecutionCount++

                    if ($global:TestPathExecutionCount -ge 2) {
                        return $true
                    } else {
                        return $false
                    }
                }

                Invoke-Expression @'
class MockedBackgroundTaskThree: BackgroundTask {
    MockedBackgroundTaskThree([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Boolean] IsAlive() {
        return $false
    }
}
'@

                $BackgroundTask = [MockedBackgroundTaskThree]::new(@{}, @{}, "ProcessHasAlreadyExitedTest", $true)
                New-Item -Path "$env:TEMP\$( $BackgroundTask.TemporaryFileName )" -Type File
            }

            It "stops early since the process has already stopped, and deletes the temporary file already created" {
                $BackgroundTask.SyncWithTemporaryFile() | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                $BackgroundTask.CheckedTemporaryFileExistence | Should -BeTrue
                $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                "$env:TEMP\$($BackgroundTask.TemporaryFileName)" | Should -Not -Exist
                $TestOutput | Should -BeExactly "Waiting for $( $BackgroundTask.Name ) to create the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                $TestWarningOutput | Should -BeExactly "ProcessHasAlreadyExitedTest has already exited;"
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }

        Context "Process has already stopped but the temporary file doesn' exist" {
            BeforeEach {
                Invoke-Expression @'
class MockedBackgroundTaskThree: BackgroundTask {
    MockedBackgroundTaskThree([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Boolean] IsAlive() {
        return $false
    }
}
'@

                $BackgroundTask = [MockedBackgroundTaskThree]::new(@{}, @{}, "ProcessHasAlreadyExitedTest", $true)
            }

            It "stops early since the process has already stopped, and skips deleting the temporary file since it does not exist" {
                $BackgroundTask.SyncWithTemporaryFile() | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                $BackgroundTask.CheckedTemporaryFileExistence | Should -BeTrue
                $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                "$env:TEMP\$($BackgroundTask.TemporaryFileName)" | Should -Not -Exist
                $TestOutput | Should -BeExactly "Waiting for $( $BackgroundTask.Name ) to create the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                $TestWarningOutput | Should -BeExactly "ProcessHasAlreadyExitedTest has already exited;"
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }

        Context "Temporary file synchronization timeout" -Tag TemporaryFileSynchronizationTimeout {
            BeforeEach {
                Mock Start-Sleep {}

                Invoke-Expression @'
class MockedBackgroundTaskFour: BackgroundTask {
    MockedBackgroundTaskFour([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Boolean] IsAlive() {
        return $true
    }
}
'@

                $BackgroundTask = [MockedBackgroundTaskFour]::new(@{}, @{}, "TemporaryFileSynchronizationTimeoutTest", $true)
            }

            It "fails the synchronization since the temporary file wait has timed out" {
                $BackgroundTask.SyncWithTemporaryFile() | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitTimeoutError)
                $BackgroundTask.CheckedTemporaryFileExistence | Should -BeTrue
                $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitTimeoutError)
                $TestOutput | Should -BeExactly "Waiting for $( $BackgroundTask.Name ) to create the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeExactly "Failed to wait for the creation of the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file;"
            }
        }

        Context "Temporary file deletion error" -Tag TemporaryFileDeletionError {
            BeforeEach {
                Mock Start-Sleep {}
                Mock Test-Path {
                    return $true
                }
                Mock Remove-Item {
                    throw "Failed to remove file"
                }
                
                Invoke-Expression @'
class MockedBackgroundTaskFive: BackgroundTask {
    MockedBackgroundTaskFive([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Boolean] IsAlive() {
        return $true
    }
}
'@

                $BackgroundTask = [MockedBackgroundTaskFive]::new(@{}, @{}, "TemporaryFileDeletionErrorTest", $true)
            }

            It "fails to remove the created temporary file" {
                $BackgroundTask.SyncWithTemporaryFile() | Should -BeExactly ([BackgroundTask]::FailedRemovingTmpFile)
                $BackgroundTask.CheckedTemporaryFileExistence | Should -BeTrue
                $BackgroundTask.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::FailedRemovingTmpFile)
                $TestOutput | Should -BeExactly "Waiting for $( $BackgroundTask.Name ) to create the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                $TestWarningOutput | Should -BeExactly "Failed removing the $env:TEMP\$( $BackgroundTask.TemporaryFileName ) temporary file;"
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Invalid task creation' -Tag InvalidTaskCreation -ForEach @(
        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = -1
        }; Name = "BasicTaskWithInvalidNegativeStandardStopTimeout"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.InvalidOperationException]}

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            StandardStopTimeout = ""
        }; Name = "BasicTaskWithInvalidStandardStopTimeout"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.InvalidOperationException]}

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            KillTimeout = -1
        }; Name = "BasicTaskWithNegativeKillTimeout"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.InvalidOperationException]}

        @{ TaskStartInfo = @{}; TaskStopInfo = @{
            KillTimeout = ""
        }; Name = "BasicTaskWithInvalidKillTimeout"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.InvalidOperationException]}

        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = " InvalidServiceNameWithSpaceAtTheBeginning"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "InvalidServiceName WithSpace"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "InvalidServiceName WithSpace"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "&InvalidServiceName"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = "InvalidServiceName&"; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = ""; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ TaskStartInfo = @{}; TaskStopInfo = @{}; Name = $null; TemporaryFileCheckEnabled = $false; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
    ) {
        It "fails to create a background task <name> since the arguments are incorrect : standard timeout = <taskstopinfo.standardstoptimeout>; force kill timeout = <taskstopinfo.killtimeout>; temporary file check = <temporaryfilecheckenabled>" {
            { [MockedBackgroundTask]::new($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) } | Should -Throw -ExceptionType $ExpectedExceptionType
        }
    }

    Context 'Invalid task start info' -Tag InvalidTaskStartInfo {
        BeforeEach {
            Invoke-Expression @'
class MockedBackgroundTaskSix: BackgroundTask {
    MockedBackgroundTaskSix([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Void] CheckTaskStartInfo() {
        throw [InvalidOperationException]::new("Task start info is incorrect")
    }
}
'@
        }

        It "fails to create a background task because the task start info is incorrect" {
            { [MockedBackgroundTaskSix]::new(@{}, @{}, "InvalidTaskStartInfoTest", $false) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Invalid altered task start info on start' -Tag InvalidAlteredTaskStartInfoOnStart {
        BeforeEach {
            Invoke-Expression @'
class MockedBackgroundTaskEight: BackgroundTask {
    MockedBackgroundTaskEight([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Void] CheckTaskStartInfo() {
        $global:TaskStartInfoCheckCounter++

        if ($global:TaskStartInfoCheckCounter -ge 2) {
            throw [InvalidOperationException]::new("Task start info is incorrect")
        }
    }

    [Boolean] IsAlive() {
        return $false
    }
}
'@
        }

        It "fails to start a background task because the altered task start info is incorrect" {
            $BackgroundTask = [MockedBackgroundTaskEight]::new(@{}, @{}, "InvalidAlteredTaskStartInfoTest", $false)
            { $BackgroundTask.Start() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Invalid task stop info' -Tag InvalidTaskStopInfo {
        BeforeEach {
            Invoke-Expression @'
class MockedBackgroundTaskNine: BackgroundTask {
    MockedBackgroundTaskNine([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Void] CheckTaskStopInfo() {
        throw [InvalidOperationException]::new("Task stop info is incorrect")
    }
}
'@
        }

        It "fails to create a background task because the task stop info is incorrect" {
            { [MockedBackgroundTaskNine]::new(@{}, @{}, "InvalidTaskStopInfoTest", $false) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Invalid altered task stop info on stop' {
        BeforeEach {
            Invoke-Expression @'
class MockedBackgroundTaskEleven: BackgroundTask {
    MockedBackgroundTaskEleven([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Void] CheckTaskStopInfo() {
        $global:TaskStopInfoCheckCounter++

        if ($global:TaskStopInfoCheckCounter -ge 2) {
            throw [InvalidOperationException]::new("Task stop info is incorrect")
        }
    }

    [Boolean] IsAlive() {
        return $true
    }
}
'@
        }

        It "fails to stop a background task because the altered task stop info is incorrect" {
            $BackgroundTask = [MockedBackgroundTaskEleven]::new(@{}, @{}, "InvalidAlteredTaskStopInfoTest", $false)
            { $BackgroundTask.Stop() } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    
    Context 'Invalid pre check setup' -Tag InvalidPreCheckSetup {
        BeforeEach {
            Invoke-Expression @'
class MockedBackgroundTaskTwelve: BackgroundTask {
    MockedBackgroundTaskTwelve([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($TaskStartInfo, $TaskStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    [Void] PreCheckSetup() {
        throw [InvalidOperationException]::new("Pre-check error")
    }
}
'@
        }

        It "fails the pre-check setup step" {
            { [MockedBackgroundTaskTwelve]::new(@{}, @{}, "PreCheckSetupError", $false) } | Should -Throw -ExceptionType ([InvalidOperationException])
        }
    }

    Context 'Invalid abstract class uses' -Tag InvalidAbstractClassUses {
        BeforeEach {
            $BackgroundTask = [MockedBackgroundTask]::new(@{}, @{}, "AbstractClassBehaviorCheck", $false)
        }

        It "fails to instantiate the background task since the task is abstract" {
            { [BackgroundTask]::new(@{}, @{}, "AbstractClassInstantiationTest", $false) } | Should -Throw "Class BackgroundTask must be inherited"
        }

        It "fails to call non-overloaded logical process handling methods" {
            { $BackgroundTask.IsAlive() } | Should -Throw "Must be implemented"
            { $BackgroundTask.StartIfNotAlive() } | Should -Throw "Must be implemented"
            { $BackgroundTask.StopIfAlive() } | Should -Throw "Must be implemented"
        }
    }
}