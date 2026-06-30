<#
.SYNOPSIS
Adds one or more packages into install image indexes.

.DESCRIPTION
Mounts selected indexes from the install image in media, adds package files, and
commits changes back to the image.

.PARAMETER MediaRoot
Path to the root of extracted Windows install media.

.PARAMETER PackagePath
Path to a package file (.cab or .msu).

.PARAMETER Index
Optional index numbers to service. Defaults to all indexes.

.PARAMETER IgnoreCheck
Skips applicability checks.

.PARAMETER PreventPending
Skips package additions if the image has pending actions.

.PARAMETER MountRoot
Temporary root path used for DISM mount operations.

.EXAMPLE
Add-WindowsPackage -MediaRoot 'D:\Work\Media' -PackagePath '.\kb.cab' -Index 1 -Verbose
#>
function Add-WindowsPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]
        $MediaRoot,

        [Parameter(Mandatory)]
        [string]
        $PackagePath,

        [int[]]
        $Index,

        [switch]
        $IgnoreCheck,

        [switch]
        $PreventPending,

        [string]
        $MountRoot = (Join-Path $env:TEMP 'SplitterMounts')
    )

    $resolvePackagePathParams = @{
        Path = $PackagePath
    }
    $resolvedPackagePath = Resolve-Path @resolvePackagePathParams

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
            if ($PSCmdlet.ShouldProcess($target, 'Add package')) {
                Write-Verbose "Adding package $resolvedPackagePath"
                $addPackageArgs = @(
                    "/Image:$mountPath"
                    '/Add-Package'
                    "/PackagePath:$resolvedPackagePath"
                )

                if ($IgnoreCheck) {
                    $addPackageArgs += '/IgnoreCheck'
                }

                if ($PreventPending) {
                    $addPackageArgs += '/PreventPending'
                }

                try {
                    $invokeAddPackageProcessParams = @{
                        FilePath = 'dism.exe'
                        ArgumentList = $addPackageArgs
                    }
                    Invoke-NativeProcess @invokeAddPackageProcessParams
                }
                catch {
                    throw "Failed to add package to image index $($image.Index). $($_.Exception.Message)"
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
