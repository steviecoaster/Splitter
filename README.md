# Splitter

Splitter is a PowerShell module for working with Windows installation ISOs and install images. It can mount media, inspect install image indexes, export selected editions, apply servicing customizations, and build edition-specific bootable ISOs.

## Features

- Edition-agnostic ISO splitting with Split-WindowsInstallMedia
- Install image discovery and export (WIM/ESD)
- Optional offline servicing support:
  - Add-WindowsDriver
  - Add-WindowsPackage
  - Add-UnattendFile
- Verbose, user-controlled progress output
- Supports WhatIf on destructive and media-modifying operations where applicable

## Requirements

- Windows with PowerShell 5.1+ or PowerShell 7+
- DISM available on the system
- Windows ADK Deployment Tools installed for oscdimg.exe
  - Expected path is detected automatically by Get-OscdimgPath
- Permissions required to mount and dismount ISO images

## Install and Import

From the repository root:

```powershell
Import-Module .\Splitter.psd1 -Force
Get-Command -Module Splitter
```

## Available Commands

The following commands are available:

### Core media and image commands:

- Mount-WindowsInstallMedia
- Dismount-WindowsInstallMedia
- Get-WindowsInstallImage
- Export-WindowsInstallImage
- Remove-WindowsInstallImage
- New-WindowsInstallMedia
- Split-WindowsInstallMedia

### Offline servicing commands:

- Add-WindowsDriver
- Add-WindowsPackage
- Add-UnattendFile

## Quick Start

### Split an ISO by edition (generic)

```powershell
Import-Module .\Splitter.psd1 -Force

$splitParams = @{
  SourceIso = 'D:\ISO\Windows.iso'
  EditionName = 'Standard', 'Datacenter'
  WorkingRoot = 'D:\Work\Splitter'
  OutputRoot = 'D:\Output'
  Verbose = $true
}

Split-WindowsInstallMedia @splitParams
```

### Split with explicit labels and output details

```powershell
$splitParams = @{
  SourceIso = 'D:\ISO\Windows.iso'
  EditionName = 'Standard', 'Datacenter'
  WorkingRoot = 'D:\Work\Splitter'
  OutputRoot = 'D:\Output'
  OutputBaseName = 'WindowsCustom'
  LabelPrefix = 'WIN'
  EditionLabelMap = @{ Standard = 'WINSTD'; Datacenter = 'WINDC' }
  PassThru = $true
  Verbose = $true
}

$result = Split-WindowsInstallMedia @splitParams

$result | Format-Table Edition, ImageCount, OutputIso, Label -AutoSize
```

### Discover valid edition filters from an ISO

Use this when you are not sure whether the ISO contains names like Standard, Datacenter, Enterprise, and so on.

```powershell
Import-Module .\Splitter.psd1 -Force

$mount = Mount-WindowsInstallMedia -Path 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso' -Verbose

$imagePath = Join-Path $mount.DriveRoot 'sources\install.wim'
if (-not (Test-Path $imagePath)) {
  $imagePath = Join-Path $mount.DriveRoot 'sources\install.esd'
}

Get-WindowsInstallImage -ImagePath $imagePath |
  Format-Table Index, Name, Description -AutoSize

Dismount-WindowsInstallMedia -InputObject $mount -Verbose
```

### Build WinServer_2025-Standard.iso and WinServer_2025-Datacenter.iso

```powershell
Import-Module .\Splitter.psd1 -Force

$splitParams = @{
  SourceIso = 'C:\LabSources\ISOs\26100.1742.240906-0331.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso'
  EditionName = 'Standard', 'Datacenter'
  WorkingRoot = 'C:\work'
  OutputRoot = 'C:\out'
  OutputBaseName = 'WinServer_2025'
  Verbose = $true
}

$result = Split-WindowsInstallMedia @splitParams
$result | Format-Table Edition, OutputIso, Label -AutoSize
```

Expected output filenames:

