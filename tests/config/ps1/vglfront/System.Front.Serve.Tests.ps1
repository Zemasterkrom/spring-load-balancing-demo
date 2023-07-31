BeforeDiscovery {
    $env:LOAD_CORE_ONLY = $true
    . $PSScriptRoot\..\..\..\..\vglfront\server\no-docker\serve.ps1
}

BeforeAll {
    $global:InitLocation = Get-Location
    $env:LOAD_CORE_ONLY = $true
    Set-Location $PSScriptRoot
    . $PSScriptRoot\..\..\..\..\vglfront\server\no-docker\serve.ps1
}

Describe 'Front server handling' {
    BeforeEach {
        Mock Invoke-ExitScript {
            Param(
                [Parameter(Position = 0, Mandatory = $false)] [Byte] $ExitCode = 0
            )
        }
                
        Mock Write-Information {}

        Mock Write-Error {}

        function Assert-ProcessesAreStopped {
            return (Get-CimInstance Win32_Process -Filter "ParentProcessId = $PID" | Where-Object { $_.Name -notmatch "conhost" }).Length -eq 0
        }

        function Assert-AtInitialLocation {
            return "$PWD" -eq $InitialLocation
        }
    }

    Context 'Abstract (mocked) behavior' -Tag AbstractRun {
        BeforeEach {
            Mock Stop-ProcessTree {}

            Mock Remove-Item {}

            Mock Test-Path {
                if ($Path -match "environment\.js$") {
                    return $true
                }

                return $false
            }

            Mock New-Item {}

            Mock Set-Content {}

            Mock Get-Content {}

            Mock node {}
        }

        Context 'Successful start' {
            BeforeEach {
                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                }

                Mock Write-Information {}
            }

            Context 'With temporary file' {
                BeforeEach {
                    $global:TMP_RUNNER_FILE_BACKUP = $env:TMP_RUNNER_FILE
                    $env:TMP_RUNNER_FILE = "TMP_RUNNER_FILE"
                    Start-Server
                }

                AfterEach {
                    $env:TMP_RUNNER_FILE = $global:TMP_RUNNER_FILE_BACKUP
                    $global:CleanupCompleted = $false
                }

                It 'handles the front server successfully' {
                    Should -Invoke Test-Path -Times 1 -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                    Should -Invoke Stop-ProcessTree -Times 1
                    Should -Invoke Set-Content -Times 1 -ParameterFilter { $Path -eq ".env" }
                    Should -Invoke New-Item -Times 1 -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                    Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -match "environment\.js$" }
                    Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 130 }
                    Assert-ProcessesAreStopped | Should -BeTrue
                    Assert-AtInitialLocation | Should -BeTrue
                }
            }

            Context 'Without temporary file' {
                BeforeEach {
                    Mock Wait-Process {}

                    $global:TMP_RUNNER_FILE_BACKUP = $env:TMP_RUNNER_FILE
                    $env:TMP_RUNNER_FILE = ""
                    Start-Server
                }

                AfterEach {
                    $env:TMP_RUNNER_FILE = $global:TMP_RUNNER_FILE_BACKUP
                    $global:CleanupCompleted = $false
                }

                It 'handles the front server successfully' {
                    Should -Not -Invoke Test-Path -Times 2 -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                    Should -Invoke Wait-Process -Times 1
                    Should -Invoke Stop-ProcessTree -Times 1
                    Should -Invoke Set-Content -Times 1 -ParameterFilter { $Path -eq ".env" }
                    Should -Not -Invoke New-Item -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                    Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -match "environment\.js$" }
                    Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 130 }
                    Assert-ProcessesAreStopped | Should -BeTrue
                    Assert-AtInitialLocation | Should -BeTrue
                }
            }
        }

        Context 'Failed start' {
            BeforeEach {
                Mock Wait-Process {}

                Mock Start-Process {
                    throw "Start error"
                }

                $global:TMP_RUNNER_FILE_BACKUP = $env:TMP_RUNNER_FILE
                $env:TMP_RUNNER_FILE = ""
                Start-Server
            }

            AfterEach {
                $env:TMP_RUNNER_FILE = $global:TMP_RUNNER_FILE_BACKUP
                $global:CleanupCompleted = $false
            }

            It 'triggers the cleanup because the process has already exited for an unknown reason' {
                Should -Not -Invoke Test-Path -Times 2 -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                Should -Not -Invoke Wait-Process -Times 1
                Should -Invoke Stop-ProcessTree -Times 1
                Should -Invoke Set-Content -Times 1 -ParameterFilter { $Path -eq ".env" }
                Should -Not -Invoke New-Item -ParameterFilter { $Path -eq "$env:TEMP\$( $env:TMP_RUNNER_FILE )" }
                Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -match "environment\.js$" }
                Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 3 }
                Assert-ProcessesAreStopped | Should -BeTrue
                Assert-AtInitialLocation | Should -BeTrue
            }
        }
    }
    
    Context 'Concrete run without front server start' -Tag ConcreteRun {
        Context 'With temporary file' {
            BeforeEach {
                Mock Start-FrontServer {
                    New-Item -Type File "$env:TEMP\$( $env:TMP_RUNNER_FILE )" > $null
                    return Start-Process powershell -NoNewWindow -ArgumentList "-Command", 'while ($true) { Start-Sleep 1 }' -PassThru
                }

                Mock Test-Path {
                    $global:TestPathCount++

                    if ($global:TestPathCount -eq 1) {
                        return $false
                    }

                    return $true
                } -ParameterFilter { $Path -eq "$env:TEMP\$env:TMP_RUNNER_FILE" }

                $global:TMP_RUNNER_FILE_BACKUP = $env:TMP_RUNNER_FILE
                $env:TMP_RUNNER_FILE = "Test_$((Get-Date -UFormat "%s") -replace ",.*", '')"
                Start-Server
            }

            AfterEach {
                $env:TMP_RUNNER_FILE = $global:TMP_RUNNER_FILE_BACKUP
            }

            It 'handles the front server successfully' {
                Get-Content "..\..\..\..\vglfront\.env" | Should -Not -Match "^TMP_RUNNER_FILE"
                "$env:TEMP\$env:TMP_RUNNER_FILE" | Should -Not -Exist
                "$env:TEMP\$($env:TMP_RUNNER_FILE)_2" | Should -Not -Exist
                "..\..\..\..\vglfront\src\assets\environment.js" | Should -Not -Exist
                Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 130 }
                Assert-ProcessesAreStopped | Should -BeTrue
                Assert-AtInitialLocation | Should -BeTrue
            }
        }
    }
}