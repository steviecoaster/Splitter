function New-CleanDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $testPathParams = @{
        Path = $Path
    }
    if (Test-Path @testPathParams) {
        $removePathParams = @{
            Path = $Path
            Recurse = $true
            Force = $true
        }
        Remove-Item @removePathParams
    }

    $newItemParams = @{
        Path = $Path
        ItemType = 'Directory'
        Force = $true
    }
    New-Item @newItemParams | Out-Null
}