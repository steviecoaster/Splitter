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
- Required binary: dism.exe (used for image discovery/export/servicing)
  - Expected from Windows: C:\Windows\System32\dism.exe
  - Verify: Get-Command dism.exe
- Required binary for ISO creation: oscdimg.exe (used by Build-BootableIso and Split-WindowsInstallMedia when building an ISO)
  - Expected ADK path is detected automatically by Get-OscdimgPath:
    - C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe
    - C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe
- Chocolatey install commands (run elevated) if needed:
  - Install Windows ADK: choco install windows-adk -y
- Permissions required to mount and dismount ISO images

## Install and Import

### From the repository root:

```powershell
Import-Module .\Splitter.psd1 -Force
Get-Command -Module Splitter
```

### From the PowerShell Gallery

#### PowerShell 7+
```powershell
Install-PSResource Splitter -Scope CurrentUser
```

#### Windows PowerShell

```powershell
Install-Module Splitter -Scope CurrentUser
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
- Build-BootableIso

## How to use Splitter

The easiest way to think about Splitter is as a 4-step workflow:

1. Split the ISO into a working media folder.
2. Inject files into that folder.
3. Add `autounattend.xml` if you want unattended setup.
4. Build the final bootable ISO.

If you only want the working folder and do not want an ISO yet, use
`-SkipBootableIso` on `Split-WindowsInstallMedia` and run `Build-BootableIso`
later.

### Recommended end-to-end example

This is the cleanest copy-paste path when you want one edition, PowerShell 7,
and an unattended install.

```powershell
Import-Module .\Splitter.psd1 -Force

$sourceIso = 'C:\ISO\Server2025.iso'
$workingRoot = 'C:\work'
$outputIso = 'C:\out\Server2025_DesktopExperience-Standard.iso'
$msiSource = 'D:\Packages\PowerShell-7.6.3-win-x64.msi'
$unattendSource = 'D:\AnswerFiles\autounattend.xml'

$mount = Mount-WindowsInstallMedia -Path $sourceIso -Verbose

$baseMedia = Join-Path $workingRoot 'BaseMedia'
New-WindowsInstallMedia -SourcePath $mount.DriveRoot -DestinationPath $baseMedia -Verbose

$baseImage = Join-Path $baseMedia 'sources\install.wim'
if (-not (Test-Path $baseImage)) {
  $baseImage = Join-Path $baseMedia 'sources\install.esd'
}

$selectedImage = Get-WindowsInstallImage -ImagePath $baseImage -Name '*Standard*'

$editionMedia = Join-Path $workingRoot 'Server2025_DesktopExperience-Standard'
New-WindowsInstallMedia -SourcePath $baseMedia -DestinationPath $editionMedia -Verbose

Remove-WindowsInstallImage -MediaRoot $editionMedia -Verbose

$destinationImage = Join-Path $editionMedia (Join-Path 'sources' ([System.IO.Path]::GetFileName($baseImage)))
Export-WindowsInstallImage -SourceImagePath $baseImage -DestinationWim $destinationImage -Image $selectedImage -Compression max -Verbose

Add-UnattendFile -MediaRoot $editionMedia -UnattendPath $unattendSource -Verbose

$payloadDir = Join-Path $editionMedia 'sources\$OEM$\$1\Install'
New-Item -Path $payloadDir -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $msiSource -Destination (Join-Path $payloadDir 'PowerShell-7.6.3-win-x64.msi') -Force

Build-BootableIso -MediaRoot $editionMedia -OutputIso $outputIso -Label 'WINSTD' -Verbose

