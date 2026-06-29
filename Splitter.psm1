$private = Get-ChildItem "$PSScriptRoot\private\*.ps1" | Sort-Object Name
$public = Get-ChildItem "$PSScriptRoot\public\*.ps1" | Sort-Object Name

foreach ($file in @($private + $public)) {
    . $file.FullName
}

$exportedFunctions = $public | ForEach-Object {
    [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
}

$exportModuleMemberParams = @{
    Function = $exportedFunctions
}
Export-ModuleMember @exportModuleMemberParams