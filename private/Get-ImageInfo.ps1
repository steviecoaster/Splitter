function Get-ImageInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ImagePath
    )

    $dismArgs = @(
        '/English'
        '/Get-WimInfo'
        "/WimFile:$ImagePath"
    )

    try {
        $invokeNativeProcessParams = @{
            FilePath = 'dism.exe'
            ArgumentList = $dismArgs
            CaptureOutput = $true
            ErrorAction = 'Stop'
        }
        $output = Invoke-NativeProcess @invokeNativeProcessParams
    }
    catch {
        throw "DISM failed while reading image info for '$ImagePath'. Run from an elevated session and verify the image path is valid. $($_.Exception.Message)"
    }

    $images = @()
    $current = [ordered]@{}

    foreach ($line in $output) {
        if ($line -match '^Index\s+:\s+(\d+)') {
            if ($current.Count -gt 0) {
                $images += [pscustomobject]$current
                $current = [ordered]@{}
            }

            $current.Index = [int]$Matches[1]
        }

        if ($line -match '^Name\s+:\s+(.+)$') {
            $current.Name = $Matches[1].Trim()
        }

        if ($line -match '^Description\s+:\s+(.+)$') {
            $current.Description = $Matches[1].Trim()
        }
    }

    if ($current.Count -gt 0) {
        $images += [pscustomobject]$current
    }

    return $images
}