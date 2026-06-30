<#
.SYNOPSIS
Gets image metadata from a Windows install WIM or ESD.

.DESCRIPTION
Reads image information from an install image file and optionally filters by name or
index.

.PARAMETER ImagePath
Path to install.wim or install.esd.

.PARAMETER Name
Optional wildcard filter for image names.

.PARAMETER Index
Optional index filter.

.EXAMPLE
Get-WindowsInstallImage -ImagePath 'D:\Media\sources\install.wim'
#>
function Get-WindowsInstallImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ImagePath,

        [string[]]
        $Name,

        [int[]]
        $Index
    )

    $getImageInfoParams = @{
        ImagePath = $ImagePath
    }
    $images = Get-ImageInfo @getImageInfoParams

    if ($Name) {
        $images = $images | Where-Object {
            $currentName = $_.Name
            foreach ($nameFilter in $Name) {
                if ($currentName -like $nameFilter) {
                    return $true
                }
            }
            return $false
        }
    }

    if ($Index) {
        $images = $images | Where-Object {
            $_.Index -in $Index
        }
    }

    $images
}
