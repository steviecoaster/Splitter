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

Describe -Name 'Split core integration' -Tag 'Integration' -Skip:(-not $canRunIntegration) {
    BeforeAll {
        $script:moduleManifest = Resolve-Path -LiteralPath (Join-Path (Get-Location) 'Splitter.psd1')
        $script:isoPath = 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
        $script:testRoot = 'C:\work\SplitterTests'

        Import-Module $script:moduleManifest -Force

        $mount = $null
        try {
            $mount = Mount-WindowsInstallMedia -Path $script:isoPath
            $imagePath = Join-Path $mount.DriveRoot 'sources\install.wim'
            if (-not (Test-Path -LiteralPath $imagePath)) {
                $imagePath = Join-Path $mount.DriveRoot 'sources\install.esd'
            }

            $script:images = @(Get-WindowsInstallImage -ImagePath $imagePath)
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

    It 'splits Standard and Datacenter with custom base name' {
        if (-not ($script:images | Where-Object { $_.Name -like '*Standard*' })) {
            Set-ItResult -Skipped -Because 'No Standard image found in ISO.'
        }

        if (-not ($script:images | Where-Object { $_.Name -like '*Datacenter*' })) {
            Set-ItResult -Skipped -Because 'No Datacenter image found in ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'SplitCoreStandardDatacenter'
        $workingRoot = Join-Path $scenarioRoot 'work'
        $outputRoot = Join-Path $scenarioRoot 'out'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $result = @(Split-WindowsInstallMedia -SourceIso $script:isoPath -EditionName @('Standard', 'Datacenter') -WorkingRoot $workingRoot -OutputRoot $outputRoot -OutputBaseName 'WinServer_2025' -PassThru)

        $result.Count | Should -Be 2
        ($result | ForEach-Object { [System.IO.Path]::GetFileName($_.OutputIso) }) | Should -Contain 'WinServer_2025-Standard.iso'
        ($result | ForEach-Object { [System.IO.Path]::GetFileName($_.OutputIso) }) | Should -Contain 'WinServer_2025-Datacenter.iso'
    }

    It 'supports OutputBaseName alias BaseIsoName' {
        if (-not ($script:images | Where-Object { $_.Name -like '*Standard*' })) {
            Set-ItResult -Skipped -Because 'No Standard image found in ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'SplitCoreBaseIsoAlias'
        $workingRoot = Join-Path $scenarioRoot 'work'
        $outputRoot = Join-Path $scenarioRoot 'out'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $result = @(Split-WindowsInstallMedia -SourceIso $script:isoPath -EditionName @('Standard') -WorkingRoot $workingRoot -OutputRoot $outputRoot -BaseIsoName 'ServerAlias' -PassThru)

        $result.Count | Should -Be 1
        [System.IO.Path]::GetFileName($result[0].OutputIso) | Should -Be 'ServerAlias-Standard.iso'
    }

    It 'can skip automatic ISO build' {
        if (-not ($script:images | Where-Object { $_.Name -like '*Standard*' })) {
            Set-ItResult -Skipped -Because 'No Standard image found in ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'SplitCoreSkipIsoBuild'
        $workingRoot = Join-Path $scenarioRoot 'work'
        $outputRoot = Join-Path $scenarioRoot 'out'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $result = @(Split-WindowsInstallMedia -SourceIso $script:isoPath -EditionName @('Standard') -WorkingRoot $workingRoot -OutputRoot $outputRoot -BaseIsoName 'SkipIsoBuild' -SkipBootableIso -PassThru)

        $result.Count | Should -Be 1
        $result[0].IsoBuilt | Should -BeFalse
        (Join-Path $outputRoot 'SkipIsoBuild-Standard.iso') | Should -Be $result[0].OutputIso
        (Test-Path -LiteralPath $result[0].OutputIso) | Should -BeFalse
        (Test-Path -LiteralPath $result[0].MediaRoot) | Should -BeTrue
    }
}
