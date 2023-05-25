BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'BackgroundJob' {
    BeforeEach {
        Reset-TestOutput
    }

    Context 'Infer default process properties from context' -Tag InferValues -ForEach @(
        @{ TaskStartInfo = @{} }
        @{ TaskStartInfo = @{
            ScriptBlock = $null
            ArgumentList = @()
        } }
        @{ TaskStartInfo = @{
            ScriptBlock = {}
            ArgumentList = $null
        } }
    ) {
        BeforeEach {
            $BackgroundJob = [BackgroundTaskFactory]::new($false).buildJob($TaskStartInfo, "InferCheck")
        }
        
        It "should deduce a default value correlated to the job start info script block / argument list" {
           $BackgroundJob.TaskStartInfo.ScriptBlock | Should -BeOfType ScriptBlock
           $BackgroundJob.TaskStartInfo.ArgumentList.Length | Should -BeExactly 0
        }
    }

    Context 'Success cases' -Tag SuccessCases {
        BeforeEach {
            $TaskStartInfo = @{}
        }

        Context 'Standard job creation without temporary file check' -ForEach @(
            @{ StopCallAlreadyExecuted = $false; StopKeyword = "Stopping"; StoppedKeyword = "Stopped"; ExpectedStopCallState = $true }
            @{ StopCallAlreadyExecuted = $true; StopKeyword = "Killing";  StoppedKeyword = "Killed"; ExpectedStopCallState = $true }
        ) {
            Context 'Basic job creation' {
                BeforeEach {
                    $TaskStartInfo.ScriptBlock = { powershell -Command 'while (`$true) { Start-Sleep 1 }' }
                    $TemporaryFileCheckEnabled = $false
                    $Name = "BasicJob"
                }
    
                It "creates the job without starting it : force kill = <stopcallalreadyexecuted>" {
                    $BackgroundJob = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildJob($TaskStartInfo, $Name)
                    $BackgroundJob.TaskStartInfo.ScriptBlock | Should -BeExactly $TaskStartInfo.ScriptBlock
                    $BackgroundJob.Name | Should -BeExactly $Name
                    $BackgroundJob.TemporaryFileCheckEnabled | Should -BeExactly $TemporaryFileCheckEnabled
                    $BackgroundJob.IsAlive() | Should -BeFalse
                    $BackgroundJob.Stop() | Should -BeExactly 0
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeFalse
                    $TestOutput | Should -BeNullOrEmpty
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
    
                It "creates the job, starts it and stops it" {
                    $BackgroundJob = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildJob($TaskStartInfo, $Name)
                    $BackgroundJob.Start()
                    $BackgroundJob.IsAlive() | Should -BeTrue
                    $BackgroundJob.Process.HasExited | Should -BeFalse
                    $BackgroundJob.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $BackgroundJob.Stop() | Should -BeExactly 0
                    $BackgroundJob.Process.HasExited | Should -BeTrue 
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeExactly $ExpectedStopCallState
                    $TestOutput | Should -BeExactly "Starting the $Name job;$StopKeyword the $Name job with PID $( $BackgroundJob.Process.Id );Killed the $Name job with PID $( $BackgroundJob.Process.Id );"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Job start with temporary file check' {
                BeforeEach {
                    $TaskStartInfo.ScriptBlock = {}
                    $TemporaryFileCheckEnabled = $true
                    $Name = "TmpJobCheckProcess"
                    $BackgroundJob = [BackgroundTaskFactory]::new($TemporaryFileCheckEnabled).buildJob($TaskStartInfo, $Name)
                }
    
                It "starts the job that creates a temporary file, and waits for the job to stop when the file is deleted : force kill = <stopcallalreadyexecuted>" {
                    $BackgroundJob.TemporaryFileCheckEnabled | Should -BeTrue
                    $BackgroundJob.CheckedTemporaryFileExistence | Should -BeFalse
                    $BackgroundJob.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitUncompleted)
                    $BackgroundJob.TaskStartInfo.ScriptBlock = { 
                        $Counter = 0
                        $TemporaryFilePath = "$env:TEMP\$($args[0])"
                        New-Item -Path $TemporaryFilePath -ItemType File > $null
                        while (Test-Path $TemporaryFilePath) {
                            Start-Sleep 1
                        } 
                        while ($Counter -le 2) {
                            Start-Sleep 1
                            $Counter++
                        }
                    }
                    $BackgroundJob.TaskStartInfo.ArgumentList = @($BackgroundJob.TemporaryFileName)
                    $BackgroundJob.Start()
                    $BackgroundJob.IsAlive() | Should -BeTrue
                    $BackgroundJob.Process.HasExited | Should -BeFalse 
                    $BackgroundJob.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $BackgroundJob.Stop() | Should -BeExactly 0
                    $BackgroundJob.Process.HasExited | Should -BeTrue
                    $BackgroundJob.CheckedTemporaryFileExistence | Should -BeTrue
                    $BackgroundJob.CheckedTemporaryFileExistenceState | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitCompleted)
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeExactly $ExpectedStopCallState
                    "$env:TEMP\$($BackgroundJob.TemporaryFileName)" | Should -Not -Exist
                    $TestOutput | Should -BeExactly "Starting the $Name job;$StopKeyword the $Name job with PID $( $BackgroundJob.Process.Id );Waiting for $Name to create the $env:TEMP\$( $BackgroundJob.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);$StoppedKeyword the $Name job with PID $( $BackgroundJob.Process.Id );"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Error cases' -Tag ErrorCases {
        Context 'Critical start error' {
            BeforeEach {
                Mock Start-Process {
                    throw "Fatal error"
                }

                $BackgroundJob = [BackgroundTaskFactory]::new($false).buildJob(@{
                    ScriptBlock = {}
                }, "CriticalStartFailTestJob")
            }

            It "raises an exception since the job failed to start" {
                { $BackgroundJob.Start() } | Should -Throw -ExceptionType ([StartBackgroundJobException])
                $BackgroundJob.IsAlive() | Should -BeFalse
                $BackgroundJob.Stop() | Should -BeExactly 0
                $TestOutput | Should -BeExactly "Starting the $( $BackgroundJob.Name ) job;"
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }

        Context 'Invalid altered task start info' {
            BeforeEach {
                $BackgroundJob = [BackgroundTaskFactory]::new($false).buildJob(@{
                    ScriptBlock = {}
                }, "InvalidChangedTaskStartInfoTestProcess")
            }

            It "raises an exception since the task start info is inconsistent" -ForEach @(
                @{ TaskStartInfo = @{} }
    
                @{ TaskStartInfo = @{
                    ScriptBlock = $null
                } }
    
                @{ TaskStartInfo = @{
                    ScriptBlock = $false
                } }
    
                @{ TaskStartInfo = @{
                    ScriptBlock = {}
                    ArgumentList = $null
                } }
    
                @{ TaskStartInfo = @{
                    ScriptBlock = {}
                    ArgumentList = $false
                } }
            ) {
                $BackgroundJob.TaskStartInfo = $TaskStartInfo
                { $BackgroundJob.Start() } | Should -Throw -ExceptionType ([InvalidOperationException])
            }

            It "raises an exception since the task start info is inconsistent in the pre-check stage" -ForEach @(  
                @{ InvalidTaskStartInfo = @{
                    ScriptBlock = $false
                } }
    
                @{ InvalidTaskStartInfo = @{
                    ScriptBlock = {}
                    ArgumentList = $false
                } }
            ) {
                { [BackgroundTaskFactory]::new($false).buildJob($InvalidTaskStartInfo, "InvalidTaskStartInfoTestProcess") } | Should -Throw -ExceptionType ([InvalidOperationException])
            }
        }

        Context 'Critical stop error' {
            Context 'Stop error' {
                BeforeEach {
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                    }
    
                    Mock Stop-Process {
                        throw "Failed to kill the job"
                    }
    
                    $BackgroundJob = [BackgroundTaskFactory]::new($false).buildJob(@{
                        ScriptBlock = {}
                    }, "CriticalStopFailTestJob")
                }
    
                It "raises an exception when the job stops because the job stop fails" {
                    $BackgroundJob.Start()
                    $BackgroundJob.IsAlive() | Should -BeTrue
                    { $BackgroundJob.Stop() } | Should -Throw -ExceptionType ([StopBackgroundJobException])
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundJob.Name ) job;Stopping the $( $BackgroundJob.Name ) job with PID $( $BackgroundJob.Process.Id );"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Wait error' {
                BeforeEach {
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                    }
    
                    Mock Stop-Process {
                        return $true
                    }

                    Mock Wait-Process {
                        throw "Failed to wait for the job to stop"
                    }
    
                    $BackgroundJob = [BackgroundTaskFactory]::new($false).buildJob(@{
                        ScriptBlock = {}
                    }, "CriticalStopWaitFailTestJob")
                }
    
                It "raises an exception when the job stops because the job stop fails" {
                    $BackgroundJob.Start()
                    $BackgroundJob.IsAlive() | Should -BeTrue
                    { $BackgroundJob.Stop() } | Should -Throw -ExceptionType ([StopBackgroundJobException])
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundJob.Name ) job;Stopping the $( $BackgroundJob.Name ) job with PID $( $BackgroundJob.Process.Id );"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }

        Context 'Temporary file sync fail' {
            Context 'Job has already exited' {
                BeforeEach {
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                    }

                    Mock Remove-Item { }

                    Invoke-Expression @'
class MockedBackgroundJob: BackgroundJob {
    MockedBackgroundJob([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {}

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

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [String] $Name) {
        return [MockedBackgroundJob]::new($JobStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }
}
'@
                    $BackgroundJob = [MockedBackgroundTaskFactory]::new($true).buildJob(@{
                        ScriptBlock = {}
                    }, "JobHasAlreadyExitedTestJob")
                }

                It "stops early since the job has already exited while trying to check for a temporary file" {
                    $BackgroundJob.Start()
                    $BackgroundJob.IsAlive() | Should -BeTrue
                    $BackgroundJob.Stop() | Should -BeExactly ([BackgroundTask]::ProcessHasAlreadyExited)
                    $BackgroundJob.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -BeExactly "Starting the $( $BackgroundJob.Name ) job;Stopping the $( $BackgroundJob.Name ) job with PID $( $BackgroundJob.Process.Id );Waiting for $( $BackgroundJob.Name ) to create the $env:TEMP\$( $BackgroundJob.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);"
                    $TestWarningOutput | Should -BeExactly "$( $BackgroundJob.Name ) has already exited;"
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }

        Context 'Temporary file creation timeout' {
            BeforeEach {
                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                }
                Mock Start-Sleep {}
                Mock Remove-Item {}
                Mock Stop-Process {}
                Mock Wait-Process {}

                Invoke-Expression @'
class MockedBackgroundJobTwo: BackgroundJob {
    MockedBackgroundJobTwo([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {}

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

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [String] $Name) {
        return [MockedBackgroundJobTwo]::new($JobStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }
}
'@
                $BackgroundJob = [MockedBackgroundTaskFactoryTwo]::new($true).buildJob(@{
                    ScriptBlock = {}
                }, "JobTemporaryFileCreationTimeoutTestJob")
            }

            It "executes a force kill since the temporary file creation has timed out" {
                $BackgroundJob.Start()
                $BackgroundJob.IsAlive() | Should -BeTrue
                $BackgroundJob.Stop() | Should -BeExactly ([BackgroundTask]::TemporaryFileWaitTimeoutError)
                $BackgroundJob.StopCallAlreadyExecuted | Should -BeTrue
                $TestOutput | Should -BeExactly "Starting the $( $BackgroundJob.Name ) job;Stopping the $( $BackgroundJob.Name ) job with PID $( $BackgroundJob.Process.Id );Waiting for $( $BackgroundJob.Name ) to create the $env:TEMP\$( $BackgroundJob.TemporaryFileName ) file ... ($( [BackgroundTask]::TemporaryFileWaitTimeout ) seconds);Killed the $( $BackgroundJob.Name ) job with PID $( $BackgroundJob.Process.Id );"
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeExactly "Failed to wait for the creation of the $env:TEMP\$( $BackgroundJob.TemporaryFileName ) file;"
            }
        }
    }
}