BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'SystemStackDetector' {
    Context 'Detect Docker Compose CLI' -Tag DockerComposeDetection {
        Context 'Success cases with valid and compatible versions' -ForEach @(
            @{ VersionString = "Docker Compose version v1.29.0 v1.0.0"; ExpectedMatchedVersion = "1.29.0" }
            @{ VersionString = "Docker Compose version v1.29.0"; ExpectedMatchedVersion = "1.29.0" }
            @{ VersionString = "v1.29.1"; ExpectedMatchedVersion = "1.29.1" }
            @{ VersionString = "1.29"; ExpectedMatchedVersion = "1.29.0" }
            @{ VersionString = "Docker Compose version v2.0"; ExpectedMatchedVersion = "2.0.0" }
            @{ VersionString = "v2.0.0"; ExpectedMatchedVersion = "2.0.0" }
            @{ VersionString = "2.0.1"; ExpectedMatchedVersion = "2.0.1" }
            @{ VersionString = "Docker Compose version v2.1.0"; ExpectedMatchedVersion = "2.1.0" }
            @{ VersionString = "v2.1.0-alpha"; ExpectedMatchedVersion = "2.1.0" }
            @{ VersionString = "2.1.0-alpha"; ExpectedMatchedVersion = "2.1.0" }
        ) {  
            Context 'CLI : docker compose' {
                BeforeEach {
                    Mock cmd {
                        if ($args -match "docker") {
                            $global:LASTEXITCODE = 0
                            return $VersionString
                        }
                    }
                }

                It "detects a compatible and available version of Docker Compose on the system (<versionstring> : <expectedmatchedversion>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly "Docker Compose version $ExpectedMatchedVersion"
                }
            }

            Context 'CLI : docker-compose' {
                BeforeEach {
                    Mock cmd {
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
                            return $VersionString
                        }
                    }
                }

                It "detects a compatible and available version of Docker Compose on the system (<versionstring> : <expectedmatchedversion>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly "Docker Compose (docker-compose) version $ExpectedMatchedVersion"
                }
            }
        }

        Context 'Error cases' {
            Context 'Invalid / incompatible versions' -ForEach @(
                @{ VersionString = $null }
                @{ VersionString = "No version" }
                @{ VersionString = "Docker Compose version" }
                @{ VersionString = "Docker Compose version 2a.6-alpha" }
                @{ VersionString = "Docker Compose version a.2-alpha" }
                @{ VersionString = "Docker Compose version 2" }
                @{ VersionString = "Docker Compose version 1.28" }
                @{ VersionString = "Docker Compose version 1.28.9" }
                @{ VersionString = "Docker Compose version 1.0" }
                @{ VersionString = "Docker Compose version 0.1" }
                @{ VersionString = "Docker Compose version 0.1.0" }
                @{ VersionString = "Docker Compose version 0.1.1" }
                @{ VersionString = "Docker Compose version 0.1.1-alpha" }
                @{ VersionString = "2" }
                @{ VersionString = "1.28" }
                @{ VersionString = "1.28.9" }
                @{ VersionString = "0.1" }
                @{ VersionString = "0.1.0" }
                @{ VersionString = "0.1.1" }
                @{ VersionString = "0.1.1-alpha" }
            ) {
                Context 'CLI : docker compose' {
                    BeforeEach {
                        Mock cmd {
                            if ($args -match "docker") {
                                $global:LASTEXITCODE = 0
                                return $VersionString
                            }
                        }
                    }
                    
                    It "fails since the Docker Compose version isn't compatible (<versionstring>)" {
                        [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly $null
                    }
                }

                Context 'CLI : docker-compose' {
                    BeforeEach {
                        Mock cmd {
                            $global:LASTEXITCODE = 0
    
                            if ($args -match "docker compose") {
                                $global:LASTEXITCODE = 1
                                return
                            }
    
                            if ($args -match "docker-compose") {
                                $global:LASTEXITCODE = 0
                                return $VersionString
                            }
                        }
                    }

                    It "fails since the Docker Compose version isn't compatible (<versionstring>)" {
                        [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly $null
                    }
                }
            }
        }

        Context 'Docker daemon system error' {
            BeforeEach {
                Mock cmd {
                    if ($args -match "docker") {
                        $global:LASTEXITCODE = 1
                    }
                }
            }

            It "fails since the Docker daemon isn't available" {
                [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly $null
            }
        }

        Context 'Docker Compose system error' {
            BeforeEach {
                Mock cmd {
                    $global:LASTEXITCODE = 0

                    if ($args -match "docker( |-)compose") {
                        $global:LASTEXITCODE = 1
                    }
                }
            }

            It "fails since the Docker daemon isn't available" {
                [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli() | Should -BeExactly $null
            }
        }
    }

    Context 'Detect Java CLI' -Tag JavaDetection {
        Context 'Success cases with valid and compatible versions' -ForEach @(
            @{ VersionString = 'openjdk version "17.0.0" "10.0.0"'; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = 'openjdk version "17.0.0"'; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = 'openjdk version 17.0.0'; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = 'openjdk version "17.0.1"'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version 17.0.1'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version "17.1.1"'; ExpectedMatchedVersion = "17.1.1" }
            @{ VersionString = 'openjdk version 17.1.1'; ExpectedMatchedVersion = "17.1.1" }
            @{ VersionString = 'openjdk version "18.0.0"'; ExpectedMatchedVersion = "18.0.0" }
            @{ VersionString = 'openjdk version 18.0.0'; ExpectedMatchedVersion = "18.0.0" }
            @{ VersionString = 'openjdk version "17.0"'; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = 'openjdk version 17.0'; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = 'openjdk version "17.0.1"'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version 17.0.1'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version 17.0.1-alpha'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version "17.0.1-alpha"'; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = 'openjdk version "18.0.1-alpha"'; ExpectedMatchedVersion = "18.0.1" }
            @{ VersionString = 'openjdk version 19.0.1-alpha'; ExpectedMatchedVersion = "19.0.1" }
            @{ VersionString = 'openjdk version 19.1.1-alpha'; ExpectedMatchedVersion = "19.1.1" }
        ) {
            Context 'stdout echo' {
                BeforeEach {
                    Mock java {
                        return $VersionString
                    }
                }

                It "succeeds since the Java version is compatible (<versionstring> : <expectedmatchedversion>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableJavaCli() | Should -BeExactly "Java version $ExpectedMatchedVersion"
                }
            }

            Context 'stderr echo' {
                BeforeEach {
                    Mock java {
                        throw $VersionString
                    }
                }

                It "succeeds since the Java version is compatible (<versionstring> : <expectedmatchedversion>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableJavaCli() | Should -BeExactly "Java version $ExpectedMatchedVersion"
                }
            }
        }

        Context 'Error cases' {
            Context 'Invalid / incompatible versions' -ForEach @(
                @{ VersionString = $null }
                @{ VersionString = "No version" }
                @{ VersionString = 'openjdk version' }
                @{ VersionString = 'openjdk version "17"' }
                @{ VersionString = 'openjdk version 17' }
                @{ VersionString = 'openjdk version "17-alpha"' }
                @{ VersionString = 'openjdk version 17-alpha' }
                @{ VersionString = 'openjdk version "17.a"' }
                @{ VersionString = 'openjdk version 17.a' }
                @{ VersionString = 'openjdk version "17.a.b"' }
                @{ VersionString = 'openjdk version 17.a.b' }
                @{ VersionString = 'openjdk version "17.a-alpha"' }
                @{ VersionString = 'openjdk version 17.a-alpha' }
                @{ VersionString = 'openjdk version "17.a.b-alpha"' }
                @{ VersionString = 'openjdk version 17.a.b-alpha' }
                @{ VersionString = 'openjdk version "16.9.9"' }
                @{ VersionString = 'openjdk version 16.9.9' }
                @{ VersionString = 'openjdk version "16.9.9-alpha"' }
                @{ VersionString = 'openjdk version 16.9.9-alpha' }
                @{ VersionString = 'openjdk version "16.9"' }
                @{ VersionString = 'openjdk version 16.9' }
                @{ VersionString = 'openjdk version "1.0.1"' }
                @{ VersionString = 'openjdk version 1.0.1' }
                @{ VersionString = 'openjdk version "1.1.1"' }
                @{ VersionString = 'openjdk version 1.1.1' }
                @{ VersionString = 'openjdk version "1.0"' }
                @{ VersionString = 'openjdk version 1.0' }
            ) {
                Context 'stdout echo' {
                    BeforeEach {
                        Mock java {
                            return $VersionString
                        }
                    }
    
                    It "fails since the Java version isn't compatible (<versionstring>)" {
                        [SystemStackDetector]::DetectCompatibleAvailableJavaCli() | Should -BeExactly $null
                    }
                }
    
                Context 'stderr echo' {
                    BeforeEach {
                        Mock java {
                            throw $VersionString
                        }
                    }
    
                    It "fails since the Java version isn't compatible (<versionstring>)" {
                        [SystemStackDetector]::DetectCompatibleAvailableJavaCli() | Should -BeExactly $null
                    }
                }
            }
    
            Context 'Java system error' {
                BeforeEach {
                    Mock java {
                        throw ""
                    }
                }
    
                It "fails since a Java system error occurs" {
                    [SystemStackDetector]::DetectCompatibleAvailableJavaCli() | Should -BeExactly $null
                }
            }
        }
    }

    Context 'Detect Node CLI' -Tag NodeDetection {
        Context 'Success cases with valid and compatible versions' -ForEach @(
            @{ VersionString = "v16.0 10.0"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "v16.0"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "v16.0-alpha"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "v16.0.0"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "v16.0.0-alpha"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "16.0.0"; ExpectedMatchedVersion = "16.0.0" }
            @{ VersionString = "v16.0.1"; ExpectedMatchedVersion = "16.0.1" }
            @{ VersionString = "v16.0.1-alpha"; ExpectedMatchedVersion = "16.0.1" }
            @{ VersionString = "16.0.1"; ExpectedMatchedVersion = "16.0.1" }
            @{ VersionString = "v16.1.0"; ExpectedMatchedVersion = "16.1.0" }
            @{ VersionString = "v16.1.0-alpha"; ExpectedMatchedVersion = "16.1.0" }
            @{ VersionString = "16.1.0"; ExpectedMatchedVersion = "16.1.0" }
            @{ VersionString = "v17.0.0"; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = "v17.0.0-alpha"; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = "17.0.0"; ExpectedMatchedVersion = "17.0.0" }
            @{ VersionString = "v17.0.1"; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = "v17.0.1-alpha"; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = "17.0.1"; ExpectedMatchedVersion = "17.0.1" }
            @{ VersionString = "v17.1.1"; ExpectedMatchedVersion = "17.1.1" }
            @{ VersionString = "v17.1.1-alpha"; ExpectedMatchedVersion = "17.1.1" }
            @{ VersionString = "17.1.1"; ExpectedMatchedVersion = "17.1.1" }
        ) {
            BeforeEach {
                Mock node {
                    return $VersionString
                }
            }

            It "succeeds since the Node version is compatible (<versionstring> : <expectedmatchedversion>)" {
                [SystemStackDetector]::DetectCompatibleAvailableNodeCli() | Should -BeExactly "Node version $ExpectedMatchedVersion"
            }
        }

        Context 'Error cases' {
            Context 'Invalid / incompatible versions' -ForEach @(
                @{ VersionString = $null }
                @{ VersionString = "v" }
                @{ VersionString = "v15.9.9-alpha" }
                @{ VersionString = "v15.9.9" }
                @{ VersionString = "v15.9.0" }
                @{ VersionString = "v15.9" }
                @{ VersionString = "v15" }
                @{ VersionString = "15.9.9" }
                @{ VersionString = "15.9.0" }
                @{ VersionString = "15.9" }
                @{ VersionString = "15" }
                @{ VersionString = "v14.9.9" }
                @{ VersionString = "v14.9.0" }
                @{ VersionString = "v14.9" }
                @{ VersionString = "v14" }
                @{ VersionString = "14.9.9" }
                @{ VersionString = "14.9.0" }
                @{ VersionString = "14.9" }
                @{ VersionString = "14" }
                @{ VersionString = "v1.9.9" }
                @{ VersionString = "v1.9.0" }
                @{ VersionString = "v1.9" }
                @{ VersionString = "v1" }
                @{ VersionString = "1.9.9" }
                @{ VersionString = "1.9.0" }
                @{ VersionString = "1.9" }
                @{ VersionString = "1" }
                @{ VersionString = "v16.a" }
                @{ VersionString = "v16.a-alpha" }
                @{ VersionString = "v16.a.b" }
                @{ VersionString = "16.a.b-alpha" }
                @{ VersionString = "16.a" }
                @{ VersionString = "16.a-alpha" }
                @{ VersionString = "16.a.b" }
                @{ VersionString = "16.a.b-alpha" }
            ) {
                BeforeEach {
                    Mock node {
                        return $VersionString
                    }
                }

                It "fails since the Node version isn't compatible (<versionstring>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableNodeCli() | Should -BeExactly $null
                }
            }

            Context 'Node system error' {
                BeforeEach {
                    Mock Node {
                        throw ""
                    }
                }
    
                It "fails since a Node system error occurs" {
                    [SystemStackDetector]::DetectCompatibleAvailableNodeCli() | Should -BeExactly $null
                }
            }
        }
    }

    Context 'Detect Maven CLI' -Tag MavenDetection {
        Context 'Success cases with valid and compatible versions' -ForEach @(
            @{ VersionString = "Apache Maven 3.5 1.0"; ExpectedMatchedVersion  = "3.5.0" }
            @{ VersionString = "Apache Maven 3.5"; ExpectedMatchedVersion  = "3.5.0" }
            @{ VersionString = "Apache Maven 3.5.0"; ExpectedMatchedVersion  = "3.5.0" }
            @{ VersionString = "Apache Maven 3.5.2"; ExpectedMatchedVersion  = "3.5.2" }
            @{ VersionString = "Apache Maven 3.5.3-alpha-1"; ExpectedMatchedVersion  = "3.5.3" }
            @{ VersionString = "Apache Maven 3.5.4-beta-2"; ExpectedMatchedVersion  = "3.5.4" }
            @{ VersionString = "Apache Maven 3.6.0-SNAPSHOT"; ExpectedMatchedVersion  = "3.6.0" }
            @{ VersionString = "Apache Maven 3.6.1-rc-1"; ExpectedMatchedVersion  = "3.6.1" }
            @{ VersionString = "Apache Maven 3.6.2"; ExpectedMatchedVersion  = "3.6.2" }
            @{ VersionString = "Apache Maven 3.6.3-alpha-1"; ExpectedMatchedVersion  = "3.6.3" }
            @{ VersionString = "Apache Maven 3.7.0-SNAPSHOT"; ExpectedMatchedVersion  = "3.7.0" }
            @{ VersionString = "Apache Maven 3.7.1-beta-1"; ExpectedMatchedVersion  = "3.7.1" }
            @{ VersionString = "Apache Maven 4.0.0-alpha-1"; ExpectedMatchedVersion  = "4.0.0" }
            @{ VersionString = "Apache Maven 4.0.0-SNAPSHOT"; ExpectedMatchedVersion  = "4.0.0" }
            @{ VersionString = "Apache Maven 4.0.0-rc-1"; ExpectedMatchedVersion  = "4.0.0" }
            @{ VersionString = "Apache Maven 4.0.0"; ExpectedMatchedVersion  = "4.0.0" }
            @{ VersionString = "Apache Maven 5.0.0-alpha-1"; ExpectedMatchedVersion  = "5.0.0" }
            @{ VersionString = "Apache Maven 5.0.0-SNAPSHOT"; ExpectedMatchedVersion  = "5.0.0" }
            @{ VersionString = "Apache Maven 5.0.0-rc-1"; ExpectedMatchedVersion  = "5.0.0" }
            @{ VersionString = "Apache Maven 5.0.0"; ExpectedMatchedVersion  = "5.0.0" }
            @{ VersionString = "Apache Maven 5.1.0-SNAPSHOT"; ExpectedMatchedVersion  = "5.1.0" }
            @{ VersionString = "Apache Maven 5.1.1-alpha-1"; ExpectedMatchedVersion  = "5.1.1" }
            @{ VersionString = "Apache Maven 5.2.0-beta-2"; ExpectedMatchedVersion  = "5.2.0" }
        ) {
            BeforeEach {
                Mock mvn {
                    return $VersionString
                }
            }

            It "succeeds since the Maven version is compatible (<versionstring> : <expectedmatchedversion>)" {
                [SystemStackDetector]::DetectCompatibleAvailableMavenCli() | Should -BeExactly "Maven (mvn) version $ExpectedMatchedVersion"
            }
        }

        Context 'Error cases' {
            Context 'Invalid / incompatible versions' -ForEach @(
                @{ VersionString = $null }
                @{ VersionString = "Apache Maven" }
                @{ VersionString = "Apache Maven 3" }
                @{ VersionString = "Apache Maven 3.a" }
                @{ VersionString = "Apache Maven 3.a-alpha" }
                @{ VersionString = "Apache Maven 3.a.b" }
                @{ VersionString = "Apache Maven 3.a.b-alpha" }
                @{ VersionString = "Apache Maven 3.0.5" }
                @{ VersionString = "Apache Maven 3.2.3-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.2.5-beta" }
                @{ VersionString = "Apache Maven 3.4.0-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.1-alpha-1" }
                @{ VersionString = "Apache Maven 3.4.2-RC-2" }
                @{ VersionString = "Apache Maven 3.4.3-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.4-beta-1" }
                @{ VersionString = "Apache Maven 3.4.5-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.6-alpha-2" }
                @{ VersionString = "Apache Maven 3.4.7-RC-1" }
                @{ VersionString = "Apache Maven 3.4.8" }
                @{ VersionString = "Apache Maven 3.4.9-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.10-beta-3" }
                @{ VersionString = "Apache Maven 3.4.11-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.12-alpha-1" }
                @{ VersionString = "Apache Maven 3.4.13-RC-2" }
                @{ VersionString = "Apache Maven 3.4.14-SNAPSHOT" }
                @{ VersionString = "Apache Maven 3.4.15-beta-1" }
                @{ VersionString = "Apache Maven 3.4.16-SNAPSHOT" }
            ) {
                BeforeEach {
                    Mock mvn {
                        return $VersionString
                    }
                }

                It "fails since the Maven version isn't compatible (<versionstring>)" {
                    [SystemStackDetector]::DetectCompatibleAvailableMavenCli() | Should -BeExactly $null
                }
            }

            Context 'Maven system error' {
                BeforeEach {
                    Mock mvn {
                        throw ""
                    }
                }
    
                It "fails since a Maven system error occurs" {
                    [SystemStackDetector]::DetectCompatibleAvailableMavenCli() | Should -BeExactly $null
                }
            }
        }
    }

    Context 'Auto-choose system' -Tag AutoDetectStack {
        Context 'Success cases' {
            Context 'Auto-choose with Docker' {
                BeforeEach {
                    [SystemStackDetector]::ChoosenSystemStack = $null

                    Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }

        return [SystemStackDetector]::ChoosenSystemStack
    }

    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }

    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return [SystemStackComponent]::new("Docker Compose", "docker compose", [Version]::new(1, 29, 0))
    }

    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null

        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }

        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }

        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}
