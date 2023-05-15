$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$InformationPreference = "Continue"

<#
    .SYNOPSIS
        Reads an environment file.

    .DESCRIPTION
        Reads an environment file and sets the values in the current environment.
        Escape characters in environment files using the \ character.

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
        } else {
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
            } else {
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
                        } else {
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
            } else {
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

<#
    .SYNOPSIS
        Stop a process tree.

    .DESCRIPTION
        Recursively stop a process tree.

    .PARAMETER ParentProcess
        Parent process object.
#>
function Stop-ProcessTree {
    Param(
        [Parameter(Mandatory = $true)] [System.Diagnostics.Process] $ParentProcess
    )

    function Stop-NestedProcessTree {
        Param(
            [Parameter(Mandatory = $true)] [Microsoft.Management.Infrastructure.CimInstance] $ChildProcess
        )

        $HasError = Get-CimInstance Win32_Process -Filter "ParentProcessId = '$( $ChildProcess.ProcessId )'" | ForEach-Object {
            Stop-NestedProcessTree -ChildProcess $_
        }

        Write-Information "--> Stopping the process with PID $( $ChildProcess.ProcessId )"
        $ChildProcess | Invoke-CimMethod -MethodName Terminate -ErrorAction SilentlyContinue

        if ($error -or (-not($?))) {
            Write-Information "--> Failed to stop the process with PID $( $ChildProcess.ProcessId )"
            return $true
        } else {
            return $false
        }
    }

    $HasError = Get-CimInstance Win32_Process -Filter "ParentProcessId = '$( $ParentProcess.Id )'" -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-NestedProcessTree -ChildProcess $_
    }

    Write-Information "--> Stopping the process with PID $( $ParentProcess.Id )"
    $ParentProcess | Stop-Process -Force -ErrorAction SilentlyContinue

    if ($HasError -or (-not($?))) {
        Write-Information "--> Failed to stop the process with PID $( $ParentProcess.Id )"
        throw "--> Failed to stop the process with PID $( $ParentProcess.Id )"
    }
}

<#
    .SYNOPSIS
        Remove environment variables and stop the front process.

    .DESCRIPTION
        Remove environment variables and stop the front process when the script execution ends.

    .PARAMETER ErrorDetected
        If enabled, it means that an error occurred during the start of the front service.
        The exit code will be 1 and not 130 which is the default code when no error is detected (background errors cannot be detected).
#>
function Cleanup {
    Param(
        [Switch] $ErrorDetected
    )
    $ErrorCode = 0

    # Stop the process if CTRL-C is triggered manually and the process has not already exited
    if ($process -and (-not($process.HasExited))) {
        Stop-ProcessTree -ParentProcess $process -ErrorAction SilentlyContinue

        if (-not($?)) {
            Write-Error "Failed to stop the front service" -ErrorAction Continue
            $ErrorCode = 2
        }
    }

    # Remove the line concerning the temporary runner file
    Set-Content -Path .env -Value (Get-Content -Path .env -ErrorAction SilentlyContinue | Select-String -Pattern 'TMP_RUNNER_FILE' -NotMatch) -ErrorAction SilentlyContinue

    if (-not($?)) {
        Write-Warning "Failed to remove the TMP_RUNNER_FILE key from the .env environment file"
        $ErrorCode = 3
    }

    # Remove temporary JavaScript environment file to avoid conflicts with Docker
    if (Test-Path src\assets\environment.js -ErrorAction SilentlyContinue) {
        Write-Information "Removing temporary JavaScript file src\assets\environment.js"
        Remove-Item src\assets\environment.js -ErrorAction SilentlyContinue
    }

    if (-not($?)) {
        Write-Warning "Failed to remove the src\assets\environment.js temporary JavaScript environment file"
        $ErrorCode = 4
    }

    # Remove environment variables
    foreach ($Key in $environmentVariables) {
        if (Test-Path env:\"$Key" | Out-Null) {
            Write-Information "Removing environment variable $key"
            Remove-Item env:\"$key" -ErrorAction SilentlyContinue
        }
    }

    if ($ErrorDetected) {
        exit $ErrorCode
    }
    exit 130
}

try {
    # Mandatory and default environment variables
    $environmentVariables = $( "FRONT_SERVER_PORT", "API_URL" )

    # Read environment variables
    $env:FRONT_SERVER_PORT = 4200
    $env:API_URL = "http://localhost:10000"

    if (-not(Test-Path .env -PathType Leaf)) {
        New-Item -Path .env -ItemType File -Force > $null
    }

    Read-EnvironmentFile .env | ForEach-Object {
        $environmentVariables += $_
    }

    if ($env:TMP_RUNNER_FILE) {
        $tmpRunnerFileCheckEnabled = $true
    }

    # Initialize the browser environment
    node "server\FileEnvironmentConfigurator.js" "src\assets\environment.js" @JSKEY@ @JSVALUE@ "window['environment']['@JSKEY@'] = '@JSVALUE@';" url "$env:API_URL" http://localhost:10000

    # Serve the front
    $encodedPort = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($env:FRONT_SERVER_PORT))
    $process = Start-Process -NoNewWindow powershell -ArgumentList "-Command", "`$encodedPort = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$encodedPort')); ng serve --port `$encodedPort" -PassThru -ErrorAction Continue;
    New-Item -Type File "$env:TEMP\$( $env:TMP_RUNNER_FILE )" -ErrorAction SilentlyContinue > $null

    # Check the existence of the temporary runner file every second and terminate the front service if it has been deleted.
    if ($tmpRunnerFileCheckEnabled) {
        while ($true) {
            if ($process.HasExited -or (-not(Test-Path -Type Leaf -Path "$env:TEMP\$( $env:TMP_RUNNER_FILE )"))) {
                break
            }

            Start-Sleep -Seconds 1
        }
    } else {
        $process | Wait-Process
    }
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue

    # Fatal error detected : stop the front process, clean up the files to restore a healthy state, and remove environment variables
    Cleanup -ErrorDetected
} finally {
    # Stop the front process, clean up the files, remove environment variables
    Cleanup
}