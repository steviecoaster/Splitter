Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$isElevated = $false
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch {
    $isElevated = $false
}
$canRunIntegration = $isElevated -and (Test-Path -LiteralPath 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso')

Describe -Name 'Export image integration' -Tag 'Integration' -Skip:(-not $canRunIntegration) {
    BeforeAll {
        $script:moduleManifest = Resolve-Path -LiteralPath (Join-Path (Get-Location) 'Splitter.psd1')
        $script:isoPath = 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
        $script:testRoot = 'C:\work\SplitterTests'
        $script:stagedSourceRoot = Join-Path $script:testRoot 'ExportImageSource'
        $script:stagedSourceImagePath = Join-Path $script:stagedSourceRoot 'install.source.wim'

        Import-Module $script:moduleManifest -Force

        if (Test-Path -LiteralPath $script:stagedSourceRoot) {
            Remove-Item -LiteralPath $script:stagedSourceRoot -Recurse -Force
        }
        New-Item -Path $script:stagedSourceRoot -ItemType Directory -Force | Out-Null

        $mount = $null
        try {
            $mount = Mount-WindowsInstallMedia -Path $script:isoPath
            $sourceImagePath = Join-Path $mount.DriveRoot 'sources\install.wim'

            if (-not (Test-Path -LiteralPath $sourceImagePath)) {
                $sourceImagePath = Join-Path $mount.DriveRoot 'sources\install.esd'
            }

            Copy-Item -LiteralPath $sourceImagePath -Destination $script:stagedSourceImagePath -Force

            $script:allImages = @(Get-WindowsInstallImage -ImagePath $script:stagedSourceImagePath)
        }
        finally {
            if ($mount) {
                Dismount-WindowsInstallMedia -InputObject $mount
            }
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
    }

    It 'exports selected image indexes to a new WIM' {
        if (-not $script:allImages) {
            Set-ItResult -Skipped -Because 'No source images discovered in test ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'ExportImageSingle'
        $outputWim = Join-Path $scenarioRoot 'install.single.wim'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $selectedImage = @($script:allImages | Select-Object -First 1)

        Export-WindowsInstallImage -SourceImagePath $script:stagedSourceImagePath -DestinationWim $outputWim -Image $selectedImage

        (Test-Path -LiteralPath $outputWim) | Should -BeTrue

        $exportedImages = @(Get-WindowsInstallImage -ImagePath $outputWim)
        $exportedImages.Count | Should -Be 1
        $exportedImages[0].Index | Should -Be 1
    }
}
