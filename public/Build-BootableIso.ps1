<#
.SYNOPSIS
Builds a bootable Windows ISO from a media folder.

.DESCRIPTION
Creates a bootable ISO by calling the module's ISO builder with a media root,
an output ISO path, and an ISO label. If OscdimgPath is not provided, the
command resolves it automatically.

.PARAMETER MediaRoot
Path to the root of the extracted Windows install media.

.PARAMETER OutputIso
Path where the ISO should be written.

.PARAMETER Label
Volume label for the ISO.

.PARAMETER OscdimgPath
Optional path to oscdimg.exe.

.EXAMPLE
Build-BootableIso -MediaRoot 'D:\Work\WindowsCustom-Standard' -OutputIso 'D:\Out\WindowsCustom-Standard.iso' -Label 'WINSTD' -Verbose
#>
function Build-BootableIso {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]
        $MediaRoot,

        [Parameter(Mandatory)]
        [string]
        $OutputIso,

        [Parameter(Mandatory)]
        [string]
        $Label,

        [string]
        $OscdimgPath
    )

    if (-not $OscdimgPath) {
        $OscdimgPath = Get-OscdimgPath
    }

    if ($PSCmdlet.ShouldProcess($OutputIso, 'Build bootable ISO')) {
        $newBootableIsoParams = @{
            OscdimgPath = $OscdimgPath
            MediaRoot = $MediaRoot
            OutputIso = $OutputIso
            Label = $Label
        }

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $newBootableIsoParams.Verbose = $true
        }

        New-BootableIso @newBootableIsoParams
    }
}