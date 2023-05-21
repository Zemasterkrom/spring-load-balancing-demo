BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'BackgroundDockerComposeProcess' {
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

        function Write-Array {
            if (($null -eq $args[0]) -or ($args[0] -isnot [Array])) {
                Write-Information "" 
            }

            for ($i = 0; $i -lt $args[0].Length; $i++) {
                if ($args[0][$i] -is [Array]) {
                    $Content = "$($args[0][$i])"
                } else {
                    $Content = $args[0][$i]
                }

                if ($i -ne $args[0].Length - 1) {
                    $Separator = " "
                } else {
                    $Separator = ""
                }

                Write-Information $Content $Separator
            }
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

    Context 'Success cases' -ForEach @(
        @{ TaskStartInfo = @{}; ExpectedServicesDescription = "" }
        @{ TaskStartInfo = @{
            Services = @()
        }; ExpectedServicesDescription = "" }
        @{ TaskStartInfo = @{
            Services = @("TestService")
        }; ExpectedServicesDescription = "TestService" }
        @{ TaskStartInfo = @{
            Services = @("TestServiceOne", "TestServiceTwo")
        }; ExpectedServicesDescription = "TestServiceOne TestServiceTwo" }
    ) {
        Context 'CLI integration testing' -ForEach @(
            @{ DockerComposeExecutable = "docker"; DockerComposeCli = "docker compose"; ExecutableDockerComposeArgument = "compose" }
            @{ DockerComposeExecutable = "docker-compose"; DockerComposeCli = "docker-compose"; ExecutableDockerComposeArgument = "" }
        ){
            Context 'Orchestrator process creation' {
                BeforeEach {
                    $global:DockerComposeCli = $DockerComposeCli

                    Mock cmd {
                        if ($global:DockerComposeCli -eq "docker compose") {
                            $global:LASTEXITCODE = 0
                            return "Docker Compose version v1.29.0"
                        } else {
                            if ($args -match "docker info") {
                                $global:LASTEXITCODE = 0
                                return
                            }
    
                            if ($args -match "docker compose") {
                                $global:LASTEXITCODE = 1
                                return
                            }
    
                            if ($args -match "docker-compose") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version v1.29.0"
                            }
                        }
                    }
        
                    $DockerComposeProcess = [BackgroundTaskFactory]::new($true).buildDockerComposeProcess($TaskStartInfo, "DockerComposeV2ProcessConfigurationTest")
                }
        
                It "configures a Docker Compose (<dockercomposecli>) orchestrator process without starting it : <expectedservicesdescription>" {
                    $DockerComposeProcess.DockerComposeCli.SystemStackComponents[0].Command -join " " | Should -BeExactly $DockerComposeCli
                    $DockerComposeProcess.TaskStartInfo.Services -join " " | Should -BeExactly $ExpectedServicesDescription
                    $DockerComposeProcess.Name | Should -BeExactly "DockerComposeV2ProcessConfigurationTest"
                    $DockerComposeProcess.TemporaryFileCheckEnabled | Should -BeFalse
                    $DockerComposeProcess.IsAlive() | Should -BeFalse
                    $DockerComposeProcess.Stop() | Should -BeExactly 0
                    $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeFalse
                }
            }

            Context 'Orchestrator process handling' -ForEach @(
                @{ StopCallAlreadyExecuted = $false; StopKeyword = "Stopping"; StoppedKeyword = "Stopped"; ExpectedStopCallState = $true; ExpectedStopTimeout = [BackgroundTask]::StandardStopTimeout }
                @{ StopCallAlreadyExecuted = $true; StopKeyword = "Killing";  StoppedKeyword = "Killed"; ExpectedStopCallState = $true; ExpectedStopTimeout = [BackgroundTask]::KillTimeout }
            ) {
                BeforeEach {
                    $global:DockerComposeCli = $DockerComposeCli

                    Mock cmd {
                        $global:LASTEXITCODE = 0

                        Write-Array $args

                        if ($args -match "version") {
                            if ($global:DockerComposeCli -eq "docker compose") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version v1.29.0"
                            } else {
                                if ($args -match "docker info") {
                                    $global:LASTEXITCODE = 0
                                    return
                                }
        
                                if ($args -match "docker compose") {
                                    $global:LASTEXITCODE = 1
                                    return
                                }
        
                                if ($args -match "docker-compose") {
                                    $global:LASTEXITCODE = 0
                                    return "Docker Compose version v1.29.0"
                                }
                            }
                        }
                    }
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false; ProcessName = $FilePath; StartInfo = @{ 
                            ArgumentList = "$($ArgumentList)"
                        } }
                    }
                    Mock Wait-Process {}
                    Mock Stop-Process {}
                    Mock Remove-Item {}

                    $DockerComposeProcess = [BackgroundTaskFactory]::new($true).buildDockerComposeProcess($TaskStartInfo, "DockerComposeV2ProcessHandlingTest")
                }
        
                It "configures a Docker Compose (<dockercomposecli>) orchestrator process, starts it and stops it : <expectedservicesdescription>; force kill = <stopcallalreadyexecuted>" {
                    $DockerComposeProcess.Start()
                    $DockerComposeProcess.IsAlive() | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.HasExited | Should -BeFalse
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.ProcessName | Should -BeExactly $DockerComposeExecutable
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.StartInfo.ArgumentList | Should -BeExactly "$ExecutableDockerComposeArgument up $ExpectedServicesDescription -t $( [BackgroundTask]::StandardStopTimeout )"
                    $DockerComposeProcess.StopCallAlreadyExecuted = $StopCallAlreadyExecuted
                    $DockerComposeProcess.Stop() | Should -BeExactly 0
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.HasExited = $true
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.HasExited | Should -BeTrue 
                    $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeTrue
                    $TestOutput | Should -MatchExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process $StopKeyword the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process /c $DockerComposeCli ? stop $ExpectedServicesDescription -t $ExpectedStopTimeout 2>&1 $StopKeyword the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Error cases' {
        Context 'Invalid altered task start info' {
            BeforeEach {
                Mock cmd {
                    $global:LASTEXITCODE = 0
                    return "Docker Compose version 1.29"
                }

                $BackgroundJob = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "InvalidChangedTaskStartInfoTestDockerComposeProcess")
            }

            It "raises an exception since the task start info is inconsistent" -ForEach @(
                @{ TaskStartInfo = @{
                    Services = $null
                } }

                @{ TaskStartInfo = @{
                    Services = $false
                } }

                @{ TaskStartInfo = @{
                    Services = @("TestService", "Invalid service name")
                } }

                @{ TaskStartInfo = @{
                    Services = @("Invalid service name")
                } }
            ) {
                $BackgroundJob.TaskStartInfo = $TaskStartInfo
                { $BackgroundJob.Start() } | Should -Throw -ExceptionType ([InvalidOperationException])
            }

            It "raises an exception since the task start info is inconsistent in the pre-check stage" -ForEach @(  
                @{ InvalidTaskStartInfo = @{
                    Services = $false
                } }

                @{ InvalidTaskStartInfo = @{
                    Services = @("TestService", "Invalid service name")
                } }

                @{ InvalidTaskStartInfo = @{
                    Services = @("Invalid service name")
                } }
            ) {
                { [BackgroundTaskFactory]::new($false).buildDockerComposeProcess($InvalidTaskStartInfo, "InvalidTaskStartInfoTestDockerComposeProcess") } | Should -Throw -ExceptionType System.InvalidOperationException
            }
        }

        Context 'Critical start error' {
            Context 'Docker Compose detection fail' {
                BeforeEach {
                    Mock cmd {
                        return $null
                    }
                }

                It "fails to create the Docker Compose task since there isn't any Docker Compose compatible version installed on the system" {
                    { [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "IncompatibleDockerComposeVersionTest") } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                }
            }

            Context 'Docker Compose orchestrator start error' {
                BeforeEach {
                    Mock cmd {
                        $global:LASTEXITCODE = 0
                        return "Docker Compose version 1.29"
                    }

                    Mock Start-Process {
                        throw "Fatal error"
                    }

                    $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStartFailTestDockerComposeProcess")
                }

                It "raises an exception since the Docker Compose orchestrator process failed to start" {
                    { $DockerComposeProcess.Start() } | Should -Throw -ExceptionType ([StartBackgroundProcessException])
                    $DockerComposeProcess.IsAlive() | Should -BeFalse
                    $DockerComposeProcess.Stop() | Should -BeExactly 0
                    $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process "
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }

        Context 'Critical stop error' {
            BeforeEach {
                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                }
                Mock Wait-Process {}
                Mock Remove-Item {}
            }

            Context 'Stop error' {
                Context 'Docker error' {
                    BeforeEach {                        
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            
                            if ($args -match "version") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version 1.29"
                            }
    
                            if ($args -match "stop") {
                                $global:LASTEXITCODE = 1
                                Write-Array $args
    
                                return
                            }
    
                            if ($args -match "kill") {
                                $global:LASTEXITCODE = 0
                                Write-Array $args
                                
                                return
                            }
                        }
                        Mock Stop-Process {}
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "stops using the container kill method because the container stop method has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        $DockerComposeProcess.Stop()  | Should -BeExactly ([BackgroundTask]::KilledDueToStopTimeout)
                        $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process Stopping the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process /c docker compose stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1 /c docker compose kill  2>&1 Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 "
                        $TestWarningOutput | Should -BeExactly "Failed to stop the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process : Docker Compose orchestrator process $( $DockerComposeProcess.Name ) stop failed. Trying to kill the Docker Compose orchestrator process. "
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }

                Context 'Orchestrator process error' {
                    BeforeEach {
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            
                            if ($args -match "version") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version 1.29"
                            }
    
                            if ($args -match "stop|kill") {
                                $global:KILL = $false
                                $global:LASTEXITCODE = 0
                                
                                if ($args -match "kill") {
                                    $global:KILL = $true
                                }

                                Write-Array $args
    
                                return
                            }
                        }
                        Mock Stop-Process {
                            if (-not($global:KILL)) {
                                throw "Fatal stop error"
                            }
                        }
                        Mock Get-WmiObject {
                            if (-not($global:KILL)) {
                                throw "Fatal stop error"
                            } else {
                                return [Object[]]@()
                            }
                        }
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "stops using the container kill operation because the container stop operation failed, but an error occurs when trying to kill the orchestrator process" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        $DockerComposeProcess.Stop()  | Should -BeExactly ([BackgroundTask]::KilledDueToStopTimeout)
                        $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process Stopping the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process /c docker compose stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1 Stopping the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 /c docker compose kill  2>&1 Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 "
                        $TestWarningOutput | Should -BeExactly "Failed to stop the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process : Unknown error occurred while trying to kill the process tree with PPID 1. Trying to kill the Docker Compose orchestrator process. "
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }
            }

            Context 'Fatal stop error' {
                Context 'Docker error' {
                    BeforeEach {
                        Mock Start-Process {
                            return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                        }
                        Mock Wait-Process {}
                        Mock Stop-Process {}
                        Mock Remove-Item {}
    
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            
                            if ($args -match "version") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version 1.29"
                            }
    
                            if ($args -match "stop|kill") {
                                $global:LASTEXITCODE = 1
                                Write-Array $args
    
                                return
                            }
                        }
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "fails because the last resort Docker operation to kill the Docker containers has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        { $DockerComposeProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException])
                        $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process Stopping the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process /c docker compose stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1 /c docker compose kill  2>&1 "
                        $TestWarningOutput | Should -BeExactly "Failed to stop the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process : Docker Compose orchestrator process $( $DockerComposeProcess.Name ) stop failed. Trying to kill the Docker Compose orchestrator process. "
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }

                Context 'Orchestrator process error' {
                    BeforeEach {
                        Mock cmd {
                            $global:LASTEXITCODE = 0

                            if ($args -match "version") {
                                $global:LASTEXITCODE = 0
                                return "Docker Compose version 1.29"
                            }
        
                            if ($args -match "stop|kill") {
                                $global:LASTEXITCODE = 0
                                Write-Array $args
        
                                return
                            }
                        }
                        Mock Stop-Process {
                            throw "Fatal stop error"
                        }
                        Mock Get-WmiObject {
                            throw "Fatal stop error"
                        }
        
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
        
                    It "fails because the Docker Compose orchestrator process kill has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        { $DockerComposeProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException])
                        $DockerComposeProcess.StopCallAlreadyExecuted | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process Stopping the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process /c docker compose stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1 Stopping the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 /c docker compose kill  2>&1 Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1 "
                        $TestWarningOutput | Should -BeExactly "Failed to stop the $( $DockerComposeProcess.Name ) Docker Compose orchestrator process : Unknown error occurred while trying to kill the process tree with PPID 1. Trying to kill the Docker Compose orchestrator process. "
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }
            }
        }
    }
}