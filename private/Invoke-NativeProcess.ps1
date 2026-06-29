function Invoke-NativeProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [string[]] $ArgumentList = @(),

        [switch] $CaptureOutput,

        [string] $WorkingDirectory
    )

    $runner = {
        param(
            [string] $RunnerFilePath,
            [string[]] $RunnerArgumentList,
            [string] $RunnerWorkingDirectory
        )

        if (-not [string]::IsNullOrWhiteSpace($RunnerWorkingDirectory)) {
            Set-Location -Path $RunnerWorkingDirectory
        }

        $out = @(& $RunnerFilePath @RunnerArgumentList 2>&1)

        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = $out | ForEach-Object { $_.ToString() }
        }
    }

    $job = Start-Job -ScriptBlock $runner -ArgumentList @($FilePath, $ArgumentList, $WorkingDirectory)

    try {
        Wait-Job -Job $job | Out-Null
        $result = Receive-Job -Job $job -ErrorAction Stop

        $outputLines = @($result.Output)

        if ($result.ExitCode -ne 0) {
            $outputText = ($outputLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine

            if ([string]::IsNullOrWhiteSpace($outputText)) {
                $outputText = 'No output was captured from the process.'
            }

            throw "$FilePath failed with exit code $($result.ExitCode). $outputText"
        }

        if ($CaptureOutput) {
            return $outputLines
        }
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}
