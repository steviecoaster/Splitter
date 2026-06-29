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

Describe -Name 'Media file operations integration' -Tag 'Integration' -Skip:(-not $canRunIntegration) {
    BeforeAll {
        $script:moduleManifest = Resolve-Path -LiteralPath (Join-Path (Get-Location) 'Splitter.psd1')
        $script:isoPath = 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
        $script:testRoot = 'C:\work\SplitterTests'

        Import-Module $script:moduleManifest -Force
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
    }

    It 'copies media and removes install image payloads' {
        $scenarioRoot = Join-Path $script:testRoot 'MediaFileOpsRemoveInstallImage'
        $mediaRoot = Join-Path $scenarioRoot 'media'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $mount = $null
        try {
            $mount = Mount-WindowsInstallMedia -Path $script:isoPath
            New-WindowsInstallMedia -SourcePath $mount.DriveRoot -DestinationPath $mediaRoot
        }
        finally {
            if ($mount) {
                Dismount-WindowsInstallMedia -InputObject $mount
            }
        }

        $wimPath = Join-Path $mediaRoot 'sources\install.wim'
        $esdPath = Join-Path $mediaRoot 'sources\install.esd'

        ((Test-Path -LiteralPath $wimPath) -or (Test-Path -LiteralPath $esdPath)) | Should -BeTrue

        Remove-WindowsInstallImage -MediaRoot $mediaRoot

        (Test-Path -LiteralPath $wimPath) | Should -BeFalse
        (Test-Path -LiteralPath $esdPath) | Should -BeFalse
    }

    It 'adds unattend file at requested relative path' {
        $scenarioRoot = Join-Path $script:testRoot 'MediaFileOpsAddUnattend'
        $mediaRoot = Join-Path $scenarioRoot 'media'

        if (Test-Path -LiteralPath $scenarioRoot) {
            Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
        }
        New-Item -Path $scenarioRoot -ItemType Directory -Force | Out-Null

        $mount = $null
        try {
            $mount = Mount-WindowsInstallMedia -Path $script:isoPath
            New-WindowsInstallMedia -SourcePath $mount.DriveRoot -DestinationPath $mediaRoot
        }
        finally {
            if ($mount) {
                Dismount-WindowsInstallMedia -InputObject $mount
            }
        }

        $unattendPath = Join-Path $scenarioRoot 'autounattend.xml'
        @'
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE" />
</unattend>
'@ | Set-Content -LiteralPath $unattendPath -Encoding UTF8

        Add-UnattendFile -MediaRoot $mediaRoot -UnattendPath $unattendPath -DestinationRelativePath 'sources\autounattend.xml'

        $destinationPath = Join-Path $mediaRoot 'sources\autounattend.xml'
        (Test-Path -LiteralPath $destinationPath) | Should -BeTrue
    }
}
