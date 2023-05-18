BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'BackgroundProcess' -ForEach @(
    @{ NoNewWindow = $null }
    @{ NoNewWindow = $true }
) {
    BeforeEach {
        Mock Write-Warning {
            $global:TestWarningOutput += Write-Output ($Message + " ")
        }

        Mock Write-Error {
            $global:TestErrorOutput += Write-Output ($Message + " ")
        }

        Mock Write-Information {
            $global:TestOutput += Write-Output ($MessageData + " ")
        }
        
        $global:TestOutput = ""
        $global:TestWarningOutput = ""
        $global:TestErrorOutput = ""
    }

    AfterEach {
        $global:TestOutput = ""
        $global:TestWarningOutput = ""
        $global:TestErrorOutput = ""
    }

    Context 'Infer default process properties from context' -Tag InferValues -ForEach @(
        @{ TaskStartInfo = @{}; ExpectedNoNewWindowProperty = $true }
        @{ TaskStartInfo = @{
            NoNewWindow = $null
        }; ExpectedNoNewWindowProperty = $true }
        @{ TaskStartInfo = @{
            NoNewWindow = -1
        }; ExpectedNoNewWindowProperty = $true }
        @{ TaskStartInfo = @{
            NoNewWindow = ""
        }; ExpectedNoNewWindowProperty = $true }
        @{ TaskStartInfo = @{
            NoNewWindow = $false
        }; ExpectedNoNewWindowProperty = $false }
    ) {
        It "should deduce a default value of <expectednonewwindowproperty> correlated to the no window property : <taskstartinfo.nonewwindow>" {
            [BackgroundTaskFactory]::new($false).buildProcess($TaskStartInfo, "InferCheck").TaskStartInfo.NoNewWindow | Should -BeExactly $ExpectedNoNewWindowProperty
        }
    }

    Context 'Success cases' -Tag SuccessCases {
        BeforeEach {
            $TaskStartInfo = (@{
                NoNewWindow = $NoNewWindow
                FilePath = "powershell"
            })
        }

        Context 'Standard process creation without temporary file check' -ForEach @(
            @{ StopCallAlreadyExecuted = $false; StopKeyword = "Stopping"; StoppedKeyword = "Stopped"; ExpectedStopCallState = $true }
            @{ StopCallAlreadyExecuted = $true; StopKeyword = "Killing";  StoppedKeyword = "Killed"; ExpectedStopCallState = $true }
        ) {
            Context 'Basic process creation' {
                BeforeEach {
                    $TaskStartInfo.ArgumentList = "-Command", 'while ($true) { Start-Sleep 1 }'
                    $TemporaryFileCheckEnabled = $false
                    $Name = "BasicProcess"
                }
    
                It "creates the process without starting it : force kill = <stopcallalreadyexecuted>" {
                    $BackgroundProcess = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildProcess($TaskStartInfo, $Name)
                    $BackgroundProcess.TaskStartInfo.NoNewWindow | Should -BeExactly $true
                    $BackgroundProcess.Name | Should -BeExactly $Name
                    $BackgroundProcess.TemporaryFileCheckEnabled | Should -BeExactly $TemporaryFileCheckEnabled
                    $BackgroundProcess.TaskStartInfo | Should -BeExactly $TaskStartInfo
                    $BackgroundProcess.IsAlive() | Should -BeFalse
                    $BackgroundProcess.Stop() | Should -BeExactly 0
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeFalse
                    $TestOutput | Should -BeNullOrEmpty
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
    
                It "creates the process, starts it and stops it" {
                    $BackgroundProcess = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildProcess($TaskStartInfo, $Name)
                    $BackgroundProcess.Start()
                    $BackgroundProcess.IsAlive() | Should -BeTrue
                    $BackgroundProcess.Process.HasExited | Should -BeFalse
                    $BackgroundProcess.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $BackgroundProcess.Stop() | Should -BeExactly 0
                    $BackgroundProcess.Process.HasExited | Should -BeTrue 
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeExactly $ExpectedStopCallState
                    $TestOutput | Should -BeExactly "Starting the $Name process $StopKeyword the $Name process with PID $( $BackgroundProcess.Process.Id ) Killed the $Name process with PID $( $BackgroundProcess.Process.Id ) "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
    
            Context 'Nested process creation' {
                BeforeEach {
                    $TemporaryFileCheckEnabled = $false
                    $Name = "NestedProcess"
                    $TemporaryFileName = $Name + "_" + [Guid]::NewGuid().ToString()
                    $TaskStartInfo.ArgumentList = "-Command", "Start-Process -NoNewWindow powershell -ArgumentList '-Command', 'New-Item -Path (`$env:TEMP + ''\'' + ''$TemporaryFileName'') > `$null ; while (`$true) { Start-Sleep 1 }' -Wait"
                   
                    function Wait-TemporaryFile {
                        $Timer = 0
    
                        while (-not(Test-Path "$env:TEMP\$TemporaryFileName")) {
                            Start-Sleep 1
    
                            if ($Timer -ge 5) {
                                throw [System.IO.FileNotFoundException]::new("The file $env:TEMP\$TemporaryFileName was not created by the nested process within the timeout interval")
                            }
    
                            $Timer++
                        }
                    }

                    $BackgroundProcess = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildProcess($TaskStartInfo, $Name)
                }
    
                AfterEach {
                    Remove-Item "$env:TEMP\$TemporaryFileName"
                }
    
                It "creates the process that starts a nested process, starts it and stops the process tree : force kill = <stopcallalreadyexecuted>" {
                    $BackgroundProcess.Start()
                    $BackgroundProcess.IsAlive() | Should -BeTrue
                    $BackgroundProcess.Process.HasExited | Should -BeFalse
                    { Wait-TemporaryFile } | Should -Not -Throw System.IO.FileNotFoundException
                    $BackgroundProcess.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $BackgroundProcess.Stop() | Should -BeExactly 0
                    $BackgroundProcess.Process.HasExited | Should -BeTrue 
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeExactly $ExpectedStopCallState
                    $TestOutput | Should -Match "Starting the $Name process $StopKeyword the $Name process with PID $( $BackgroundProcess.Process.Id ) (Killing the process with PID [0-9]+ ?)+ Killed the $Name process with PID $( $BackgroundProcess.Process.Id ) "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Process start with temporary file check' {
                BeforeEach {
                    $TemporaryFileCheckEnabled = $true
                    $Name = "TmpProcessCheckProcess"
                    $BackgroundProcess = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildProcess($TaskStartInfo, $Name)
                }
    
                It "starts the process that creates a temporary file, and waits for the process to stop when the file is deleted : force kill = <stopcallalreadyexecuted>" {
                    $BackgroundProcess.TemporaryFileCheckEnabled | Should -BeTrue
                    $BackgroundProcess.CheckedTemporaryFileExistence | Should -BeFalse
                    $BackgroundProcess.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitUncompleted)
                    $BackgroundProcess.TaskStartInfo.ArgumentList = "-Command", "`$Counter = 0; `$TemporaryFilePath = `$env:TEMP + '\' + '$($BackgroundProcess.TemporaryFileName)' ; New-Item -Path `$TemporaryFilePath -ItemType File > `$null; while (Test-Path `$TemporaryFilePath) { Start-Sleep 1 }; while (`$Counter -le 5) { Start-Sleep 1; `$Counter++; }"
                    $BackgroundProcess.Start()
                    $BackgroundProcess.IsAlive() | Should -BeTrue
                    $BackgroundProcess.Process.HasExited | Should -BeFalse 
                    $BackgroundProcess.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $BackgroundProcess.Stop() | Should -BeExactly 0
                    $BackgroundProcess.Process.HasExited | Should -BeTrue
                    $BackgroundProcess.CheckedTemporaryFileExistence | Should -BeTrue
                    $BackgroundProcess.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitCompleted)
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeExactly $ExpectedStopCallState
                    "$env:TEMP\$($BackgroundProcess.TemporaryFileName)" | Should -Not -Exist
                    $TestOutput | Should -BeExactly "Starting the $Name process $StopKeyword the $Name process with PID $( $BackgroundProcess.Process.Id ) Waiting for $Name to create the $env:TEMP\$( $BackgroundProcess.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds) $StoppedKeyword the $Name process with PID $( $BackgroundProcess.Process.Id ) "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }

        Context 'Error cases' -Tag ErrorCases {
            Context 'Critical start error' {
                BeforeEach {
                    Mock Start-Process {
                        throw "Fatal error"
                    }

                    $BackgroundProcess = [BackgroundTaskFactory]::new($false).buildProcess(@{
                        FilePath = "process"
                    }, "CriticalStartFailTestProcess")
                }

                It "raises an exception since the process failed to start" {
                    { $BackgroundProcess.Start() } | Should -Throw -ExceptionType ([StartBackgroundProcessException])
                    $BackgroundProcess.IsAlive() | Should -BeFalse
                    $BackgroundProcess.Stop() | Should -BeExactly 0
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundProcess.Name ) process "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Critical stop error' {
                BeforeEach {
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; IsAlive = $true }
                    }

                    Invoke-Expression @'
class MockedBackgroundProcess: BackgroundProcess {
    MockedBackgroundProcess([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {}
    
    hidden [Void] StopProcessTree() {
        throw [StopBackgroundProcessException]::new("Failed to kill the process")
    }
}
'@

                    Invoke-Expression @'
class MockedBackgroundTaskFactory: BackgroundTaskFactory {
    MockedBackgroundTaskFactory([Boolean] $TemporaryFileCheckEnabled) : base($TemporaryFileCheckEnabled) {}

    [BackgroundTask] buildProcess([Hashtable] $ProcessStartInfo, [String] $Name) {
        return [MockedBackgroundProcess]::new($ProcessStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }
}
'@

                    $BackgroundProcess = [MockedBackgroundTaskFactory]::new($false).buildProcess(@{
                        FilePath = "process"
                    }, "CriticalStopFailTestProcess")
                }

                It "raises an exception when the process stops because the process stop fails" {
                    $BackgroundProcess.Start()
                    $BackgroundProcess.IsAlive() | Should -BeTrue
                    { $BackgroundProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException])
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundProcess.Name ) process Stopping the $( $BackgroundProcess.Name ) process with PID $( $BackgroundProcess.Process.Id ) "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Temporary file sync fail' {
                Context 'Process has already exited' {
                    BeforeEach {
                        Mock Start-Process {
                            return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; IsAlive = $true }
                        }

                        Mock Remove-Item { }

                        Invoke-Expression @'
class MockedBackgroundProcess: BackgroundProcess {
    MockedBackgroundProcess([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {}

    [Int] SyncWithTemporaryFile() {
        return $this.SyncWithTemporaryFile({
            return $true
        }, [BackgroundTask]::TemporaryFileWaitTimeout)
    }
}
'@

                        Invoke-Expression @'
class MockedBackgroundTaskFactory: BackgroundTaskFactory {
    MockedBackgroundTaskFactory([Boolean] $TemporaryFileCheckEnabled): base($TemporaryFileCheckEnabled) {}

    [BackgroundTask] buildProcess([Hashtable] $ProcessStartInfo, [String] $Name) {
        return [MockedBackgroundProcess]::new($ProcessStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }
}
'@
                        $BackgroundProcess = [MockedBackgroundTaskFactory]::new($true).buildProcess(@{
                            FilePath = "process"
                        }, "ProcessHasAlreadyExitedTestProcess")
                    }

                    It "stops early since the process has already exited while trying to check for a temporary file" {
                        $BackgroundProcess.Start()
                        $BackgroundProcess.IsAlive() | Should -BeTrue
                        $BackgroundProcess.Stop() | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                        $BackgroundProcess.StopCallAlreadyExecuted | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $BackgroundProcess.Name ) process Stopping the $( $BackgroundProcess.Name ) process with PID $( $BackgroundProcess.Process.Id ) Waiting for $( $BackgroundProcess.Name ) to create the $env:TEMP\$( $BackgroundProcess.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds) "
                        $TestWarningOutput | Should -BeExactly "$( $BackgroundProcess.Name ) has already exited "
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }
            }

            Context 'Temporary file creation timeout' {
                BeforeEach {
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; IsAlive = $true }
                    }
                    Mock Start-Sleep {}
                    Mock Remove-Item {}

                    Invoke-Expression @'
class MockedBackgroundProcessTwo: BackgroundProcess {
    MockedBackgroundProcessTwo([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {}

    [Int] StopProcessTree() {
        return 0
    }

    [Int] SyncWithTemporaryFile() {
        return $this.SyncWithTemporaryFile({
            return $false
        }, [BackgroundTask]::TemporaryFileWaitTimeout)
    }
}
'@

                    Invoke-Expression @'
class MockedBackgroundTaskFactoryTwo: BackgroundTaskFactory {
    MockedBackgroundTaskFactoryTwo([Boolean] $TemporaryFileCheckEnabled): base($TemporaryFileCheckEnabled) {}

    [BackgroundTask] buildProcess([Hashtable] $ProcessStartInfo, [String] $Name) {
        return [MockedBackgroundProcessTwo]::new($ProcessStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }
}
'@

                    $BackgroundProcess = [MockedBackgroundTaskFactoryTwo]::new($true).buildProcess(@{
                        FilePath = "process"
                    }, "ProcessTemporaryFileCreationTimeoutTestProcess")
                }

                It "executes a force kill since the temporary file creation has timed out" {
                    $BackgroundProcess.Start()
                    $BackgroundProcess.IsAlive() | Should -BeTrue
                    $BackgroundProcess.Stop() | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitTimeoutError)
                    $BackgroundProcess.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundProcess.Name ) process Stopping the $( $BackgroundProcess.Name ) process with PID $( $BackgroundProcess.Process.Id ) Waiting for $( $BackgroundProcess.Name ) to create the $env:TEMP\$( $BackgroundProcess.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds) Killed the $( $BackgroundProcess.Name ) process with PID $( $BackgroundProcess.Process.Id ) "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeExactly "Failed to wait for the creation of the $env:TEMP\$( $BackgroundProcess.TemporaryFileName ) file "
                }
            }
        }
    }
}