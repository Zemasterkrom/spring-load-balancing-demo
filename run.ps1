$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$InformationPreference = "Continue"

###########################
# System oriented classes #
###########################

class InvokeAndException: Exception {
    [Int] $Code
    [Exception] $AdditionalException

    InvokeAndException([String] $Message, [Int]$Code): base($Message) {
        $this.Code = $Code
        $this.AdditionalException = [Exception]::new("")
    }

    InvokeAndException([String] $Message, [Int]$Code, [Exception] $AdditionalException): base($Message) {
        $this.Code = $Code
        $this.AdditionalException = $AdditionalException
    }
}

<#
    .SYNOPSIS
        Allows to execute commands with the && bash style

    .DESCRIPTION
         If the command execution fails, an exception will be thrown. In the event of a PowerShell error, the exception depends on the command being executed unsuccessfully, otherwise an InvokeAndException will be thrown.

    .PARAMETER ReturnObject
        If this option is enabled, the object of the invoked expression will be returned

    .EXAMPLE
        PS>Invoke-And Write-Output Test # Shows "test"
        PS>$o = Invoke-And -ReturnObject 1 # Returns 1
        PS>Invoke-And Write-Output $o # Shows 1

    .EXAMPLE
        PS>Invoke-And cmd /c exit 1 # Will throw an InvokeAndException

    .EXAMPLE
        PS>Invoke-And cmd /c exit 1 # Will throw an InvokeAndException
        PS>Invoke-And Write-Output Test # This command will not be executed due to the failure of the previous Invoke-And (if exception is catched)

    .OUTPUTS
        System.Object. Object resulting from the Invoke-Expression call.
#>
function Invoke-And {
    Param(
        [Switch]$ReturnObject
    )
    $global:LASTEXITCODE = $null

    try {
        if ($ReturnObject) {
            $Obj = Invoke-Expression @"
$args
"@ -ErrorAction Stop
        } else {
            Invoke-Expression @"
$args | Out-Host
"@ -ErrorAction Stop
        }
    } catch {
        throw $_
    }

    $Code = if ($? -and ($LASTEXITCODE -eq 0) -or ($null -eq $LASTEXITCODE)) {
        0
    } else {
        if ($null -ne $LASTEXITCODE) {
            $LASTEXITCODE
        } else {
            1
        }
    }

    if ($Code -ne 0) {
        throw [InvokeAndException]::new("Run failed with error code : $Code", $Code)
    }

    if ($ReturnObject) {
        return $Obj
    } else {
        return $null
    }
}

<#
    .SYNOPSIS
        Reads an environment file

    .DESCRIPTION
        Reads an environment file and sets the values in the current environment
        Escape characters in environment files using the \ character

    .PARAMETER FilePath
        Path of the environment file

    .PARAMETER Encoding
        File encoding. Default is UTF8.

    .OUTPUTS
        System.Array. Array containing the keys of the loaded environment file.
