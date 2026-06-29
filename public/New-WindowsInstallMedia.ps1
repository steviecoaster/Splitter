<#
.SYNOPSIS
Creates a new install media tree by copying source media.

.DESCRIPTION
Creates a clean destination directory and copies all source media files into it.

.PARAMETER SourcePath
Source media root path.

.PARAMETER DestinationPath
Destination media root path.

.EXAMPLE
New-WindowsInstallMedia -SourcePath 'E:\' -DestinationPath 'D:\Work\BaseMedia' -Verbose
#>
function New-WindowsInstallMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [string] $DestinationPath
    )

    Write-Verbose "Copying media from $SourcePath to $DestinationPath"
    $copyIsoContentsParams = @{
        SourcePath = $SourcePath
        DestinationPath = $DestinationPath
    }
    Copy-IsoContents @copyIsoContentsParams
}
