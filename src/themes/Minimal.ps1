Set-StrictMode -Version Latest

function global:Get-SwiftPoshThemeMinimal {
    [CmdletBinding()]
    param()

    @{
        Name = 'Minimal'
        Render = {
            param(
                [string[]]$RenderedSegments,
                [hashtable]$Context,
                [hashtable]$Config
            )

            $symbolAnsi = Get-SwiftPoshAnsi -Foreground 'Cyan'
            $symbol = "$($symbolAnsi.Prefix)$($Config.PromptSymbol)$($symbolAnsi.Suffix)"

            $line = ($RenderedSegments -join '  ').Trim()
            "$line`n$symbol "
        }
    }
}