'@
                }

                It 'chooses Docker since the Docker Compose version is available and compatible' {
                    [MockedSystemStackDetector]::AutoDetectStack() | Should -BeExactly "Docker Compose version 1.29.0"
                    [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() | Should -BeExactly "Docker Compose version 1.29.0"
                    [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly "Docker Compose version 1.29.0"
                }
            }
        }

        Context 'Auto-choose with Java, Maven and Node' {
            BeforeEach {
                [SystemStackDetector]::ChoosenSystemStack = $null

                Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }

        return [SystemStackDetector]::ChoosenSystemStack
    }

    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }

    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return $null
    }

    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        return [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0, 0))
    }

    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        return [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5, 0))
    }

    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        return [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0, 0))
    }

    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null

        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }

        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }

        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}
'@
            }

            It "chooses the system environment since the Docker Compose version isn't compatible" {
                [MockedSystemStackDetector]::AutoDetectStack() | Should -BeExactly "Java version 17.0.0`nMaven (mvn) version 3.5.0`nNode version 16.0.0"
                [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() | Should -BeExactly "Java version 17.0.0`nMaven (mvn) version 3.5.0`nNode version 16.0.0"
                [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly "Java version 17.0.0`nMaven (mvn) version 3.5.0`nNode version 16.0.0"
            }
        }

        Context 'Error cases' {
            Context 'Not any system requirements matched' {
                BeforeEach {
                    [SystemStackDetector]::ChoosenSystemStack = $null

                    Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }
    
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        return $null
    }
    
    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null
    
        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }
    
        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }
    
        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
                }
