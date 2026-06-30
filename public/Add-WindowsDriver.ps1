<#
.SYNOPSIS
Adds one or more drivers into install image indexes.

.DESCRIPTION
Mounts selected indexes from the install image in media, adds driver packages, and
commits changes back to the image.

.PARAMETER MediaRoot
Path to the root of extracted Windows install media.

.PARAMETER DriverPath
Path to a driver INF file or a folder containing drivers.

.PARAMETER Index
Optional index numbers to service. Defaults to all indexes.

.PARAMETER Recurse
Recursively searches for driver INF files when DriverPath is a folder.

.PARAMETER ForceUnsigned
Adds unsigned drivers.

.PARAMETER MountRoot
Temporary root path used for DISM mount operations.

.EXAMPLE
Add-WindowsDriver -MediaRoot 'D:\Work\Media' -DriverPath 'D:\Drivers' -Recurse -Verbose
#>
function Add-WindowsDriver {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]
        $MediaRoot,

        [Parameter(Mandatory)]
        [string]
        $DriverPath,

        [int[]]
        $Index,

        [switch]
        $Recurse,

        [switch]
        $ForceUnsigned,

        [string]
        $MountRoot = (Join-Path $env:TEMP 'SplitterMounts')
    )

    $resolveDriverPathParams = @{
        Path = $DriverPath
    }
    $resolvedDriverPath = Resolve-Path @resolveDriverPathParams

    $getInstallImagePathParams = @{
        MediaRoot = $MediaRoot
    }
    $installImagePath = Get-InstallImagePath @getInstallImagePathParams

    $getWindowsInstallImageParams = @{
        ImagePath = $installImagePath
    }
    $images = Get-WindowsInstallImage @getWindowsInstallImageParams

    if ($Index) {
        $images = $images | Where-Object {
            $_.Index -in $Index
        }
    }

    if (-not $images) {
        throw "No matching image indexes were found to service."
    }

    foreach ($image in $images) {
        $mountPath = Join-Path $MountRoot ("Image{0}" -f $image.Index)

        $newCleanDirectoryParams = @{
            Path = $mountPath
        }
        New-CleanDirectory @newCleanDirectoryParams

        Write-Verbose "Mounting image index $($image.Index) to $mountPath"
        $mountArgs = @(
            '/Mount-Image'
            "/ImageFile:$installImagePath"
            "/Index:$($image.Index)"
            "/MountDir:$mountPath"
            '/CheckIntegrity'
        )

        try {
            $invokeMountProcessParams = @{
                FilePath = 'dism.exe'
                ArgumentList = $mountArgs
            }
            Invoke-NativeProcess @invokeMountProcessParams
        }
        catch {
            throw "Failed to mount image index $($image.Index). $($_.Exception.Message)"
        }

        $shouldCommit = $false
        try {
            $target = "index $($image.Index)"
            if ($PSCmdlet.ShouldProcess($target, 'Add driver')) {
                Write-Verbose "Adding driver(s) from $resolvedDriverPath"
                $addDriverArgs = @(
                    "/Image:$mountPath"
                    '/Add-Driver'
                    "/Driver:$resolvedDriverPath"
                )

                if ($Recurse) {
                    $addDriverArgs += '/Recurse'
                }

                if ($ForceUnsigned) {
                    $addDriverArgs += '/ForceUnsigned'
                }

                try {
                    $invokeAddDriverProcessParams = @{
                        FilePath = 'dism.exe'
                        ArgumentList = $addDriverArgs
                    }
                    Invoke-NativeProcess @invokeAddDriverProcessParams
                }
                catch {
                    throw "Failed to add drivers to image index $($image.Index). $($_.Exception.Message)"
                }

                $shouldCommit = $true
            }
        }
        finally {
            if ($shouldCommit) {
                Write-Verbose "Committing mounted image index $($image.Index)"
                $unmountArgs = @(
                    '/Unmount-Image'
                    "/MountDir:$mountPath"
                    '/Commit'
                )
            }
            else {
                Write-Verbose "Discarding mounted image index $($image.Index)"
                $unmountArgs = @(
                    '/Unmount-Image'
                    "/MountDir:$mountPath"
                    '/Discard'
                )
            }

            try {
                $invokeUnmountProcessParams = @{
                    FilePath = 'dism.exe'
                    ArgumentList = $unmountArgs
                }
                Invoke-NativeProcess @invokeUnmountProcessParams
            }
            catch {
                throw "Failed to unmount image index $($image.Index). $($_.Exception.Message)"
            }
        }
    }
}
