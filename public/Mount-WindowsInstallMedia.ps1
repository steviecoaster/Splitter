<#
.SYNOPSIS
Mounts a Windows ISO and returns media details.

.DESCRIPTION
Mounts a Windows install ISO and returns an object containing the mounted drive root,
volume details, and source image path for downstream commands.

.PARAMETER Path
Path to the ISO file to mount.

.EXAMPLE
Mount-WindowsInstallMedia -Path 'D:\ISO\Win.iso' -Verbose
#>
function Mount-WindowsInstallMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolvePathParams = @{
        LiteralPath = $Path
        ErrorAction = 'Stop'
    }
    $resolvedPath = Resolve-Path @resolvePathParams
    $imagePath = $resolvedPath.ProviderPath

    $getItemParams = @{
        LiteralPath = $imagePath
        ErrorAction = 'Stop'
    }
    $imageFile = Get-Item @getItemParams

    if ($imageFile.PSIsContainer) {
        throw "Path must point to an ISO file, not a directory: $imagePath"
    }

    if ($imageFile.Length -le 0) {
        throw "ISO file is empty: $imagePath"
    }

    Write-Verbose "Mounting image: $imagePath"
    $mountDiskImageParams = @{
        ImagePath = $imagePath
        PassThru = $true
        ErrorAction = 'Stop'
    }
    $stagedImagePath = $null

    try {
        $diskImage = Mount-DiskImage @mountDiskImageParams
    }
    catch {
        Write-Verbose "Mount from source path failed: $($_.Exception.Message)"
        Write-Verbose "Staging ISO to a local temp path and retrying mount."

        $stageRoot = Join-Path $env:TEMP 'Splitter\MountedIsos'
        $newStageRootParams = @{
            Path = $stageRoot
            ItemType = 'Directory'
            Force = $true
        }
        New-Item @newStageRootParams | Out-Null

        $stagedImagePath = Join-Path $stageRoot ("{0}.iso" -f [guid]::NewGuid().ToString('N'))
        $copyItemParams = @{
            LiteralPath = $imagePath
            Destination = $stagedImagePath
            Force = $true
            ErrorAction = 'Stop'
        }
        Copy-Item @copyItemParams

        Write-Verbose "Retrying mount with staged image: $stagedImagePath"
        $mountDiskImageParams.ImagePath = $stagedImagePath
        $diskImage = Mount-DiskImage @mountDiskImageParams
    }

    $getVolumeParams = @{
        DiskImage = $diskImage
        ErrorAction = 'Stop'
    }
    $volume = Get-Volume @getVolumeParams

    if (-not $volume.DriveLetter) {
        throw "Mounted image did not expose a drive letter."
    }

    [pscustomobject]@{
        ImagePath = [string] $mountDiskImageParams.ImagePath
        SourceImagePath = $imagePath
        StagedImagePath = $stagedImagePath
        DriveLetter = [string] $volume.DriveLetter
        DriveRoot = "{0}:\" -f $volume.DriveLetter
        DiskImage = $diskImage
        Volume = $volume
    }
}
