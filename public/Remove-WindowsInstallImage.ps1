<#
.SYNOPSIS
Removes install image files from a media root.

.DESCRIPTION
Removes sources\install.wim, sources\install.esd, and sources\install.swm* from a
media tree so a new install.wim can be written.

.PARAMETER MediaRoot
Path to the root of extracted Windows install media.

.EXAMPLE
Remove-WindowsInstallImage -MediaRoot 'D:\Work\Media' -Verbose
#>
function Remove-WindowsInstallImage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]
        $MediaRoot
    )

    $removePaths = @(
        (Join-Path $MediaRoot 'sources\install.wim')
        (Join-Path $MediaRoot 'sources\install.esd')
    )

    $swmPattern = Join-Path $MediaRoot 'sources\install*.swm'
    $findSwmParams = @{
        Path = $swmPattern
        ErrorAction = 'SilentlyContinue'
    }
    $swmFiles = Get-ChildItem @findSwmParams
    if ($swmFiles) {
        $removePaths += $swmFiles.FullName
    }

    foreach ($path in $removePaths) {
        $testPathParams = @{
            Path = $path
        }

        if (Test-Path @testPathParams) {
            if ($PSCmdlet.ShouldProcess($path, 'Remove-Item')) {
                Write-Verbose "Removing image file: $path"
                $removeItemParams = @{
                    Path = $path
                    Force = $true
                }
                Remove-Item @removeItemParams
            }
        }
    }
}
