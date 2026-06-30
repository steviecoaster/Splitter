function Format-ByteSize {
    param(
        [Parameter(Mandatory)]
        [long]
        $Bytes
    )

    if ($Bytes -lt 1KB) {
        return "$Bytes B"
    }

    if ($Bytes -lt 1MB) {
        return ('{0:N2} KB' -f ($Bytes / 1KB))
    }

    if ($Bytes -lt 1GB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }

    return ('{0:N2} GB' -f ($Bytes / 1GB))
}