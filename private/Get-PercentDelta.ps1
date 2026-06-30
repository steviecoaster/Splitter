function Get-PercentDelta {
    param(
        [Parameter(Mandatory)]
        [long]
        $Base,

        [Parameter(Mandatory)]
        [long]
        $Current
    )

    if ($Base -le 0) {
        return [double] 0
    }

    return [math]::Round((($Current - $Base) / [double] $Base) * 100, 2)
}