- C:\out\WinServer_2025-Standard.iso
- C:\out\WinServer_2025-Datacenter.iso

### Split an Enterprise-only ISO without guessing

```powershell
Import-Module .\Splitter.psd1 -Force

$splitParams = @{
  SourceIso = 'C:\LabSources\ISOs\ClientEnterpriseEval.iso'
  EditionName = '*Enterprise*'
  WorkingRoot = 'C:\work'
  OutputRoot = 'C:\out'
  OutputBaseName = 'Windows_11_Enterprise'
  PassThru = $true
  Verbose = $true
}

Split-WindowsInstallMedia @splitParams |
  Format-Table Edition, ImageCount, OutputIso -AutoSize
```

### Build only Desktop Experience or only Server Core

```powershell
Import-Module .\Splitter.psd1 -Force

# Only Desktop Experience
$desktopExperienceParams = @{
  SourceIso = 'C:\LabSources\ISOs\Server2025.iso'
  EditionName = 'Standard'
  DesktopExperience = $true
  WorkingRoot = 'C:\work'
  OutputRoot = 'C:\out'
  OutputBaseName = 'WinServer_2025'
  Verbose = $true
}

Split-WindowsInstallMedia @desktopExperienceParams

# Only Server Core
$serverCoreParams = @{
  SourceIso = 'C:\LabSources\ISOs\Server2025.iso'
  EditionName = 'Standard'
  ServerCore = $true
  WorkingRoot = 'C:\work'
  OutputRoot = 'C:\out'
  OutputBaseName = 'WinServer_2025'
  Verbose = $true
}

Split-WindowsInstallMedia @serverCoreParams
```

Note: ServerCore filtering is inferred as "not Desktop Experience" because Server
Core images typically do not include "(Desktop Experience)" in the name.

## Common Workflows

### Inspect indexes in install.wim/install.esd

```powershell
Get-WindowsInstallImage -ImagePath 'D:\Media\sources\install.wim'
Get-WindowsInstallImage -ImagePath 'D:\Media\sources\install.wim' -Name '*Datacenter*'
Get-WindowsInstallImage -ImagePath 'D:\Media\sources\install.wim' -Index 1,2
```

### Export selected indexes to a new WIM

```powershell
$images = Get-WindowsInstallImage -ImagePath 'D:\Media\sources\install.wim' -Name '*Standard*'

$exportParams = @{
  SourceImagePath = 'D:\Media\sources\install.wim'
  DestinationWim = 'D:\Media\sources\install.standard.wim'
  Image = $images
  Compression = 'max'
  Verbose = $true
}

Export-WindowsInstallImage @exportParams
```

### Add drivers to one or more indexes

```powershell
$driverParams = @{
  MediaRoot = 'D:\Work\WindowsCustom-Standard'
  DriverPath = 'D:\Drivers'
  Recurse = $true
  Index = 1
  Verbose = $true
}

Add-WindowsDriver @driverParams
```

### Add packages to one or more indexes

```powershell
$packageParams = @{
  MediaRoot = 'D:\Work\WindowsCustom-Standard'
  PackagePath = 'D:\Packages\kb.cab'
  Index = 1
  Verbose = $true
}

Add-WindowsPackage @packageParams
```

### Add unattended setup file

```powershell
$unattendParams = @{
  MediaRoot = 'D:\Work\WindowsCustom-Standard'
  UnattendPath = 'D:\AnswerFiles\autounattend.xml'
  Verbose = $true
}

Add-UnattendFile @unattendParams
```

## Troubleshooting

- oscdimg.exe not found:
  - Install Windows ADK Deployment Tools.
- No matching indexes found:
  - Run Example A to list available indexes and names from the source ISO.
  - Then rerun split with EditionName values that match Name or Description.
  - Wildcards are supported, for example '*Enterprise*'.
- Mount or dismount failures:
  - Ensure elevated privileges and that no process has files locked in the mounted media.
- DISM servicing errors:
  - Check DISM output and confirm package/driver compatibility with the target image index.
