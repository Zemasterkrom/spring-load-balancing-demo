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
         If the command execution fails, an InvokeAndException is thrown

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
            $obj = Invoke-Expression @"
$args
"@
        } else {
            Invoke-Expression @"
$args | Out-Host
"@
        }

        $code = if ($? -and ($LASTEXITCODE -eq 0) -or ($null -eq $LASTEXITCODE)) {
            0
        } else {
            if ($null -ne $LASTEXITCODE) {
                $LASTEXITCODE
            } else {
                1
            }
        }

        if ($code -ne 0) {
            throw [InvokeAndException]::new("Run failed with error code : $code", $code)
        }

        if ($ReturnObject) {
            return $obj
        }
        else {
            return $null
        }
    } catch [InvokeAndException] {
        throw $_
    } catch {
        throw [InvokeAndException]::new("Run failed with unknown error : " + $_.Exception.Message, 1, $_.Exception)
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
            & cmd /c "docker info >nul 2>&1"
        } catch {
        }

        if ($LASTEXITCODE -eq 0) {
            try {
                $DockerComposeVersion = & cmd /c "docker compose version 2>nul"
            } catch {
            }

            if ($LASTEXITCODE -eq 0) {
                $DockerComposeCli = "docker compose"
                $ChoosenSystemStackTag = [SystemStackTag]::Docker
            } else {
                try {
                    $DockerComposeVersion = & cmd /c "docker-compose version 2>nul"
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
            if (($DockerComposeVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)\.([0-9]+).*$") -and (($DockerComposeVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredDockerComposeVersion)) {
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
            $JavaVersion = & java -version 2>&1
        } catch {
            # https://github.com/PowerShell/PowerShell/issues/4002
            # https://bugs.java.com/bugdatabase/view_bug.do?bug_id=4380614
            $JavaVersion = $_.Exception.Message
        }

        if (($JavaVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)\.([0-9]+).*$") -and (($JavaVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredJavaVersion)) {
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
            $MavenVersion = & mvn -version
        } catch {
            return $null
        }

        if (($MavenVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)\.([0-9]+).*$") -and (($MavenVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredMavenVersion)) {
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
            $NodeVersion = & node -v 2> $null
        } catch {
            return $null
        }

        if (($LASTEXITCODE -eq 0) -and ($NodeVersion -match "^[^0-9]*([0-9]+)\.([0-9]+)\.([0-9]+).*$") -and (($NodeVersion = [Version]::new($Matches[1], $Matches[2], $Matches[3])) -ge [SystemStackDetector]::RequiredNodeVersion)) {
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
    [ValidateNotNull()] [String[]] $AssociatedTag

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
class Environment {
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

    # Loaded environment variables
    [ValidateNotNull()] [String[]] $EnvironmentVariables

    # Choosen system stack to run the demo
    [ValidateNotNull()] [SystemStack] $SystemStack

    # Flag that allows to set the basic cleanup as executed
    [ValidateNotNull()] [Boolean] $BasicCleanupExecuted

    # Flag that allows to set the advanced cleanup as executed
    [ValidateNotNull()] [Boolean] $AdvancedCleanupExecuted

    # Cleanup termination exit code
    [ValidateRange(0, 255)] [Int] $CleanupExitCode

    <#
        .DESCRIPTION
            Constructor that initializes the default properties of the environment
    #>
    Environment() {
        $this.LoadBalancing = $true
        $this.Build = $true
        $this.Start = $true
        $this.EnvironmentFilePath = ".env"
        $this.EnvironmentFileEncoding = "utf8"
        $this.SystemStack = [SystemStack]::new([SystemStackTag]::Docker, [SystemStackComponent[]]@([SystemStackComponent]::new("Docker Compose", "docker compose", [SystemStackDetector]::RequiredDockerComposeVersion)))
        $this.BasicCleanupExecuted = $false
        $this.AdvancedCleanupExecuted = $false
        $this.CleanupExitCode = 0
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

    SetEnvironmentFile([String] $FilePath, [String] $Encoding = "utf-8") {
        $this.EnvironmentFilePath = $FilePath
        $this.EnvironmentFileEncoding = $Encoding
    }

    SetEnvironmentVariables([String[]] $EnvironmentVariables) {
        $PreviousEnvironmentVariables = $this.EnvironmentVariables
        $this.EnvironmentVariables = @()

        if ($null -eq $EnvironmentVariables) {
            return
        } else {
            foreach ($EnvironmentVariable in $EnvironmentVariables) {
                if ( [String]::IsNullOrWhiteSpace($EnvironmentVariable)) {
                    $this.EnvironmentVariables = $PreviousEnvironmentVariables
                    throw [ArgumentNullException]::new("Environment variable name cannot be null or empty")
                }

                $this.EnvironmentVariables += $EnvironmentVariable
            }
        }
    }

    AddEnvironmentVariables([String[]] $EnvironmentVariables) {
        $PreviousEnvironmentVariables = $this.EnvironmentVariables

        if ($null -eq $EnvironmentVariables) {
            return
        }

        foreach ($EnvironmentVariable in $EnvironmentVariables) {
            if ( [String]::IsNullOrWhiteSpace($EnvironmentVariable)) {
                $this.EnvironmentVariables = $PreviousEnvironmentVariables
                throw [ArgumentNullException]::new("Environment variable name cannot be null or empty")
            }

            $this.EnvironmentVariables += $EnvironmentVariable
        }

        $this.EnvironmentVariables = $this.EnvironmentVariables | Get-Unique
    }

    ReadEnvironmentFile() {
        $this.EnvironmentVariables += Read-EnvironmentFile -FilePath $this.EnvironmentFilePath -Encoding $this.EnvironmentFileEncoding | Get-Unique
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
    static [Int] $TemporaryFileWaitCompleted = 0
    static [Int] $ProcessHasAlreadyExited = 3
    static [Int] $TemporaryFileWaitTimeoutError = 4
    static [Int] $FailedRemovingTmpFile = 5
    static [Int] $TemporaryFileWaitUnknownError = 6
    static [Int] $KilledDueToStopTimeout = 7

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
        $this.TemporaryFileName = $this.Name.ToLower() + "_" + [Guid]::NewGuid().ToString()
        $this.CheckedTemporaryFileExistence = $false
        $this.CheckedTemporaryFileExistenceState = [BackgroundTask]::TemporaryFileWaitCompleted
        $this.TemporaryFileCheckEnabled = $TemporaryFileCheckEnabled
        $this.StopCallAlreadyExecuted = $false

        if ($null -eq $this.TaskStopInfo.StandardStopTimeout) {
            $this.TaskStopInfo.StandardStopTimeout = [BackgroundTask]::StandardStopTimeout
        }

        if ($null -eq $this.TaskStopInfo.KillTimeout) {
            $this.TaskStopInfo.KillTimeout = [BackgroundTask]::KillTimeout
        }

        if (($this.TaskStopInfo.StandardStopTimeout -isnot [Int]) -or ($this.TaskStopInfo.StandardStopTimeout -lt 0)) {
            throw [ArgumentException]::new("Invalid standard timeout. Standard timeout cannot be negative.")
        }

        if (($this.TaskStopInfo.KillTimeout -isnot [Int]) -or ($this.TaskStopInfo.KillTimeout -lt 0)) {
            throw [ArgumentException]::new("Invalid force kill timeout. Force kill timeout cannot be negative.")
        }
    }

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

        .OUTPUTS
            Number representing the status of the start execution
    #>
    [Void] Start() {
        if (-not($this.IsAlive())) {
            $this.StartIfNotAlive()
            $this.StopCallAlreadyExecuted = $false
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
            if ( $this.CanStop()) {
                $StopCode = $this.StopIfAlive()
                $this.StopCallAlreadyExecuted = $true
                $this.GracefulStop()

                return $StopCode
            }

            return 0
        } catch {
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
                Write-Information "Waiting for $( $this.Name ) to create the $env:TEMP\$( $this.TemporaryFileName ) ... ($TemporaryFileWaitTimeout seconds)"
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

                Remove-Item "$env:TEMP\$( $this.TemporaryFileName )"

                $this.CheckedTemporaryFileExistenceState = if ($?) {
                    $ReturnCode
                } else {
                    [BackgroundTask]::FailedRemovingTmpFile
                }
                $this.CheckedTemporaryFileExistence = $true
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

        try {
            # If there are child processes, kill the entire process tree
            $ChildProcesses = Get-CimInstance -Class Win32_Process -Filter "ParentProcessId = '$( $this.Process.Id )'"

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
                    $NextChildProcesses = Get-CimInstance -Class Win32_Process -Filter "ParentProcessId = '$( $CurrentChildProcess.ProcessId )'"

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

                        $CurrentChildProcess | Invoke-WmiMethod -Name Terminate > $null

                        if (-not($?)) {
                            throw [StopBackgroundProcessException]::new("WmiMethod Terminate failed")
                        }

                        try {
                            $PSChildProcess = Get-Process -Id $CurrentChildProcess.ProcessId
                        } catch {
                            continue
                        }

                        $PSChildProcess | Wait-Process -Timeout $this.TaskStopInfo.KillTimeout > $null

                        if (-not($?)) {
                            throw [StopBackgroundProcessException]::new("Failed waiting for the process to exit within $( $this.TaskStopInfo.KillTimeout ) seconds")
                        }
                    } catch {
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
                Write-Error "Failed to kill the process with PID $( $this.Process.Id ) : $( $_.Exception.Message )" -ErrorAction Continue
                $Success = $false
            }
        } catch {
            throw [StopBackgroundProcessException]::new("Unknown error occurred while trying to kill the process tree with PPID $( $this.Process.Id )")
        }

        if (-not($Success)) {
            throw [StopBackgroundProcessException]::new("Failed to kill the process tree of the process with PPID $( $this.Process.Id )")
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

        if (Test-Path "$env:TEMP\$( $this.TemporaryFileName )" -ErrorAction SilentlyContinue) {
            Remove-Item "$env:TEMP\$( $this.TemporaryFileName )" -ErrorAction SilentlyContinue
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
    BackgroundDockerComposeProcess([Hashtable] $DockerComposeProcessStartInfo, [Hashtable] $DockerComposeProcessStopInfo, [String] $Name, [Boolean] $TemporaryFileCheckEnabled): base($DockerComposeProcessStartInfo, $DockerComposeProcessStopInfo, $Name, $TemporaryFileCheckEnabled) {
        $CurrentSystemStack = [SystemStackDetector]::RetrieveCurrentSystemStack()

        if ((-not($CurrentSystemStack)) -or (-not($CurrentSystemStack.Tag.Equals([SystemStackTag]::Docker)))) {
            $CurrentSystemStack = [SystemStackDetector]::DetectCompatibleAvailableDockerComposeCli()
        }

        if ((-not($CurrentSystemStack)) -or ($CurrentSystemStack.SystemStackComponents.Length -lt 1)) {
            throw [System.Management.Automation.CommandNotFoundException]::new("No compatible and available Docker Compose version found. Requires Docker Compose >= $( [SystemStackDetector]::RequiredDockerComposeVersion ).")
        }

        $this.DockerComposeCli = $CurrentSystemStack

        if (($null -ne $this.TaskStartInfo.Options) -and ($this.TaskStartInfo.Options -isnot [Array])) {
            throw [ArgumentException]::new("Docker Compose start options must be passed as an array")
        }

        $this.DockerComposeServicesOrchestrator = [BackgroundTaskFactory]::new($false).buildProcess((@{
            FilePath = $this.DockerComposeCli.SystemStackComponents[0].Command[0]
            ArgumentList = "$( $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] ) up $( $this.TaskStartInfo.ServiceName ) -t $( $this.TaskStopInfo.StandardStopTimeout )"
        }), "$( $this.Name )DockerComposeOrchestrator")
    }

    [Boolean] IsAlive() {
        return (($isRunning = & cmd /c $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] ps $this.TaskStartInfo.ServiceName --services --filter "status=running" 2`>`&1) -and (-not([String]::IsNullOrWhiteSpace($isRunning)))) -or
                (($isRestarting = & cmd /c $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] ps $this.TaskStartInfo.ServiceName --services --filter "status=restarting" 2`>`&1) -and (-not([String]::IsNullOrWhiteSpace($isRestarting)))) -or
                (($isPaused = & cmd /c $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] ps $this.TaskStartInfo.ServiceName --services --filter "status=paused" 2`>`&1) -and (-not([String]::IsNullOrWhiteSpace($isPaused))))
    }

    hidden [Void] StartIfNotAlive() {
        try {
            Write-Information "Starting the $( $this.Name ) Docker Compose service"
            $this.DockerComposeServicesOrchestrator.Start()

            if (-not($?) -or ($LASTEXITCODE -ne 0)) {
                throw [StartBackgroundProcessException]::new("$( $this.Name ) Docker Compose service start failed : $( $_.Exception.Message )")
            }
        } catch {
            throw [StartBackgroundProcessException]::new("Failed to start the $( $this.Name ) Docker Compose service : $( $_.Exception.Message )")
        }
    }

    hidden [Int] StopIfAlive() {
        if (-not($this.StopCallAlreadyExecuted)) {
            Write-Information "Stopping the $( $this.Name ) Docker Compose service"
        } else {
            Write-Information "Killing the $( $this.Name ) Docker Compose service"
        }

        try {
            # Stop the service container gracefully
            # StdErr redirection bug, using the old CMD as alternative: https://github.com/PowerShell/PowerShell/issues/4002
            & cmd /c "$( $this.DockerComposeCli.SystemStackComponents[0].Command[0] )" $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] stop "$( $this.TaskStartInfo.ServiceName )" -t $this.TaskStopInfo.StandardStopTimeout 2`>`&1 | Out-Host

            if ($? -and ($LASTEXITCODE -eq 0)) {
                return [BackgroundTask]::SuccessfullyStopped
            }

            throw [StopBackgroundProcessException]::new("Docker Compose service $( $this.Name ) stop failed : $( $_.Exception.Message )")
        } catch {
            try {
                # Fatal error or timeout : force kill the service container
                Write-Warning "Failed to stop the $( $this.Name ) Docker Compose service. Trying to kill the Docker Compose service."

                # StdErr redirection bug, using the old CMD as alternative: https://github.com/PowerShell/PowerShell/issues/4002
                & cmd /c "$( $this.DockerComposeCli.SystemStackComponents[0].Command[0] )" $this.DockerComposeCli.SystemStackComponents[0].Command[1 .. ($this.DockerComposeCli.SystemStackComponents[0].Command.Length - 1)] kill "$( $this.TaskStartInfo.ServiceName )" 2`>`&1 | Out-Host

                if ($? -and ($LASTEXITCODE -eq 0)) {
                    return [BackgroundTask]::KilledDueToStopTimeout
                }

                throw [StopBackgroundProcessException]::new("Docker Compose service $( $this.Name ) kill failed : $( $_.Exception.Message )")
            } catch {
                throw [StopBackgroundProcessException]::new("Failed to stop the $( $this.Name ) Docker Compose service : $( $_.Exception.Message )")
            }
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
        if ($this.TaskStartInfo.ScriptBlock -isnot [ScriptBlock]) {
            throw [ArgumentException]::new("Incompatible ScriptBlock found. Background jobs must be associated to an init ScriptBlock.")
        }

        $this.Process = $null
    }

    [Boolean] IsAlive() {
        return $this.Process -and (-not($this.Process.HasExited))
    }

    hidden [Void] StartIfNotAlive() {
        try {
            Write-Information "Starting the $( $this.Name ) job"

            $EncodedScriptBlockInfo = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($this.TaskStartInfo.ScriptBlock.ToString()))
            $this.Process = Start-Process powershell -NoNewWindow -ArgumentList "-Command", "
`$HashtableTaskStartInfo = [ScriptBlock]::Create([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$EncodedScriptBlockInfo')))
`$Job = Start-Job @HashtableTaskStartInfo
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
            throw [BackgroundJobException]::new("Failed to start the $( $this.Name ) job : $( $_.Exception.Message )")
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
                Write-Information "Killing the $( $this.Name ) job with PID $( $this.Process.Id )"

                $this.Process | Stop-Process -Force

                if (-not($?)) {
                    throw [StopBackgroundJobException]::new("Failed stopping the job")
                }

                $this.Process | Wait-Process -Timeout $this.TaskStopInfo.KillTimeout > $null

                if (-not($?)) {
                    throw [StopBackgroundJobException]::new("Failed waiting for the job to terminate within $( $this.TaskStopInfo.KillTimeout ) seconds")
                }

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
    BackgroundTaskFactory([String] $TemporaryFileCheckEnabled) {
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
        }, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildDockerComposeProcess([Hashtable] $DockerComposeProcessStartInfo, [Hashtable] $DockerComposeProcessStopInfo, [String] $Name) {
        return [BackgroundDockerComposeProcess]::new($DockerComposeProcessStartInfo, $DockerComposeProcessStopInfo, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [String] $Name) {
        return [BackgroundJob]::new($JobStartInfo, @{
        }, $Name, $this.TemporaryFileCheckEnabled)
    }

    [BackgroundTask] buildJob([Hashtable] $JobStartInfo, [Hashtable] $JobStopInfo, [String] $Name) {
        return [BackgroundJob]::new($JobStartInfo, $JobStopInfo, $Name, $this.TemporaryFileCheckEnabled)
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
    static [Environment] $Environment

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
        [Runner]::Environment = [Environment]::new()
        [Runner]::Tasks = @()

        # Parse run arguments
        foreach ($Option in $Options) {
            switch ($Option) {
                --no-start {
                    [Runner]::Environment.EnableStart($false)
                }
                --no-build {
                    [Runner]::Environment.EnableBuild($false)
                }
                --no-load-balancing {
                    [Runner]::Environment.EnableLoadBalancing($false)
                    [Runner]::Environment.SetEnvironmentFile("no-load-balancing.env", "utf8")
                }
                --source-only {
                    [Runner]::Environment.EnableSourceOnlyMode($true)
                }
            }
        }

        # Execute if not sourced
        if (-not([Runner]::Environment.SourceOnly)) {
            [Runner]::run()
        }
    }

    hidden static [Void] Run() {
        try {
            # Auto-configure the environment and environment variables
            [Runner]::Configure()

            # Build demo packages
            [Runner]::Build()

            # Ready : start the demo !
            [Runner]::Start()
        } finally {
            [Runner]::Cleanup(130)
        }
    }

    <#
        .DESCRIPTION
            Auto-configure some variables related to the Git / DNS environment
    #>
    hidden static [Void] Configure() {
        try {
            [Console]::TreatControlCAsInput = $false

            if ([Runner]::Environment.Start) {
                Write-Information "Reading environment variables ..."
                [Runner]::Environment.ReadEnvironmentFile()

                Write-Information "Environment auto-configuration ..."
                $env:GIT_CONFIG_BRANCH = Invoke-And -ReturnObject git rev-parse --abbrev-ref HEAD
                $env:LOADBALANCER_HOSTNAME = [System.Net.Dns]::GetHostName()
                $env:API_HOSTNAME = $env:LOADBALANCER_HOSTNAME
                $env:API_TWO_HOSTNAME = $env:LOADBALANCER_HOSTNAME
                [Runner]::Environment.SetSystemStack([SystemStackDetector]::RetrieveMostAppropriateSystemStack())

                Write-Information ([Runner]::Environment.SystemStack)

                if ([Runner]::Environment.SystemStack.Tag -eq [SystemStackTag]::System) {
                    $env:CONFIG_SERVER_URL = "http://localhost:$env:CONFIG_SERVER_PORT"
                    $env:EUREKA_SERVERS_URLS = "http://localhost:$env:DISCOVERY_SERVER_PORT/eureka"

                    Remove-Item env:\DB_URL -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_USERNAME -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_PASSWORD -ErrorAction SilentlyContinue
                    Remove-Item env:\DB_PORT -ErrorAction SilentlyContinue

                    [Runner]::Environment.AddEnvironmentVariables(@("CONFIG_SERVER_URL", "EUREKA_SERVERS_URLS"))
                }

                [Runner]::Environment.AddEnvironmentVariables(@("GIT_CONFIG_BRANCH", "LOADBALANCER_HOSTNAME", "API_HOSTNAME", "API_TWO_HOSTNAME"))
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
        }
    }

    <#
        .DESCRIPTION
            Build demo packages
     #>
    hidden static [Void] Build() {
        try {
            if ([Runner]::Environment.SystemStack.Tag.Equals([SystemStackTag]::Docker) -and [Runner]::Environment.Build) {
                # Docker build
                Write-Information "Building images and packages ..."

                # Run the command in the old CMD to avoid the Docker Compose console error message : https://github.com/docker/compose/issues/8186
                if ([Runner]::Environment.LoadBalancing) {
                    Invoke-And "cmd /c $( [Runner]::Environment.SystemStack.SystemStackComponents[0].Command[0] ) $( [Runner]::Environment.SystemStack.SystemStackComponents[0].Command[1 .. ([Runner]::Environment.SystemStack.SystemStackComponents[0].Command.Length - 1)] ) build `"2`>`&1`""
                } else {
                    Invoke-And "cmd /c $( [Runner]::Environment.SystemStack.SystemStackComponents[0].Command[0] ) $( [Runner]::Environment.SystemStack.SystemStackComponents[0].Command[1 .. ([Runner]::Environment.SystemStack.SystemStackComponents[0].Command.Length - 1)] ) -f docker-compose-no-load-balancing.yml build `"2`>`&1`""
                }
            } else {
                # No-docker build
                if (-not([Runner]::Environment.Build) -and [Runner]::Environment.SystemStack.Tag.Equals([SystemStackTag]::System)) {
                    if ([Runner]::Environment.Start -and (-not([Runner]::Environment.LoadBalancing)) -and
                            (-not(Test-Path vglconfig/target/vglconfig.jar -PathType Leaf) -or
                                    -not(Test-Path vglservice/target/vglservice.jar -PathType Leaf) -or
                                    -not(Test-Path vglfront/node_modules -PathType Container))) {
                        Write-Information "No Load Balancing packages are not completely built. Build mode enabled."
                        [Runner]::Environment.Build = $true
                    }

                    if ([Runner]::Environment.Start -and [Runner]::Environment.LoadBalancing -and
                            (-not(Test-Path vglconfig/target/vglconfig.jar -PathType Leaf) -or
                                    -not(Test-Path vglservice/target/vglservice.jar -PathType Leaf) -or
                                    -not(Test-Path vglfront/node_modules -PathType Container) -or
                                    -not(Test-Path vgldiscovery/target/vgldiscovery.jar -PathType Leaf) -or
                                    -not(Test-Path vglloadbalancer/target/vglloadbalancer.jar -PathType Leaf))) {
                        Write-Information "Load Balancing packages are not completely built. Build mode enabled."
                        [Runner]::Environment.Build = $true
                    }
                }

                if ([Runner]::Environment.Build -and ([Runner]::Environment.SystemStack.Tag.Equals([SystemStackTag]::System))) {
                    Write-Information "Building packages ..."

                    Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglconfig -f vglconfig\pom.xml
                    Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglservice -f vglservice\pom.xml

                    if ([Runner]::Environment.LoadBalancing) {
                        Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vgldiscovery -f vgldiscovery\pom.xml
                        Invoke-And mvn clean package -T 3 -DskipTests -DfinalName=vglloadbalancer -f vglloadbalancer\pom.xml
                    }

                    Invoke-And Set-Location vglfront
                    Invoke-And npm install
                    Invoke-And Set-Location ..
                }
            }
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue

            if ($LASTEXITCODE) {
                [Runner]::Cleanup($LASTEXITCODE)
            } else {
                [Runner]::Cleanup(9)
            }
        }
    }

    <#
        .DESCRIPTION
            Start the demo
     #>
    hidden static [Void] Start() {
        try {
            if ([Runner]::Environment.Start) {
                if ( [Runner]::Environment.SystemStack.Tag.Equals([SystemStackTag]::Docker)) {
                    # Docker run
                    Write-Output "Launching Docker services ..."

                    if ([Runner]::Environment.LoadBalancing) {
                        [Runner]::Tasks = @([BackgroundTaskFactory]::new($false).buildDockerComposeProcess(@{
                        }, "LoadBalancingServices"))
                    } else {
                        [Runner]::Tasks = @([BackgroundTaskFactory]::new($false).buildDockerComposeProcess((@{
                            Options = "-f", "docker-compose-no-load-balancing.yml", "--env-file", "no-load-balancing.env"
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

                    if ([Runner]::Environment.LoadBalancing) {
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
                    [Console]::TreatControlCAsInput = $true # Disable CTRL-C default action to allow special cleanup handling
                }

                foreach ($Task in [Runner]::Tasks) {
                    $Task.Start()
                }

                while ($true) {
                    # Allow cleanup interrupt: if CTRL-C is triggered twice, the processes will be killed
                    if ([Console]::KeyAvailable) {
                        $keyboardKeyCombination = [Console]::ReadKey($true)

                        if ($keyboardKeyCombination.Modifiers -eq "Control" -and $keyboardKeyCombination.Key -eq "C") {
                            [Runner]::Cleanup(130)
                        }
                    }

                    # Loop through tasks and exit if any has exited
                    foreach ($Task in [Runner]::Tasks) {
                        if (-not($Task.IsAlive())) {
                            [Runner]::Cleanup(3)
                        }
                    }

                    Start-Sleep -Seconds 1
                }
            }
        } catch [StartBackgroundTaskException] {
            Write-Error $_.Exception.Message -ErrorAction Continue

            if ($LASTEXITCODE) {
                [Runner]::Cleanup($LASTEXITCODE)
            } else {
                [Runner]::Cleanup(10)
            }
        } catch {
            Write-Error $_.Exception.Message -ErrorAction Continue
            [Runner]::Cleanup(11)
        }
    }

    <#
        .DESCRIPTION
            Cleanup the environment (process, environment variables, temporary files)

        .PARAM Code
            Cleanup exit code
    #>
    hidden static [Void] Cleanup([Int] $Code) {
        if (([Runner]::Environment.CleanupExitCode -eq 0) -or ([Runner]::Environment.CleanupExitCode -ne 130)) {
            [Runner]::Environment.CleanupExitCode = $Code
        }

        # Environment cleanup
        if (-not([Runner]::Environment.BasicCleanUpExecuted)) {
            if ( "$pwd".Contains("vglfront")) {
                Set-Location ..
            }

            foreach ($Key in [Runner]::Environment.EnvironmentVariables) {
                if (Test-Path env:\"$Key") {
                    Write-Information "Removing environment variable $Key"
                    Remove-Item env:\"$Key"
                }
            }

            [Runner]::Environment.BasicCleanupExecuted = $true
        }

        # Processes cleanup
        if (-not([Runner]::Environment.AdvancedCleanupExecuted)) {
            foreach ($Task in [Runner]::Tasks) {
                # Allow cleanup interrupt: if CTRL-C is triggered, the cleanup will be restarted
                if ([Console]::KeyAvailable) {
                    $keyboardKeyCombination = [Console]::ReadKey($true)

                    if ($keyboardKeyCombination.Modifiers -eq "Control" -and $keyboardKeyCombination.Key -eq "C") {
                        [Runner]::Cleanup(130)
                    }
                }

                # Stop the process
                try {
                    $StopCode = $Task.Stop()

                    if ($StopCode -ne [BackgroundTask]::SuccessfullyStopped) {
                        [Runner]::Environment.CleanupExitCode = $StopCode
                    }
                } catch [StopBackgroundTaskException] {
                    Write-Error $_.Exception.Message -ErrorAction Continue
                    [Runner]::Environment.CleanupExitCode = 12
                } catch {
                    Write-Error $_.Exception.Message -ErrorAction Continue
                    [Runner]::Environment.CleanupExitCode = 13
                }
            }

            [Runner]::Environment.AdvancedCleanupExecuted = $true
        }

        [Console]::TreatControlCAsInput = $false
        [SystemStackDetector]::ChoosenSystemStack = $null
        exit [Runner]::Environment.CleanupExitCode
    }
}

[Runner]::Main([String[]]$args)