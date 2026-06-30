function Copy-IsoContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $SourcePath,

        [Parameter(Mandatory)]
        [string]
        $DestinationPath
    )

    $newCleanDirectoryParams = @{
        Path = $DestinationPath
    }
    New-CleanDirectory @newCleanDirectoryParams

    $copyArgs = @(
        $SourcePath
        $DestinationPath
        '/E'
    )

    robocopy @copyArgs | Out-Null

    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed with exit code $LASTEXITCODE"
    }
}