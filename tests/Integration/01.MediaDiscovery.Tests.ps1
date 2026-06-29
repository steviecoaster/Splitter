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

Describe -Name 'Media discovery integration' -Tag 'Integration' -Skip:(-not $canRunIntegration) {
    BeforeAll {
        $script:moduleManifest = Resolve-Path -LiteralPath (Join-Path (Get-Location) 'Splitter.psd1')
        $script:isoPath = 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'

        Import-Module $script:moduleManifest -Force

        $script:mount = Mount-WindowsInstallMedia -Path $script:isoPath
        $script:installImagePath = Join-Path $script:mount.DriveRoot 'sources\install.wim'

        if (-not (Test-Path -LiteralPath $script:installImagePath)) {
            $script:installImagePath = Join-Path $script:mount.DriveRoot 'sources\install.esd'
        }

        if (-not (Test-Path -LiteralPath $script:installImagePath)) {
            throw 'Could not find install.wim or install.esd in mounted media.'
        }

        $script:images = @(Get-WindowsInstallImage -ImagePath $script:installImagePath)
    }

    AfterAll {
        if ($script:mount) {
            Dismount-WindowsInstallMedia -InputObject $script:mount
        }
    }

    It 'mounts media and exposes a drive root' {
        $script:mount | Should -Not -BeNullOrEmpty
        $script:mount.DriveRoot | Should -Match '^[A-Z]:\\$'
        (Test-Path -LiteralPath $script:mount.DriveRoot) | Should -BeTrue
    }

    It 'finds install.wim or install.esd' {
        (Test-Path -LiteralPath $script:installImagePath) | Should -BeTrue
    }

    It 'reads image metadata with index and name' {
        $script:images.Count | Should -BeGreaterThan 0
        ($script:images | Where-Object { $_.Index -is [int] }).Count | Should -Be $script:images.Count
        ($script:images | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }).Count | Should -Be $script:images.Count
    }

    It 'supports index filtering' {
        $firstIndex = $script:images[0].Index
        $filtered = @(Get-WindowsInstallImage -ImagePath $script:installImagePath -Index $firstIndex)

        $filtered.Count | Should -Be 1
        $filtered[0].Index | Should -Be $firstIndex
    }
}