#>
function Read-EnvironmentFile {
    Param(
        [Parameter(Position = 0, Mandatory = $true)] [String] $FilePath,
        [Parameter(Position = 1, Mandatory = $false)] [String] $Encoding = "utf8"
    )

    function GetCharacterWithoutOverflow {
        Param(
            [Parameter(Position = 0, Mandatory = $true)] [String] $String,
            [Parameter(Position = 1, Mandatory = $true)] [Int64] $Index
        )

        return ($_ = if (($Index -ge 0) -and ($Index -lt $String.Length)) {
            $String.Substring($Index, 1)
        }
        else {
            ""
        })
    }

    $keys = @()

    Get-Content "$FilePath" -Encoding "$Encoding" | ForEach-Object {
        if (!($_ -match "^([a-zA-Z][a-zA-Z0-9_]*)=([^\r\n\t\f\v ].*|[\r\n\t\f\v ]*)$") -or !$matches[1]) {
            return
        }

        $key = $matches[1]
        $value = $matches[2]
        $newValue = ""

        $firstNotBlankCharPosition = -1
        $trailingWhitespaceCount = 0
        $consecutiveBackslashesCount = 0
        $foundQuote = ""

        # Process and decode the value
        for ($i = 0; $i -lt $value.Length; $i++) {
            # Process backslashes escaping
            if (((GetCharacterWithoutOverflow $value $i) -eq "\") -and ((GetCharacterWithoutOverflow $value ($i + 1)) -ne "\")) {
                $consecutiveBackslashesCount++
                continue
            }

            if (((GetCharacterWithoutOverflow $value $i) -eq "\") -and ((GetCharacterWithoutOverflow $value ($i + 1)) -eq "\")) {
                $consecutiveBackslashesCount += 2
                $i++
            }

            # Detect the first non-blank character position (after escaping)
            if (($firstNotBlankCharPosition -eq -1) -and (((GetCharacterWithoutOverflow $value $i) -notmatch "[\t ]") -or (((GetCharacterWithoutOverflow $value ($i - 1)) -eq "\") -and ((GetCharacterWithoutOverflow $value $i) -match "[\t ]")))) {
                $firstNotBlankCharPosition = $i
            }

            # Count the blank characters that need to be removed
            if (((GetCharacterWithoutOverflow $value ($i - 1)) -ne "\") -and ((GetCharacterWithoutOverflow $value $i) -match "[\t ]")) {
                $trailingWhitespaceCount++
            }
            else {
                $trailingWhitespaceCount = 0
            }

            # The number of backslashes is even : we must check the possible presence of slashes
            if ($consecutiveBackslashesCount%2 -eq 0) {
                $consecutiveBackslashesCount = 0
                $skip = $false
                $valueToConcatenate = ""

                # Opening quote found
                if ((GetCharacterWithoutOverflow $value $i) -match "['`"]") {
                    $foundQuote = (GetCharacterWithoutOverflow $value $i)

                    # Process and search for the closing quote
                    for ($j = $i + 1; $j -lt $value.Length; $j++) {
                        # Process backslashes escaping
                        if (((GetCharacterWithoutOverflow $value $j) -eq "\") -and ((GetCharacterWithoutOverflow $value ($j + 1)) -ne "\")) {
                            $consecutiveBackslashesCount++

                            # Failed to detect the closing quote, ending and printing the opening quote
                            if ($j -eq ($value.Length - 1)) {
                                $valueToConcatenate = $foundQuote + $valueToConcatenate
                                $i = $j
                            }

                            continue
                        }

                        if (((GetCharacterWithoutOverflow $value $j) -eq "\") -and ((GetCharacterWithoutOverflow $value ($j + 1)) -eq "\")) {
                            $consecutiveBackslashesCount += 2
                            $j++
                        }

                        # Count the additional blank characters that need to be removed
                        if (((GetCharacterWithoutOverflow $value ($j - 1)) -ne "\") -and ((GetCharacterWithoutOverflow $value $j) -match "[\t ]")) {
                            $trailingWhitespaceCount++
                        }
                        else {
                            $trailingWhitespaceCount = 0
                        }


                        # Closing quote detected, quotes are ignored
                        if (($consecutiveBackslashesCount%2 -eq 0) -and ($foundQuote -ne "") -and ((GetCharacterWithoutOverflow $value $j) -eq $foundQuote)) {
                            $foundQuote = ""
                            $consecutiveBackslashesCount = 0
                            $skip = $true
                            $i = $j
                            break
                        }

                        if ((GetCharacterWithoutOverflow $value $j) -ne "\") {
                            $consecutiveBackslashesCount = 0
                        }

                        $valueToConcatenate += (GetCharacterWithoutOverflow $value $j)

                        # Failed to detect the closing quote, ending and printing the opening quote
                        if ($j -eq ($value.Length - 1)) {
                            $valueToConcatenate = $foundQuote + $valueToConcatenate
                            $i = $j
                        }
                    }
                }

                # No pairs of quotes detected : append the current character
                if (!$skip -and ($valueToConcatenate -eq "")) {
                    $valueToConcatenate += (GetCharacterWithoutOverflow $value $i)
                }

                $newValue += $valueToConcatenate
            }
            else {
                $newValue += (GetCharacterWithoutOverflow $value $i)
            }

            if ((GetCharacterWithoutOverflow $value $i) -ne "\") {
                $consecutiveBackslashesCount = 0
            }
        }

        # Retrieve only relevant characters (remove trailing whitespace)
        $newValue = $newValue.Substring(0, $newValue.Length - $trailingWhitespaceCount)

        Set-Content env:\$key $newValue
        $keys += $key
    }

    return $keys | Get-Unique
}

function Get-ScriptRoot {
    return $PSScriptRoot
}

function Invoke-ExitScript {
    Param(
        [Parameter(Position = 0, Mandatory = $false)] [Byte] $ExitCode = 0
    )

    exit $ExitCode
}

function Watch-CleanupShortcut {
    if ([Console]::KeyAvailable) {
        $KeyboardKeyCombination = [Console]::ReadKey($true)

        if ($KeyboardKeyCombination.Modifiers -eq "Control" -and $KeyboardKeyCombination.Key -eq "C") {
            return $true
        }
    }
}

function Checkpoint-Placeholder {}

###############################
# Environment related classes #
###############################

<#
    .DESCRIPTION
        Automatically detect the most appropriate stack to run the demo, with a tag and the associated software
#>
class SystemStackDetector {
    # Fixed choosen system stack
    static [SystemStack] $ChoosenSystemStack = $null

    # Required Docker Compose version
    static [Version] $RequiredDockerComposeVersion = [Version]::new(1, 29)

    # Required Java version
    static [Version] $RequiredJavaVersion = [Version]::new(17, 0)

    # Required Maven version
    static [Version] $RequiredMavenVersion = [Version]::new(3, 5)

    # Required Node version
    static [Version] $RequiredNodeVersion = [Version]::new(16, 0)

    <#
        .DESCRIPTION
            Retrieve the choosen system stack only once (singleton)

        .OUTPUTS
            Choosen system stack
    #>
    static [SystemStack] RetrieveMostAppropriateSystemStack() {
        if ($null -eq [SystemStackDetector]::ChoosenSystemStack) {
            [SystemStackDetector]::ChoosenSystemStack = [SystemStackDetector]::AutoDetectStack()
        }

        return [SystemStackDetector]::ChoosenSystemStack
    }

    <#
        .DESCRIPTION
            Retrieve the current system stack even if it is not set

        .OUTPUTS
            Current system stack even if it is not set
    #>
    static [SystemStack] RetrieveCurrentSystemStack() {
        return [SystemStackDetector]::ChoosenSystemStack
    }

    <#
        .DESCRIPTION
            Detect an available and compatible Docker Compose CLI on the system

        .OUTPUTS
            Docker Compose CLI info if available and compatible
     #>
    static [SystemStackComponent] DetectCompatibleAvailableDockerComposeCli() {
        # StdErr redirection bug, using the old CMD as alternative: https://github.com/PowerShell/PowerShell/issues/4002
        $DockerComposeVersion = ""
        $DockerComposeCli = ""
        
        try {
            cmd /c "docker info >nul 2>&1" >$null
        } catch {
        }

        if ($LASTEXITCODE -eq 0) {
            try {
                $DockerComposeVersion = cmd /c "docker compose version 2>nul"
            } catch {
            }

            if ($LASTEXITCODE -eq 0) {
                $DockerComposeCli = "docker compose"
                $ChoosenSystemStackTag = [SystemStackTag]::Docker
            } else {
                try {
                    $DockerComposeVersion = cmd /c "docker-compose version 2>nul"
                } catch {
                }

                if ($LASTEXITCODE -eq 0) {
                    $DockerComposeCli = "docker-compose"
                    $ChoosenSystemStackTag = [SystemStackTag]::Docker
                } else {
                    $ChoosenSystemStackTag = [SystemStackTag]::System
                }
            }
        } else {
            $ChoosenSystemStackTag = [SystemStackTag]::System
        }

        if ($ChoosenSystemStackTag -eq [SystemStackTag]::Docker) {
            if (([String]$DockerComposeVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)(?:\.(?=[0-9]+)([0-9]+))?.*$") -and (($DockerComposeVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredDockerComposeVersion)) {
                return [SystemStackComponent]::new("Docker Compose", $DockerComposeCli, $DockerComposeVersion)
            }
        }

        return $null
    }

    <#
        .DESCRIPTION
            Detect an available and compatible Java CLI on the system

        .OUTPUTS
            Java CLI info if available and compatible
    #>
    static [SystemStackComponent] DetectCompatibleAvailableJavaCli() {
        try {
            $JavaVersion = java -version 2>&1
        } catch {
            # https://github.com/PowerShell/PowerShell/issues/4002
            # https://bugs.java.com/bugdatabase/view_bug.do?bug_id=4380614
            $JavaVersion = $_.Exception.Message
        }

        if (([String]$JavaVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)(?:\.(?=[0-9]+)([0-9]+))?.*$") -and (($JavaVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredJavaVersion)) {
            return [SystemStackComponent]::new("Java", "java", $JavaVersion)
        }

        return $null
    }

    <#
        .DESCRIPTION
            Detect an available and compatible Maven CLI on the system

        .OUTPUTS
            Maven CLI info if available and compatible
    #>
    static [SystemStackComponent] DetectCompatibleAvailableMavenCli() {
        try {
            $MavenVersion = mvn -version
        } catch {
            return $null
        }

        if (([String]$MavenVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)(?:\.(?=[0-9]+)([0-9]+))?.*$") -and (($MavenVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredMavenVersion)) {
            return [SystemStackComponent]::new("Maven", "mvn", $MavenVersion)
        }

        return $null
    }

    <#
        .DESCRIPTION
            Detect an available and compatible Node CLI on the system

        .OUTPUTS
            Node CLI info if available and compatible
    #>
    static [SystemStackComponent] DetectCompatibleAvailableNodeCli() {
        try {
            $NodeVersion = node -v 2> $null
        } catch {
            return $null
        }

        if (([String]$NodeVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)(?:\.(?=[0-9]+)([0-9]+))?.*$") -and (($NodeVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredNodeVersion)) {
            return [SystemStackComponent]::new("Node", "node", $NodeVersion)
        }

        return $null
    }

    <#
        .DESCRIPTION
            Automatically detect the most appropriate stack to run the demo, with a tag and the associated software

        .OUTPUTS
            The most appropriate system stack
    #>
    static [SystemStack] AutoDetectStack() {
        $DockerComposeCli = $null
        $JavaCli = $null
        $MavenCli = $null
        $NodeCli = $null

        if ($DockerComposeCli = [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()) {
            return [SystemStack]::new([SystemStackTag]::Docker, @($DockerComposeCli))
        }

        if (($JavaCli = [SystemStackDetector]::DetectCompatibleAvailableJavaCli()) -and ($MavenCli = [SystemStackDetector]::DetectCompatibleAvailableMavenCli()) -and ($NodeCli = [SystemStackDetector]::DetectCompatibleAvailableNodeCli())) {
            return [SystemStack]::new([SystemStackTag]::System, @($JavaCli, $MavenCli, $NodeCli))
        }

        throw [System.Management.Automation.CommandNotFoundException]::new("Unable to run the demo. Required : Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ) or Java >= $( [SystemStackDetector]::RequiredJavaVersion ) with Maven >= $( [SystemStackDetector]::RequiredMavenVersion ) and Node >= $( [SystemStackDetector]::RequiredNodeVersion ).")
    }
}

# Tags that represent a category of software that can be associated to run the demo
enum SystemStackTag {
    Docker
    System
}

<#
    .DESCRIPTION
       System stack description, with a tag and the associated components
#>
class SystemStack {
    # Tag
    [ValidateNotNull()] [SystemStackTag] $Tag

    # Components list
    [ValidateNotNull()] [SystemStackComponent[]] $SystemStackComponents

    <#
        .DESCRIPTION
            Constructor of the system stack

        .PARAM Tag
            Tag of the system stack

        .PARAM StackComponents
            Stack components list
    #>
    SystemStack([SystemStackTag] $Tag, [SystemStackComponent[]] $SystemStackComponents) {
        if (($null -eq $SystemStackComponents) -or ($SystemStackComponents.Length -eq 0)) {
            throw [ArgumentException]::new("System stack must contain at least one stack component")
        }

        foreach ($SystemStackComponent in $SystemStackComponents) {
            if ($null -eq $SystemStackComponent) {
                throw [ArgumentNullException]::new("Stack components cannot be null")
            }
        }

        $this.Tag = $Tag
        $this.SystemStackComponents = $SystemStackComponents
    }

    [String] ToString() {
        $SystemStackInformation = ""

        for ($i = 0; $i -lt $this.SystemStackComponents.Length; $i++) {
            $SystemStackInformation += $this.SystemStackComponents[$i]

            if ($i -ne ($this.SystemStackComponents.Length - 1)) {
                $SystemStackInformation += "`n"
            }
        }

        return $SystemStackInformation
    }
}

<#
    .DESCRIPTION
        Represents a component of a system stack
#>
class SystemStackComponent {
    # Associated command tag
    [ValidateNotNullOrEmpty()] [String] $AssociatedTag

    # Component command
    [ValidateNotNullOrEmpty()] [String[]] $Command

    # Component version
    [ValidateNotNull()] [Version] $Version

    <#
        .DESCRIPTION
            Constructor of the stack component

        .PARAM AssociatedTag
            Associated command tag

        .PARAM Command
            Command of the component

        .PARAM Version
            Version of the component
     #>
    SystemStackComponent([String] $AssociatedTag, [String] $Command, [Version] $Version) {
        if ( [String]::IsNullOrWhiteSpace($Command)) {
            throw [ArgumentException]::new("The component command cannot be empty")
        }

        $this.AssociatedTag = $AssociatedTag
        $this.Command = -split $Command
        $this.Version = $Version
    }

    [String] ToString() {
        if (($this.AssociatedTag -eq $this.Command) -or ([String]::IsNullOrWhiteSpace($this.AssociatedTag))) {
            return "$( $this.AssociatedTag ) version $( $this.Version )"
        } else {
            return "$( $this.AssociatedTag ) ($( $this.Command )) version $( $this.Version )"
        }
    }
}
<#
    .DESCRIPTION
       This class groups the properties of the environment
#>
class EnvironmentContext {
    # Indicates whether or not load balancing will be enabled
    [ValidateNotNull()] [Boolean] $LoadBalancing

    # Indicates if a build should take place
    [ValidateNotNull()] [Boolean] $Build

    # Indicates if the demo should start (final step after having built the packages)
    [ValidateNotNull()] [boolean] $Start

    # Indicates if the demo should be runned or only sourced
    [ValidateNotNull()] [Boolean] $SourceOnly

    # Path to the environment file
    [ValidateNotNullOrEmpty()] [String] $EnvironmentFilePath

    # Environment file encoding
    [ValidateNotNullOrEmpty()] [String] $EnvironmentFileEncoding

    # Initial location of the running script (current directory)
    [ValidateNotNullOrEmpty()] [String] $InitialPath

    # Real location of the running script
    [ValidateNotNullOrEmpty()] [String] $ScriptPath

    # Loaded environment variables
    [ValidateNotNull()] [String[]] $EnvironmentVariables

    # Choosen system stack to run the demo
    [SystemStack] $SystemStack

    # Cleanup termination exit code
    [Byte] $CleanupExitCode

    <#
        .DESCRIPTION
            Constructor that initializes the default properties of the environment
    #>
    EnvironmentContext() {
        $this.LoadBalancing = $true
        $this.Build = $true
        $this.Start = $true
        $this.InitialPath = "$PWD"
        $this.ScriptPath = Get-ScriptRoot
        $this.SetLocationToScriptPath()
        $this.EnvironmentFilePath = ".env"
        $this.EnvironmentFileEncoding = "UTF8"
        $this.EnvironmentVariables = @()
        $this.SystemStack = $null
        $this.CleanupExitCode = 0
    }

    SetLocationToScriptPath() {
        if ($env:SCRIPT_PATH -and ($env:SCRIPT_PATH -ne $this.ScriptPath)) {
            if (Test-Path -PathType Container $env:SCRIPT_PATH) {
                $this.ScriptPath = (Resolve-Path $env:SCRIPT_PATH).Path
                $env:SCRIPT_PATH = $this.ScriptPath
            } else {
                throw [System.IO.DirectoryNotFoundException]::new("$env:SCRIPT_PATH is not a directory. Unable to continue.")
            }
        }
        
        try {
            if ("$PWD" -ne $this.ScriptPath) {
                Set-Location $this.ScriptPath
            }
        } catch {
            throw [System.IO.IOException]::new("Unable to switch to the $( $this.ScriptPath ) base directory of the script. Unable to continue.")
        }

        if (-not(Test-Path -PathType Leaf run.ps1)) {
            throw [System.IO.FileNotFoundException]::new("Unable to find the base script in the changed $( $this.ScriptPath ) directory. Unable to continue.")
        }
    }

    ResetLocationToInitialPath() {
        Set-Location $this.InitialPath
    }

    EnableLoadBalancing([Boolean] $LoadBalancing) {
        $this.LoadBalancing = $LoadBalancing
    }

    EnableBuild([Boolean] $Build) {
        $this.Build = $Build
    }

    EnableStart([Boolean] $Start) {
        $this.Start = $Start
    }

    EnableSourceOnlyMode([Boolean] $SourceOnly) {
        $this.SourceOnly = $SourceOnly
    }

    SetEnvironmentFile([String] $FilePath, [String] $Encoding) {
        $this.EnvironmentFilePath = $FilePath
        $this.EnvironmentFileEncoding = $Encoding
    }

    SetEnvironmentVariableKeys([String[]] $EnvironmentVariables) {
        $PreviousEnvironmentVariables = $this.EnvironmentVariables
        $this.EnvironmentVariables = @()

        if ($null -eq $EnvironmentVariables) {
            return
        } else {
            foreach ($EnvironmentVariable in $EnvironmentVariables) {
                if ($EnvironmentVariable -notmatch "^[a-zA-Z][a-zA-Z0-9_]*$") {
                    $this.EnvironmentVariables = $PreviousEnvironmentVariables
                    throw [System.ArgumentException]::new("The name of the environment variable ($EnvironmentVariable) cannot be null or empty and must not contain spaces")
                }

                $this.EnvironmentVariables += $EnvironmentVariable
            }
        }
    }

    AddEnvironmentVariableKeys([String[]] $EnvironmentVariables) {
        $PreviousEnvironmentVariables = $this.EnvironmentVariables

        if ($null -eq $EnvironmentVariables) {
            return
        }

        foreach ($EnvironmentVariable in $EnvironmentVariables) {
            if ($EnvironmentVariable -notmatch "^[a-zA-Z][a-zA-Z0-9_]*$") {
                $this.EnvironmentVariables = $PreviousEnvironmentVariables
                throw [System.ArgumentException]::new("The name of the environment variable ($EnvironmentVariable) cannot be null or empty and must not contain spaces")
            }

            $this.EnvironmentVariables += $EnvironmentVariable
        }

        $this.EnvironmentVariables = $this.EnvironmentVariables | Select-Object -Unique | Group-Object -Property { $_.ToUpper() } | ForEach-Object { $_.Group[0] }
    }

    RemoveEnvironmentVariables() {
        foreach ($Key in $this.EnvironmentVariables) {
            if (Test-Path env:\"$Key") {
                Write-Information "Removing environment variable $Key"
                Remove-Item env:\"$Key"
            }
        }

        $this.EnvironmentVariables = @()
    }

    ReadEnvironmentFile() {
        $this.EnvironmentVariables += Read-EnvironmentFile -FilePath $this.EnvironmentFilePath -Encoding $this.EnvironmentFileEncoding | Select-Object -Unique | Group-Object -Property { $_.ToUpper() } | ForEach-Object { $_.Group[0] }
    }

    SetSystemStack([SystemStack] $SystemStack) {
        $this.SystemStack = $SystemStack
    }
}

###############################
# Background tasks exceptions #
###############################

<#
    .DESCRIPTION
        Exception encountered while using a background task
#>
class BackgroundTaskException: System.Management.ManagementException {
    BackgroundTaskException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while using a background process
#>
class BackgroundProcessException: BackgroundTaskException {
    BackgroundProcessException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while starting a background task
#>
class StartBackgroundTaskException: BackgroundProcessException {
    StartBackgroundTaskException([String] $Message): base($Message) {
    }
}


<#
    .DESCRIPTION
        Exception encountered while starting a background process
#>
class StartBackgroundProcessException: StartBackgroundTaskException {
    StartBackgroundProcessException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while using a background job
#>
class BackgroundJobException: BackgroundTaskException {
    BackgroundJobException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while starting a background job
#>
class StartBackgroundJobException: BackgroundJobException {
    StartBackgroundJobException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while stopping a background task
#>
class StopBackgroundTaskException: BackgroundTaskException {
    StopBackgroundTaskException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while stopping a background process
#>
class StopBackgroundProcessException: StopBackgroundTaskException {
    StopBackgroundProcessException([String] $Message): base($Message) {
    }
}

<#
    .DESCRIPTION
        Exception encountered while stopping a background job
#>
class StopBackgroundJobException: StopBackgroundTaskException {
    StopBackgroundJobException([String] $Message): base($Message) {
    }
}

############################
# Background tasks classes #
############################

<#
    .DESCRIPTION
        Abstract class representing a basic instance of a background task
#>
class BackgroundTask {
    # Task start information properties
    [ValidateNotNull()] [Hashtable] $TaskStartInfo

    # Task stop information properties
    [ValidateNotNull()] [Hashtable] $TaskStopInfo

    # Task name
    [ValidatePattern("^[a-zA-Z][a-zA-Z0-9_]*$")] [String] $Name

    # Temporary file name that will be created by the process itself to indicate that it has been started
    [ValidateNotNull()] [String] $TemporaryFileName

    # Flag that indicates whether the temporary file has already been checked for waiting or not
    [ValidateNotNull()] [Int] $CheckedTemporaryFileExistence

    # Flag that indicates the state of the temporary file check
    [ValidateNotNull()] [Int] $CheckedTemporaryFileExistenceState

    # Flag to enable or disable the temporary file check
    [ValidateNotNull()] [Boolean] $TemporaryFileCheckEnabled

    # Flag which is set to true once a task stop is requested
    [ValidateNotNull()] [Boolean] $StopCallAlreadyExecuted

    # Default timeouts
    static [Int] $TemporaryFileWaitTimeout = 15
    static [Int] $StandardStopTimeout = 20
    static [Int] $KillTimeout = 8

    # Flags addressing the different error cases
    static [Int] $SuccessfullyStopped = 0
    static [Int] $TemporaryFileWaitUncompleted = -1
    static [Int] $TemporaryFileWaitCompleted = 0
    static [Int] $ProcessHasAlreadyExited = 3
    static [Int] $TemporaryFileWaitTimeoutError = 4
    static [Int] $FailedRemovingTmpFile = 5
    static [Int] $TemporaryFileWaitUnknownError = 6
    static [Int] $KilledDueToStopTimeout = 7
    static [Int] $KilledDueToUnknownError = 8

    # Flags concerning the stop fallbacks codes
    static [Int] $GracefulStopSuccessful = 0
    static [Int] $GracefulStopFailed = 1

    <#
        .DESCRIPTION
            Basic background task constructor.
            It defines the main parameters concerning the management of temporary files, which are common to all background tasks.
            Start and stop properties are initialized through this basic constructor.

        .PARAM TaskStartInfo
            Start info of the task that needs to be started

        .PARAM TaskStopInfo
            Stop info of the task that needs to be stopped

        .PARAM Name
            Name of the background task

        .PARAM TemporaryFileCheckEnabled
            Enable or disable the temporary file check
    #>
    BackgroundTask([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled) {
        $type = $this.GetType()

        if ($this.GetType() -eq [BackgroundTask]) {
            throw "Class $type must be inherited"
        }

        $this.TaskStartInfo = $TaskStartInfo
        $this.TaskStopInfo = $TaskStopInfo
        $this.Name = $Name
        $this.CheckedTemporaryFileExistence = $false
        $this.CheckedTemporaryFileExistenceState = [BackgroundTask]::TemporaryFileWaitUncompleted
        $this.TemporaryFileCheckEnabled = $TemporaryFileCheckEnabled
        $this.StopCallAlreadyExecuted = $false
        $this.TemporaryFileName = if ($TemporaryFileCheckEnabled) {
            $this.Name.ToLower() + "_" + [Guid]::NewGuid().ToString()
        } else {
            ""
        }

        if ($null -eq $this.TaskStopInfo.StandardStopTimeout) {
            $this.TaskStopInfo.StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
        }

        if ($null -eq $this.TaskStopInfo.KillTimeout) {
            $this.TaskStopInfo.KillTimeout = [BackgroundTask]::KillTimeout
        }

        $this.PreCheckSetup()
        $this.CheckTaskStartInfo()
        $this.CheckBasicTaskStopInfo()
        $this.CheckTaskStopInfo()
    }

    <#
        .DESCRIPTION
            Method that contains the pre check setup logic
    #>
    [Void] PreCheckSetup() {}
    

    <#
        .DESCRIPTION
            Returns only if the current task start info is valid, raises an exception otherwise
    #>
    [Void] CheckTaskStartInfo() {}

    <#
        .DESCRIPTION
            Returns only if the current basic task stop info is valid, raises an exception otherwise
    #>
    [Void] CheckBasicTaskStopInfo() {
        if (($this.TaskStopInfo.StandardStopTimeout -isnot [Int]) -or ($this.TaskStopInfo.StandardStopTimeout -lt 0)) {
            throw [InvalidOperationException]::new("Invalid standard timeout. Standard timeout cannot be negative.")
        }

        if (($this.TaskStopInfo.KillTimeout -isnot [Int]) -or ($this.TaskStopInfo.KillTimeout -lt 0)) {
            throw [InvalidOperationException]::new("Invalid force kill timeout. Force kill timeout cannot be negative.")
        }
    }

    <#
        .DESCRIPTION
            Returns only if the current task stop info is valid, raises an exception otherwise
    #>
    [Void] CheckTaskStopInfo() {}

    <#
        .DESCRIPTION
            Returns if the current task is alive

        .OUTPUTS
            true if the task is alive, false otherwise
    #>
    [Boolean] IsAlive() {
        throw "Must be implemented"
    }

    <#
        .DESCRIPTION
            Start a background task if not alive
    #>
    [Void] Start() {
        try {
            if (-not($this.IsAlive())) {
                $this.CheckTaskStartInfo()
                $this.StartIfNotAlive()
                $this.StopCallAlreadyExecuted = $false
            }
        } catch [StartBackgroundProcessException] {
            $this.Stop()
            throw $_
        }
    }

    <#
        .DESCRIPTION
            Start a background task if not alive (hidden core logic)

        .OUTPUTS
            Number representing the status of the start execution
    #>
    hidden [Void] StartIfNotAlive() {
        throw "Must be implemented"
    }

    <#
        .DESCRIPTION
            Stop a background task if alive

        .OUTPUTS
            Number representing the status of the stop execution
    #>
    [Int] Stop() {
        try {
            $this.CheckBasicTaskStopInfo()
            $this.CheckTaskStopInfo()

            if ( $this.CanStop()) {
                $StopCode = $this.StopIfAlive()
                $this.StopCallAlreadyExecuted = $true
                $this.GracefulStop()

                return $StopCode
            }

            return 0
        } catch {
            $this.StopCallAlreadyExecuted = $true
            $this.GracefulStop()
            throw $_
        }
    }

    <#
        .DESCRIPTION
            Returns if the task can be stopped or not

        .OUTPUTS
            Boolean flag indicating if the task can be stopped or not
     #>
    [Boolean] CanStop() {
        return $this.IsAlive()
    }

    <#
        .DESCRIPTION
            Stop a background task if alive (hidden core logic)

        .OUTPUTS
            Number representing the status of the stop execution
    #>
    hidden [Int] StopIfAlive() {
        throw "Must be implemented"
    }

    <#
        .DESCRIPTION
            Executes a fallback stop shutdown in the event that the standard shutdown logic was not executed correctly

        .OUTPUTS
            Number representing the status of the fallback stop execution
    #>
    hidden [Int] GracefulStop() {
        return [BackgroundTask]::GracefulStopSuccessful
    }

    <#
        .DESCRIPTION
            Wait for the temporary file associated with the background task to be created

        .PARAM HasExited
            Script block that checks if the task has already exited

        .PARAM TemporaryFileWaitTimeout
            Temporary file wait timeout before aborting

        .OUTPUTS
            Number associated with the state of waiting for the creation of the temporary file
    #>
    [Int] SyncWithTemporaryFile([System.Management.Automation.ScriptBlock] $HasExited, [Int] $TemporaryFileWaitTimeout) {
        try {
            if ($this.TemporaryFileCheckEnabled) {
                $CopiedTemporaryFileWaitTimeout = $TemporaryFileWaitTimeout

                if ($null -eq $CopiedTemporaryFileWaitTimeout) {
                    $CopiedTemporaryFileWaitTimeout = [BackgroundTask]::TemporaryFileWaitTimeout
                }
    
                if ($CopiedTemporaryFileWaitTimeout -lt 0) {
                    throw [ArgumentException]::new("Invalid timeout. Temporary file wait timeout cannot be negative.")
                }
    
                if ($null -eq $HasExited) {
                    $HasExited = {
                        return -not($this.IsAlive())
                    }
                }
    
                if (($this.TemporaryFileCheckEnabled) -and (-not($this.CheckedTemporaryFileExistence))) {
                    Write-Information "Waiting for $( $this.Name ) to create the $env:TEMP\$( $this.TemporaryFileName ) file ... ($TemporaryFileWaitTimeout seconds)"
                    $WaitTime = 0
                    $ReturnCode = 0
    
                    while (-not(Test-Path -Type Leaf "$env:TEMP\$( $this.TemporaryFileName )")) {
                        if (& $HasExited) {
                            Write-Warning "$( $this.Name ) has already exited"
                            $ReturnCode = [BackgroundTask]::ProcessHasAlreadyExited
                            break
                        }
    
                        if ($WaitTime -eq $CopiedTemporaryFileWaitTimeout) {
                            Write-Error "Failed to wait for the creation of the $env:TEMP\$( $this.TemporaryFileName ) file" -ErrorAction Continue
                            $ReturnCode = [BackgroundTask]::TemporaryFileWaitTimeoutError
                            break
                        }
    
                        Start-Sleep -Seconds 1
                        $WaitTime++
                    }

                    $Code = $?
                    
                    try {
                        if (Test-Path -Type Leaf "$env:TEMP\$( $this.TemporaryFileName )") {
                            Remove-Item "$env:TEMP\$( $this.TemporaryFileName )" -ErrorAction Continue
                        }

                        $Code = $?
                    } catch {
                        $Code = $?
                        Write-Warning "Failed removing the $env:TEMP\$( $this.TemporaryFileName ) temporary file"
                    } finally {
                        if ($ReturnCode -ne [BackgroundTask]::TemporaryFileWaitTimeoutError) {        
                            $this.CheckedTemporaryFileExistenceState = if ($Code) {
                                $ReturnCode
                            } else {
                                [BackgroundTask]::FailedRemovingTmpFile
                            }
                        } else {
                            $this.CheckedTemporaryFileExistenceState = $ReturnCode
                        }
    
                        $this.CheckedTemporaryFileExistence = $true
                    }
                }
            } else {
                $this.CheckedTemporaryFileExistenceState = [BackgroundTask]::TemporaryFileWaitUncompleted
            }
        } catch {
            Write-Error "Failed running the temporary file creation check loop of $env:TEMP\$( $this.TemporaryFileName )" -ErrorAction Continue
            $this.CheckedTemporaryFileExistenceState = [BackgroundTask]::TemporaryFileWaitUnknownError
            $this.CheckedTemporaryFileExistence = $true
        }

        return $this.CheckedTemporaryFileExistenceState
    }

    <#
        .DESCRIPTION
            Default wrapper for the SyncWithTemporaryFile method

        .OUTPUTS
            Number associated with the state of waiting for the creation of the temporary file
     #>
    [Int] SyncWithTemporaryFile() {
        return $this.SyncWithTemporaryFile({
            return -not($this.IsAlive())
        }, [BackgroundTask]::TemporaryFileWaitTimeout)
    }
}

<#
    .DESCRIPTION
        Concrete class that represents a instance of a Windows process
#>
class BackgroundProcess: BackgroundTask {
    # Process
    [System.Diagnostics.Process] $Process

    <#
        .DESCRIPTION
            Constructor of the background process

        .PARAM ProcessStartInfo
            Start info of the process that needs to be started

        .PARAM ProcessStopInfo
            Stop info of the process that needs to be stopped

        .PARAM Name
            Name of the background task

        .PARAM TemporaryFileCheckEnabled
            Enable or disable the temporary file check
    #>
    BackgroundProcess([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name = "", [Boolean] $TemporaryFileCheckEnabled): base($ProcessStartInfo, $ProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {
        $this.TaskStartInfo.NoNewWindow = if ($this.TaskStartInfo.NoNewWindow -isnot [Boolean]) {
            $true
        } else {
            $this.TaskStartInfo.NoNewWindow
        }

        $this.Process = $null
    }

    [Boolean] IsAlive() {
        return $this.Process -and (-not($this.Process.HasExited))
    }

    hidden [Void] StartIfNotAlive() {
        try {
            Write-Information "Starting the $( $this.Name ) process"
            $env:TMP_RUNNER_FILE = $this.TemporaryFileName
            $TaskStartInfo = $this.TaskStartInfo
            $this.Process = Start-Process @TaskStartInfo -PassThru
        } catch {
            throw [StartBackgroundProcessException]::new("Failed to start the $( $this.Name ) process : $( $_.Exception.Message )")
        }
    }

    hidden [Int] StopIfAlive() {
        $ForceKill = $false
        $ReturnCode = [BackgroundTask]::SuccessfullyStopped

        if (-not($this.StopCallAlreadyExecuted)) {
            Write-Information "Stopping the $( $this.Name ) process with PID $( $this.Process.Id )"
        } else {
            Write-Information "Killing the $( $this.Name ) process with PID $( $this.Process.Id )"
        }

        $SyncCode = $this.SyncWithTemporaryFile()

        if (($SyncCode -eq [BackgroundTask]::TemporaryFileWaitCompleted) -and (-not($this.StopCallAlreadyExecuted))) {
            try {
                # Temporary file successfully created : wait for the process to stop
                $this.Process | Wait-Process -Timeout $this.TaskStopInfo.StandardStopTimeout > $null

                if (-not($?)) {
                    throw [StopBackgroundProcessException]::new("Failed waiting for the process to exit within $( $this.TaskStopInfo.StandardStopTimeout ) seconds")
                }

                Write-Information "Stopped the $( $this.Name ) process with PID $( $this.Process.Id )"
            } catch {
                Write-Warning "Failed waiting for the $( $this.Name ) process with PID $( $this.Process.Id ) to exit: $( $_.Exception.Message ). Trying to kill the process." -ErrorAction Continue
                $ForceKill = $true
            }
        } elseif ($SyncCode -eq [BackgroundTask]::ProcessHasAlreadyExited) {
            return $SyncCode
        } else {
            $ForceKill = $true
        }

        if ($ForceKill) {
            # Fatal error / force kill request : force kill the process
            $this.StopProcessTree()
            Write-Information "Killed the $( $this.Name ) process with PID $( $this.Process.Id )"

            if ($this.TemporaryFileCheckEnabled) {
                $ReturnCode = $this.CheckedTemporaryFileExistenceState
            }
        }

        return $ReturnCode
    }

    <#
        .DESCRIPTION
            Stop the entire process tree of the current process
    #>
    hidden [Void] StopProcessTree() {
        $Success = $true
        $AdditionalErrorMessage = ""

        try {
            # If there are child processes, kill the entire process tree
            $ChildProcesses = Get-WmiObject -Class Win32_Process -Filter "ParentProcessId = '$( $this.Process.Id )'"

            if ($null -eq $ChildProcesses) {
                $ChildProcesses = @()
            }

            if ($ChildProcesses -isnot [Object[]]) {
                $ChildProcesses = @($ChildProcesses)
            }

            if ($ChildProcesses.Length) {
                $ChildProcessesStack = [System.Collections.Stack]::new()

                # Initialize the first child processes in a stack
                foreach ($ChildProcess in $ChildProcesses) {
                    $ChildProcessesStack.Push($ChildProcess)
                }

                # Process the child processes kill recursively using a stack
                while ($ChildProcessesStack.Count -gt 0) {
                    $CurrentChildProcess = $ChildProcessesStack.Pop()
                    $NextChildProcesses = Get-WmiObject -Class Win32_Process -Filter "ParentProcessId = '$( $CurrentChildProcess.ProcessId )'"

                    if ($null -eq $NextChildProcesses) {
                        $NextChildProcesses = @()
                    }

                    if ($NextChildProcesses -isnot [Object[]]) {
                        $NextChildProcesses = @($NextChildProcesses)
                    }

                    # Add the next child processes to the stack
                    foreach ($ChildProcess in $NextChildProcesses) {
                        $ChildProcessesStack.Push($ChildProcess)
                    }

                    # Kill the current poped child process
                    try {
                        Write-Information "Killing the process with PID $( $CurrentChildProcess.ProcessId )"

                        try {
                            $CurrentChildProcess = Get-Process -Id $CurrentChildProcess.ProcessId
                        } catch {
                            continue
                        }
                        
                        $CurrentChildProcess | Stop-Process -Force

                        if (-not($?)) {
                            throw [StopBackgroundProcessException]::new("Stop-Process failed")
                        }

                        $CurrentChildProcess | Wait-Process -Timeout $this.TaskStopInfo.KillTimeout > $null

                        if (-not($?)) {
                            throw [StopBackgroundProcessException]::new("Failed waiting for the process to exit within $( $this.TaskStopInfo.KillTimeout ) seconds")
                        }
                    } catch {
                        $AdditionalErrorMessage += "Failed to kill the process with PID $( $CurrentChildProcess.ProcessId ) : $( $_.Exception.Message )"
                        Write-Error "Failed to kill the process with PID $( $CurrentChildProcess.ProcessId ) : $( $_.Exception.Message )" -ErrorAction Continue
                        $Success = $false
                    }
                }
            }

            # Kill the current process
            try {
                $this.Process | Stop-Process -Force

                if (-not($?)) {
                    throw [StopBackgroundProcessException]::new("Stop-Process failed")
                }

                $this.Process | Wait-Process -Timeout $this.TaskStopInfo.KillTimeout > $null

                if (-not($?)) {
                    throw [StopBackgroundProcessException]::new("Failed waiting for the process to terminate within $( $this.TaskStopInfo.KillTimeout ) seconds")
                }
            } catch {
                $AdditionalErrorMessage += "Failed to kill the process with PID $( $this.Process.Id ) : $( $_.Exception.Message )"
                Write-Error "Failed to kill the process with PID $( $this.Process.Id ) : $( $_.Exception.Message )" -ErrorAction Continue
                $Success = $false
            }
        } catch {
            throw [StopBackgroundProcessException]::new("Unknown error occurred while trying to kill the process tree with PPID $( $this.Process.Id )")
        }

        if (-not($Success)) {
            throw [StopBackgroundProcessException]::new("Failed to kill the process tree of the process with PPID $( $this.Process.Id ) : $AdditionalErrorMessage")
        }
    }

    hidden [Int] GracefulStop() {
        $Success = $true

        switch ($this.Name) {
            VglFront {
                # Remove the line concerning the temporary runner file
                Set-Content -Path vglfront\.env -Value (Get-Content -Path vglfront\.env -ErrorAction SilentlyContinue | Select-String -Pattern 'TMP_RUNNER_FILE' -NotMatch) -ErrorAction SilentlyContinue
                $Success = $?

                # Remove temporary JavaScript environment file to avoid conflicts with Docker
                if (Test-Path vglfront\src\assets\environment.js -ErrorAction SilentlyContinue) {
                    Write-Information "Removing temporary JavaScript file src\assets\environment.js"
                    Remove-Item vglfront\src\assets\environment.js -ErrorAction SilentlyContinue
                    $Success = if ($?) {
                        $Success
                    } else {
                        $false
                    }
                } else {
                    $Success = if ($?) {
                        $Success
                    } else {
                        $false
                    }
                }
            }
        }

        if ($this.TemporaryFileCheckEnabled) {
            if (Test-Path "$env:TEMP\$( $this.TemporaryFileName )" -ErrorAction SilentlyContinue) {
                Remove-Item "$env:TEMP\$( $this.TemporaryFileName )" -ErrorAction SilentlyContinue
            }
        }
        
        $Success = if ($?) {
            $Success
        } else {
            $false
        }

        if ($Success) {
            return [BackgroundTask]::GracefulStopSuccessful
        } else {
            return [BackgroundTask]::GracefulStopFailed
        }
    }
}

<#
    .DESCRIPTION
        Concrete class that represents a instance of a Docker Compose process
#>
class BackgroundDockerComposeProcess: BackgroundProcess {
    # Available compatible Docker Compose CLI. If not found, the strategy invocation will fail.
    [ValidateNotNull()] [SystemStack] $DockerComposeCli

    # Background process that manages the start of the Docker services
    [BackgroundProcess] $DockerComposeServicesOrchestrator

    # Background process that shows the output of the Docker services
    [BackgroundProcess] $DockerComposeServicesLogger

    # Arguments that refer to the options allowing the execution of Docker with the Compose mode if necessary
    [String[]] $DockerComposeProcessArgumentList

    <#
        .DESCRIPTION
            Constructor of the Docker Compose process

        .PARAM DockerComposeProcessStartInfo
            Start info of the Docker Compose process that needs to be started

        .PARAM DockerComposeProcessStopInfo
            Stop info of the Docker Compose process that needs to be stopped

        .PARAM Name
            Name of the background task associated to the process

        .PARAM TemporaryFileCheckEnabled
            Enable or disable the temporary file check
    #>
    BackgroundDockerComposeProcess([Hashtable] $DockerComposeProcessStartInfo, [Hashtable] $DockerComposeProcessStopInfo, [String] $Name): base($DockerComposeProcessStartInfo, $DockerComposeProcessStopInfo, $Name, $false) {
        if ($this.DockerComposeCli.SystemStackComponents[0].Command.Length -gt 1) {
            $this.TaskStartInfo.DockerComposeProcessArgumentList = $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] 
        } else {
            $this.TaskStartInfo.DockerComposeProcessArgumentList = @($this.DockerComposeCli.SystemStackComponents[0].Command[1])
        }

        if ($this.TaskStartInfo.ProjectName) {
            $this.TaskStartInfo.ProjectArgumentList = @("-p", $this.TaskStartInfo.ProjectName)
        } else {
            $this.TaskStartInfo.ProjectArgumentList = @()
        }

        $this.DockerComposeServicesOrchestrator = [BackgroundTaskFactory]::new($false).buildProcess((@{
            FilePath = $this.DockerComposeCli.SystemStackComponents[0].Command[0]
            ArgumentList = "$( $this.TaskStartInfo.DockerComposeProcessArgumentList ) $( $this.TaskStartInfo.ProjectArgumentList ) $( $this.TaskStartInfo.StartArguments ) up $( $this.TaskStartInfo.Services ) -d"
        }), "$( $this.Name )DockerComposeServicesOrchestrator")

        $this.DockerComposeServicesLogger = [BackgroundTaskFactory]::new($false).buildProcess((@{
            FilePath = $this.DockerComposeCli.SystemStackComponents[0].Command[0]
            ArgumentList = "$( $this.TaskStartInfo.DockerComposeProcessArgumentList ) $( $this.TaskStartInfo.ProjectArgumentList ) $( $this.TaskStartInfo.StartArguments ) up $( $this.TaskStartInfo.Services )"
        }), "$( $this.Name )DockerComposeServicesLogger")
    }

    [Void] PreCheckSetup() {
        $CurrentSystemStack = [SystemStackDetector]::RetrieveCurrentSystemStack()

        if ((-not($CurrentSystemStack)) -or (-not($CurrentSystemStack.Tag.Equals([SystemStackTag]::Docker)))) {
            if (-not($DetectedDockerComposeCli = [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli())) {
                throw [System.Management.Automation.CommandNotFoundException]::new("No compatible and available Docker Compose version found. Requires Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ).")
            }

            $this.DockerComposeCli = [SystemStack]::new([SystemStackTag]::Docker, @($DetectedDockerComposeCli))
        } else {
            $this.DockerComposeCli = $CurrentSystemStack
        }

        if ($null -eq $this.TaskStartInfo.StartArguments) {
            $this.TaskStartInfo.StartArguments = @()
        }
        
        if ($null -eq $this.TaskStartInfo.Services) {
            $this.TaskStartInfo.Services = @()
        }

        if ($null -eq $this.TaskStartInfo.DockerComposeProcessArgumentList) {
            $this.TaskStartInfo.DockerComposeProcessArgumentList = @()
        }

        if ($null -eq $this.TaskStartInfo.ProjectArgumentList) {
            $this.TaskStartInfo.ProjectArgumentList = @()
        }
    }

    [Void] CheckTaskStartInfo() {
        if ((-not($this.DockerComposeCli)) -or ($this.DockerComposeCli.SystemStackComponents.Length -lt 1)) {
            throw [System.Management.Automation.CommandNotFoundException]::new("No compatible and available Docker Compose version found. Requires Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ).")
        }

        if ($this.TaskStartInfo.StartArguments -isnot [Array]) {
            throw [System.InvalidOperationException]::new("Docker Compose start arguments must be passed as an array")
        }

        if ($this.TaskStartInfo.Services -isnot [Array]) {
            throw [System.InvalidOperationException]::new("Docker Compose service names must be passed as an array")
        }

        if ($this.TaskStartInfo.DockerComposeProcessArgumentList -isnot [Array]) {
            throw [System.InvalidOperationException]::new("Docker Compose process argument list must be passed as an array")
        }

        if ($this.TaskStartInfo.ProjectArgumentList -isnot [Array]) {
            throw [System.InvalidOperationException]::new("Docker Compose project argument list must be passed as an array")
        }

        if (($null -ne $this.TaskStartInfo.ProjectName) -and ($this.TaskStartInfo.ProjectName -isnot [String])) {
            throw [System.InvalidOperationException]::new("Docker Compose project name must be a string")
        }
    }

    [Boolean] IsAlive() {
        return ($this.DockerComposeServicesOrchestrator -and $this.DockerComposeServicesOrchestrator.IsAlive()) -or ($this.DockerComposeServicesLogger -and $this.DockerComposeServicesLogger.IsAlive())
    }

    hidden [Void] StartIfNotAlive() {
        try {
            Write-Information "Starting the $( $this.Name ) Docker Compose services"
            $this.DockerComposeServicesOrchestrator.Start()
            $this.DockerComposeServicesOrchestrator.Process | Wait-Process

            if (-not($?) -or ($LASTEXITCODE -ne 0)) {
                throw [StartBackgroundProcessException]::new("$( $this.Name ) Docker Compose services start failed")
            }

            $this.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted = $true
            
            Write-Information "Starting the $( $this.Name ) Docker Compose services logger"
            $this.DockerComposeServicesLogger.Start()

            if (-not($?) -or ($LASTEXITCODE -ne 0)) {
                throw [StartBackgroundProcessException]::new("$( $this.Name ) Docker Compose services logger start failed")
            }
        } catch {
            throw [StartBackgroundProcessException]::new("Failed to start the $( $this.Name ) Docker Compose services : $( $_.Exception.Message )")
        }
    }

    <#
        .DESCRIPTION
            Core method for stopping containers using a custom command prompt instruction

        .PARAM Command
            Command instruction to stop containers

        .PARAM SuccessReturnCode
            Code returned when the stop operation is successful

        .PARAM ExceptionMessage
            Exception message returned on failure

        .OUTPUTS
            Return code on success, exception on failure
    #>
    hidden [Int] StopServices([String] $Command, [Int] $SuccessReturnCode, [String] $ExceptionMessage) {
        $Success = $true
        $StopErrorDetails = ""

        # StdErr redirection bug, using the old CMD as alternative: https://github.com/PowerShell/PowerShell/issues/4002
        cmd /c "$Command" | Out-Host
            
        if (-not($?) -or ($LASTEXITCODE -ne 0)) {
            $Success = $false
        }
    
        try {
            $this.DockerComposeServicesOrchestrator.Stop()
        } catch {
            $StopErrorDetails += $_.Exception.Message
            $Success = $false
        } finally {
            try {
                $this.DockerComposeServicesLogger.Stop()
            } catch {
                $StopErrorDetails += "- $($_.Exception.Message)"
                $Success = $false
            }
        }
    
        if ($Success) {
            return $SuccessReturnCode
        }

        throw [StopBackgroundProcessException]::new($ExceptionMessage + " : $StopErrorDetails")
    }

    hidden [Int] StopIfAlive() {
        $this.TemporaryFileCheckEnabled = $false

        if ($this.StopCallAlreadyExecuted) {
            $this.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted = $true
            $this.DockerComposeServicesLogger.StopCallAlreadyExecuted = $true
        }

        if (-not($this.StopCallAlreadyExecuted)) {
            Write-Information "Stopping the $( $this.Name ) Docker Compose services"
        } else {
            Write-Information "Killing the $( $this.Name ) Docker Compose services"
        }

        try {
            # Stop the service container gracefully
            # StdErr redirection bug, using the old CMD as alternative: https://github.com/PowerShell/PowerShell/issues/4002
            if (-not($this.StopCallAlreadyExecuted)) {
                return $this.StopServices(
                    "$( $this.DockerComposeCli.SystemStackComponents[0].Command[0] ) $( $this.TaskStartInfo.DockerComposeProcessArgumentList ) $( $this.TaskStartInfo.ProjectArgumentList ) stop $( $this.TaskStartInfo.Services ) -t $( $this.TaskStopInfo.StandardStopTimeout ) 2>&1",
                    [BackgroundTask]::SuccessfullyStopped,
                    "Docker Compose $( $this.Name ) services stop failed"
                )
            }
            
            $this.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted = $true
            $this.DockerComposeServicesLogger.StopCallAlreadyExecuted = $true

            return $this.StopServices(
                "$( $this.DockerComposeCli.SystemStackComponents[0].Command[0] ) $( $this.TaskStartInfo.DockerComposeProcessArgumentList ) $( $this.TaskStartInfo.ProjectArgumentList ) kill $( $this.TaskStartInfo.Services ) 2>&1",
                [BackgroundTask]::SuccessfullyStopped,
                "Docker Compose $( $this.Name ) services kill failed"
            )
        } catch {
            $this.DockerComposeServicesOrchestrator.StopCallAlreadyExecuted = $true
            $this.DockerComposeServicesLogger.StopCallAlreadyExecuted = $true
                
            # Fatal error or timeout : force kill the service container
            Write-Warning "Failed to stop a $( $this.Name ) Docker Compose process : $( $_.Exception.Message ). Trying to kill the Docker Compose services and the logger process."

            return $this.StopServices(
                "$( $this.DockerComposeCli.SystemStackComponents[0].Command[0] ) $( $this.TaskStartInfo.DockerComposeProcessArgumentList ) $( $this.TaskStartInfo.ProjectArgumentList ) kill $( $this.TaskStartInfo.Services ) 2>&1",
                [BackgroundTask]::KilledDueToUnknownError,
                "Docker Compose $( $this.Name ) services kill failed"
            )
        }
    }
}

<#
    .DESCRIPTION
        Concrete class that represents a instance of a background job.
        Since the jobs cannot retrieve the results in real time, we start a new PowerShell process to retrieve the results of the jobs in parallel.
#>
class BackgroundJob: BackgroundTask {
    # Job process
    [System.Diagnostics.Process] $Process

    <#
        .DESCRIPTION
            Constructor of the background job

        .PARAM Name
            Name of the background task associated to the job

         .PARAM JobStartInfo
            Start info of the job that needs to be started

        .PARAM JobStartInfo
            Stop info of the job that needs to be stopped

        .PARAM TemporaryFileCheckEnabled
            Enable or disable the temporary file check
    #>
    BackgroundJob([Hashtable] $JobStartInfo, [Hashtable] $JobStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($JobStartInfo, $JobStopInfo, $Name, $TemporaryFileCheckEnabled) {
        $this.Process = $null
    }

    [Void] PreCheckSetup() {
        if ($null -eq $this.TaskStartInfo.ScriptBlock) {
            $this.TaskStartInfo.ScriptBlock = {}
        }

        if ($null -eq $this.TaskStartInfo.ArgumentList) {
            $this.TaskStartInfo.ArgumentList = @()
        }
    }

    [Void] CheckTaskStartInfo() {
        if ($this.TaskStartInfo.ScriptBlock -isnot [ScriptBlock]) {
            throw [InvalidOperationException]::new("Incompatible ScriptBlock found. Background jobs must be associated to an init ScriptBlock.")
        }

        if ($this.TaskStartInfo.ArgumentList -isnot [Array]) {
            throw [InvalidOperationException]::new("Incompatible ArgumentList found. If used, the argument list must be an array of data arguments.")
        }
    }

    [Boolean] IsAlive() {
        return $this.Process -and (-not($this.Process.HasExited))
    }

    hidden [Void] StartIfNotAlive() {
        try {
            Write-Information "Starting the $( $this.Name ) job"

            $EncodedScriptBlockInfo = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($this.TaskStartInfo.ScriptBlock.ToString()))
            $JsonArgumentList = if ($this.TaskStartInfo.ArgumentList.Length) {
                $this.TaskStartInfo.ArgumentList | ConvertTo-Json
            } else {
                ""
            }
            $EncodedArgumentList = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($JsonArgumentList))

            $this.Process = Start-Process powershell -NoNewWindow -ArgumentList "-Command", "
`$HashtableTaskStartInfo = [ScriptBlock]::Create([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$EncodedScriptBlockInfo')))
`$TaskStartInfoArgumentList = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$EncodedArgumentList')) | ConvertFrom-Json
`$Job = Start-Job @HashtableTaskStartInfo -ArgumentList `$TaskStartInfoArgumentList
while (`$Job -and (`$Job.State -eq 'Running')) {
    `$Output = `Receive-Job -Job `$Job -ErrorAction SilentlyContinue

    if (`$Output) {
        Write-Output `$Output
    }

    Start-Sleep -Seconds 1
}

if (`$LASTEXITCODE) {
    exit `$LASTEXITCODE
} elseif (`$Job.State -eq 'Failed') {
    exit 2
}
exit" -PassThru
        } catch {
            throw [StartBackgroundJobException]::new("Failed to start the $( $this.Name ) job : $( $_.Exception.Message )")
        }
    }

    hidden [Int] StopIfAlive() {
        $ForceKill = $false
        $ReturnCode = [BackgroundTask]::SuccessfullyStopped

        if (-not($this.StopCallAlreadyExecuted)) {
            Write-Information "Stopping the $( $this.Name ) job with PID $( $this.Process.Id )"
        } else {
            Write-Information "Killing the $( $this.Name ) job with PID $( $this.Process.Id )"
        }

        $SyncCode = $this.SyncWithTemporaryFile()

        if (($SyncCode -eq [BackgroundTask]::TemporaryFileWaitCompleted) -and (-not($this.StopCallAlreadyExecuted))) {
            # Temporary file successfully created : wait for the job to stop
            try {
                $this.Process | Wait-Process -Timeout $this.TaskStopInfo.StandardStopTimeout> $null

                if (-not($?)) {
                    throw [StopBackgroundJobException]::new("Failed waiting for the job to exit within $( $this.TaskStopInfo.StandardStopTimeout ) seconds")
                }

                Write-Information "Stopped the $( $this.Name ) job with PID $( $this.Process.Id )"
            } catch {
                Write-Warning "Failed waiting for the $( $this.Name ) job with PID $( $this.Process.Id ) to exit : $( $_.Exception.Message ). Trying to kill the job." -ErrorAction Continue
                $ForceKill = $true
            }
        } elseif ($SyncCode -eq [BackgroundTask]::ProcessHasAlreadyExited) {
            return $SyncCode
        } else {
            $ForceKill = $true
        }

        # Fatal error / force kill request : force kill the job
        if ($ForceKill) {
            try {
                $this.Process | Stop-Process -Force

                if (-not($?)) {
                    throw [StopBackgroundJobException]::new("Failed stopping the job")
                }

                $this.Process | Wait-Process -Timeout $this.TaskStopInfo.KillTimeout > $null

                if (-not($?)) {
                    throw [StopBackgroundJobException]::new("Failed waiting for the job to terminate within $( $this.TaskStopInfo.KillTimeout ) seconds")
                }

                Write-Information "Killed the $( $this.Name ) job with PID $( $this.Process.Id )"

                if ($this.TemporaryFileCheckEnabled) {
                    $ReturnCode = $this.CheckedTemporaryFileExistenceState
                }
            } catch {
                throw [StopBackgroundJobException]::new("Failed to kill the $( $this.Name ) job with PID $( $this.Process.Id ): $( $_.Exception.Message )")
            }
        }

        return $ReturnCode
    }
}

<#
    .DESCRIPTION
        Factory that automatically chooses the most appropriate background task constructor
#>
class BackgroundTaskFactory {
    # Name of the background task
    [ValidateNotNull()] [Boolean] $TemporaryFileCheckEnabled

    <#
        .DESCRIPTION
            Constructor of the factory background task delegator

        .PARAM Name
            Name of the background task
     #>
    BackgroundTaskFactory([Boolean] $TemporaryFileCheckEnabled) {
        $this.TemporaryFileCheckEnabled = $TemporaryFileCheckEnabled
    }

    [BackgroundTask] buildProcess([Hashtable] $ProcessStartInfo, [String] $Name) {
        return [BackgroundProcess]::new($ProcessStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildProcess([Hashtable] $ProcessStartInfo, [Hashtable] $ProcessStopInfo, [String] $Name) {
        return [BackgroundProcess]::new($ProcessStartInfo, $ProcessStopInfo, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildDockerComposeProcess([Hashtable] $DockerComposeProcessStartInfo, [String] $Name) {
        return [BackgroundDockerComposeProcess]::new($DockerComposeProcessStartInfo, @{
        }, $Name)
    }

    [BackgroundTask] buildDockerComposeProcess([Hashtable] $DockerComposeProcessStartInfo, [Hashtable] $DockerComposeProcessStopInfo, [String] $Name) {
        return [BackgroundDockerComposeProcess]::new($DockerComposeProcessStartInfo, $DockerComposeProcessStopInfo, $Name)
    }

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [String] $Name) {
        return [BackgroundJob]::new($JobStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [Hashtable] $JobStopInfo, [String] $Name) {
        return [BackgroundJob]::new($JobStartInfo, $JobStopInfo, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildTask([Hashtable] $TaskStartInfo, [String] $Name, [System.Reflection.TypeInfo] $Type) {
        switch ($Type) {
            BackgroundProcess { return $this.buildProcess($TaskStartInfo, $Name) }
            BackgroundDockerComposeProcess { return $this.buildDockerComposeProcess($TaskStartInfo, $Name) }
            BackgroundJob { return $this.buildJob($TaskStartInfo, $Name) }
        }

        throw [System.InvalidOperationException]::new("Invalid BackgroundTask type passed to the factory method")
    }

    [BackgroundTask] buildTask([Hashtable] $TaskStartInfo, [Hashtable] $TaskStopInfo, [String] $Name, [System.Reflection.TypeInfo] $Type) {
        switch ($Type) {
            [BackgroundProcess] { return $this.buildProcess($TaskStartInfo, $TaskStopInfo, $Name) }
            [BackgroundDockerComposeProcess] { return $this.buildDockerComposeProcess($TaskStartInfo, $TaskStopInfo, $Name) }
            [BackgroundJob] { return $this.buildJob($TaskStartInfo, $TaskStopInfo, $Name) }
        }

        throw [System.InvalidOperationException]::new("Invalid BackgroundTask type passed to the factory method")
    }
}

##################
# Core functions #
##################

<#
    .DESCRIPTION
       This is the main class that manages the execution of the demo
#>
class Runner {
    # Environment properties
    static [EnvironmentContext] $EnvironmentContext

    # Background demo tasks
    static [Array] $Tasks

    <#
        .DESCRIPTION
             Run the load-balancing demo given the passed run arguments

        .PARAM Args
            --no-start : don't start the demo
            --no-build : don't build the packages when starting the demo. If some packages are missing, the build will be automatically enabled.
            --no-load-balancing : because of the demo intent, the load balancing is enabled by default
            --source-only : don't run the demo at all. Useful for testing.
    #>
    static [Void] Main([String[]] $Options) {
        try {
            [SystemStackDetector]::ChoosenSystemStack = $null
            [Runner]::EnvironmentContext = [EnvironmentContext]::new()
            [Runner]::Tasks = @()
    
            # Parse run arguments
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

        # Execute if not sourced
        if (-not([Runner]::EnvironmentContext.SourceOnly)) {
            if ((-not([Runner]::EnvironmentContext.Start))-and (-not([Runner]::EnvironmentContext.Build))) {
                break
            }

            [Runner]::Run()
        }
    }

    hidden static [Void] Run() {
        try {
            # Auto-choose the launch / environment method
            [Runner]::AutoChooseSystemStack($false)

            # Auto-configure the environment and environment variables
            [Runner]::ConfigureEnvironmentVariables()

            # Build demo packages
            [Runner]::Build()

            # Ready : start the demo !
            [Runner]::Start()
        } finally {
            [Runner]::Cleanup([Runner]::EnvironmentContext.CleanupExitCode)
        }
    }

    <#
        .DESCRIPTION
            Auto-choose the launch / environment method

        .PARAM ThrowException
            If this option is enabled, when an error occurs, the exception is thrown again
    #>
    hidden static [Void] AutoChooseSystemStack([Boolean] $ThrowException) {
        if ([Runner]::EnvironmentContext.CleanupExitCode -ne 0) {
            break
        }
        
        try {
            if (($null -eq [Runner]::EnvironmentContext.SystemStack) -and ([Runner]::EnvironmentContext.Start -or [Runner]::EnvironmentContext.Build)) {
                Write-Information "Auto-choosing the launch method ..."
                [Runner]::EnvironmentContext.SetSystemStack([SystemStackDetector]::RetrieveMostAppropriateSystemStack())
                Write-Information ([Runner]::EnvironmentContext.SystemStack.ToString())
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(127)

            if ($ThrowException) {
                throw $_
            }
        }
    }

    <#
        .DESCRIPTION
            Default wrapper for the system stack auto-choose
    #>
    hidden static [Void] AutoChooseSystemStack() {
        [Runner]::AutoChooseSystemStack($false)
    }

    <#
        .DESCRIPTION
            Auto-configure some variables related to the Git / DNS environment
    #>
    hidden static [Void] ConfigureEnvironmentVariables() {
        if ([Runner]::EnvironmentContext.CleanupExitCode -ne 0) {
            break
        }

        try {
            [Runner]::EnvironmentContext.SetLocationToScriptPath()
            [Console]::TreatControlCAsInput = $false

            if ([Runner]::EnvironmentContext.Start) {
                Write-Information "Reading environment variables ..."
                [Runner]::EnvironmentContext.ReadEnvironmentFile()
                
                Write-Information "Environment auto-configuration ..."

                try {
                    $env:GIT_CONFIG_BRANCH = Invoke-And -ReturnObject git rev-parse --abbrev-ref HEAD
                } catch {
                    $env:GIT_CONFIG_BRANCH = "master"
                }

                try {
                    $env:LOADBALANCER_HOSTNAME = hostname
                } catch {
                    $env:LOADBALANCER_HOSTNAME = "localhost"
                }

                $env:API_HOSTNAME = $env:LOADBALANCER_HOSTNAME
                $env:API_TWO_HOSTNAME = $env:LOADBALANCER_HOSTNAME

                if ([Runner]::EnvironmentContext.SystemStack.Tag -eq [SystemStackTag]::System) {
                    $env:CONFIG_SERVER_URL = "http://localhost:$env:CONFIG_SERVER_PORT"
                    
                    if ([Runner]::EnvironmentContext.LoadBalancing -eq $true) {
                        $env:EUREKA_SERVERS_URLS = "http://localhost:$env:DISCOVERY_SERVER_PORT/eureka"
                        [Runner]::EnvironmentContext.AddEnvironmentVariableKeys(@("CONFIG_SERVER_URL", "EUREKA_SERVERS_URLS"))
                    } else {
                        $env:EUREKA_SERVERS_URLS = ""
                    }

                    Remove-Item env:\DB_URL -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_USERNAME -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_PASSWORD -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_PORT -ErrorAction SilentlyContinue
                }

                [Runner]::EnvironmentContext.AddEnvironmentVariableKeys(@("GIT_CONFIG_BRANCH", "LOADBALANCER_HOSTNAME", "API_HOSTNAME", "API_TWO_HOSTNAME"))
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(127)
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue

            if ($LASTEXITCODE) {
                [Runner]::Cleanup($LASTEXITCODE)
            } else {
                [Runner]::Cleanup(8)
            }
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }
    }

    <#
        .DESCRIPTION
            Build demo packages
     #>
    hidden static [Void] Build() {
        if ([Runner]::EnvironmentContext.CleanupExitCode -ne 0) {
            break
        }

        try {
            [Runner]::EnvironmentContext.SetLocationToScriptPath()
            [Runner]::AutoChooseSystemStack($true)

            if ([Runner]::EnvironmentContext.SystemStack.Tag.Equals([SystemStackTag]::Docker) -and [Runner]::EnvironmentContext.Build) {
                # Docker build
                Write-Information "Building images and packages ..."
                
                # Run the command in the old CMD to avoid the Docker Compose console error message : https://github.com/docker/compose/issues/8186
                if ([Runner]::EnvironmentContext.LoadBalancing) {
                    Invoke-And "cmd /c $( [Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command[0] ) $( [Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command[1 .. ([Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command.Length - 1)] ) build '2`>`&1'"
                } else {
                    Invoke-And "cmd /c $( [Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command[0] ) $( [Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command[1 .. ([Runner]::EnvironmentContext.SystemStack.SystemStackComponents[0].Command.Length - 1)] ) -f docker-compose-no-load-balancing.yml build '2`>`&1'"
                }
            } else {
                # No-docker build
                if (-not([Runner]::EnvironmentContext.Build) -and [Runner]::EnvironmentContext.SystemStack.Tag.Equals([SystemStackTag]::System)) {
                    if ([Runner]::EnvironmentContext.Start -and (-not([Runner]::EnvironmentContext.LoadBalancing)) -and
                            (-not(Test-Path vglconfig/target/vglconfig.jar -PathType Leaf) -or
                                    -not(Test-Path vglservice/target/vglservice.jar -PathType Leaf) -or
                                    -not(Test-Path vglfront/node_modules -PathType Container))) {
                        Write-Information "No Load Balancing packages are not completely built. Build mode enabled."
                        [Runner]::EnvironmentContext.Build = $true
                    }

                    if ([Runner]::EnvironmentContext.Start -and [Runner]::EnvironmentContext.LoadBalancing -and
                            (-not(Test-Path vglconfig/target/vglconfig.jar -PathType Leaf) -or
                                    -not(Test-Path vglservice/target/vglservice.jar -PathType Leaf) -or
                                    -not(Test-Path vglfront/node_modules -PathType Container) -or
                                    -not(Test-Path vgldiscovery/target/vgldiscovery.jar -PathType Leaf) -or
                                    -not(Test-Path vglloadbalancer/target/vglloadbalancer.jar -PathType Leaf))) {
                        Write-Information "Load Balancing packages are not completely built. Build mode enabled."
                        [Runner]::EnvironmentContext.Build = $true
                    }
                }

                if ([Runner]::EnvironmentContext.Build -and ([Runner]::EnvironmentContext.SystemStack.Tag.Equals([SystemStackTag]::System))) {
                    Write-Information "Building packages ..."

                    Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglconfig -f vglconfig\pom.xml
                    Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglservice -f vglservice\pom.xml

                    if ([Runner]::EnvironmentContext.LoadBalancing) {
                        Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vgldiscovery -f vgldiscovery\pom.xml
                        Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglloadbalancer -f vglloadbalancer\pom.xml
                    }

                    Invoke-And Set-Location vglfront
                    Invoke-And npm install
                    Invoke-And Set-Location ..
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(127)
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(9)
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }
    }

    <#
        .DESCRIPTION
            Start the demo
     #>
    hidden static [Void] Start() {
        if ([Runner]::EnvironmentContext.CleanupExitCode -ne 0) {
            break
        }

        try {
            [Runner]::EnvironmentContext.SetLocationToScriptPath()
            
            if ([Runner]::EnvironmentContext.Start) {
                [Runner]::AutoChooseSystemStack($true)
                
                if ( [Runner]::EnvironmentContext.SystemStack.Tag.Equals([SystemStackTag]::Docker)) {
                    # Docker run
                    Write-Information "Launching Docker services ..."

                    if ([Runner]::EnvironmentContext.LoadBalancing) {
                        [Runner]::Tasks = @([BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{
                            ProjectName = "vglloadbalancing-enabled"
                        }, "LoadBalancingServices"))
                    } else {
                        [Runner]::Tasks = @([BackgroundTaskFactory]::new($false).buildDockerComposeProcess((@{
                            StartArguments = "-f", "docker-compose-no-load-balancing.yml", "--env-file", "no-load-balancing.env"
                            ProjectName = "vglloadbalancing-disabled"
                        }), "NoLoadBalancingServices"))
                    }
                } else {
                    # No-docker run
                    $frontTask = [BackgroundTaskFactory]::new($true).buildJob(@{
                        ScriptBlock = {
                            Set-Location "$using:PWD\vglfront"
                            Write-Output n | npm run start 2> $null
                        }
                    }, "VglFront")

                    Write-Output "FRONT_SERVER_PORT=$env:FRONT_SERVER_PORT" >vglfront\.env
                    Write-Output "API_URL=$env:API_URL" >>vglfront\.env
                    Write-Output "TMP_RUNNER_FILE=$( $frontTask.TemporaryFileName )" >>vglfront\.env

                    [Runner]::Tasks += [BackgroundTaskFactory]::new($true).buildProcess((@{
                        FilePath = "java"
                        ArgumentList = "-XX:TieredStopAtLevel=1", "-Dspring.config.location=file:.\vglconfig\src\main\resources\application.properties", "-jar", "vglconfig\target\vglconfig.jar"
                    }), "VglConfig")

                    [Runner]::Tasks += [BackgroundTaskFactory]::new($true).buildProcess((@{
                        FilePath = "java"
                        ArgumentList = "-XX:TieredStopAtLevel=1", "-Dspring.config.location=file:.\vglservice\src\main\resources\application.properties", "-jar", "vglservice\target\vglservice.jar"
                    }), "VglServiceOne")

                    if ([Runner]::EnvironmentContext.LoadBalancing) {
                        [Runner]::Tasks += [BackgroundTaskFactory]::new($true).buildProcess((@{
                            FilePath = "java"
                            ArgumentList = "-XX:TieredStopAtLevel=1", "-Dspring.config.location=file:.\vglservice\src\main\resources\application.properties", "-DAPI_SERVER_PORT=$env:API_TWO_SERVER_PORT", "-DAPI_HOSTNAME=$env:API_TWO_HOSTNAME", "-jar", "vglservice\target\vglservice.jar"
                        }), "VglServiceTwo")

                        [Runner]::Tasks += [BackgroundTaskFactory]::new($true).buildProcess((@{
                            FilePath = "java"
                            ArgumentList = "-XX:TieredStopAtLevel=1", "-Dspring.config.location=file:.\vglloadbalancer\src\main\resources\application.properties", "-jar", "vglloadbalancer\target\vglloadbalancer.jar"
                        }), "VglLoadBalancer")

                        [Runner]::Tasks += [BackgroundTaskFactory]::new($true).buildProcess((@{
                            FilePath = "java"
                            ArgumentList = "-XX:TieredStopAtLevel=1", "-Dspring.config.location=file:.\vgldiscovery\src\main\resources\application.properties", "-jar", "vgldiscovery\target\vgldiscovery.jar"
                        }), "VglDiscovery")
                    }

                    [Runner]::Tasks += $frontTask

                    # Start every background task
                    Write-Information "Launching services ..."
                }

                [Console]::TreatControlCAsInput = $true # Disable CTRL-C default action to allow special cleanup handling

                foreach ($Task in [Runner]::Tasks) {
                    $Task.Start()
                }

                while ($true) {
                    if (Watch-CleanupShortcut) {
                        [Runner]::Cleanup(130)
                        break
                    }

                    $ShouldStop = $false

                    # Loop through tasks and exit if any has exited
                    foreach ($Task in [Runner]::Tasks) {
                        if (-not($Task.IsAlive())) {
                            [Runner]::Cleanup(3)
                            $ShouldStop = $true
                        }
                    }

                    if ($ShouldStop) {
                        break
                    }

                    Start-Sleep -Seconds 1
                }
            }
        } catch [System.Management.Automation.CommandNotFoundException] {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(127)
        } catch [StartBackgroundTaskException] {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(10)
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(11)
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }
    }

    <#
        .DESCRIPTION
            Cleanup the environment (process, environment variables, temporary files)

        .PARAM Code
            Cleanup exit code
    #>
    hidden static [Void] Cleanup([Byte] $Code) {
        try {
            if (([Runner]::EnvironmentContext.CleanupExitCode -eq 0) -or ([Runner]::EnvironmentContext.CleanupExitCode -ne 130)) {
                [Runner]::EnvironmentContext.CleanupExitCode = $Code
            }

            [Runner]::EnvironmentContext.RemoveEnvironmentVariables()
            [Runner]::StopRunningProcesses()

            [Console]::TreatControlCAsInput = $false
            [SystemStackDetector]::ChoosenSystemStack = $null
            Invoke-ExitScript ([Runner]::EnvironmentContext.CleanupExitCode)
        } finally {
            [Runner]::EnvironmentContext.ResetLocationToInitialPath()
        }
    }

    <#
        .DESCRIPTION
            Stops the running processes
    #>
    hidden static [Void] StopRunningProcesses() {
        foreach ($Task in [Runner]::Tasks) {
            if (Watch-CleanupShortcut) {
                [Runner]::Cleanup(130)
                break
            }

            # Stop the process
            try {
                $StopCode = $Task.Stop()

                if ($StopCode -ne [BackgroundTask]::SuccessfullyStopped) {
                    [Runner]::EnvironmentContext.CleanupExitCode = $StopCode
                }

                Checkpoint-Placeholder
            } catch [StopBackgroundTaskException] {
                Write-Error $_.Exception.Message -ErrorAction Continue
                [Runner]::EnvironmentContext.CleanupExitCode = 12
            } catch {
                Write-Error $_.Exception.Message -ErrorAction Continue
                [Runner]::EnvironmentContext.CleanupExitCode = 13
            }
        }
    }
}

[Runner]::Main([String[]]$args)