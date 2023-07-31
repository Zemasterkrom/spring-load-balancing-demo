BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'BackgroundDockerComposeProcess' {
    BeforeEach {
        function Write-Array {
            if (($null -eq $args[0]) -or ($args[0] -isnot [Array])) {
                Write-Information "" 
            }

            $CompleteContent = ""

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

                $CompleteContent += "$Content$Separator"
            }

            Write-Information $CompleteContent
        }

        Reset-TestOutput
    }

    AfterEach {
        Reset-TestOutput
    }

    Context 'Success cases' -Tag SuccessCases -ForEach @(
        @{ TaskStartInfo = @{}; ExpectedProjectArgumentListDescription = ""; ExpectedStartArgumentsDescription = ""; ExpectedServicesDescription = "" }
        @{ TaskStartInfo = @{
            Services = @()
        }; ExpectedProjectArgumentListDescription = ""; ExpectedStartArgumentsDescription = ""; ExpectedServicesDescription = "";  }
        @{ TaskStartInfo = @{
            Services = @("TestService")
        }; ExpectedProjectArgumentListDescription = ""; ExpectedStartArgumentsDescription = ""; ExpectedServicesDescription = "TestService" }
        @{ TaskStartInfo = @{
            Services = @("TestServiceOne", "TestServiceTwo")
        }; ExpectedProjectArgumentListDescription = ""; ExpectedStartArgumentsDescription = ""; ExpectedServicesDescription = "TestServiceOne TestServiceTwo" }
        @{ TaskStartInfo = @{
            Services = @("TestServiceOne", "TestServiceTwo")
            ProjectName = "TestProject"
        }; ExpectedProjectArgumentListDescription = "-p TestProject"; ExpectedStartArgumentsDescription = ""; ExpectedServicesDescription = "TestServiceOne TestServiceTwo" }
        @{ TaskStartInfo = @{
            Services = @("TestServiceOne", "TestServiceTwo")
            ProjectName = "TestProject"
            StartArguments = @("StartArgument")
        }; ExpectedProjectArgumentListDescription = "-p TestProject"; ExpectedStartArgumentsDescription = "StartArgument"; ExpectedServicesDescription = "TestServiceOne TestServiceTwo" }
        @{ TaskStartInfo = @{
            Services = @("TestServiceOne", "TestServiceTwo")
            StartArguments = @("StartArgumentOne", "StartArgumentTwo")
        }; ExpectedProjectArgumentListDescription = ""; ExpectedStartArgumentsDescription = "StartArgumentOne StartArgumentTwo"; ExpectedServicesDescription = "TestServiceOne TestServiceTwo" }
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
        
                It "configures a Docker Compose (<dockercomposecli>) orchestrator process without starting it : expected project argument list description = <expectedprojectargumentlistdescription> ; expected start arguments description = <expectedstartargumentsdescription> ; expected service description = <expectedservicesdescription>" {
                    $DockerComposeProcess.DockerComposeCli.SystemStackComponents[0].Command -join " " | Should -BeExactly $DockerComposeCli
                    $DockerComposeProcess.TaskStartInfo.Services -join " " | Should -BeExactly $ExpectedServicesDescription
                    $DockerComposeProcess.TaskStartInfo.StartArguments -join " " | Should -BeExactly $ExpectedStartArgumentsDescription
                    $DockerComposeProcess.TaskStartInfo.ProjectArgumentList -join " " | Should -BeExactly $ExpectedProjectArgumentListDescription
                    $DockerComposeProcess.Name | Should -BeExactly "DockerComposeV2ProcessConfigurationTest"
                    $DockerComposeProcess.TemporaryFileCheckEnabled | Should -BeFalse
                    $DockerComposeProcess.IsAlive() | Should -BeFalse
                    $DockerComposeProcess.Stop() | Should -BeExactly 0
                    $DockerComposeProcess.ForceKillAtNextRequest | Should -BeFalse
                }
            }

            Context 'Orchestrator process handling' -ForEach @(
                @{ ForceKillAtNextRequest = $false; ExpectedStopCallState = $true }
                @{ ForceKillAtNextRequest = $true; ExpectedStopCallState = $true }
            ) {
                BeforeEach {
                    $global:DockerComposeCli = $DockerComposeCli

                    Mock cmd {
                        $global:LASTEXITCODE = 0

                        if ($args -match "stop|kill") {
                            Write-Array $args
                        }

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

                    Mock Wait-Process {
                        $_.HasExited = $true
                    }

                    Mock Stop-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $true }
                    }

                    Mock Remove-Item {}

                    $DockerComposeProcess = [BackgroundTaskFactory]::new($true).buildDockerComposeProcess($TaskStartInfo, "DockerComposeV2ProcessHandlingTest")
                
                    if (-not($ForceKillAtNextRequest)) {
                        $ExpectedRegularExpressionMatch = "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c $DockerComposeCli ? $ExpectedProjectArgumentListDescription stop $ExpectedServicesDescription -t $( $DockerComposeProcess.TaskStopInfo.StandardStopTimeout) 2>&1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                    } else {
                        $ExpectedRegularExpressionMatch = "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Killing the $( $DockerComposeProcess.Name ) Docker Compose services;/c $DockerComposeCli ? $ExpectedProjectArgumentListDescription kill $ExpectedServicesDescription 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                    }
                
                }
        
                It "configures a Docker Compose (<dockercomposecli>) orchestrator process, starts it and stops it : expected project argument list description = <expectedprojectargumentlistdescription> ; expected start arguments description = <expectedstartargumentsdescription> ; expected service description = <expectedservicesdescription> ; force kill = <forcekillatnextrequest>" {
                    $DockerComposeProcess.Start()
                    $DockerComposeProcess.IsAlive() | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.HasExited | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.ProcessName | Should -BeExactly $DockerComposeExecutable
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.StartInfo.ArgumentList | Should -BeExactly "$ExecutableDockerComposeArgument $ExpectedProjectArgumentListDescription $ExpectedStartArgumentsDescription up $ExpectedServicesDescription -d"
                    $DockerComposeProcess.DockerComposeServicesLogger.Process.HasExited | Should -BeFalse
                    $DockerComposeProcess.DockerComposeServicesLogger.Process.ProcessName | Should -BeExactly ($DockerComposeProcess.DockerComposeServicesOrchestrator.Process.ProcessName)
                    $DockerComposeProcess.DockerComposeServicesLogger.Process.StartInfo.ArgumentList | Should -BeExactly "$ExecutableDockerComposeArgument $ExpectedProjectArgumentListDescription $ExpectedStartArgumentsDescription up $ExpectedServicesDescription"
                    $DockerComposeProcess.ForceKillAtNextRequest = $ForceKillAtNextRequest
                    $DockerComposeProcess.Stop() | Should -BeExactly 0
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesOrchestrator.Process.HasExited | Should -BeTrue 
                    $DockerComposeProcess.DockerComposeServicesLogger.ForceKillAtNextRequest | Should -BeTrue
                    $DockerComposeProcess.DockerComposeServicesLogger.Process.HasExited | Should -BeTrue 
                    $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                    $TestOutput | Should -MatchExactly $ExpectedRegularExpressionMatch
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Error cases' -Tag ErrorCases {
        Context 'Invalid altered task start info' {
            BeforeEach {
                Mock cmd {
                    $global:LASTEXITCODE = 0
                    return "Docker Compose version 1.29"
                }

                $BackgroundJob = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "InvalidChangedTaskStartInfoTestDockerComposeProcess")
            }

            It "raises an exception since the task start info is inconsistent : services = <taskstartinfo.services> ; project name = <taskstartinfo.projectname> ; project argument list = <taskstartinfo.projectargumentlist> ; start arguments = <taskstartinfo.startarguments>" -ForEach @(
                @{ TaskStartInfo = @{
                    Services = $null
                } }

                @{ TaskStartInfo = @{
                    Services = $false
                } }

                @{ TaskStartInfo = @{
                    ProjectName = $null
                } }

                @{ TaskStartInfo = @{
                    ProjectName = $false
                } }

                @{ TaskStartInfo = @{
                    ProjectArgumentList = $null
                } }

                @{ TaskStartInfo = @{
                    ProjectArgumentList = $false
                } }

                @{ TaskStartInfo = @{
                    StartArguments = $null
                } }

                @{ TaskStartInfo = @{
                    StartArguments = $false
                } }
            ) {
                $BackgroundJob.TaskStartInfo = $TaskStartInfo
                { $BackgroundJob.Start() } | Should -Throw -ExceptionType ([InvalidOperationException])
            }

            It "raises an exception since the task start info is inconsistent in the pre-check stage : services = <taskstartinfo.services> ; project name = <taskstartinfo.projectname> ; project argument list = <taskstartinfo.projectargumentlist> ; start arguments = <taskstartinfo.startarguments>" -ForEach @(  
                @{ TaskStartInfo = @{
                    Services = $false
                } }

                @{ TaskStartInfo = @{
                    ProjectName = $false
                } }

                @{ TaskStartInfo = @{
                    ProjectArgumentList = $false
                } }

                @{ TaskStartInfo = @{
                    StartArguments = $false
                } }
            ) {
                { [BackgroundTaskFactory]::new($false).buildDockerComposeProcess($TaskStartInfo, "InvalidTaskStartInfoTestDockerComposeProcess") } | Should -Throw -ExceptionType System.InvalidOperationException
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

            Context 'Docker Compose services start error' {
                BeforeEach {
                    Mock cmd {
                        $global:LASTEXITCODE = 0
                        return "Docker Compose version 1.29"
                    }
                }

                Context 'Docker Compose orchestrator start error' {
                    BeforeEach {   
                        Mock Start-Process {
                            throw "Fatal error"
                        }
                        
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStartFailTestDockerComposeOrchestratorProcess")
                    }
    
                    It "raises an exception since the Docker Compose orchestrator process failed to start" {
                        { $DockerComposeProcess.Start() } | Should -Throw -ExceptionType ([StartBackgroundProcessException])
                        $DockerComposeProcess.IsAlive() | Should -BeFalse
                        $DockerComposeProcess.Stop() | Should -BeExactly 0
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;"
                        $TestWarningOutput | Should -BeNullOrEmpty
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }
    
                Context 'Docker Compose logger start error' {
                    BeforeEach {
                        $global:StartProcessCounter = 0

                        Mock Start-Process {
                            $global:StartProcessCounter++

                            if ($global:StartProcessCounter -eq 2) {
                                throw "Fatal error"
                            }

                            return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                        }

                        Mock Wait-Process {
                            $_.HasExited = $true
                        }

                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStartFailTestDockerComposeLoggerProcess")
                    }
    
                    It "raises an exception since the Docker Compose logger process failed to start" {
                        { $DockerComposeProcess.Start() } | Should -Throw -ExceptionType ([StartBackgroundProcessException])
                        $DockerComposeProcess.IsAlive() | Should -BeFalse
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.IsAlive() | Should -BeFalse
                        $DockerComposeProcess.DockerComposeServicesLogger.IsAlive() | Should -BeFalse
                        $DockerComposeProcess.Stop() | Should -BeExactly 0
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;"
                        $TestWarningOutput | Should -BeNullOrEmpty
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
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

                        Mock Stop-Process {
                            return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $true }
                        }
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "stops using the container kill method because the container stop method has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        $DockerComposeProcess.Stop() | Should -BeExactly ([BackgroundTask]::KilledDueToUnknownError)
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesLogger.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : . Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }

                Context 'Orchestrator process error' {
                    BeforeEach {
                        $global:StopCounter = 0
                        
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            
                            if ($args -match "version") {
                                return "Docker Compose version 1.29"
                            }
    
                            if ($args -match "stop|kill") {
                                Write-Array $args
                                return
                            }
                        }

                        Mock Stop-Process {
                            $global:StopCounter++

                            if ($global:StopCounter -eq 1) {
                                throw "Fatal stop error"
                            }
                        }

                        Mock Get-WmiObject {
                            return @()
                        }
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "stops services using the force kill operation by security because the orchestrator process kill has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        $DockerComposeProcess.Stop()  | Should -BeExactly ([BackgroundTask]::KilledDueToUnknownError)
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error. Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeExactly "Failed to kill the process with PID 1 : Fatal stop error;"
                    }
                }

                Context 'Logger process error' {
                    BeforeEach {
                        $global:StopCounter = 0
                        
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            
                            if ($args -match "version") {
                                return "Docker Compose version 1.29"
                            }
    
                            if ($args -match "stop|kill") {
                                Write-Array $args
                                return
                            }
                        }
                        Mock Stop-Process {
                            $global:StopCounter++

                            if ($global:StopCounter -eq 2) {
                                throw "Fatal stop error"
                            }
                        }
                        Mock Get-WmiObject {
                            return @()
                        }
    
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
    
                    It "stops services using the force kill operation by security because the logger process kill has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        $DockerComposeProcess.Stop()  | Should -BeExactly ([BackgroundTask]::KilledDueToUnknownError)
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : - Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error. Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeExactly "Failed to kill the process with PID 1 : Fatal stop error;"
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
                        { $DockerComposeProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException]) -ExpectedMessage "Docker Compose $( $DockerComposeProcess.Name ) services kill failed : "
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : . Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }

                Context 'Orchestrator process error' {
                    BeforeEach {
                        $global:StopCounter = 0

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
                            $global:StopCounter++

                            if (($global:StopCounter -ne 0) -and (($global:StopCounter % 2) -eq 1)) {
                                throw "Fatal stop error"
                            }
                        }

                        Mock Get-WmiObject {
                            return @()
                        }
        
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
        
                    It "fails because the Docker Compose orchestrator process kill has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        { $DockerComposeProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException]) -ExpectedMessage "Docker Compose $( $DockerComposeProcess.Name ) services kill failed : Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error"
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error. Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeExactly "Failed to kill the process with PID 1 : Fatal stop error;Failed to kill the process with PID 1 : Fatal stop error;"
                    }
                }

                Context 'Logger process error' {
                    BeforeEach {
                        Mock cmd {
                            $global:StopCounter = 0
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
                            $global:StopCounter++

                            if (($global:StopCounter -ne 0) -and (($global:StopCounter % 2) -eq 0)) {
                                throw "Fatal stop error"
                            }
                        }
                        Mock Get-WmiObject {
                            return @()
                        }
        
                        $DockerComposeProcess = [BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{}, "CriticalStopFailTestDockerComposeProcess")
                    }
        
                    It "fails because the Docker Compose logger process kill has failed" {
                        $DockerComposeProcess.Start()
                        $DockerComposeProcess.IsAlive() | Should -BeTrue
                        { $DockerComposeProcess.Stop() } | Should -Throw -ExceptionType ([StopBackgroundProcessException]) -ExpectedMessage "Docker Compose $( $DockerComposeProcess.Name ) services kill failed : - Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error"
                        $DockerComposeProcess.ForceKillAtNextRequest | Should -BeTrue
                        $DockerComposeProcess.DockerComposeServicesOrchestrator.ForceKillAtNextRequest | Should -BeTrue
                        $TestOutput | Should -BeExactly "Starting the $( $DockerComposeProcess.Name ) Docker Compose services;Starting the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process;Starting the $( $DockerComposeProcess.Name ) Docker Compose services logger;Starting the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process;Stopping the $( $DockerComposeProcess.Name ) Docker Compose services;/c docker compose  stop  -t $( [BackgroundTask]::StandardStopTimeout ) 2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Stopping the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;/c docker compose  kill  2>&1;Killing the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killed the $( $DockerComposeProcess.DockerComposeServicesOrchestrator.Name ) process with PID 1;Killing the $( $DockerComposeProcess.DockerComposeServicesLogger.Name ) process with PID 1;"
                        $TestWarningOutput | Should -BeExactly "Failed to stop a $( $DockerComposeProcess.Name ) Docker Compose process : Docker Compose $( $DockerComposeProcess.Name ) services stop failed : - Failed to kill the process tree of the process with PPID 1 : Failed to kill the process with PID 1 : Fatal stop error. Trying to kill the Docker Compose services and the logger process.;"
                        $TestErrorOutput | Should -BeExactly "Failed to kill the process with PID 1 : Fatal stop error;Failed to kill the process with PID 1 : Fatal stop error;"
                    }
                }
            }
        }
    }
}