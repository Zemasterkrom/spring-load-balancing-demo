BeforeDiscovery {
    . $PSScriptRoot\..\Import-Code.ps1
}

BeforeAll {
    . $PSScriptRoot\..\Import-Code.ps1
}

Describe 'SystemStack' {
    It 'creates a standard system stack <associatedtag> <command> <version>' -TestCases @(
        @{ AssociatedTag = "Command"; Command = "Command"; Version = [Version]::new(1,0); Expected = "Command version 1.0" }
        @{ AssociatedTag = "Command"; Command = "command"; Version = [Version]::new(1,0); Expected = "Command version 1.0" }
        @{ AssociatedTag = "command"; Command = "Command"; Version = [Version]::new(1,0); Expected = "command version 1.0" }
        @{ AssociatedTag = "Tag"; Command = "Command"; Version = [Version]::new(1,0); Expected = "Tag (Command) version 1.0" }
        @{ AssociatedTag = "Tag"; Command = "CommandPartOne CommandPartTwo"; Version = [Version]::new(1,0); Expected = "Tag (CommandPartOne CommandPartTwo) version 1.0" }
        @{ AssociatedTag = "CommandPartOne"; Command = "CommandPartOne CommandPartTwo"; Version = [Version]::new(1,0); Expected = "CommandPartOne (CommandPartOne CommandPartTwo) version 1.0" }
        @{ AssociatedTag = "CommandPartOne CommandPartTwo"; Command = "CommandPartOne CommandPartTwo"; Version = [Version]::new(1,0); Expected = "CommandPartOne CommandPartTwo version 1.0" }
        @{ AssociatedTag = "commandPartOne commandPartTwo"; Command = "CommandPartOne CommandPartTwo"; Version = [Version]::new(1,0); Expected = "commandPartOne commandPartTwo version 1.0" }
        @{ AssociatedTag = "CommandPartOne CommandPartTwo"; Command = "commandPartOne commandPartTwo"; Version = [Version]::new(1,0); Expected = "CommandPartOne CommandPartTwo version 1.0" }
    ) {
        [SystemStackComponent]::new($AssociatedTag, $Command, $Version) | Should -BeExactly $Expected
    }

    It 'fails to create a standard system stack component since the arguments are incorrect <associatedtag> <command> <version>' -TestCases @(
        @{ AssociatedTag = $null; Command = "Command"; Version = [Version]::new(1,0); ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ AssociatedTag = "Tag"; Command = $null; Version = [Version]::new(1,0); ExpectedExceptionType = [ArgumentException] }
        @{ AssociatedTag = "Tag"; Command = "Command"; Version = $null; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ AssociatedTag = ""; Command = "Command"; Version = $null; ExpectedExceptionType = [System.Management.Automation.SetValueInvocationException] }
        @{ AssociatedTag = "Tag"; Command = ""; Version = [Version]::new(1,0); ExpectedExceptionType = [ArgumentException]}
    ) {
        { [SystemStackComponent]::new($AssociatedTag, $Command, $Version) } | Should -Throw -ExceptionType $ExpectedExceptionType
    }
}