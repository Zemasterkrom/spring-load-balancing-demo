BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'EnvironmentContext' {
    BeforeEach {
        $SCRIPT_PATH = $env:SCRIPT_PATH
    }

    AfterEach {
        $env:SCRIPT_PATH = $SCRIPT_PATH
    }

    Context 'Set environment variable keys' -Tag SetEnvironmentVariableKeys {
        Context 'Valid keys' -ForEach @(
            @{ Keys = @("TestOne", "TestTwo")}
            @{ Keys = @("Test_One", "Test_Two")}
            @{ Keys = @("testone", "testtwo")}
            @{ Keys = @("test_one", "test_two")}
            @{ Keys = @("testOne", "testTwo")}
            @{ Keys = @("test_One", "test_Two")}
            @{ Keys = @("TestOne1", "TestTwo2")}
            @{ Keys = @("Test_One1", "Test_Two2")}
            @{ Keys = @("testone1", "testtwo2")}
            @{ Keys = @("test_one1", "test_two2")}
            @{ Keys = @("testOne1", "testTwo2")}
            @{ Keys = @("test_One1", "test_Two2")}
            @{ Keys = @("TestOne", "TestTwo", "TestTwo")}
        ) {
            BeforeEach {
               $EnvironmentContext =  [EnvironmentContext]::new()
            }

            It "successfully associates the environment variable keys with the list" {
                { $EnvironmentContext.SetEnvironmentVariableKeys($Keys) } | Should -Not -Throw -ExceptionType System.ArgumentException
            }
        }

        Context 'Invalid keys' -ForEach @(
            @{ Keys = @($null)}
            @{ Keys = @("TestOne", $null)}
            @{ Keys = @("Test One")}
            @{ Keys = @(" Test One")}
            @{ Keys = @("9TestOne")}
            @{ Keys = @("TestOne", "")}
            @{ Keys = @("TestOne", " ")}
            @{ Keys = @("&TestOne", " ")}
            @{ Keys = @("&TestOne", " ")}
            @{ Keys = @("TestOne",  $null)}
            @{ Keys = @("TestOne",  $null)}
            @{ Keys = @("&TestOne", $null)}
            @{ Keys = @("&TestOne", $null)}
        ) {
            BeforeEach {
               $EnvironmentContext =  [EnvironmentContext]::new()
            }

            It "fails since the some keys are invalid" {
                { $EnvironmentContext.SetEnvironmentVariableKeys($Keys) } | Should -Throw -ExceptionType System.ArgumentException
            }
        }
    }

    Describe 'Add environment variable keys' -Tag AddEnvironmentVariableKeys {
        Context 'Valid keys' -ForEach @(
            @{ Keys = @("TestOne", "TestTwo"); ExpectedKeys = @("Test", "TestOne", "TestTwo") }
            @{ Keys = @("Test_One", "Test_Two"); ExpectedKeys = @("Test", "Test_One", "Test_Two") }
            @{ Keys = @("testone", "testtwo"); ExpectedKeys = @("Test", "testone", "testtwo") }
            @{ Keys = @("test", "testtwo"); ExpectedKeys = @("Test", "testtwo") }
            @{ Keys = @("testone", "Test", "testtwo"); ExpectedKeys = @("Test", "testone", "testtwo") }
        ) {
            BeforeEach {
               $EnvironmentContext = [EnvironmentContext]::new()
               $EnvironmentContext.SetEnvironmentVariableKeys(@("Test"))
            }

            It "successfully adds the environment variable keys to the list and remain unique (case insensitive)" {
                $EnvironmentContext.AddEnvironmentVariableKeys($Keys)
                Compare-Object $EnvironmentContext.EnvironmentVariables $ExpectedKeys | Should -BeNullOrEmpty
            }
        }

        Context 'Invalid keys' -ForEach @(
            @{ Keys = @($null)}
            @{ Keys = @("TestOne", $null)}
            @{ Keys = @("Test One")}
            @{ Keys = @(" Test One")}
            @{ Keys = @("9TestOne")}
            @{ Keys = @("TestOne", "")}
            @{ Keys = @("TestOne", " ")}
            @{ Keys = @("&TestOne", " ")}
            @{ Keys = @("&TestOne", " ")}
            @{ Keys = @("TestOne",  $null)}
            @{ Keys = @("TestOne",  $null)}
            @{ Keys = @("&TestOne", $null)}
            @{ Keys = @("&TestOne", $null)}
        ) {
            BeforeEach {
               $EnvironmentContext =  [EnvironmentContext]::new()
            }

            It "fails since the some keys are invalid, changes are cancelled" {
                { $EnvironmentContext.AddEnvironmentVariableKeys($Keys) } | Should -Throw -ExceptionType System.ArgumentException
                Compare-Object $EnvironmentContext.EnvironmentVariables @() | Should -BeNullOrEmpty
            }
        }
    }

    Describe 'Read environment variables' -Tag ReadEnvironmentVariables {
        BeforeEach {
            $EnvironmentContext = [EnvironmentContext]::new()
        }

        Context 'Load Balancing mode' {
            BeforeEach {
                $EnvironmentContext.ReadEnvironmentFile()
            }

            It "reads and sets load balancing variables successfully" {
                $EnvironmentContext.EnvironmentFilePath | Should -BeExactly .env
                { $EnvironmentContext.ReadEnvironmentFile() } | Should -Not -Throw
                $EnvironmentContext.EnvironmentVariables.Length | Should -BeGreaterThan 0
            }
        }

        Context 'No Load Balancing mode' {
            BeforeEach {
                $EnvironmentContext.SetEnvironmentFile("no-load-balancing.env", "UTF8")
                $EnvironmentContext.ReadEnvironmentFile()
            }

            It "reads and sets load balancing variables successfully" {
                { $EnvironmentContext.ReadEnvironmentFile() } | Should -Not -Throw
                $EnvironmentContext.EnvironmentVariables.Length | Should -BeGreaterThan 0
            }
        }
    }

    Context 'Set script location' -Tag SetScriptLocation {
        Context 'Set without location hint' {
            BeforeEach {
                Mock Set-Location {}
                Mock Get-ScriptRoot {
                    return "ScriptRoot"
                }

                $env:SCRIPT_PATH = ""
                $EnvironmentContext = [EnvironmentContext]::new()
            }

            It "sets and changes the root location of the script using the PSScriptRoot variable" {
                $EnvironmentContext.SetLocationToScriptPath() 
                $EnvironmentContext.ScriptPath | Should -BeExactly "ScriptRoot"
            }
        }

        Context 'Set with location hint' {
            BeforeEach {
                Mock Set-Location {}
                Mock Get-ScriptRoot {
                    return "ScriptRoot"
                }

                $EnvironmentContext = [EnvironmentContext]::new()
            }

            It "sets and changes the root location of the script using the custom SCRIPT_PATH variable" {
                $EnvironmentContext.SetLocationToScriptPath() 
                $EnvironmentContext.ScriptPath | Should -BeExactly $env:SCRIPT_PATH
                $env:SCRIPT_PATH | Should -Not -BeNullOrEmpty
            }
        }
    }
}