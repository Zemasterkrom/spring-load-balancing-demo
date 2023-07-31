Mock Write-Warning {
    if ($null -eq $Message) {
        $global:TestWarningOutput += Write-Output ";"
    }

    $global:TestWarningOutput += Write-Output ($Message.ToString() + ";")
}

Mock Write-Error {
    if ($null -eq $Message) {
        $global:TestErrorOutput += Write-Output ";"
    }

    $global:TestErrorOutput += Write-Output ($Message.ToString() + ";")
}

Mock Write-Information {
    if ($null -eq $MessageData) {
        $global:TestOutput += Write-Output ";"
    }

    $global:TestOutput += Write-Output ($MessageData.ToString() + ";")
}

function Reset-TestOutput {
    $global:TestOutput = ""
    $global:TestWarningOutput = ""
    $global:TestErrorOutput = ""
}

$env:SCRIPT_PATH = "$PSScriptRoot\..\..\.."
. $PSScriptRoot\..\..\..\run.ps1 --load-core-only