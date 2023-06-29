BeforeDiscovery {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

Describe 'Docker run (Load Balancing)' {
    BeforeEach {
        Mock java {
            throw "Unavailable"
        }

        Mock mvn {
            throw "Unavailable"
        }

        Mock node {
            throw "Unavailable"
        }

        Mock npm {
            throw "Unavailable"
        }

        Mock Invoke-ExitScript {
            Param(
                [Parameter(Position = 0, Mandatory = $false)] [Byte] $ExitCode = 0
            )
        }

        Reset-TestOutput
    }

    Context 'Disabled run' -Tag DisabledRun {
        BeforeEach {
            [Runner]::Main(@("--no-build", "--no-start"))
        }

        It "checks that the demonstration isn't launched" {
            $TestOutput | Should -BeNullOrEmpty
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }

    Context 'Abstract (mocked) run behavior' -Tag AbstractRun {
        BeforeEach {
            Invoke-Expression @'
class MockedRunner: Runner {
    static [Void] Main([String[]] $Options) {
        try {
            [SystemStackDetector]::ChoosenSystemStack = $null
            [Runner]::EnvironmentContext = [EnvironmentContext]::new()
            [Runner]::Tasks = @()
    
            foreach ($Option in $Options) {
                switch ($Option) {
                    --no-start {
                        [Runner]::EnvironmentContext.EnableStart($false)
                    }
                    --no-build {
                        [Runner]::EnvironmentContext.EnableBuild($false)
                    }
                    --no-load-balancing {
                        [Runner]::EnvironmentContext.EnableLoadBalancing($false)
                        [Runner]::EnvironmentContext.SetEnvironmentFile("no-load-balancing.env", "UTF8")
                    }
                    --source-only {
                        [Runner]::EnvironmentContext.EnableSourceOnlyMode($true)
                    }
                }
            }
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(1)
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }

        if (-not([Runner]::EnvironmentContext.SourceOnly)) {
            if ((-not([Runner]::EnvironmentContext.Start))-and (-not([Runner]::EnvironmentContext.Build))) {
                break
            }

            [MockedRunner]::Run()
        }
    }

    hidden static [Void] Run() {
        try {
            [Runner]::Start()
        } finally {
            [Runner]::Cleanup([Runner]::EnvironmentContext.CleanupExitCode)
        }
    }
}
'@

            Mock Invoke-And {}

            Mock cmd {
                $global:LASTEXITCODE = 0
                
                if ("$args" -match "docker.* version") {
                    return "Docker Compose version v1.29.0"
                }
            }
        }

        Context 'Run mode enabled' {
            BeforeEach {
                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $true }
                }

                Mock Test-Path {
                    return $true
                }

                Mock Remove-Item {}
                Mock Stop-Process {}
                Mock Wait-Process {}

                [MockedRunner]::Main(@("--no-build"))
            }

            It 'checks that the run stage is triggered' {
                $TestOutput | Should -Match "Launching Docker services ...;Starting the LoadBalancingServices Docker Compose services;Starting the LoadBalancingServicesDockerComposeServicesOrchestrator process;Starting the LoadBalancingServices Docker Compose services logger;Starting the LoadBalancingServicesDockerComposeServicesLogger process;"
                $TestOutput | Should -Not -Match "Launching services ..."
                [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 3
                Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 3 }
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Concrete run behavior check' -Tag ConcreteRun {
        BeforeEach {
            function Assert-ContainersAreStopped {
                $RunningServices = (cmd /c "$([Runner]::Tasks[0].DockerComposeCli.SystemStackComponents[0].Command[0]) $([Runner]::Tasks[0].TaskStartInfo.DockerComposeProcessArgumentList) -p vglloadbalancing-enabled ps --filter status=running --services").Split([Environment]::NewLine)
                $RunningServices += (cmd /c "$([Runner]::Tasks[0].DockerComposeCli.SystemStackComponents[0].Command[0]) $([Runner]::Tasks[0].TaskStartInfo.DockerComposeProcessArgumentList) -p vglloadbalancing-enabled ps --filter status=restarting --services").Split([Environment]::NewLine)
                $RunningServices = $RunningServices | Where-Object { -not([String]::IsNullOrWhiteSpace($_)) } | Get-Unique
                $MatchedRunningServicesCounter = 0
                $TotalRunningServicesCounter = 0

                foreach ($RunningService in $RunningServices) {
                    switch -Regex ($RunningService) {
                        "^(vgldatabase|vglconfig|vgldiscovery|vglloadbalancer|vglfront|vglservice|vglservice-two)$" {
                            $TotalRunningServicesCounter++
                            $MatchedRunningServicesCounter++
                        }
                        default {
                            $TotalRunningServicesCounter++
                        }
                    }
                }

                return ($MatchedRunningServicesCounter -eq 0) -and ($TotalRunningServicesCounter -eq $MatchedRunningServicesCounter) -and (-not([Runner]::Tasks[0].IsAlive()))
            }

            function Assert-ContainersAreStarted {
                $RunningServices = (cmd /c "$([Runner]::Tasks[0].DockerComposeCli.SystemStackComponents[0].Command[0]) $([Runner]::Tasks[0].TaskStartInfo.DockerComposeProcessArgumentList) -p vglloadbalancing-enabled ps --filter status=running --services").Split([Environment]::NewLine)
                $RunningServices = $RunningServices | Where-Object { -not([String]::IsNullOrWhiteSpace($_)) } | Get-Unique
                $MatchedRunningServicesCounter = 0
                $TotalRunningServicesCounter = 0

                foreach ($RunningService in $RunningServices) {
                    switch -Regex ($RunningService) {
                        "^(vgldatabase|vglconfig|vgldiscovery|vglloadbalancer|vglfront|vglservice|vglservice-two)$" {
                            $TotalRunningServicesCounter++
                            $MatchedRunningServicesCounter++
                        }
                        default {
                            $TotalRunningServicesCounter++
                        }
                    }
                }

                if (-not($global:CleanupTriggered)) {
                    if (($MatchedRunningServicesCounter -eq 7) -and ($TotalRunningServicesCounter -eq $MatchedRunningServicesCounter)) {
                        $global:CleanupTriggered = $true
                        return $true
                    }

                    if ($MatchedRunningServicesCounter -ne 7) {
                        $global:CleanupTriggered = $true
                        $global:StartErrorMessage = "Some containers seem not to be started! Number of started containers : $MatchedRunningServicesCounter"
                        throw $global:StartErrorMessage
                    }

                    if ($TotalRunningServicesCounter -ne $MatchedRunningServicesCounter) {
                        $global:CleanupTriggered = $true
                        $global:StartErrorMessage = "The number of started Docker containers must not exceed 4 containers!"
                        throw $global:StartErrorMessage
                    }
                }
            }

            function Assert-AtBaseLocation {
                return "$PWD" -eq ([Runner]::EnvironmentContext.InitialPath)
            }

            Mock Watch-CleanupShortcut {
                return Assert-ContainersAreStarted
            }
            
            Mock Out-Host {}

            Mock Start-Process {
                Param(
                    [String] $FilePath,
                    [String] $RedirectStandardOutput,
                    [Switch] $NoNewWindow,
                    [Switch] $PassThru,
                    [String[]] $ArgumentList
                )

                $HashtablePSBoundParameters =  ([Hashtable]$PSBoundParameters)
                return Start-Process @HashtablePSBoundParameters -RedirectStandardOutput NUL
            } -ParameterFilter { $RedirectStandardOutput -ne "NUL" }
            
            [Runner]::Main(@())
        }

        AfterEach {
            $global:CleanupTriggered = $false
            $global:StartErrorMessage = ""
        }

        It 'starts the demonstration with Docker and stops it successfully' {
            $TestOutput | Should -Match "Launching Docker services ..."
            $TestOutput | Should -Not -Match "Launching services ..."
            $global:StartErrorMessage | Should -BeNullOrEmpty
            [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 130
            Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 130 }
            [Runner]::Tasks.Length | Should -BeExactly 1
            Assert-ContainersAreStopped | Should -BeTrue
            Assert-AtBaseLocation | Should -BeTrue
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }
}