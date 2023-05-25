Mock Write-Warning {
    $global:TestWarningOutput += Write-Output ($Message + ";")
}

Mock Write-Error {
    $global:TestErrorOutput += Write-Output ($Message + ";")
}

Mock Write-Information {
    $global:TestOutput += Write-Output ($MessageData + ";")
}

function Reset-TestOutput {
    $global:TestOutput = ""
    $global:TestWarningOutput = ""
    $global:TestErrorOutput = ""
}

$env:SCRIPT_PATH = "$PSScriptRoot\..\..\.."
. $PSScriptRoot\..\..\..\run.ps1 --source-only