Set-StrictMode -Version Latest

function global:Get-SwiftPoshSegmentPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $homePath = [System.IO.Path]::GetFullPath($HOME)
    $current = [System.IO.Path]::GetFullPath($Context.Location)

    if ($current.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $current.Substring($homePath.Length).TrimStart('\', '/')
        $display = if ([string]::IsNullOrWhiteSpace($relative)) { '~' } else { "~/$relative" }
    } else {
        $display = $current
    }

    @{
        Text       = $display
        Foreground = 'BrightBlue'
    }
}
