<#
.SYNOPSIS
Dismounts a previously mounted Windows ISO.

.DESCRIPTION
Dismounts an ISO by path or by passing the object returned from
Mount-WindowsInstallMedia.

.PARAMETER ImagePath
Path to the mounted ISO image.

.PARAMETER InputObject
Object returned by Mount-WindowsInstallMedia.

.EXAMPLE
$mount = Mount-WindowsInstallMedia -Path 'D:\ISO\Win.iso'
Dismount-WindowsInstallMedia -InputObject $mount
#>
function Dismount-WindowsInstallMedia {
    [CmdletBinding(DefaultParameterSetName = 'ByPath', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [string] $ImagePath,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [psobject] $InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByObject') {
            $ImagePath = [string] $InputObject.ImagePath
        }

        if ([string]::IsNullOrWhiteSpace($ImagePath)) {
            throw "ImagePath is required to dismount media."
        }

        if ($PSCmdlet.ShouldProcess($ImagePath, 'Dismount-DiskImage')) {
            Write-Verbose "Dismounting image: $ImagePath"
            $dismountDiskImageParams = @{
                ImagePath = $ImagePath
            }
            $null = Dismount-DiskImage @dismountDiskImageParams
        }
    }
}
