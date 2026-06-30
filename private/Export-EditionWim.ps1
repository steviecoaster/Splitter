function Export-EditionWim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $SourceImagePath,

        [Parameter(Mandatory)]
        [object[]]
        $Images,

        [Parameter(Mandatory)]
        [string]
        $EditionName,

        [Parameter(Mandatory)]
        [string]
        $DestinationWim
    )

    $testDestinationWimParams = @{
        Path = $DestinationWim
    }

    if (Test-Path @testDestinationWimParams) {
        $removeDestinationWimParams = @{
            Path = $DestinationWim
            Force = $true
        }
        Remove-Item @removeDestinationWimParams
    }

    $editionImages = $Images | Where-Object {
        $_.Name -match "Windows Server 2025 $EditionName" -and
        $_.Name -notmatch 'Azure'
    }

    if (-not $editionImages) {
        throw "No Windows Server 2025 $EditionName images were found."
    }

    foreach ($image in $editionImages) {
        Write-Verbose "Exporting $($image.Name) from index $($image.Index)..."

        $exportArgs = @(
            '/Export-Image'
            "/SourceImageFile:$SourceImagePath"
            "/SourceIndex:$($image.Index)"
            "/DestinationImageFile:$DestinationWim"
            '/Compress:max'
            '/CheckIntegrity'
        )

        dism @exportArgs

        if ($LASTEXITCODE -ne 0) {
            throw "DISM export failed for $($image.Name)"
        }
    }
}