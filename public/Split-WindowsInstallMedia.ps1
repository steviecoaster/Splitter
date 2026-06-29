<#
.SYNOPSIS
Splits a Windows ISO into edition-specific install media and ISOs.

.DESCRIPTION
Mounts a source Windows ISO, stages base media, creates one media copy per requested
edition, exports matching image indexes, and builds bootable output ISOs.

.PARAMETER SourceIso
Path to the source ISO.

.PARAMETER EditionName
Edition names used to match install image names, such as Standard or Datacenter.

.PARAMETER WorkingRoot
Path for intermediate working files.

.PARAMETER OutputRoot
Path for generated ISO output files.

.PARAMETER OutputBaseName
Base file name prefix for generated ISO files.

.PARAMETER BaseIsoName
Alias of OutputBaseName.

.PARAMETER IsoBaseName
Alias of OutputBaseName.

.PARAMETER LabelPrefix
Prefix used when generating ISO labels.

.PARAMETER EditionLabelMap
Optional hashtable for explicit per-edition ISO labels.

.PARAMETER IncludeDesktopExperience
When set, only indexes with "Desktop Experience" in the name or description are
included.

.PARAMETER IncludeServerCore
When set, only indexes without "Desktop Experience" in the name or description are
included.

.PARAMETER DesktopExperience
Alias of IncludeDesktopExperience.

.PARAMETER ServerCore
Alias of IncludeServerCore.

.PARAMETER PassThru
Returns result objects for each generated edition.

.EXAMPLE
Split-WindowsInstallMedia -SourceIso '.\Windows.iso' -EditionName Standard, Datacenter -WorkingRoot '.\work' -OutputRoot '.\out' -Verbose

.EXAMPLE
Split-WindowsInstallMedia -SourceIso '.\WindowsServer.iso' -EditionName Standard, Datacenter -WorkingRoot 'C:\work' -OutputRoot 'C:\out' -OutputBaseName 'WinServer_2025' -Verbose

Creates output files like WinServer_2025-Standard.iso and WinServer_2025-Datacenter.iso.

.EXAMPLE
Split-WindowsInstallMedia -SourceIso '.\WindowsServer.iso' -EditionName Standard -DesktopExperience -WorkingRoot 'C:\work' -OutputRoot 'C:\out' -OutputBaseName 'WinServer_2025' -Verbose