'@   
                }

                It "fails because no required system components are present" {
                    { [MockedSystemStackDetector]::AutoDetectStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    { [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly $null
                }
            }

            Context "Java version not matched when Docker can't be used" {
                BeforeEach {
                    [SystemStackDetector]::ChoosenSystemStack = $null

                    Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }
    
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        return [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5, 0))
    }

    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        return [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0, 0))
    }
    
    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null
    
        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }
    
        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }
    
        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}
'@   
                }

                It "fails because Java version isn't compatible" {
                    { [MockedSystemStackDetector]::AutoDetectStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    { [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly $null
                }
            }

            Context "Maven version not matched when Docker can't be used" {
                BeforeEach {
                    [SystemStackDetector]::ChoosenSystemStack = $null

                    Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }
    
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        return [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0, 0))
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        return $null
    }

    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        return [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0, 0))
    }
    
    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null
    
        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }
    
        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }
    
        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}
'@   
                }

                It "fails because Maven version isn't compatible" {
                    { [MockedSystemStackDetector]::AutoDetectStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    { [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly $null
                }
            }

            Context "Node version not matched when Docker can't be used" {
                BeforeEach {
                    [SystemStackDetector]::ChoosenSystemStack = $null

                    Invoke-Expression @'
class MockedSystemStackDetector: SystemStackDetector {
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [MockedSystemStackDetector]::AutoDetectStack()
        }
    
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        return $null
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        return [SystemStackComponent]::new("Java", "java", [Version]::new(17, 0, 0))
    }
    
    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        return [SystemStackComponent]::new("Maven", "mvn", [Version]::new(3, 5, 0))
    }

    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        return $null
    }
    
    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null
    
        if ($DockerComposeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }
    
        if (($JavaCli = [MockedSystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [MockedSystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [MockedSystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }
    
        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}
'@   
                }

                It "fails because Node version isn't compatible" {
                    { [MockedSystemStackDetector]::AutoDetectStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    { [MockedSystemStackDetector]::RetrieveMostAppropriateSystemStack() } | Should -Throw -ExceptionType System.Management.Automation.CommandNotFoundException
                    [MockedSystemStackDetector]::RetrieveCurrentSystemStack() | Should -BeExactly $null
                }
            }
        }
    }
}