$private = Get-ChildItem "$PSScriptRoot\private\*.ps1" | Sort-Object Name
$public = Get-ChildItem "$PSScriptRoot\public\*.ps1" | Sort-Object Name

foreach ($file in @($private + $public)) {
    . $file.FullName
}

try {
    $null = Get-OscdimgPath -ErrorAction Stop
}
catch {
    throw "Missing required binary: oscdimg.exe (DISM intentionally excluded). Install with 'choco install windows-adk -y'. $($_.Exception.Message)"
}