Includes only Standard indexes that contain Desktop Experience.
#>
function Split-WindowsInstallMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourceIso,

        [Parameter(Mandatory)]
        [string[]] $EditionName,

        [Parameter(Mandatory)]
        [string] $WorkingRoot,

        [Parameter(Mandatory)]
        [string] $OutputRoot,

        [Alias('BaseIsoName', 'IsoBaseName')]
        [string] $OutputBaseName,

        [string] $LabelPrefix = 'WIN',

        [hashtable] $EditionLabelMap,

        [Alias('DesktopExperience')]
        [switch] $IncludeDesktopExperience,

        [Alias('ServerCore')]
        [switch] $IncludeServerCore,

        [switch] $PassThru
    )

    function Format-ByteSize {
        param(
            [Parameter(Mandatory)]
            [long] $Bytes
        )

        if ($Bytes -lt 1KB) {
            return "$Bytes B"
        }

        if ($Bytes -lt 1MB) {
            return ('{0:N2} KB' -f ($Bytes / 1KB))
        }

        if ($Bytes -lt 1GB) {
            return ('{0:N2} MB' -f ($Bytes / 1MB))
        }

        return ('{0:N2} GB' -f ($Bytes / 1GB))
    }

    function Get-PercentDelta {
        param(
            [Parameter(Mandatory)]
            [long] $Base,

            [Parameter(Mandatory)]
            [long] $Current
        )

        if ($Base -le 0) {
            return [double] 0
        }

        return [math]::Round((($Current - $Base) / [double] $Base) * 100, 2)
    }

    $resolvePathParams = @{
        LiteralPath = $SourceIso
        ErrorAction = 'Stop'
    }
    $resolvedSourceIso = Resolve-Path @resolvePathParams
    $sourceIsoPath = $resolvedSourceIso.ProviderPath
    $sourceIsoSizeBytes = (Get-Item -LiteralPath $sourceIsoPath).Length

    if (-not $OutputBaseName) {
        $outputBaseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceIsoPath)
    }

    $newWorkingRootParams = @{
        Path = $WorkingRoot
        ItemType = 'Directory'
        Force = $true
    }
    New-Item @newWorkingRootParams | Out-Null

    $newOutputRootParams = @{
        Path = $OutputRoot
        ItemType = 'Directory'
        Force = $true
    }
    New-Item @newOutputRootParams | Out-Null

    $getOscdimgPathParams = @{
    }
    $oscdimgPath = Get-OscdimgPath @getOscdimgPathParams

    $mount = $null

    try {
        $mountWindowsInstallMediaParams = @{
            Path = $sourceIsoPath
        }
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $mountWindowsInstallMediaParams.Verbose = $true
        }
        $mount = Mount-WindowsInstallMedia @mountWindowsInstallMediaParams

        $baseMedia = Join-Path $WorkingRoot 'BaseMedia'
        $newBaseMediaParams = @{
            SourcePath = $mount.DriveRoot
            DestinationPath = $baseMedia
        }
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $newBaseMediaParams.Verbose = $true
        }
        New-WindowsInstallMedia @newBaseMediaParams

        $getInstallImagePathParams = @{
            MediaRoot = $baseMedia
        }
        $sourceImagePath = Get-InstallImagePath @getInstallImagePathParams
        $sourceImageExtension = [System.IO.Path]::GetExtension($sourceImagePath).ToLowerInvariant()
        $destinationImageFileName = if ($sourceImageExtension -eq '.esd') { 'install.esd' } else { 'install.wim' }
        $imageCompression = if ($sourceImageExtension -eq '.esd') { 'recovery' } else { 'max' }
        $sourceImageSizeBytes = (Get-Item -LiteralPath $sourceImagePath).Length

        Write-Verbose ("Source ISO: {0} ({1})" -f (Format-ByteSize -Bytes $sourceIsoSizeBytes), $sourceIsoPath)
        Write-Verbose ("Source image payload: {0} ({1})" -f (Format-ByteSize -Bytes $sourceImageSizeBytes), [System.IO.Path]::GetFileName($sourceImagePath))

        $getWindowsInstallImageParams = @{
            ImagePath = $sourceImagePath
        }
        $allImages = Get-WindowsInstallImage @getWindowsInstallImageParams

        $results = @()

        foreach ($edition in $EditionName) {
            $editionPattern = if ($edition -match '[\*\?\[]') {
                $edition
            }
            else {
                "*$edition*"
            }

            $matchingImages = $allImages | Where-Object {
                $_.Name -like $editionPattern -or
                $_.Description -like $editionPattern
            }

            if ($IncludeDesktopExperience -xor $IncludeServerCore) {
                if ($IncludeDesktopExperience) {
                    $matchingImages = $matchingImages | Where-Object {
                        $_.Name -like '*Desktop Experience*' -or
                        $_.Description -like '*Desktop Experience*'
                    }
                }

                if ($IncludeServerCore) {
                    $matchingImages = $matchingImages | Where-Object {
                        $_.Name -notlike '*Desktop Experience*' -and
                        $_.Description -notlike '*Desktop Experience*'
                    }
                }
            }

            if (-not $matchingImages) {
                $availableImagesText = ($allImages | ForEach-Object {
                    "[{0}] {1}" -f $_.Index, $_.Name
                }) -join '; '

                if ($IncludeDesktopExperience -and -not $IncludeServerCore) {
                    $flavorText = " and flavor 'Desktop Experience'"
                }
                elseif ($IncludeServerCore -and -not $IncludeDesktopExperience) {
                    $flavorText = " and flavor 'Server Core'"
                }
                else {
                    $flavorText = ''
                }

                throw "No install image indexes matched edition filter '$edition'$flavorText. Available images: $availableImagesText"
            }

            $safeEdition = ($edition -replace '[^A-Za-z0-9]+', '-').Trim('-')
            if ([string]::IsNullOrWhiteSpace($safeEdition)) {
                $safeEdition = "Edition$($matchingImages[0].Index)"
            }

            $editionMediaRoot = Join-Path $WorkingRoot ("{0}-{1}" -f $outputBaseName, $safeEdition)
            $newEditionMediaParams = @{
                SourcePath = $baseMedia
                DestinationPath = $editionMediaRoot
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $newEditionMediaParams.Verbose = $true
            }
            New-WindowsInstallMedia @newEditionMediaParams

            $removeWindowsInstallImageParams = @{
                MediaRoot = $editionMediaRoot
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $removeWindowsInstallImageParams.Verbose = $true
            }
            Remove-WindowsInstallImage @removeWindowsInstallImageParams

            $destinationImagePath = Join-Path $editionMediaRoot (Join-Path 'sources' $destinationImageFileName)
            $exportWindowsInstallImageParams = @{
                SourceImagePath = $sourceImagePath
                DestinationWim = $destinationImagePath
                Image = $matchingImages
                Compression = $imageCompression
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $exportWindowsInstallImageParams.Verbose = $true
            }
            Export-WindowsInstallImage @exportWindowsInstallImageParams

            $destinationImageSizeBytes = (Get-Item -LiteralPath $destinationImagePath).Length

            $isoFileName = '{0}-{1}.iso' -f $outputBaseName, $safeEdition
            $outputIsoPath = Join-Path $OutputRoot $isoFileName

            if ($EditionLabelMap -and $EditionLabelMap.ContainsKey($edition)) {
                $isoLabel = [string] $EditionLabelMap[$edition]
            }
            else {
                $isoLabel = ('{0}{1}' -f $LabelPrefix, $safeEdition).ToUpperInvariant()
                $isoLabel = $isoLabel -replace '[^A-Z0-9]', ''
                if ($isoLabel.Length -gt 32) {
                    $isoLabel = $isoLabel.Substring(0, 32)
                }

                if ([string]::IsNullOrWhiteSpace($isoLabel)) {
                    $isoLabel = 'WININSTALL'
                }
            }

            Write-Verbose "Building ISO for edition '$edition' at $outputIsoPath"
            $newBootableIsoParams = @{
                OscdimgPath = $oscdimgPath
                MediaRoot = $editionMediaRoot
                OutputIso = $outputIsoPath
                Label = $isoLabel
            }
            New-BootableIso @newBootableIsoParams

            $outputIsoSizeBytes = (Get-Item -LiteralPath $outputIsoPath).Length
            $installImageDeltaPct = Get-PercentDelta -Base $sourceImageSizeBytes -Current $destinationImageSizeBytes
            $isoDeltaPct = Get-PercentDelta -Base $sourceIsoSizeBytes -Current $outputIsoSizeBytes

            Write-Verbose ("Size report [{0}] image: {1} -> {2} ({3:N2}% delta)" -f $edition, (Format-ByteSize -Bytes $sourceImageSizeBytes), (Format-ByteSize -Bytes $destinationImageSizeBytes), $installImageDeltaPct)
            Write-Verbose ("Size report [{0}] iso: {1} -> {2} ({3:N2}% delta)" -f $edition, (Format-ByteSize -Bytes $sourceIsoSizeBytes), (Format-ByteSize -Bytes $outputIsoSizeBytes), $isoDeltaPct)

            $result = [pscustomobject]@{
                Edition = $edition
                ImageCount = @($matchingImages).Count
                MediaRoot = $editionMediaRoot
                InstallWim = $destinationImagePath
                OutputIso = $outputIsoPath
                Label = $isoLabel
                SourceIsoSizeBytes = $sourceIsoSizeBytes
                SourceInstallImageSizeBytes = $sourceImageSizeBytes
                OutputInstallImageSizeBytes = $destinationImageSizeBytes
                OutputIsoSizeBytes = $outputIsoSizeBytes
                InstallImageDeltaPercent = $installImageDeltaPct
                IsoDeltaPercent = $isoDeltaPct
            }
            $results += $result
        }

        if ($PassThru) {
            $results
        }
    }
    finally {
        if ($mount) {
            $dismountWindowsInstallMediaParams = @{
                InputObject = $mount
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) {
                $dismountWindowsInstallMediaParams.Verbose = $true
            }
            Dismount-WindowsInstallMedia @dismountWindowsInstallMediaParams
        }
    }
}
