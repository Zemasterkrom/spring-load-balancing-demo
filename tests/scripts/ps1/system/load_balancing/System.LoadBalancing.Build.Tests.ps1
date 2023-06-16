BeforeDiscovery {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\..\Import-Code.ps1
}

Describe 'System build (Load Balancing)' {
    BeforeEach {
        Mock cmd {
            throw "Unavailable"
        }

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
        [Runner]::AutoChooseSystemStack()
        [Runner]::ConfigureEnvironmentVariables()
        [Runner]::Build()
    }
}
'@

        $global:CONSISTENT_BUILD_STATE = $null
        Reset-TestOutput
    }

    Context 'Disabled build' -Tag DisabledBuild {
        BeforeEach {
            [Runner]::Main(@("--no-build", "--no-start"))
        }
        
        It "does not trigger package building since the build mode is disabled" {
            $TestOutput | Should -BeNullOrEmpty
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }

    Context 'Abstract (mocked) build behavior' -Tag AbstractBuild {
        BeforeEach {
            Mock Invoke-And {
                if ("$args" -match "loadbalancer") {
                    $global:CONSISTENT_BUILD_STATE = $true
                } elseif ("$args" -match "config") {
                    $global:CONSISTENT_BUILD_STATE = $false
                }
            }

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

        Context 'Packages check behavior check' {
            Context 'Missing packages auto-detection' {
                BeforeEach {
                    Mock Test-Path {
                        return $false
                    }
                    
                    [MockedRunner]::Main(@("--no-build"))
                }

                It 'should enable the build mode since some packages are not built and start mode is enabled' {
                    $global:CONSISTENT_BUILD_STATE | Should -BeTrue
                    $TestOutput | Should -Match "Auto-choosing the launch method ...;Java version 17.0;0\r\n|\r|\nMaven \(mvn\) version 3.5.0\r\n|\r|\nNode version 16.0.0;Reading environment variables ...;Environment auto-configuration ...;Load Balancing packages are not completely built. Build mode enabled.;Building packages ...;"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Missing packages auto-detection (no missing packages)' {
                BeforeEach {
                    Mock Test-Path {
                        return $true
                    }

                    [MockedRunner]::Main(@("--no-build"))
                }

                It 'should not trigger the build of the packages since the required packages are present' {
                    $global:CONSISTENT_BUILD_STATE | Should -BeNullOrEmpty
                    $TestOutput | Should -Match "Auto-choosing the launch method ...;Java version 17.0\r\n|\r|\nMaven \(mvn\) version 3.5.0\r\n|\r|\nNode version 16.0.0;Reading environment variables ...;Environment auto-configuration ...;"
                    $TestOutput | Should -Not -Match "Building"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }

            Context 'Build by default' {
                BeforeEach {
                    Mock Test-Path {
                        return $true
                    }

                    [Runner]::Main(@("--no-start"))
                }

                It 'should process the build even if there are not any changes in the project' {
                    $global:CONSISTENT_BUILD_STATE | Should -BeTrue
                    $TestOutput | Should -Match "Auto-choosing the launch method ...;Java version 17.0.0\r\n|\r|\nMaven \(mvn\) version 3.5.0\r\n|\r|\nNode version 16.0.0;Building packages ...;"
                    $TestWarningOutput | Should -BeNullOrEmpty
                    $TestErrorOutput | Should -BeNullOrEmpty
                }
            }
        }
    }

    Context 'Concrete build behavior check' -Tag ConcreteBuild {
        BeforeEach {
            Mock mvn {
                if ($args -match "version") {
                    $MvnVersionJob = Start-Job { mvn -version }
                    return Receive-Job $MvnVersionJob -Wait
                } else {
                    $MvnProcess = Start-Process mvn -NoNewWindow -RedirectStandardOutput NUL -ArgumentList "$args" -Wait -PassThru

                    if ($MvnProcess.ExitCode -ne 0) {
                        throw "Fatal Maven error"
                    }
                }
            }

            Mock npm {
                $NpmProcess = Start-Process npm -NoNewWindow -RedirectStandardOutput NUL -ArgumentList "$args" -Wait -PassThru
            
                if ($NpmProcess.ExitCode -ne 0) {
                    throw "Fatal npm error"
                }
            }

            [Runner]::Main(@("--no-start"))
        }

        It "builds the packages and images correctly" {
            $TestOutput | Should -Match "Auto-choosing the launch method ..."
            $TestOutput | Should -Match "Java version.*\s*Maven \(mvn\) version.*\s*Node version"
            $TestOutput | Should -Match "Building"
            $TestWarningOutput | Should -BeNullOrEmpty
            $TestErrorOutput | Should -BeNullOrEmpty
        }
    }
}