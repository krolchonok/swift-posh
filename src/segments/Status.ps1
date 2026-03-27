Set-StrictMode -Version Latest

function global:Get-SwiftPoshSegmentStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    if ($Context.Success) {
        return $null
    }

    $code = if ($null -ne $Context.NativeExitCode -and $Context.NativeExitCode -ne 0) {
        $Context.NativeExitCode
    } else {
        1
    }

    @{
        Text       = "- $code"
        Foreground = 'BrightRed'
    }
}
