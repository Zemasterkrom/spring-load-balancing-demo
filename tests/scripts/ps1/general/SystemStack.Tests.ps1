BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'SystemStackComponent' {
    It 'creates a standard system stack component <tag> <systemstackcomponents>' -ForEach @(
        @{ Tag = [SystemStackTag]::Docker; SystemStackComponents = [SystemStackComponent[]]@([SystemStackComponent]::new("Docker Compose", "docker compose", [Version]::new(1, 29))); Expected = "Docker Compose version 1.29" }
        @{ Tag = [SystemStackTag]::System; SystemStackComponents = [SystemStackComponent[]]@([SystemStackComponent]::new("Java", "java", [Version]::new(17, 0)), [SystemStackComponent]::new("Node", "node", [Version]::new(16, 0))); Expected = "Java version 17.0`nNode version 16.0" }
    ) {
        [SystemStack]::new($Tag, $SystemStackComponents) | Should -BeExactly $Expected
    }

    It 'fails to create a system stack since the arguments are incorrect <tag> <systemstackcomponents>' -ForEach @(
        @{ Tag = $null; SystemStackComponents = @([SystemStackComponent]::new("Docker Compose", "docker compose", [Version]::new(1, 29))); ExpectedExceptionType = [System.Management.Automation.MethodException] }
        @{ Tag = [SystemStackTag]::Docker; SystemStackComponents = @(); ExpectedExceptionType = [ArgumentException] }
        @{ Tag = [SystemStackTag]::Docker; SystemStackComponents = @($null); ExpectedExceptionType = [ArgumentNullException] }
    ) {
        { [SystemStack]::new($Tag, $SystemStackComponents) } | Should -Throw -ExceptionType $ExpectedExceptionType
    }
}