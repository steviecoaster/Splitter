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

Describe -Name 'Split flavor integration' -Tag 'Integration' -Skip:(-not $canRunIntegration) {
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
            $script:standardDesktop = @($script:images | Where-Object {
                ($_.Name -like '*Standard*' -or $_.Description -like '*Standard*') -and
                ($_.Name -like '*Desktop Experience*' -or $_.Description -like '*Desktop Experience*')
            })
            $script:standardCore = @($script:images | Where-Object {
                ($_.Name -like '*Standard*' -or $_.Description -like '*Standard*') -and
                $_.Name -notlike '*Desktop Experience*' -and
                $_.Description -notlike '*Desktop Experience*'
            })
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

    It 'splits Standard Desktop Experience flavor' {
        if (-not $script:standardDesktop) {
            Set-ItResult -Skipped -Because 'No Standard Desktop Experience image found in ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'SplitFlavorDesktop'
        $workingRoot = Join-Path $scenarioRoot 'work'
        $outputRoot = Join-Path $scenarioRoot 'out'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $result = @(Split-WindowsInstallMedia -SourceIso $script:isoPath -EditionName @('Standard') -DesktopExperience -WorkingRoot $workingRoot -OutputRoot $outputRoot -OutputBaseName 'FlavorTest' -PassThru)

        $result.Count | Should -Be 1
        $result[0].ImageCount | Should -Be $script:standardDesktop.Count
        (Test-Path -LiteralPath $result[0].OutputIso) | Should -BeTrue
    }

    It 'splits Standard Server Core flavor' {
        if (-not $script:standardCore) {
            Set-ItResult -Skipped -Because 'No Standard Server Core image found in ISO.'
        }

        $scenarioRoot = Join-Path $script:testRoot 'SplitFlavorCore'
        $workingRoot = Join-Path $scenarioRoot 'work'
        $outputRoot = Join-Path $scenarioRoot 'out'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $result = @(Split-WindowsInstallMedia -SourceIso $script:isoPath -EditionName @('Standard') -ServerCore -WorkingRoot $workingRoot -OutputRoot $outputRoot -OutputBaseName 'FlavorTest' -PassThru)

        $result.Count | Should -Be 1
        $result[0].ImageCount | Should -Be $script:standardCore.Count
        (Test-Path -LiteralPath $result[0].OutputIso) | Should -BeTrue
    }
}
