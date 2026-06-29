function Get-InstallImagePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $MediaRoot
    )

    $wimPath = Join-Path $MediaRoot 'sources\install.wim'
    $esdPath = Join-Path $MediaRoot 'sources\install.esd'

    $testWimPathParams = @{
        Path = $wimPath
    }
    if (Test-Path @testWimPathParams) {
        return $wimPath
    }

    $testEsdPathParams = @{
        Path = $esdPath
    }
    if (Test-Path @testEsdPathParams) {
        return $esdPath
    }

    throw "Could not find sources\install.wim or sources\install.esd"
}