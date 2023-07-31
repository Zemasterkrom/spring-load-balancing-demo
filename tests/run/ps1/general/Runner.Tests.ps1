BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'Runner' {
    BeforeEach {
        Reset-TestOutput
    }

    Context 'Environment context configuration' -Tag EnvironmentContextConfiguration -ForEach @(
        @{ Options = @(); ExpectedOptions = @{
            Build = $true
            Start = $true
            LoadCoreOnly = $false
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 1 }

        @{ Options = @("--no-build"); ExpectedOptions = @{
            Build = $false
            Start = $true
            LoadCoreOnly = $false
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 1 }

        @{ Options = @("--no-build", "--no-start"); ExpectedOptions = @{
            Build = $false
            Start = $false
            LoadCoreOnly = $false
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 1 }

        @{ Options = @("--no-build", "--no-start", "--no-load-balancing"); ExpectedOptions = @{
            Build = $false
            Start = $false
            LoadCoreOnly = $false
            LoadBalancing = $false
            EnvironmentFilePath = "no-load-balancing.env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 1 }

        @{ Options = @("--load-core-only"); ExpectedOptions = @{
            Build = $true
            Start = $true
            LoadCoreOnly = $true
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 0 }

        @{ Options = @("--load-core-only", "--no-build"); ExpectedOptions = @{
            Build = $false
            Start = $true
            LoadCoreOnly = $true
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRun = 0 }

        @{ Options = @("--load-core-only", "--no-build", "--no-start"); ExpectedOptions = @{
            Build = $false
            Start = $false
            LoadCoreOnly = $true
            LoadBalancing = $true
            EnvironmentFilePath = ".env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 0 }

        @{ Options = @("--load-core-only", "--no-build", "--no-start", "--no-load-balancing"); ExpectedOptions = @{
            Build = $false
            Start = $false
            LoadCoreOnly = $true
            LoadBalancing = $false
            EnvironmentFilePath = "no-load-balancing.env"
            EnvironmentFileEncoding = "UTF8"
        }; ExpectedRunTimes = 0 }
    ) {
        BeforeEach {
            function Test-Call {}
            Mock Test-Call {}

            Invoke-Expression @'
class MockedRunner: Runner {
    static [Void] Main([String[]] $Options) {
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

        if (-not([Runner]::EnvironmentContext.LoadCoreOnly)) {
            [MockedRunner]::Run()
        }
    }

    hidden static [Void] Run() {
        Test-Call
    }
}
'@
        }

        It "configures the environment properties according to the options passed to the script : Build = <expectedoptions.build>; Start = <expectedoptions.start>; LoadCoreOnly = <expectedoptions.loadcoreonly>; LoadBalancing = <expectedoptions.loadbalancing>; ExpectedRunTimes = <expectedruntimes>" {
            [MockedRunner]::Main($Options)
            [MockedRunner]::EnvironmentContext.Build | Should -BeExactly $ExpectedOptions.Build
            [MockedRunner]::EnvironmentContext.Start | Should -BeExactly $ExpectedOptions.Start
            [MockedRunner]::EnvironmentContext.LoadCoreOnly | Should -BeExactly $ExpectedOptions.LoadCoreOnly
            [MockedRunner]::EnvironmentContext.LoadBalancing | Should -BeExactly $ExpectedOptions.LoadBalancing
            [MockedRunner]::EnvironmentContext.EnvironmentFilePath | Should -BeExactly $ExpectedOptions.EnvironmentFilePath
            [MockedRunner]::EnvironmentContext.EnvironmentFileEncoding | Should -BeExactly $ExpectedOptions.EnvironmentFileEncoding
            Should -Invoke Test-Call -Times $ExpectedRunTimes
        }
    }

    Context 'Environment variables auto-configuration' -Tag EnvironmentVariablesConfiguration {
        BeforeEach {
            Mock Invoke-ExitScript {}
            Mock cmd {
                $global:LASTEXITCODE = 0
                return "Docker Compose version 1.29"
            }
        }

        Context 'Successful automatic configuration' {
            Context 'Stack-independent configuration' -ForEach @(
                @{ SystemStack = [SystemStack]::new([SystemStackTag]::System, @(
                    [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0))
                    [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5))
                    [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0))
                )) }
    
                @{ SystemStack = [SystemStack]::new([SystemStackTag]::Docker, @(
                    [SystemStackComponent]::new("Docker Compose", "docker compose", [Version]::new(1, 29))
                )) }
            ) {
                Context 'General configuration' -ForEach @(
                    @{ LoadBalancing = $true }
                    @{ LoadBalancing = $false }
                ) {
                    BeforeEach {
                        $env:GIT_CONFIG_BRANCH = ""
                        $env:LOADBALANCER_HOSTNAME = ""
                        $env:API_HOSTNAME = ""
                        $env:API_TWO_HOSTNAME = ""
                        $env:CONFIG_SERVER_URL = ""
    
                        if ($LoadBalancing) {
                            [Runner]::Main(@("--load-core-only"))
                        } else {
                            [Runner]::Main(@("--load-core-only", "--no-load-balancing"))
                        }
    
                        [Runner]::EnvironmentContext.SetSystemStack($SystemStack)
                    }
    
                    It "auto-configures the environment variables with success : load balancing = <loadbalancing>" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:GIT_CONFIG_BRANCH | Should -Not -BeNullOrEmpty
                        $env:LOADBALANCER_HOSTNAME | Should -Not -BeNullOrEmpty
                        $env:API_HOSTNAME | Should -BeExactly $env:LOADBALANCER_HOSTNAME
                        $env:API_TWO_HOSTNAME | Should -BeExactly $env:LOADBALANCER_HOSTNAME
                        $env:CONFIG_SERVER_URL | Should -Not -BeNullOrEmpty
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("DB_URL") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("DB_USERNAME") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("DB_PASSWORD") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("DB_PORT") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("GIT_CONFIG_BRANCH") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("LOADBALANCER_HOSTNAME") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("API_HOSTNAME") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("API_TWO_HOSTNAME") | Should -BeTrue
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("CONFIG_SERVER_URL") | Should -BeTrue
                        $TestOutput | Should -BeExactly "Reading environment variables ...;Environment auto-configuration ...;"
                        $TestWarningOutput | Should -BeNullOrEmpty
                        $TestErrorOutput | Should -BeNullOrEmpty
                    }
                }
    
                Context 'Load Balancing mode' {
                    BeforeEach {
                        $env:EUREKA_SERVERS_URLS = ""
                        [Runner]::Main(@("--load-core-only"))
                        [Runner]::EnvironmentContext.SetSystemStack($SystemStack)
                    }
                
                    It "auto-configures the environment variables including the EUREKA_SERVERS_URLS variable" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:EUREKA_SERVERS_URLS | Should -Not -BeNullOrEmpty
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("EUREKA_SERVERS_URLS") | Should -BeTrue
                    }
                }
    
                Context 'No Load Balancing mode' {
                    BeforeEach {
                        $env:EUREKA_SERVERS_URLS = ""
                        [Runner]::Main(@("--load-core-only", "--no-load-balancing"))
                        [Runner]::EnvironmentContext.SetSystemStack($SystemStack)
                    }
                
                    It "auto-configures the environment variables with success without the EUREKA_SERVERS_URLS variable" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:EUREKA_SERVERS_URLS | Should -BeNullOrEmpty
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("EUREKA_SERVERS_URLS") | Should -BeFalse
                    }
                }
            }

            Context 'System-dependent configuration'  {
                Context 'General configuration' -ForEach @(
                    @{ LoadBalancing = $true }
                    @{ LoadBalancing = $false }
                ) {
                    BeforeEach {
                        if ($LoadBalancing) {
                            [Runner]::Main(@("--load-core-only"))
                        } else {
                            [Runner]::Main(@("--load-core-only", "--no-load-balancing"))
                        }
    
                        [Runner]::EnvironmentContext.SetSystemStack([SystemStack]::new([SystemStackTag]::System, @(
                            [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0))
                            [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5))
                            [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0))
                        )))
                    }
    
                    It "removes unnecessary environment variables as we are using a system dependent implementation : load balancing = <loadbalancing>" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:DB_URL | Should -BeNullOrEmpty
                        $env:DB_USERNAME | Should -BeNullOrEmpty
                        $env:DB_PASSWORD | Should -BeNullOrEmpty
                        $env:DB_PORT | Should -BeNullOrEmpty
                    }
                }

                Context 'Load Balancing mode' {
                    BeforeEach {
                        $env:EUREKA_SERVERS_URLS = ""
                        [Runner]::Main(@("--load-core-only"))
                        [Runner]::EnvironmentContext.SetSystemStack([SystemStack]::new([SystemStackTag]::System, @(
                            [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0))
                            [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5))
                            [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0))
                        )))
                    }
                
                    It "ensures that the EUREKA_SERVERS_URLS variable remains defined even if we are using a system implementation" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:EUREKA_SERVERS_URLS | Should -Not -BeNullOrEmpty
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("EUREKA_SERVERS_URLS") | Should -BeTrue
                    }
                }
    
                Context 'No Load Balancing mode' {
                    BeforeEach {
                        $env:EUREKA_SERVERS_URLS = ""
                        [Runner]::Main(@("--load-core-only", "--no-load-balancing"))
                        [Runner]::EnvironmentContext.SetSystemStack([SystemStack]::new([SystemStackTag]::System, @(
                            [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0))
                            [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5))
                            [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0))
                        )))
                    }
                
                    It "ensures that the EUREKA_SERVERS_URLS variable remains undefined even if we are using a system implementation" {
                        [Runner]::ConfigureEnvironmentVariables()
                        $env:EUREKA_SERVERS_URLS | Should -BeNullOrEmpty
                        [Runner]::EnvironmentContext.EnvironmentVariables.Contains("EUREKA_SERVERS_URLS") | Should -BeFalse
                    }
                }
            }
        }

        Context 'Fallback configuration' -Tag FallbackConfiguration -ForEach @(
            @{ LoadBalancing = $true }
            @{ LoadBalancing = $false }
        ) {
            BeforeEach {
                Mock Invoke-And {
                    if ($args -match "git") {
                        throw "git fatal error"
                    }
                }

                Mock hostname {
                    throw "hostname fatal error"
                }

                if ($LoadBalancing) {
                    [Runner]::Main(@("--load-core-only"))
                } else {
                    [Runner]::Main(@("--load-core-only", "--no-load-balancing"))
                }
            }

            It "configures the system-dependant properties using the system environment instead on relying on the environment file : load balancing = <loadbalancing>" {
                [Runner]::ConfigureEnvironmentVariables()
                $env:GIT_CONFIG_BRANCH | Should -BeExactly "master"
                $env:LOADBALANCER_HOSTNAME | Should -BeExactly "localhost"
                $env:API_HOSTNAME | Should -BeExactly $env:LOADBALANCER_HOSTNAME
                $env:API_TWO_HOSTNAME | Should -BeExactly $env:LOADBALANCER_HOSTNAME
            }
        }

        Context 'Ignore configuration if not needed' {
            BeforeEach {
                [Runner]::Main(@("--load-core-only", "--no-start"))
            }

            It "ignores the configuration because the demo launch is disabled" {
                [Runner]::ConfigureEnvironmentVariables()
                $TestOutput | Should -BeNullOrEmpty
                $TestWarningOutput | Should -BeNullOrEmpty
                $TestErrorOutput | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Cleanup' -Tag Cleanup {
        BeforeEach {
            Mock Invoke-ExitScript {
                Param(
                    [Parameter(Position = 0, Mandatory = $false)] [Byte] $ExitCode = 0
                )
            }
        }
        
        Context 'Environment variables cleanup' {
            Context 'Existing environment variables' -ForEach @(
                @{ EnvironmentVariables = @("TestVariable") }
                @{ EnvironmentVariables = @("TestVariable", "TestVariableTwo") }
            ) {
                BeforeEach {
                    foreach ($EnvironmentVariable in $EnvironmentVariables) {
                        Set-Item "env:$EnvironmentVariable" $true
                    }
    
                    $EnvironmentContext = [EnvironmentContext]::new()
                    $EnvironmentContext.EnvironmentVariables = $EnvironmentVariables
                }
    
                It "removes the environment variable <_> from the current environment" -ForEach $EnvironmentVariables {
                    $EnvironmentContext.RemoveEnvironmentVariables()
                    Test-Path env:\"$_" | Should -BeFalse
                    $EnvironmentContext.EnvironmentVariables.Length | Should -BeExactly 0
                    $TestOutput | Should -Match "Removing environment variable $_"
                }
            }
            
            Context 'Inexistent environment variables' -ForEach @(
                @{ EnvironmentVariables = @("UnknownVariable") }
                @{ EnvironmentVariables = @("UnknownVariable", "UnknownVariableTwo") }
            ) {
                BeforeEach {
                    foreach ($EnvironmentVariable in $EnvironmentVariables) {
                        if (Test-Path env:\"$EnvironmentVariable") {
                            Remove-Item env:\"$EnvironmentVariable"
                        }
                    }
    
                    $EnvironmentContext = [EnvironmentContext]::new()
                    $EnvironmentContext.EnvironmentVariables = $EnvironmentVariables
                }

                It "does not remove the <_> environment variable from the current environment because it does not exist" -ForEach $EnvironmentVariables {
                    $EnvironmentContext.RemoveEnvironmentVariables()
                    Test-Path env:\"$_" | Should -BeFalse
                    $EnvironmentContext.EnvironmentVariables.Length | Should -BeExactly 0
                    $TestOutput | Should -Not -Match "Removing environment variable $_"
                }
            }
        }

        Context 'Stop running processes' -ForEach @(
            @{ Type = [BackgroundProcess]; Name = "StopTestProcess" }
            @{ Type = [BackgroundDockerComposeProcess]; Name = "StopDockerComposeTestProcess" }
            @{ Type = [BackgroundJob]; Name = "StopTestJob" }
        ) {
            BeforeEach {
                Mock cmd {
                    $global:LASTEXITCODE = 0
                    return "Docker Compose version 1.29"
                }

                Mock Start-Process {
                    return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $false }
                }

                [Runner]::Tasks = @(
                    [BackgroundTaskFactory]::new($false).buildTask(@{}, $Name, $Type)
                )
                [Runner]::EnvironmentContext.CleanupExitCode = 0
            }

            Context 'Error cases' {
                Context 'Task stop error' {
                    BeforeEach {
                        Mock Checkpoint-Placeholder {
                            throw [StopBackgroundTaskException]::new("Fatal task stop error")
                        }
                    }
            
                    It "fails to stop the <name> task of type <type> because the process has failed to stop" {
                        [Runner]::StopRunningProcesses()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 12
                    }
                }
            
                Context 'Unknown stop error' {
                    BeforeEach {
                        Mock Checkpoint-Placeholder {
                            throw "Fatal unknown stop error"
                        }
                    }
            
                    It "fails to stop the <name> task of type <type> because an unknown error has occured"  {
                        [Runner]::StopRunningProcesses()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 13
                    }
                }
            }

            Context 'Success cases' {
                It "stops the <name> task of type <type> successfully" {
                    [Runner]::StopRunningProcesses()
                    [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 0
                }
            }
        }

        Context 'Fatal error handling' {
            Context 'Command not found error' -ForEach @(
                @{ MethodName = "AutoChooseSystemStack" }
                @{ MethodName = "ConfigureEnvironmentVariables" }
                @{ MethodName = "Build" }
                @{ MethodName = "Start" }
            ) {
                BeforeEach {
                    Mock cmd {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
                    Mock java {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
                    Mock mvn {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
                    Mock node {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
                    Mock Invoke-And {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
                    Mock Read-EnvironmentFile {
                        throw [System.Management.Automation.CommandNotFoundException]::new("Not found")
                    }
    
                    [Runner]::Main(@("--load-core-only"))
                }
    
                It "executes the cleanup routine because the system does not have a compatible stack to run the demonstration : method name = <methodname>" {
                    [Runner]::$MethodName()
                    [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 127
                    Should -Invoke Invoke-ExitScript -ParameterFilter { $ExitCode -eq 127 }
                }
            }
    
            Context 'General error' -ForEach @(
                @{ MethodName = "ConfigureEnvironmentVariables"; ExpectedExitCode = 8 }
                @{ MethodName = "Build"; ExpectedExitCode = 9 }
                @{ MethodName = "Start"; ExpectedExitCode = 11 }
            ) {
                BeforeEach {
                    Mock cmd {
                        if ($args -match "build|up") {
                            throw "Fatal error"
                        } else {
                            $global:LASTEXITCODE = 0
                            return "Docker Compose version 1.29"
                        }
                    }
                    Mock java {
                        throw "Fatal error"
                    }
                    Mock mvn {
                        throw "Fatal error"
                    }
                    Mock node {
                        throw "Fatal error"
                    }
                    Mock Invoke-And {
                        throw "Fatal error"
                    }
                    Mock Read-EnvironmentFile {
                        throw "Fatal error"
                    }
                    Mock Write-Information {
                        throw "Fatal error"
                    }
    
                    [Runner]::Main(@("--load-core-only"))
                }
    
                It "executes the cleanup routine because the call to <methodname> failed : expected exit code = <expectedexitcode>" {
                    [Runner]::$MethodName()
                    [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly $ExpectedExitCode
                    Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq $ExpectedExitCode }
                }
            }
    
            Context 'Process start error' {
                Context 'Docker Compose process start error' {
                    BeforeEach {
                        Mock cmd {
                            $global:LASTEXITCODE = 0
                            return "Docker Compose version 1.29"
                        }
                        Mock Start-Process {
                            throw "Docker fatal error"
                        }
        
                        [Runner]::Main(@("--load-core-only"))
                    }
        
                    It "executes the cleanup routine because containers start failed" {
                        [Runner]::Start()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 10
                        Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 10 }
                    }
                }
        
                Context 'System process start error' {
                    BeforeEach {
                        Mock cmd {
                            $global:LASTEXITCODE = 1
                        }
                        Mock java {
                            $global:LASTEXITCODE = 0
                            return "Java version 17.0"
                        }
                        Mock mvn {
                            $global:LASTEXITCODE = 0
                            return "Maven version 3.5"
                        }
                        Mock node {
                            $global:LASTEXITCODE = 0
                            return "Node version 16.0"
                        }
                        Mock Start-Process {
                            throw "Process fatal error"
                        }
        
                        [Runner]::Main(@("--load-core-only"))
                    }
        
                    It "executes the cleanup routine because process start failed" {
                        [Runner]::Start()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 10
                        Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 10 }
                    }
                }
            }

            Context 'Process stop error' {
                BeforeEach {
                    Mock cmd {
                        $global:LASTEXITCODE = 0
                        return "Docker Compose version 1.29"
                    }
                    Mock Start-Process {
                        return New-MockObject -Type System.Diagnostics.Process -Properties @{ Id = 1; HasExited = $true }
                    }
                }
                
                Context 'Task stop error' {
                    BeforeEach {
                        Mock Checkpoint-Placeholder {
                            throw [StopBackgroundTaskException]::new("Fatal task stop error")
                        }
        
                        [Runner]::Main(@("--load-core-only"))
                    }
        
                    It "executes the cleanup routine because containers stop failed" {
                        [Runner]::Start()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 12
                        Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 12 }
                    }
                }
        
                Context 'Unknown stop error' {
                    BeforeEach {
                        Mock Checkpoint-Placeholder {
                            throw "Fatal unknown stop error"
                        }

                        [Runner]::Main(@("--load-core-only"))
                    }
        
                    It "executes the cleanup routine because process stop failed" {
                        [Runner]::Start()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 13
                        Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 13 }
                    }
                }

                Context 'Process stop success' {
                    BeforeEach {
                        Mock Checkpoint-Placeholder {}
                    }
    
                    It "stops the tasks successfully" {
                        [Runner]::Start()
                        [Runner]::EnvironmentContext.CleanupExitCode | Should -BeExactly 3
                        Should -Invoke Invoke-ExitScript -Times 1 -ParameterFilter { $ExitCode -eq 3 }
                    }
                }
            }
        }
    }
}