Dismount-WindowsInstallMedia -InputObject $mount -Verbose
```

### Command reference

Use these when you already know the step you need.

```powershell
# Discover image names and indexes
$mount = Mount-WindowsInstallMedia -Path 'C:\ISO\Windows.iso' -Verbose
$imagePath = Join-Path $mount.DriveRoot 'sources\install.wim'
if (-not (Test-Path $imagePath)) {
  $imagePath = Join-Path $mount.DriveRoot 'sources\install.esd'
}
Get-WindowsInstallImage -ImagePath $imagePath | Format-Table Index, Name, Description -AutoSize
Dismount-WindowsInstallMedia -InputObject $mount -Verbose

# Split a source ISO and stop before building the ISO
Split-WindowsInstallMedia -SourceIso 'C:\ISO\Windows.iso' -EditionName 'Standard' -WorkingRoot 'C:\work' -OutputRoot 'C:\out' -SkipBootableIso -PassThru

# Split and build immediately
Split-WindowsInstallMedia -SourceIso 'C:\ISO\Windows.iso' -EditionName 'Standard', 'Datacenter' -WorkingRoot 'C:\work' -OutputRoot 'C:\out' -OutputBaseName 'WinServer_2025' -PassThru

# Inject drivers, packages, and unattend files into an existing working folder
Add-WindowsDriver -MediaRoot 'D:\Work\WindowsCustom-Standard' -DriverPath 'D:\Drivers' -Recurse -Index 1 -Verbose
Add-WindowsPackage -MediaRoot 'D:\Work\WindowsCustom-Standard' -PackagePath 'D:\Packages\kb.cab' -Index 1 -Verbose
Add-UnattendFile -MediaRoot 'D:\Work\WindowsCustom-Standard' -UnattendPath 'D:\AnswerFiles\autounattend.xml' -Verbose

# Build the final ISO from edited media
Build-BootableIso -MediaRoot 'D:\Work\WindowsCustom-Standard' -OutputIso 'D:\Out\WindowsCustom-Standard.iso' -Label 'WINSTD' -Verbose
```

### Notes

- `Split-WindowsInstallMedia` still builds the ISO by default so the common case
  stays one command.
- Use `-SkipBootableIso` when you want to stop after the media folder is ready.
- `sources\$OEM$\$1\Install` copies files to `C:\Install` on the installed OS.
- The MSI filename copied into `sources\$OEM$\$1\Install` must exactly match the
  path referenced by `autounattend.xml`.
- `FirstLogonCommands` in `autounattend.xml` is the simplest place to launch
  an MSI after setup, but it runs only after the first interactive logon.

### Verify unattend payloads before booting

Mount the finished ISO and confirm these paths exist before testing in a VM or
on hardware:

```powershell
$iso = 'C:\out\Server2025_DesktopExperience-Standard.iso'
$mount = Mount-DiskImage -ImagePath $iso -PassThru
$volume = $mount | Get-Volume
$drive = "$($volume.DriveLetter):\"

Test-Path (Join-Path $drive 'autounattend.xml')
Test-Path (Join-Path $drive 'sources\$OEM$\$1\Install\PowerShell-7.6.3-win-x64.msi')

Get-Content (Join-Path $drive 'autounattend.xml') | Select-String 'PowerShell-7.6.3-win-x64.msi'

Dismount-DiskImage -ImagePath $iso
```

If all three checks succeed, the ISO contains both the answer file and the MSI
payload at the path the sample answer file expects.

## Troubleshooting

- oscdimg.exe not found:
  - Install Windows ADK Deployment Tools.
  - Chocolatey install:
    - choco install windows-adk -y
  - Confirm path with Get-OscdimgPath after install.
- dism.exe not found:
  - Confirm with Get-Command dism.exe.
  - Use a standard Windows image with DISM available in C:\Windows\System32.
- No matching indexes found:
  - Run Example A to list available indexes and names from the source ISO.
  - Then rerun split with EditionName values that match Name or Description.
  - Wildcards are supported, for example '*Enterprise*'.
- Mount or dismount failures:
  - Ensure elevated privileges and that no process has files locked in the mounted media.
- DISM servicing errors:
  - Check DISM output and confirm package/driver compatibility with the target image index.
