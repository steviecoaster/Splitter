<#
.SYNOPSIS
Exports one or more install image indexes into a new WIM.

.DESCRIPTION
Uses DISM export operations to build a destination install.wim containing only the
selected indexes.

.PARAMETER SourceImagePath
Source install.wim or install.esd path.

.PARAMETER DestinationWim
Destination install.wim path.

.PARAMETER Image
Image objects from Get-WindowsInstallImage containing Index and Name.

.PARAMETER Compression
DISM compression mode for destination image.

.EXAMPLE
$img = Get-WindowsInstallImage -ImagePath .\install.wim -Name '*Datacenter*'
Export-WindowsInstallImage -SourceImagePath .\install.wim -DestinationWim .\datacenter.wim -Image $img -Verbose
#>
function Export-WindowsInstallImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $SourceImagePath,

        [Parameter(Mandatory)]
        [string]
        $DestinationWim,

        [Parameter(Mandatory)]
        [object[]]
        $Image,

        [ValidateSet('none', 'fast', 'max', 'recovery')]
        [string]
        $Compression = 'max'
    )

    if (-not (Test-Path -LiteralPath $SourceImagePath)) {
        throw "Source image path was not found: $SourceImagePath"
    }

    $destinationParent = Split-Path -Path $DestinationWim -Parent
    if ([string]::IsNullOrWhiteSpace($destinationParent)) {
        throw "DestinationWim must include a parent directory: $DestinationWim"
    }

    if (-not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -Path $destinationParent -ItemType Directory -Force | Out-Null
    }

    $testDestinationWimParams = @{
        LiteralPath = $DestinationWim
    }
    if (Test-Path @testDestinationWimParams) {
        $removeDestinationWimParams = @{
            LiteralPath = $DestinationWim
            Force = $true
        }
        Remove-Item @removeDestinationWimParams
    }

    $resolvedSourceImagePath = [System.IO.Path]::GetFullPath($SourceImagePath)
    $resolvedDestinationWim = [System.IO.Path]::GetFullPath($DestinationWim)

    foreach ($currentImage in $Image) {
        if ($null -eq $currentImage.Index) {
            throw "Each image input must include an Index property."
        }

        Write-Verbose "Exporting image index $($currentImage.Index): $($currentImage.Name)"
        $dismArgs = @(
            '/Export-Image'
            "/SourceImageFile:$resolvedSourceImagePath"
            "/SourceIndex:$($currentImage.Index)"
            "/DestinationImageFile:$resolvedDestinationWim"
            "/Compress:$Compression"
            '/CheckIntegrity'
        )

        $invokeNativeProcessParams = @{
            FilePath = 'dism.exe'
            ArgumentList = $dismArgs
        }

        try {
            Invoke-NativeProcess @invokeNativeProcessParams
        }
        catch {
            throw "DISM export failed for index $($currentImage.Index). $($_.Exception.Message)"
        }
    }
}
