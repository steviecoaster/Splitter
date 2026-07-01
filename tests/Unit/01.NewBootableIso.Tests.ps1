Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe -Name 'New-BootableIso unit' {
    BeforeAll {
        $script:moduleManifest = Resolve-Path -LiteralPath (Join-Path (Get-Location) 'Splitter.psd1')
        Import-Module $script:moduleManifest -Force
        $script:module = Get-Module Splitter
    }

    AfterEach {
        if ($script:scenarioRoot -and (Test-Path -LiteralPath $script:scenarioRoot)) {
            Remove-Item -LiteralPath $script:scenarioRoot -Recurse -Force
        }

        $script:scenarioRoot = $null
    }

    It 'creates the output directory before invoking oscdimg' {
        $script:scenarioRoot = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
        $mediaRoot = Join-Path $script:scenarioRoot 'media'

        New-Item -Path (Join-Path $mediaRoot 'boot') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $mediaRoot 'efi\microsoft\boot') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $mediaRoot 'boot\etfsboot.com') -Value 'stub'
        Set-Content -LiteralPath (Join-Path $mediaRoot 'efi\microsoft\boot\efisys.bin') -Value 'stub'

        $outputIso = Join-Path $script:scenarioRoot 'out\nested\probe.iso'

        {
            & $script:module {
                param(
                    $IsoPath,
                    $Root
                )

                New-BootableIso -OscdimgPath 'C:\does-not-exist\oscdimg.exe' -MediaRoot $Root -OutputIso $IsoPath -Label 'PROBE'
            } $outputIso $mediaRoot
        } | Should -Throw

        (Test-Path -LiteralPath (Split-Path -Path $outputIso -Parent)) | Should -BeTrue
    }
}