function Invoke-PesterJob
{
[CmdletBinding(DefaultParameterSetName='LegacyOutputXml')]
    param(
        [Alias('Path','relative_path')]
        [System.Object[]]
        ${Script},

        [Alias('Name')]
        [string[]]
        ${TestName},

        [switch]
        ${EnableExit},

        [Parameter(ParameterSetName='LegacyOutputXml')]
        [string]
        ${OutputXml},

        [Alias('Tags')]
        [string[]]
        ${Tag},

        [string[]]
        ${ExcludeTag},

        [switch]
        ${PassThru},

        [System.Object[]]
        ${CodeCoverage},

        [switch]
        ${Strict},

        [Parameter(ParameterSetName='NewOutputSet')]
        [string]
        ${OutputFile},

        [Parameter(ParameterSetName='NewOutputSet')]
        [ValidateSet('LegacyNUnitXml','NUnitXml')]
        [string]
        ${OutputFormat},

        [Parameter(ParameterSetName='NewOutputSet')]
        [ValidateSet('Diagnostic')]
        [string]
        ${Output},

        [switch]
        ${Quiet}
    )

    $EncodedParams = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(($PSBoundParameters | ConvertTo-Json)))
    $PesterProcess = Start-Process powershell -NoNewWindow -ArgumentList "-Command", "
function ConvertTo-Hashtable() {
    param(
        [Parameter(ValueFromPipeline)]
        `$Object
    )
    
    if ( `$null -eq `$Object ) { return `$null }
    
    if ( `$Object -is [PSObject] ) {
        `$Result = @{}
        `$Items = `$Object | Get-Member -MemberType NoteProperty
    
        foreach( `$Item in `$Items ) {
            `$Key = `$Item.Name
            `$Value = ConvertTo-Hashtable -Object `$Object.`$Key
            `$Result.Add(`$key, `$value)
        }
    
        return `$Result
    } elseif (`$Object -is [Array]) {
        `$Result = [Object[]]::new(`$Object.Length)
    
        for (`$i = 0; `$i -lt `$Object.Length; `$i++) {
            `$Result[`$i] = ConvertTo-Hashtable -Object `$Object[`$i]
        }
    
        return `$Result
    } else {
        return `$Object
    }
}

`$DecodedParams = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('$EncodedParams')) | ConvertFrom-Json | ConvertTo-Hashtable
Invoke-Pester `@DecodedParams
exit `$LASTEXITCODE" -Wait -PassThru

    if ($PesterProcess.ExitCode -ne 0) {
        throw [System.Management.Automation.ApplicationFailedException]::new("One or more Pester tests failed")
    }
}

Set-Alias ipj Invoke-PesterJob