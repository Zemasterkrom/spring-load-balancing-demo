BeforeDiscovery {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

BeforeAll {
    Set-Location $PSScriptRoot
    . $PSScriptRoot\..\..\Import-Code.ps1
}

Describe 'System run (no Load Balancing)' {
    BeforeEach {
        Mock cmd {
            throw "Unavailable"
        }

        Mock Invoke-ExitScript {
            Param(
                [Parameter(Position = 0, Mandatory = $false)] [Byte] $ExitCode = 0
            )
        }

        $global:CONSISTENT_BUILD_STATE = $true
        Reset-TestOutput
    }

    Context 'Disabled run' -Tag DisabledRun {
        BeforeEach {
            [Runner]::Main(@("--no-build", "--no-start", "--no-load-balancing"))
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
                    --load-core-only {
                        [Runner]::EnvironmentContext.EnableLoadCoreOnlyMode($true)
                    }
                }
            }
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(1)
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }

        if (-not([Runner]::EnvironmentContext.LoadCoreOnly)) {
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

            Mock java {
                return "Java version 17.0"
            }

            Mock mvn {
                return "Maven version 3.5"
            }

            Mock node {
                return "Node version 16.0"
            }
        }

        Context 'Run mode enabled' {
            BeforeEach {
                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $true }
                }

                Mock Test-Path {
                    return $true
                } -ParameterFilter { $args -notmatch "env" }

                Mock Remove-Item {}
                Mock Stop-Process {}
                Mock Wait-Process {}

                [MockedRunner]::Main(@("--no-build", "--no-load-balancing"))
            }

            It 'checks that the run stage is triggered' {
                $TestOutput | Should -Match "Launching services ...;Starting the VglConfig process;Starting the VglServiceOne process;"
                $TestOutput | Should -Not -Match "VglServiceTwo|VglLoadBalancer|VglDiscovery"
                $TestOutput | Should -Not -Match "Launching Docker services ..."
                [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 3
                Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 3 }
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Concrete run behavior check' -Tag ConcreteRun {
        BeforeEach {
            function Assert-ProcessesAreStopped {
                foreach ($Task in [Runner]::Tasks) {
                    if ($Task.IsAlive()) {
                        return $false
                    }
                }

                return $true
            }

            function Assert-AtBaseLocation {
                return "$PWD" -eq ([Runner]::EnvironmentContext.InitialPath)
            }

            Mock Watch-CleanupShortcut {
                if (-not($global:CleanupTriggered)) {
                    $global:CleanupTriggered = $true
                    return $true
                }

                return $false
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

            [Runner]::Main(@("--no-load-balancing"))
        }

        AfterEach {
            $global:CleanupTriggered = $false
        }

        It 'starts the demonstration without Docker and stops it successfully' {
            $TestOutput | Should -Match "Launching services ..."
            $TestOutput | Should -Not -Match "Launching Docker services ..."
            Get-Content "$PSScriptRoot\..\..\..\..\..\vglfront\.env" | Should -Not -Match "^TMP_RUNNER_FILE"
            "$PSScriptRoot\..\..\..\..\..\vglfront\src\assets\environment.js" | Should -Not -Exist
            [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 130
            Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 130 }
            Assert-ProcessesAreStopped | Should -BeTrue
            Assert-AtBaseLocation | Should -BeTrue
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }
}