function Get-OscdimgPath {
    [CmdletBinding()]
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    )

    foreach ($path in $possiblePaths) {
        $testPathParams = @{
            Path = $path
        }
        if (Test-Path @testPathParams) {
            return $path
        }
    }

    throw "oscdimg.exe was not found. Install the Windows ADK Deployment Tools."
}