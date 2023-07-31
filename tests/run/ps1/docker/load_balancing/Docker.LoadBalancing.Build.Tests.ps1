BeforeDiscovery {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

Describe 'Docker build (Load Balancing)' {
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

        Mock Invoke-ExitScript {}

        $global:CONSISTENT_BUILD_STATE = $null
        $global:CORRECT_BUILD_ENVIRONMENT = $false
        Reset-TestOutput
    }

    Context 'Disabled build' -Tag DisabledBuild {
        BeforeEach {
            [Runner]::Main(@("--no-build", "--no-start"))
        }
        
        It "does not trigger images building since the build mode is disabled" {
            $TestOutput | Should -BeNullOrEmpty
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }

    Context 'Abstract (mocked) build behavior' -Tag AbstractBuild {
        BeforeEach {
            Mock Invoke-And {
                if ("$args" -match "docker") {
                    $global:CORRECT_BUILD_ENVIRONMENT = $true

                    if (("$args" -match "build") -and ("$args" -notmatch "docker-compose-no-load-balancing.yml")) {
                        $global:CONSISTENT_BUILD_STATE = $true
                    } else {
                        $global:CONSISTENT_BUILD_STATE = $false
                    }
                }
            }

            Mock cmd {
                $global:LASTEXITCODE = 0

                if ("$args" -match "docker.* version") {
                    return "Docker Compose version v1.29.0"
                }
            }

            [Runner]::Main(@("--no-start"))
        }

        It 'checks that Docker is triggered' {
            $global:CORRECT_BUILD_ENVIRONMENT | Should -BeTrue
            $global:CONSISTENT_BUILD_STATE | Should -BeTrue
            $TestOutput | Should -Match "Building images and packages ..."
            $TestOutput | Should -Not -Match "Building packages ..."
            $TestWarningOutput | Should -BeNullOrEmpty
        }
    }

    Context 'Concrete build behavior check' -Tag ConcreteBuild {
        BeforeEach {
            Mock cmd {
                $global:LASTEXITCODE = 0
                
                if ($args -match "version") {
                    $CmdJob = Start-Job { cmd $args } -ArgumentList $args
                    return Receive-Job $CmdJob -Wait
                } else {
                    $CmdProcess = Start-Process cmd -NoNewWindow -RedirectStandardOutput NUL -ArgumentList "$args" -Wait -PassThru -WorkingDirectory "$PWD"

                    if ($CmdProcess.ExitCode -ne 0) {
                        throw "Fatal cmd error"
                    }
                }
            }

            [Runner]::Main(@("--no-start"))
        }

        It "builds the images correctly" {
            $TestOutput | Should -Match "Building images and packages ..."
            $TestOutput | Should -Not -Match "Building packages ..."
            [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 0
            Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 0 }
            $TestWarningOutput | Should -BeNullOrEmpty
        }
    }
}