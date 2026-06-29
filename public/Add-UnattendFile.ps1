<#
.SYNOPSIS
Adds an unattend XML file to Windows install media.

.DESCRIPTION
Copies an unattend XML file into the media root or a specified relative destination
path.

.PARAMETER MediaRoot
Path to the root of extracted Windows install media.

.PARAMETER UnattendPath
Path to the unattend XML file.

.PARAMETER DestinationRelativePath
Relative path under MediaRoot where the file will be placed.

.EXAMPLE
Add-UnattendFile -MediaRoot 'D:\Work\Media' -UnattendPath '.\autounattend.xml' -Verbose
#>
function Add-UnattendFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $MediaRoot,

        [Parameter(Mandatory)]
        [string] $UnattendPath,

        [string] $DestinationRelativePath = 'autounattend.xml'
    )

    $resolveUnattendPathParams = @{
        Path = $UnattendPath
    }
    $resolvedUnattendPath = Resolve-Path @resolveUnattendPathParams

    $destinationPath = Join-Path $MediaRoot $DestinationRelativePath
    $destinationDirectory = Split-Path -Path $destinationPath -Parent

    $newDestinationDirectoryParams = @{
        Path = $destinationDirectory
        ItemType = 'Directory'
        Force = $true
    }
    New-Item @newDestinationDirectoryParams | Out-Null

    if ($PSCmdlet.ShouldProcess($destinationPath, 'Copy unattend file')) {
        Write-Verbose "Copying unattend file to $destinationPath"
        $copyItemParams = @{
            Path = $resolvedUnattendPath
            Destination = $destinationPath
            Force = $true
        }
        Copy-Item @copyItemParams
    }
}
