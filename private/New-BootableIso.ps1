function New-BootableIso {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $OscdimgPath,

        [Parameter(Mandatory)]
        [string]
        $MediaRoot,

        [Parameter(Mandatory)]
        [string]
        $OutputIso,

        [Parameter(Mandatory)]
        [string]
        $Label
    )

    $etfsboot = Join-Path $MediaRoot 'boot\etfsboot.com'
    $efisys = Join-Path $MediaRoot 'efi\microsoft\boot\efisys.bin'

    $testEtfsbootParams = @{
        Path = $etfsboot
    }
    if (-not (Test-Path @testEtfsbootParams)) {
        throw "Missing BIOS boot file: $etfsboot"
    }

    $testEfisysParams = @{
        Path = $efisys
    }
    if (-not (Test-Path @testEfisysParams)) {
        throw "Missing UEFI boot file: $efisys"
    }

    $outputIsoParent = Split-Path -Path $OutputIso -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputIsoParent)) {
        $newOutputDirectoryParams = @{
            Path = $outputIsoParent
            ItemType = 'Directory'
            Force = $true
        }
        New-Item @newOutputDirectoryParams | Out-Null
    }

    $testOutputIsoParams = @{
        Path = $OutputIso
    }
    if (Test-Path @testOutputIsoParams) {
        $removeOutputIsoParams = @{
            Path = $OutputIso
            Force = $true
        }
        Remove-Item @removeOutputIsoParams
    }

    $oscdimgArgs = @(
        '-m'
        '-o'
        '-u2'
        "-l$Label"
        "-bootdata:2#p0,e,b$etfsboot#pEF,e,b$efisys"
        $MediaRoot
        $OutputIso
    )

    try {
        $invokeNativeProcessParams = @{
            FilePath = $OscdimgPath
            ArgumentList = $oscdimgArgs
            ErrorAction = 'Stop'
        }
        Invoke-NativeProcess @invokeNativeProcessParams
    }
    catch {
        throw "oscdimg failed while creating $OutputIso. $($_.Exception.Message)"
    }
}